package dev.steenbakker.nordicdfu

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.util.*

/**
 * Flutter plugin for Nordic DFU
 * Handles Flutter-specific concerns and delegates DFU logic to NordicDfu
 */
class NordicDfuPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler, DfuCallback {

    private var mContext: Context? = null
    private var nordicDfu: NordicDfu? = null

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    // Track pending results for each device address
    private val pendingResults: MutableMap<String, MethodChannel.Result> = mutableMapOf()

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        mContext = binding.applicationContext
        nordicDfu = NordicDfu(binding.applicationContext)
        nordicDfu?.setCallback(this)

        methodChannel = MethodChannel(binding.binaryMessenger, "dev.steenbakker.nordic_dfu/method")
        methodChannel!!.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "dev.steenbakker.nordic_dfu/event")
        eventChannel!!.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        nordicDfu?.cleanup()
        nordicDfu = null
        mContext = null
        methodChannel = null
        eventChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDfu" -> initiateDfu(call, result)
            "abortDfu" -> abortDfu(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun initiateDfu(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")
        val name = call.argument<String>("name")
        var filePath = call.argument<String>("filePath")
        var fileInAsset = call.argument<Boolean>("fileInAsset")
        val forceDfu = call.argument<Boolean>("forceDfu")
        val enableUnsafeExperimentalButtonlessServiceInSecureDfu =
            call.argument<Boolean>("enableUnsafeExperimentalButtonlessServiceInSecureDfu")
        val disableNotification = call.argument<Boolean>("disableNotification")
        val keepBond = call.argument<Boolean>("keepBond")
        val packetReceiptNotificationsEnabled =
            call.argument<Boolean>("packetReceiptNotificationsEnabled")
        val restoreBond = call.argument<Boolean>("restoreBond")
        val startAsForegroundService = call.argument<Boolean>("startAsForegroundService")
        val numberOfPackets = call.argument<Int>("numberOfPackets")
        val dataDelay = call.argument<Int>("dataDelay")
        val numberOfRetries = call.argument<Int>("numberOfRetries")

        val rebootTime = call.argument<Int>("rebootTime")?.toLong()

        if (fileInAsset == null) fileInAsset = false
        if (address == null || filePath == null) {
            result.error("Abnormal parameter", "address and filePath are required", null)
            return
        }

        // Handle asset files
        if (fileInAsset) {
            val loader = FlutterInjector.instance().flutterLoader()
            filePath = loader.getLookupKeyForAsset(filePath)
            val tempFileName =
                PathUtils.getExternalAppCachePath(mContext!!) + UUID.randomUUID().toString() + ".zip"
            // copy asset file to temp path
            if (!ResourceUtils.copyFileFromAssets(filePath, tempFileName, mContext!!)) {
                result.error("File Error", "File not found!", filePath)
                return
            }

            // now, the path is an absolute path, and can pass it to nordic dfu library
            filePath = tempFileName
        }

        // Create DFU configuration
        val config = DfuConfig(
            address = address,
            name = name,
            filePath = filePath,
            forceDfu = forceDfu,
            enableUnsafeExperimentalButtonlessServiceInSecureDfu = enableUnsafeExperimentalButtonlessServiceInSecureDfu,
            disableNotification = disableNotification,
            keepBond = keepBond,
            packetReceiptNotificationsEnabled = packetReceiptNotificationsEnabled,
            restoreBond = restoreBond,
            startAsForegroundService = startAsForegroundService,
            numberOfPackets = numberOfPackets,
            dataDelay = dataDelay,
            numberOfRetries = numberOfRetries,
            rebootTime = rebootTime
        )

        // Store pending result for this address
        pendingResults[address] = result

        // Start DFU
        nordicDfu?.startDfu(config)?.onFailure { error ->
            result.error("DFU_START_ERROR", error.message, null)
            pendingResults.remove(address)
        }
    }

    // Aborts ongoing DFU processes.
    //
    // If `call.argument("address")` is null, the abort command will be sent to all active DFU controllers
    // If `call.argument("address")` is provided, the abort command will be sent to the specific DFU controller
    //
    // Note: the underlying controller implementation does not currently support individual aborts;
    // all active DFU processes are affected. See: https://github.com/NordicSemiconductor/Android-DFU-Library/blob/0c559244b34ebd27a4f51f045c067b965f918b73/lib/dfu/src/main/java/no/nordicsemi/android/dfu/DfuServiceController.java#L31-L39
    //
    // Per-address abort handling is included here for cross-platform consistency and future compatibility.
    private fun abortDfu(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")

        nordicDfu?.abortDfu(address)?.onSuccess {
            result.success(null)
        }?.onFailure { error ->
            result.error("ABORT_ERROR", error.message, null)
        }
    }

    // DfuCallback interface implementations
    override fun onDeviceConnected(deviceAddress: String) {
        sink?.success(mapOf("onDeviceConnected" to deviceAddress))
    }

    override fun onDeviceConnecting(deviceAddress: String) {
        sink?.success(mapOf("onDeviceConnecting" to deviceAddress))
    }

    override fun onDeviceDisconnected(deviceAddress: String) {
        sink?.success(mapOf("onDeviceDisconnected" to deviceAddress))
    }

    override fun onDeviceDisconnecting(deviceAddress: String) {
        sink?.success(mapOf("onDeviceDisconnecting" to deviceAddress))
    }

    override fun onDfuProcessStarting(deviceAddress: String) {
        sink?.success(mapOf("onDfuProcessStarting" to deviceAddress))
    }

    override fun onDfuProcessStarted(deviceAddress: String) {
        sink?.success(mapOf("onDfuProcessStarted" to deviceAddress))
    }

    override fun onEnablingDfuMode(deviceAddress: String) {
        sink?.success(mapOf("onEnablingDfuMode" to deviceAddress))
    }

    override fun onFirmwareValidating(deviceAddress: String) {
        sink?.success(mapOf("onFirmwareValidating" to deviceAddress))
    }

    override fun onProgressChanged(
        deviceAddress: String,
        percent: Int,
        speed: Float,
        avgSpeed: Float,
        currentPart: Int,
        partsTotal: Int
    ) {
        val parameters = mutableMapOf<String, Any>()
        parameters["deviceAddress"] = deviceAddress
        parameters["percent"] = percent
        parameters["speed"] = speed
        parameters["avgSpeed"] = avgSpeed
        parameters["currentPart"] = currentPart
        parameters["partsTotal"] = partsTotal

        sink?.success(mapOf("onProgressChanged" to parameters))
    }

    override fun onError(deviceAddress: String, error: Int, errorType: Int, message: String) {
        val parameters = mutableMapOf<String, Any>()
        parameters["deviceAddress"] = deviceAddress
        parameters["error"] = error
        parameters["errorType"] = errorType
        parameters["message"] = message
        sink?.success(mapOf("onError" to parameters))

        pendingResults[deviceAddress]?.error(
            "$error",
            "DFU FAILED: $message",
            "Address: $deviceAddress, Error Type: $errorType"
        )
        pendingResults.remove(deviceAddress)
    }

    override fun onDfuCompleted(deviceAddress: String) {
        sink?.success(mapOf("onDfuCompleted" to deviceAddress))
        pendingResults[deviceAddress]?.success(deviceAddress)
        pendingResults.remove(deviceAddress)
    }

    override fun onDfuAborted(deviceAddress: String) {
        sink?.success(mapOf("onDfuAborted" to deviceAddress))
        pendingResults[deviceAddress]?.error(
            "DFU_ABORTED", "DFU ABORTED by user", "device address: $deviceAddress"
        )
        pendingResults.remove(deviceAddress)
    }
}
