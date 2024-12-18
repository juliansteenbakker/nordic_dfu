package dev.steenbakker.nordicdfu

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import no.nordicsemi.android.dfu.DfuBaseService
import no.nordicsemi.android.dfu.DfuBaseService.NOTIFICATION_ID
import no.nordicsemi.android.dfu.DfuProgressListenerAdapter
import no.nordicsemi.android.dfu.DfuServiceController
import no.nordicsemi.android.dfu.DfuServiceInitiator
import no.nordicsemi.android.dfu.DfuServiceListenerHelper
import java.util.*
import android.util.Log

private class DfuProcess(
    val deviceAddress: String,
    val controller: DfuServiceController,
    val pendingResult: MethodChannel.Result,
    val serviceClass: Class<out DfuBaseService>
)

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

class NordicDfuPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private var mContext: Context? = null

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var activeDfuMap: MutableMap<String, DfuProcess> = mutableMapOf() 

    private var hasCreateNotification = false

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        mContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "dev.steenbakker.nordic_dfu/method")
        methodChannel!!.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "dev.steenbakker.nordic_dfu/event")
        eventChannel!!.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
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

        if (fileInAsset) {
            val loader = FlutterInjector.instance().flutterLoader()
            filePath = loader.getLookupKeyForAsset(filePath)
            val tempFileName =
                (PathUtils.getExternalAppCachePath(mContext!!) + UUID.randomUUID().toString())
            // copy asset file to temp path
            if (!ResourceUtils.copyFileFromAssets(filePath, tempFileName, mContext!!)) {
                result.error("File Error", "File not found!", "$filePath")
                return
            }

            // now, the path is an absolute path, and can pass it to nordic dfu libarary
            filePath = tempFileName
        }
        startDfu(
            address,
            name,
            filePath,
            forceDfu,
            enableUnsafeExperimentalButtonlessServiceInSecureDfu,
            disableNotification,
            keepBond,
            packetReceiptNotificationsEnabled,
            restoreBond,
            startAsForegroundService,
            result,
            numberOfPackets,
            dataDelay,
            numberOfRetries,
            rebootTime
        )
    }

    // Aborts ongoing DFU processes.
    //
    // If `call.argument("address")` is null, the abort command will be sent to all active DFU controllers
    // If `call.argument("address")` is provided, the abort command will be sent to the specific DFU controller
    // 
    // Note: the underlying controller implementation does not currently support individual aborts;
    // all active DFU processes are affected. See: https://github.com/NordicSemiconductor/Android-DFU-Library/blob/0c559244b34ebd27a4f51f045c067b965f918b73/lib/dfu/src/main/java/no/nordicsemi/android/dfu/DfuServiceController.java#L31-L39
    // 
    // Per-address abort handling is included here for cross-platform consistency and future compatability.
    private fun abortDfu(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")

        if (address == null) {
            // Abort all DFU processes
            if (activeDfuMap.isEmpty()) {
                result.error("NO_ACTIVE_DFU", "No active DFU processes to abort", null)
                return
            }
            activeDfuMap.values.forEach { it.controller.abort() }
            result.success(null)
            return
        }

        // Abort DFU process for the specified address
        val process = activeDfuMap[address]
        if (process == null) {
            result.error("INVALID_ADDRESS", "No DFU process found for address: $address", null)
            return
        }

        // Log a warning if multiple DFU processes are active
        if (activeDfuMap.size > 1) {
            Log.w("[NordicDfu]", "abortDfu will abort all DFU processes")
        }

        process.controller.abort()
        result.success(null)
    }

    private fun startDfu(
        address: String,
        name: String?,
        filePath: String,
        forceDfu: Boolean?,
        enableUnsafeExperimentalButtonlessServiceInSecureDfu: Boolean?,
        disableNotification: Boolean?,
        keepBond: Boolean?,
        packetReceiptNotificationsEnabled: Boolean?,
        restoreBond: Boolean?,
        startAsForegroundService: Boolean?,
        result: MethodChannel.Result,
        numberOfPackets: Int?,
        dataDelay: Int?,
        numberOfRetries: Int?,
        rebootTime: Long?
    ) {

        val starter = DfuServiceInitiator(address).setZip(filePath)

        if (name != null) starter.setDeviceName(name)
        if (enableUnsafeExperimentalButtonlessServiceInSecureDfu != null) {
            starter.setUnsafeExperimentalButtonlessServiceInSecureDfuEnabled(
                enableUnsafeExperimentalButtonlessServiceInSecureDfu
            )
        }
        if (forceDfu != null) starter.setForceDfu(forceDfu)
        if (disableNotification != null) starter.setDisableNotification(disableNotification)
        if (startAsForegroundService != null) starter.setForeground(startAsForegroundService)
        if (keepBond != null) starter.setKeepBond(keepBond)
        if (restoreBond != null) starter.setRestoreBond(restoreBond)
        if (packetReceiptNotificationsEnabled != null) {
            starter.setPacketsReceiptNotificationsEnabled(packetReceiptNotificationsEnabled)
        }
        if (numberOfPackets != null) {
            starter.setPacketsReceiptNotificationsValue(numberOfPackets)
        }
        if (dataDelay != null) {
            starter.setPrepareDataObjectDelay(dataDelay.toLong())
        }
        if (numberOfRetries != null) {
            starter.setNumberOfRetries(numberOfRetries)
        }

        if (rebootTime != null) {
            starter.setRebootTime(rebootTime)
        }

        if (mContext != null) {
            DfuServiceListenerHelper.registerProgressListener(mContext!!, mDfuProgressListener, address)
        }

        // fix notification on android 8 and above
        if (startAsForegroundService == null || startAsForegroundService) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !hasCreateNotification) {
                DfuServiceInitiator.createDfuNotificationChannel(mContext!!)
                hasCreateNotification = true
            }
        }

        val serviceClass = getAvailableDfuServiceClass() ?: run {
            result.error("PARALLEL_LIMIT_REACHED", "No available DFU service slots", null)
            return
        }
        val controller = starter.start(mContext!!, serviceClass)

        activeDfuMap[address] = DfuProcess(
            deviceAddress = address,
            controller = controller,
            pendingResult = result,
            serviceClass = serviceClass
        )
    }

    private fun getAvailableDfuServiceClass(): Class<out DfuBaseService>? {
        return DFU_SERVICE_CLASSES.firstOrNull { serviceClass ->
            activeDfuMap.values.none { it.serviceClass == serviceClass }
        }
    }

    private fun cancelNotification() {
        // let's wait a bit until we cancel the notification. When canceled immediately it will be recreated by service again.
        Handler(Looper.getMainLooper()).postDelayed({
            val manager =
                mContext!!.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }, 200)
    }

    private val mDfuProgressListener: DfuProgressListenerAdapter =
        object : DfuProgressListenerAdapter() {
            override fun onDeviceConnected(deviceAddress: String) {
                super.onDeviceConnected(deviceAddress)
                sink?.success(mapOf("onDeviceConnected" to deviceAddress))
            }

            override fun onError(
                deviceAddress: String, error: Int, errorType: Int, message: String
            ) {
                super.onError(deviceAddress, error, errorType, message)
                cancelNotification()
                val parameters = mutableMapOf<String, Any>()
                parameters["deviceAddress"] = deviceAddress
                parameters["error"] = error
                parameters["errorType"] = errorType
                parameters["message"] = message
                sink?.success(mapOf("onError" to parameters))
                activeDfuMap[deviceAddress]?.pendingResult?.error(
                    "$error",
                    "DFU FAILED: $message",
                    "Address: $deviceAddress, Error Type: $errorType"
                )
                activeDfuMap.remove(deviceAddress)
            }

            override fun onDeviceConnecting(deviceAddress: String) {
                super.onDeviceConnecting(deviceAddress)
                sink?.success(mapOf("onDeviceConnecting" to deviceAddress))
            }

            override fun onDeviceDisconnected(deviceAddress: String) {
                super.onDeviceDisconnected(deviceAddress)
                sink?.success(mapOf("onDeviceDisconnected" to deviceAddress))
            }

            override fun onDeviceDisconnecting(deviceAddress: String) {
                super.onDeviceDisconnecting(deviceAddress)
                sink?.success(mapOf("onDeviceDisconnecting" to deviceAddress))
            }

            override fun onDfuAborted(deviceAddress: String) {
                super.onDfuAborted(deviceAddress)
                cancelNotification()
                sink?.success(mapOf("onDfuAborted" to deviceAddress))
                activeDfuMap[deviceAddress]?.pendingResult?.error(
                    "DFU_ABORTED", "DFU ABORTED by user", "device address: $deviceAddress"
                )
                activeDfuMap.remove(deviceAddress)
            }

            override fun onDfuCompleted(deviceAddress: String) {
                super.onDfuCompleted(deviceAddress)
                cancelNotification()
                sink?.success(mapOf("onDfuCompleted" to deviceAddress))
                activeDfuMap[deviceAddress]?.pendingResult?.success(deviceAddress)
                activeDfuMap.remove(deviceAddress)
            }

            override fun onDfuProcessStarted(deviceAddress: String) {
                super.onDfuProcessStarted(deviceAddress)
                sink?.success(mapOf("onDfuProcessStarted" to deviceAddress))
            }

            override fun onDfuProcessStarting(deviceAddress: String) {
                super.onDfuProcessStarting(deviceAddress)
                sink?.success(mapOf("onDfuProcessStarting" to deviceAddress))
            }

            override fun onEnablingDfuMode(deviceAddress: String) {
                super.onEnablingDfuMode(deviceAddress)
                sink?.success(mapOf("onEnablingDfuMode" to deviceAddress))
            }

            override fun onFirmwareValidating(deviceAddress: String) {
                super.onFirmwareValidating(deviceAddress)
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
                super.onProgressChanged(
                    deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal
                )
                val parameters = mutableMapOf<String, Any>()
                parameters["deviceAddress"] = deviceAddress
                parameters["percent"] = percent
                parameters["speed"] = speed
                parameters["avgSpeed"] = avgSpeed
                parameters["currentPart"] = currentPart
                parameters["partsTotal"] = partsTotal

                sink?.success(mapOf("onProgressChanged" to parameters))
            }
        }

}
