package app.derafsh.drf

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.util.Log
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import org.json.JSONObject

class DrfApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        app = this
        filesDir.mkdirs()
        cacheDir.mkdirs()
        val working = getExternalFilesDir(null) ?: filesDir
        working.mkdirs()
        try {
            val options = SetupOptions().also {
                it.basePath = filesDir.path
                it.workingPath = working.path
                it.tempPath = cacheDir.path
                it.logMaxLines = 1000
                it.debug = false
                it.crashReportSource = "Derafsh"
                it.appVersion = versionCode().toString()
                it.appMarketingVersion = versionName()
                it.platformMetadata = JSONObject().apply {
                    put("os", "Android " + Build.VERSION.RELEASE)
                    put("sdk", Build.VERSION.SDK_INT)
                    put("manufacturer", Build.MANUFACTURER)
                    put("model", Build.MODEL)
                }.toString()
            }
            Libbox.setup(options)
        } catch (e: Exception) {
            Log.w(TAG, "libbox setup: ${e.message}")
        }
    }

    private fun versionName(): String = try {
        packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"
    } catch (_: Exception) {
        "1.0.0"
    }

    @Suppress("DEPRECATION")
    private fun versionCode(): Long = try {
        packageManager.getPackageInfo(packageName, 0).versionCode.toLong()
    } catch (_: Exception) {
        0L
    }

    companion object {
        private const val TAG = "DrfApplication"

        lateinit var app: DrfApplication
            private set

        val connectivity: ConnectivityManager
            get() = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val notificationManager: NotificationManager
            get() = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }
}
