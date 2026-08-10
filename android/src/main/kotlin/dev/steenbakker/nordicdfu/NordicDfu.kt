package dev.steenbakker.nordicdfu

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import no.nordicsemi.android.dfu.DfuBaseService
import no.nordicsemi.android.dfu.DfuBaseService.NOTIFICATION_ID
import no.nordicsemi.android.dfu.DfuProgressListener
import no.nordicsemi.android.dfu.DfuProgressListenerAdapter
import no.nordicsemi.android.dfu.DfuServiceInitiator
import no.nordicsemi.android.dfu.DfuServiceListenerHelper
import java.util.Locale

/**
 * Core Nordic DFU logic handler
 * Manages DFU processes independently of Flutter
 *
 * A device rebooting into its bootloader commonly advertises with its address incremented by one,
 * and the DFU library reports callbacks with the address of the phase currently connected. Device
 * identity is therefore carried by the listener instance rather than the address argument: each DFU
 * gets a [ScopedDfuProgressListener] bound to the address it was started with. Bootloaders using
 * some other address are picked up by [fallbackListener].
 */
class NordicDfu(private val context: Context, private val callback: DfuCallback) {

    private val activeDfuMap: MutableMap<String, DfuProcess> = mutableMapOf()
    private var hasCreatedNotification = false

    /** Per-DFU listeners, keyed by original address, kept so they can be unregistered again. */
    private val scopedListeners: MutableMap<String, DfuProgressListener> = mutableMapOf()

    /** Bootloader address -> original address, learned at runtime by [fallbackListener]. */
    private val addressAliases: MutableMap<String, String> = mutableMapOf()

    /** Every address form of recently finished processes, so late events are not re-attributed. */
    private val recentlyFinished: MutableSet<String> = LinkedHashSet()

    private var fallbackListenerRegistered = false

    companion object {
        private const val TAG = "[NordicDfu]"

        /** Bounds [recentlyFinished] to roughly one entry per parallel DFU slot. */
        private const val RECENTLY_FINISHED_LIMIT = 32

        private val DFU_SERVICE_CLASSES = arrayListOf(
            DfuService::class.java,
            DfuService2::class.java,
            DfuService3::class.java,
            DfuService4::class.java,
            DfuService5::class.java,
            DfuService6::class.java,
            DfuService7::class.java,
            DfuService8::class.java,
            // more service classes can be added here to support more parallel DFU processes
            // (make sure to also update AndroidManifest.xml)
        )
    }

