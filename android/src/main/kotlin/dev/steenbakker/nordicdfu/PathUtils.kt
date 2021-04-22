package dev.steenbakker.nordicdfu

import android.content.Context
import android.os.Environment
import java.io.File

object PathUtils {
    /**
     * Return the path of /storage/emulated/0/Android/data/package/cache.
     *
     * @return the path of /storage/emulated/0/Android/data/package/cache
     */
    fun getExternalAppCachePath(context: Context): String {
        return if (isExternalStorageDisable) "" else getAbsolutePath(context.applicationContext.externalCacheDir)
    }

    private val isExternalStorageDisable: Boolean
        get() = Environment.MEDIA_MOUNTED != Environment.getExternalStorageState()

    private fun getAbsolutePath(file: File?): String {
        return if (file == null) "" else file.absolutePath
    }
}