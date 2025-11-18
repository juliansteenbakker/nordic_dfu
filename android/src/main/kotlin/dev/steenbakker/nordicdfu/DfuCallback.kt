package dev.steenbakker.nordicdfu

/**
 * Callback interface for DFU events
 */
interface DfuCallback {
    fun onDeviceConnected(deviceAddress: String)
    fun onDeviceConnecting(deviceAddress: String)
    fun onDeviceDisconnected(deviceAddress: String)
    fun onDeviceDisconnecting(deviceAddress: String)
    fun onDfuProcessStarting(deviceAddress: String)
    fun onDfuProcessStarted(deviceAddress: String)
    fun onEnablingDfuMode(deviceAddress: String)
    fun onFirmwareValidating(deviceAddress: String)
    fun onProgressChanged(
        deviceAddress: String,
        percent: Int,
        speed: Float,
        avgSpeed: Float,
        currentPart: Int,
        partsTotal: Int
    )
    fun onError(deviceAddress: String, error: Int, errorType: Int, message: String)
    fun onDfuCompleted(deviceAddress: String)
    fun onDfuAborted(deviceAddress: String)
}
