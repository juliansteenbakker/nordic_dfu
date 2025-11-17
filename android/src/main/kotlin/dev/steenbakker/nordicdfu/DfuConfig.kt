package dev.steenbakker.nordicdfu

/**
 * Data class representing DFU configuration parameters
 */
data class DfuConfig(
    val address: String,
    val name: String?,
    val filePath: String,
    val forceDfu: Boolean?,
    val enableUnsafeExperimentalButtonlessServiceInSecureDfu: Boolean?,
    val disableNotification: Boolean?,
    val keepBond: Boolean?,
    val packetReceiptNotificationsEnabled: Boolean?,
    val restoreBond: Boolean?,
    val startAsForegroundService: Boolean?,
    val numberOfPackets: Int?,
    val dataDelay: Int?,
    val numberOfRetries: Int?,
    val rebootTime: Long?,
    val mbrSize: Int?,
    val scope: Int?,
    val currentMtu: Int?
)