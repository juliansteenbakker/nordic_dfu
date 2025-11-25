package dev.steenbakker.nordicdfu

import no.nordicsemi.android.dfu.DfuBaseService
import no.nordicsemi.android.dfu.DfuServiceController

/**
 * Data class representing an active DFU process
 */
data class DfuProcess(
    val deviceAddress: String,
    val controller: DfuServiceController,
    val serviceClass: Class<out DfuBaseService>
)
