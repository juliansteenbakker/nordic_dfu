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
import no.nordicsemi.android.dfu.DfuBaseService.NOTIFICATION_ID
import no.nordicsemi.android.dfu.DfuProgressListenerAdapter
import no.nordicsemi.android.dfu.DfuServiceController
import no.nordicsemi.android.dfu.DfuServiceInitiator
import no.nordicsemi.android.dfu.DfuServiceListenerHelper
import java.util.*

class NordicDfuPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private var mContext: Context? = null

    private var pendingResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    private var controller: DfuServiceController? = null
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
            "abortDfu" -> abortDfu()
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        if (mContext != null) {
            DfuServiceListenerHelper.registerProgressListener(mContext!!, mDfuProgressListener)
        }

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
        pendingResult = result
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

    private fun abortDfu() {
        if (controller != null) {
            controller!!.abort()
        }
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
        pendingResult = result

        // fix notification on android 8 and above
        if (startAsForegroundService == null || startAsForegroundService) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !hasCreateNotification) {
                DfuServiceInitiator.createDfuNotificationChannel(mContext!!)
                hasCreateNotification = true
            }
        }
        controller = starter.start(mContext!!, DfuService::class.java)
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
                if (pendingResult != null) {
                    pendingResult!!.error(
                        "$error",
                        "DFU FAILED: $message",
                        "Address: $deviceAddress, Error Type: $errorType"
                    )
                    pendingResult = null
                }
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
                pendingResult?.error(
                    "DFU_ABORTED", "DFU ABORTED by user", "device address: $deviceAddress"
                )
                pendingResult = null
            }

            override fun onDfuCompleted(deviceAddress: String) {
                super.onDfuCompleted(deviceAddress)
                cancelNotification()
                sink?.success(mapOf("onDfuCompleted" to deviceAddress))
                pendingResult?.success(deviceAddress)
                pendingResult = null
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
