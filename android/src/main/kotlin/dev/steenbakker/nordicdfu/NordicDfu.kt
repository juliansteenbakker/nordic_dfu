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

/**
 * Core Nordic DFU logic handler
 * Manages DFU processes independently of Flutter
 */
class NordicDfu(private val context: Context, private val callback: DfuCallback) {

    private val activeDfuMap: MutableMap<String, DfuProcess> = mutableMapOf()
    private var hasCreatedNotification = false

    companion object {
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

        // Register progress listener
        DfuServiceListenerHelper.registerProgressListener(context, dfuProgressListener, config.address)

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
            Log.w("[NordicDfu]", "abortDfu will abort all DFU processes")
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

    private val dfuProgressListener: DfuProgressListener =
        object : DfuProgressListenerAdapter() {
            override fun onDeviceConnected(deviceAddress: String) {
                super.onDeviceConnected(deviceAddress)
                callback.onDeviceConnected(deviceAddress)
            }

            override fun onError(
                deviceAddress: String, error: Int, errorType: Int, message: String
            ) {
                super.onError(deviceAddress, error, errorType, message)
                cancelNotification()
                callback.onError(deviceAddress, error, errorType, message)
                activeDfuMap.remove(deviceAddress)
            }

            override fun onDeviceConnecting(deviceAddress: String) {
                super.onDeviceConnecting(deviceAddress)
                callback.onDeviceConnecting(deviceAddress)
            }

            override fun onDeviceDisconnected(deviceAddress: String) {
                super.onDeviceDisconnected(deviceAddress)
                callback.onDeviceDisconnected(deviceAddress)
            }

            override fun onDeviceDisconnecting(deviceAddress: String) {
                super.onDeviceDisconnecting(deviceAddress)
                callback.onDeviceDisconnecting(deviceAddress)
            }

            override fun onDfuAborted(deviceAddress: String) {
                super.onDfuAborted(deviceAddress)
                cancelNotification()
                callback.onDfuAborted(deviceAddress)
                activeDfuMap.remove(deviceAddress)
            }

            override fun onDfuCompleted(deviceAddress: String) {
                super.onDfuCompleted(deviceAddress)
                cancelNotification()
                callback.onDfuCompleted(deviceAddress)
                activeDfuMap.remove(deviceAddress)
            }

            override fun onDfuProcessStarted(deviceAddress: String) {
                super.onDfuProcessStarted(deviceAddress)
                callback.onDfuProcessStarted(deviceAddress)
            }

            override fun onDfuProcessStarting(deviceAddress: String) {
                super.onDfuProcessStarting(deviceAddress)
                callback.onDfuProcessStarting(deviceAddress)
            }

            override fun onEnablingDfuMode(deviceAddress: String) {
                super.onEnablingDfuMode(deviceAddress)
                callback.onEnablingDfuMode(deviceAddress)
            }

            override fun onFirmwareValidating(deviceAddress: String) {
                super.onFirmwareValidating(deviceAddress)
                callback.onFirmwareValidating(deviceAddress)
            }

            override fun onProgressChanged(
                deviceAddress: String,
                percent: Int,
                speed: Float,
                avgSpeed: Float,
                currentPart: Int,
                partsTotal: Int
            ) {
                super.onProgressChanged(
                    deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal
                )
                callback.onProgressChanged(
                    deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal
                )
            }
        }
}
