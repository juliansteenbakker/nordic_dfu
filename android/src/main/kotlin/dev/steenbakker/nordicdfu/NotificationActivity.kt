package dev.steenbakker.nordicdfu

import android.app.Activity
import android.os.Bundle

class NotificationActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // If this activity is the root activity of the task, the app is not running
        if (isTaskRoot) {
            // Start the app before finishing
            val pm = application.packageManager
            val intent = pm.getLaunchIntentForPackage(application.packageName)
            startActivity(intent)
        }

        // Now finish, which will drop the user in to the activity that was at the top
        //  of the task stack
        finish()
    }
}