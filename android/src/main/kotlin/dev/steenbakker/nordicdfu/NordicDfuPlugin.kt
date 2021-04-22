package dev.steenbakker.nordicdfu

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Handler
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import no.nordicsemi.android.dfu.*
import no.nordicsemi.android.dfu.DfuBaseService.NOTIFICATION_ID
import java.util.*

class NordicDfuPlugin : FlutterPlugin, MethodCallHandler {
    /**
     * hold context
     */
    private var mContext: Context? = null

    /**
     * hold result
     */
    private var pendingResult: MethodChannel.Result? = null

    /**
     * Method Channel
     */
    private var channel: MethodChannel? = null
    private var controller: DfuServiceController? = null
    private var hasCreateNotification = false
    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        mContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.steenbakker.nordic_dfu/method")
        val instance = NordicDfuPlugin()
        DfuServiceListenerHelper.registerProgressListener(mContext!!, instance.mDfuProgressListener)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        mContext = null
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "startDfu") {
            val address = call.argument<String>("address")
            val name = call.argument<String>("name")
            var filePath = call.argument<String>("filePath")
            var fileInAsset = call.argument<Boolean>("fileInAsset")
            val forceDfu = call.argument<Boolean>("forceDfu")
            val enableUnsafeExperimentalButtonlessServiceInSecureDfu = call.argument<Boolean>("enableUnsafeExperimentalButtonlessServiceInSecureDfu")
            val disableNotification = call.argument<Boolean>("disableNotification")
            val keepBond = call.argument<Boolean>("keepBond")
            val packetReceiptNotificationsEnabled = call.argument<Boolean>("packetReceiptNotificationsEnabled")
            val restoreBond = call.argument<Boolean>("restoreBond")
            val startAsForegroundService = call.argument<Boolean>("startAsForegroundService")
            val numberOfPackets = call.argument<Int>("numberOfPackets")
            val enablePRNs = call.argument<Boolean>("enablePRNs")
            if (fileInAsset == null) {
                fileInAsset = false
            }
            if (address == null || filePath == null) {
                result.error("Abnormal parameter", "address and filePath are required", null)
                return
            }
            if (fileInAsset) {
                val loader = FlutterInjector.instance().flutterLoader()
                filePath = loader.getLookupKeyForAsset(filePath)
                val tempFileName = (PathUtils.getExternalAppCachePath(mContext!!)
                        + UUID.randomUUID().toString())
                // copy asset file to temp path
                ResourceUtils.copyFileFromAssets(filePath, tempFileName, mContext!!)
                // now, the path is an absolute path, and can pass it to nordic dfu libarary
                filePath = tempFileName
            }
            pendingResult = result
            startDfu(address, name, filePath, forceDfu, enableUnsafeExperimentalButtonlessServiceInSecureDfu, disableNotification, keepBond, packetReceiptNotificationsEnabled, restoreBond, startAsForegroundService, result, numberOfPackets, enablePRNs)
        } else if (call.method == "abortDfu") {
            if (controller != null) {
                controller!!.abort()
            }
        } else {
            result.notImplemented()
        }
    }

    /**
     * Start Dfu
     */
    private fun startDfu(address: String, name: String?, filePath: String?, forceDfu: Boolean?, enableUnsafeExperimentalButtonlessServiceInSecureDfu: Boolean?, disableNotification: Boolean?, keepBond: Boolean?, packetReceiptNotificationsEnabled: Boolean?, restoreBond: Boolean?, startAsForegroundService: Boolean?, result: MethodChannel.Result, numberOfPackets: Int?, enablePRNs: Boolean?) {
        val starter = DfuServiceInitiator(address)
                .setZip(filePath!!)
                .setKeepBond(true)
                .setForceDfu(forceDfu ?: false)
                .setPacketsReceiptNotificationsEnabled(enablePRNs
                        ?: (Build.VERSION.SDK_INT < Build.VERSION_CODES.M))
                .setPacketsReceiptNotificationsValue(numberOfPackets ?: 0)
                .setPrepareDataObjectDelay(400)
                .setUnsafeExperimentalButtonlessServiceInSecureDfuEnabled(true)
        if (name != null) {
            starter.setDeviceName(name)
        }
        pendingResult = result
        if (enableUnsafeExperimentalButtonlessServiceInSecureDfu != null) {
            starter.setUnsafeExperimentalButtonlessServiceInSecureDfuEnabled(enableUnsafeExperimentalButtonlessServiceInSecureDfu)
        }
        if (forceDfu != null) {
            starter.setForceDfu(forceDfu)
        }
        if (disableNotification != null) {
            starter.setDisableNotification(disableNotification)
        }
        if (startAsForegroundService != null) {
            starter.setForeground(startAsForegroundService)
        }
        if (keepBond != null) {
            starter.setKeepBond(keepBond)
        }
        if (restoreBond != null) {
            starter.setRestoreBond(restoreBond)
        }
        if (packetReceiptNotificationsEnabled != null) {
            starter.setPacketsReceiptNotificationsEnabled(packetReceiptNotificationsEnabled)
        }

        // fix notification on android 8 and above
        if (startAsForegroundService == null || startAsForegroundService) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !hasCreateNotification) {
                DfuServiceInitiator.createDfuNotificationChannel(mContext!!)
                hasCreateNotification = true
            }
        }
        controller = starter.start(mContext!!, DfuService::class.java)
    }

    private val mDfuProgressListener: DfuProgressListenerAdapter = object : DfuProgressListenerAdapter() {
        override fun onDeviceConnected(deviceAddress: String) {
            super.onDeviceConnected(deviceAddress)
            channel!!.invokeMethod("onDeviceConnected", deviceAddress)
        }

        override fun onError(deviceAddress: String, error: Int, errorType: Int, message: String) {
            super.onError(deviceAddress, error, errorType, message)
            cancelNotification()
            channel!!.invokeMethod("onError", deviceAddress)
            if (pendingResult != null) {
                pendingResult!!.error("2", "DFU FAILED", "device address: $deviceAddress")
                pendingResult = null
            }
        }

        override fun onDeviceConnecting(deviceAddress: String) {
            super.onDeviceConnecting(deviceAddress)
            channel!!.invokeMethod("onDeviceConnecting", deviceAddress)
        }

        override fun onDeviceDisconnected(deviceAddress: String) {
            super.onDeviceDisconnected(deviceAddress)
            channel!!.invokeMethod("onDeviceDisconnected", deviceAddress)
        }

        override fun onDeviceDisconnecting(deviceAddress: String) {
            super.onDeviceDisconnecting(deviceAddress)
            channel!!.invokeMethod("onDeviceDisconnecting", deviceAddress)
        }

        override fun onDfuAborted(deviceAddress: String) {
            super.onDfuAborted(deviceAddress)
            cancelNotification()
            if (pendingResult != null) {
                pendingResult!!.error("2", "DFU ABORTED", "device address: $deviceAddress")
                pendingResult = null
            }
            channel!!.invokeMethod("onDfuAborted", deviceAddress)
        }

        override fun onDfuCompleted(deviceAddress: String) {
            super.onDfuCompleted(deviceAddress)
            cancelNotification()
            if (pendingResult != null) {
                pendingResult!!.success(deviceAddress)
                pendingResult = null
            }
            channel!!.invokeMethod("onDfuCompleted", deviceAddress)
        }

        override fun onDfuProcessStarted(deviceAddress: String) {
            super.onDfuProcessStarted(deviceAddress)
            channel!!.invokeMethod("onDfuProcessStarted", deviceAddress)
        }

        override fun onDfuProcessStarting(deviceAddress: String) {
            super.onDfuProcessStarting(deviceAddress)
            channel!!.invokeMethod("onDfuProcessStarting", deviceAddress)
        }

        override fun onEnablingDfuMode(deviceAddress: String) {
            super.onEnablingDfuMode(deviceAddress)
            channel!!.invokeMethod("onEnablingDfuMode", deviceAddress)
        }

        override fun onFirmwareValidating(deviceAddress: String) {
            super.onFirmwareValidating(deviceAddress)
            channel!!.invokeMethod("onFirmwareValidating", deviceAddress)
        }

        override fun onProgressChanged(deviceAddress: String, percent: Int, speed: Float, avgSpeed: Float, currentPart: Int, partsTotal: Int) {
            super.onProgressChanged(deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal)
            val paras: HashMap<String?, Any?> = object : HashMap<String?, Any?>() {
                init {
                    put("percent", percent)
                    put("speed", speed)
                    put("avgSpeed", avgSpeed)
                    put("currentPart", currentPart)
                    put("partsTotal", partsTotal)
                    put("deviceAddress", deviceAddress)
                }
            }
            channel!!.invokeMethod("onProgressChanged", paras)
        }
    }

    private fun cancelNotification() {
        // let's wait a bit until we cancel the notification. When canceled immediately it will be recreated by service again.
        Handler().postDelayed({
            val manager = mContext!!.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }, 200)
    }

    init {
        channel!!.setMethodCallHandler(this)
    }
}