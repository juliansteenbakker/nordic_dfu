package dev.steenbakker.nordicdfu

import android.content.Context
import java.io.*

object ResourceUtils {
    private const val BUFFER_SIZE = 8192

    /**
     * Copy the file from assets.
     *
     * @param assetsFilePath The path of file in assets.
     * @param destFilePath   The path of destination file.
     * @param context        The context
     * @return `true`: success<br></br>`false`: fail
     */
    fun copyFileFromAssets(assetsFilePath: String, destFilePath: String, context: Context): Boolean {
        var res = true
        try {
            val assets = context.applicationContext.assets.list(assetsFilePath)
            if (assets != null && assets.isNotEmpty()) {
                for (asset in assets) {
                    res = res and copyFileFromAssets("$assetsFilePath/$asset", "$destFilePath/$asset", context)
                }
            } else {
                res = writeFileFromIS(
                        destFilePath,
                        context.applicationContext.assets.open(assetsFilePath)
                )
            }
        } catch (e: IOException ) {
            e.printStackTrace()
            res = false
        } catch (f: FileNotFoundException) {
            f.printStackTrace()
            res = false
        }
        return res
    }

    ///////////////////////////////////////////////////////////////////////////
    // other utils methods
    ///////////////////////////////////////////////////////////////////////////
    private fun writeFileFromIS(filePath: String,
                                `is`: InputStream): Boolean {
        return writeFileFromIS(getFileByPath(filePath), `is`)
    }

    private fun writeFileFromIS(file: File?,
                                `is`: InputStream?): Boolean {
        if (!createOrExistsFile(file) || `is` == null) return false
        var os: OutputStream? = null
        return try {
            os = BufferedOutputStream(FileOutputStream(file, false))
            val data = ByteArray(BUFFER_SIZE)
            var len: Int
            while (`is`.read(data, 0, BUFFER_SIZE).also { len = it } != -1) {
                os.write(data, 0, len)
            }
            true
        } catch (e: IOException) {
            e.printStackTrace()
            false
        } finally {
            try {
                `is`.close()
            } catch (e: IOException) {
                e.printStackTrace()
            }
            try {
                os?.close()
            } catch (e: IOException) {
                e.printStackTrace()
            }
        }
    }

    private fun getFileByPath(filePath: String): File? {
        return if (isSpace(filePath)) null else File(filePath)
    }

    private fun createOrExistsFile(file: File?): Boolean {
        if (file == null) return false
        if (file.exists()) return file.isFile
        return if (!createOrExistsDir(file.parentFile)) false else try {
            file.createNewFile()
        } catch (e: IOException) {
            e.printStackTrace()
            false
        }
    }

    private fun isSpace(s: String?): Boolean {
        if (s == null) return true
        var i = 0
        val len = s.length
        while (i < len) {
            if (!Character.isWhitespace(s[i])) {
                return false
            }
            ++i
        }
        return true
    }

    private fun createOrExistsDir(file: File?): Boolean {
        return file != null && if (file.exists()) file.isDirectory else file.mkdirs()
    }
}