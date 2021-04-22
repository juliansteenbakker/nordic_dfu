package dev.steenbakker.nordicdfu

import android.app.Activity
import no.nordicsemi.android.dfu.DfuBaseService

class DfuService : DfuBaseService() {
    override fun getNotificationTarget(): Class<out Activity?> {
        return NotificationActivity::class.java
    }

    override fun isDebug(): Boolean {
        // Override this method and return true if you need more logs in LogCat
        // Note: BuildConfig.DEBUG always returns false in library projects, so please use
        // your app package BuildConfig
        return true
    }
}