    /**
     * Start a DFU process with the given configuration
     * @return true if started successfully, false otherwise
     */
    fun startDfu(config: DfuConfig): Result<Unit> {
        val starter = DfuServiceInitiator(config.address).setZip(config.filePath)

        // Configure DFU service initiator
        config.name?.let { starter.setDeviceName(it) }
        config.enableUnsafeExperimentalButtonlessServiceInSecureDfu?.let {
            starter.setUnsafeExperimentalButtonlessServiceInSecureDfuEnabled(it)
        }
        config.forceDfu?.let { starter.setForceDfu(it) }
        config.disableNotification?.let { starter.setDisableNotification(it) }
        config.startAsForegroundService?.let { starter.setForeground(it) }
        config.keepBond?.let { starter.setKeepBond(it) }
        config.restoreBond?.let { starter.setRestoreBond(it) }
        config.packetReceiptNotificationsEnabled?.let {
            starter.setPacketsReceiptNotificationsEnabled(it)
        }
        config.numberOfPackets?.let {
            starter.setPacketsReceiptNotificationsValue(it)
        }
        config.dataDelay?.let {
            starter.setPrepareDataObjectDelay(it.toLong())
        }
        config.numberOfRetries?.let {
            starter.setNumberOfRetries(it)
        }
        config.rebootTime?.let {
            starter.setRebootTime(it)
        }
        config.mbrSize?.let {
            starter.setMbrSize(it)
        }
        config.scope?.let {
            starter.setScope(it)
        }
        config.currentMtu?.let {
            starter.setCurrentMtu(it)
        }

        warnAboutAdjacentAddress(config.address)

        // Registers under both this address and the incremented one, so the listener keeps
        // receiving events after the device reboots into its bootloader.
        val scopedListener = ScopedDfuProgressListener(config.address)
        scopedListeners[config.address] = scopedListener
        DfuServiceListenerHelper.registerProgressListener(context, scopedListener, config.address)

        if (!fallbackListenerRegistered) {
            DfuServiceListenerHelper.registerProgressListener(context, fallbackListener)
            fallbackListenerRegistered = true
        }

        // Create notification channel if needed (Android 8+)
        if (config.startAsForegroundService != false) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !hasCreatedNotification) {
                DfuServiceInitiator.createDfuNotificationChannel(context)
                hasCreatedNotification = true
            }
        }

        // Get available DFU service class
        val serviceClass = getAvailableDfuServiceClass()
            ?: return Result.failure(Exception("No available DFU service slots"))

        // Start DFU service
        val controller = starter.start(context, serviceClass)

        // Store active DFU process
        activeDfuMap[config.address] = DfuProcess(
            deviceAddress = config.address,
            controller = controller,
            serviceClass = serviceClass
        )

        return Result.success(Unit)
    }

    /**
     * Abort DFU process for a specific address or all processes if address is null
     */
    fun abortDfu(address: String?): Result<Unit> {
        if (address == null) {
            // Abort all DFU processes
            if (activeDfuMap.isEmpty()) {
                return Result.failure(Exception("No active DFU processes to abort"))
            }
            activeDfuMap.values.forEach { it.controller.abort() }
            return Result.success(Unit)
        }

        // Abort DFU process for the specified address
        val process = activeDfuMap[address]
            ?: return Result.failure(Exception("No DFU process found for address: $address"))

        // Log a warning if multiple DFU processes are active
        if (activeDfuMap.size > 1) {
            Log.w(TAG, "abortDfu will abort all DFU processes")
        }

        process.controller.abort()
        return Result.success(Unit)
    }

    /**
     * Check if there's an active DFU process for the given address
     */
    fun hasActiveDfu(address: String): Boolean {
        return activeDfuMap.containsKey(address)
    }

    /**
     * Get the number of active DFU processes
     */
    fun getActiveDfuCount(): Int {
        return activeDfuMap.size
    }

    /**
     * Unregisters every progress listener and drops all tracking state. Listeners live in a static
     * map inside `DfuServiceListenerHelper`, so not unregistering them leaks this instance and its
     * context. Running DFU services are unaffected.
     */
    fun dispose() {
        scopedListeners.values.forEach {
            DfuServiceListenerHelper.unregisterProgressListener(context, it)
        }
        scopedListeners.clear()

        if (fallbackListenerRegistered) {
            DfuServiceListenerHelper.unregisterProgressListener(context, fallbackListener)
            fallbackListenerRegistered = false
        }

        activeDfuMap.clear()
        addressAliases.clear()
        recentlyFinished.clear()
    }

    private fun getAvailableDfuServiceClass(): Class<out DfuBaseService>? {
        return DFU_SERVICE_CLASSES.firstOrNull { serviceClass ->
            activeDfuMap.values.none { it.serviceClass == serviceClass }
        }
    }

    private fun cancelNotification() {
        // Wait a bit before canceling the notification to prevent it from being recreated by the service
        Handler(Looper.getMainLooper()).postDelayed({
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }, 200)
    }

    /**
     * The address a bootloader conventionally advertises with. Mirrors the DFU library's
     * `BootloaderScannerFactory.getIncrementedAddress()`, which lives in its `internal` package and
     * is therefore reimplemented rather than imported. Wrapping the last octet without carrying is
     * deliberate: deviating would disagree with the library's own listener registration.
     */
    private fun incrementedAddress(address: String): String {
        // Expects the canonical "00:11:22:33:44:55" form Android reports.
        if (address.length != 17) return address
        val lastOctet = address.substring(15).toIntOrNull(16) ?: return address
        val incremented = String.format(Locale.US, "%02X", (lastOctet + 1) and 0xFF)
        return address.substring(0, 15) + incremented
    }

    /**
     * The DFU library keys scoped listeners in a single map, so two devices with adjacent addresses
     * overwrite each other's bootloader entry. Batch provisioned devices often have adjacent
     * addresses, so surface this rather than silently misrouting one of them.
     */
    private fun warnAboutAdjacentAddress(address: String) {
        val adjacent = activeDfuMap.keys.firstOrNull { active ->
            incrementedAddress(active).equals(address, ignoreCase = true) ||
                incrementedAddress(address).equals(active, ignoreCase = true)
        } ?: return

        Log.w(
            TAG,
            "Starting DFU on $address while $adjacent is still running. Their addresses are " +
                "adjacent, so the DFU library cannot tell their bootloaders apart and callbacks " +
                "may be attributed to the wrong device. Update them one after another instead."
        )
    }

    /**
     * True when a scoped listener already covers [reportedAddress]. The DFU library dispatches to
     * it alongside [fallbackListener], so without this check events would be reported twice.
     */
    private fun isClaimedByScopedListener(reportedAddress: String): Boolean =
        scopedListeners.keys.any { original ->
            original.equals(reportedAddress, ignoreCase = true) ||
                incrementedAddress(original).equals(reportedAddress, ignoreCase = true)
        }

    /**
     * Resolves an address no scoped listener covers, or null if the event should be dropped. Only
     * reached for bootloaders using something other than the incremented address, where the only
     * unambiguous attribution is a single running DFU. The attribution is remembered, so it stays
     * stable once another DFU starts; with several already running the event is dropped rather
     * than risk resolving another device's result.
     */
    private fun resolveUnclaimedAddress(reportedAddress: String): String? {
        if (isClaimedByScopedListener(reportedAddress)) return null

        val key = reportedAddress.uppercase(Locale.US)

        addressAliases[key]?.let { original ->
            if (activeDfuMap.containsKey(original)) return original
        }

        if (recentlyFinished.contains(key)) return null

        if (activeDfuMap.size != 1) {
            Log.w(
                TAG,
                "Dropping DFU callback for unknown address $reportedAddress: ${activeDfuMap.size} " +
                    "DFUs are running, so it cannot be attributed to one of them."
            )
            return null
        }

        val inFlight = activeDfuMap.keys.first()
        Log.w(
            TAG,
            "DFU callback reported unknown address $reportedAddress. Its bootloader does not use " +
                "the incremented address, attributing it to the DFU on $inFlight."
        )
        addressAliases[key] = inFlight
        return inFlight
    }

    /** Forgets a finished process and every address that resolved to it. */
    private fun finish(originalAddress: String) {
        activeDfuMap.remove(originalAddress)

        scopedListeners.remove(originalAddress)?.let {
            DfuServiceListenerHelper.unregisterProgressListener(context, it)
        }

        // Remember every form this address could still arrive as, so a late event is dropped
        // instead of being attributed to whichever DFU runs next.
        rememberFinished(originalAddress.uppercase(Locale.US))
        rememberFinished(incrementedAddress(originalAddress).uppercase(Locale.US))
        addressAliases.entries
            .filter { it.value.equals(originalAddress, ignoreCase = true) }
            .map { it.key }
            .forEach {
                rememberFinished(it)
                addressAliases.remove(it)
            }
    }

    private fun rememberFinished(address: String) {
        recentlyFinished.remove(address) // re-insert so it counts as the most recent entry
        recentlyFinished.add(address)
        while (recentlyFinished.size > RECENTLY_FINISHED_LIMIT) {
            recentlyFinished.remove(recentlyFinished.first())
        }
    }

    // Terminal events, shared by the scoped and fallback listeners. [address] is always the
    // address the DFU was started with.

    private fun dispatchDfuCompleted(address: String) {
        cancelNotification()
        callback.onDfuCompleted(address)
        finish(address)
    }

    private fun dispatchDfuAborted(address: String) {
        cancelNotification()
        callback.onDfuAborted(address)
        finish(address)
    }

    private fun dispatchError(address: String, error: Int, errorType: Int, message: String) {
        cancelNotification()
        callback.onError(address, error, errorType, message)
        finish(address)
    }

    /** Reports one DFU's callbacks with the address it was started with. */
    private inner class ScopedDfuProgressListener(
        private val originalAddress: String
    ) : DfuProgressListenerAdapter() {

        override fun onDeviceConnected(deviceAddress: String) =
            callback.onDeviceConnected(originalAddress)

        override fun onDeviceConnecting(deviceAddress: String) =
            callback.onDeviceConnecting(originalAddress)

        override fun onDeviceDisconnected(deviceAddress: String) =
            callback.onDeviceDisconnected(originalAddress)

        override fun onDeviceDisconnecting(deviceAddress: String) =
            callback.onDeviceDisconnecting(originalAddress)

        override fun onDfuProcessStarting(deviceAddress: String) =
            callback.onDfuProcessStarting(originalAddress)

        override fun onDfuProcessStarted(deviceAddress: String) =
            callback.onDfuProcessStarted(originalAddress)

        override fun onEnablingDfuMode(deviceAddress: String) =
            callback.onEnablingDfuMode(originalAddress)

        override fun onFirmwareValidating(deviceAddress: String) =
            callback.onFirmwareValidating(originalAddress)

        override fun onDfuCompleted(deviceAddress: String) =
            dispatchDfuCompleted(originalAddress)

        override fun onDfuAborted(deviceAddress: String) =
            dispatchDfuAborted(originalAddress)

        override fun onError(
            deviceAddress: String, error: Int, errorType: Int, message: String
        ) = dispatchError(originalAddress, error, errorType, message)

        override fun onProgressChanged(
            deviceAddress: String,
            percent: Int,
            speed: Float,
            avgSpeed: Float,
            currentPart: Int,
            partsTotal: Int
        ) = callback.onProgressChanged(
            originalAddress, percent, speed, avgSpeed, currentPart, partsTotal
        )
    }

    /**
     * Handles bootloaders advertising with something other than the incremented address, which no
     * scoped listener covers. Addresses a scoped listener already reported are ignored here.
     */
    private val fallbackListener: DfuProgressListener = object : DfuProgressListenerAdapter() {

        override fun onDeviceConnected(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onDeviceConnected(it) }
        }

        override fun onDeviceConnecting(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onDeviceConnecting(it) }
        }

        override fun onDeviceDisconnected(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onDeviceDisconnected(it) }
        }

        override fun onDeviceDisconnecting(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onDeviceDisconnecting(it) }
        }

        override fun onDfuProcessStarting(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onDfuProcessStarting(it) }
        }

        override fun onDfuProcessStarted(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onDfuProcessStarted(it) }
        }

        override fun onEnablingDfuMode(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onEnablingDfuMode(it) }
        }

        override fun onFirmwareValidating(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { callback.onFirmwareValidating(it) }
        }

        override fun onDfuCompleted(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { dispatchDfuCompleted(it) }
        }

        override fun onDfuAborted(deviceAddress: String) {
            resolveUnclaimedAddress(deviceAddress)?.let { dispatchDfuAborted(it) }
        }

        override fun onError(
            deviceAddress: String, error: Int, errorType: Int, message: String
        ) {
            resolveUnclaimedAddress(deviceAddress)?.let {
                dispatchError(it, error, errorType, message)
            }
        }

        override fun onProgressChanged(
            deviceAddress: String,
            percent: Int,
            speed: Float,
            avgSpeed: Float,
            currentPart: Int,
            partsTotal: Int
        ) {
            resolveUnclaimedAddress(deviceAddress)?.let {
                callback.onProgressChanged(it, percent, speed, avgSpeed, currentPart, partsTotal)
            }
        }
    }
}
