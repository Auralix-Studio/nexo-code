package pro.aurx.nexo

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Una vez al día, con la app cerrada, mira si hay versión nueva y lo avisa.
 *
 * Solo avisa: descargar, verificar e instalar lo hace UpdateService al abrir
 * la app, que es donde están las comprobaciones de integridad. Va con
 * JobScheduler del sistema y no con WorkManager para no sumar una librería
 * (WorkManager usa JobScheduler por debajo en estas versiones de Android).
 */
class UpdateCheckJob : JobService() {
    @Volatile
    private var worker: Thread? = null

    override fun onStartJob(params: JobParameters): Boolean {
        worker = thread(name = "nexo-update-check") {
            val ok = runCatching { check() }
                .onFailure { Log.w(TAG, "No se pudo revisar la versión", it) }
                .isSuccess
            // Si falló la red, que el sistema lo reintente más tarde.
            jobFinished(params, !ok)
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        worker?.interrupt()
        return true
    }

    private fun check() {
        val latest = fetchLatestVersion() ?: return
        val installed = packageManager.getPackageInfo(packageName, 0).versionName ?: return
        if (!isNewer(latest, installed)) return
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        // Un aviso por versión, no uno cada día.
        if (prefs.getString(KEY_NOTIFIED, null) == latest) return
        if (notify(latest)) prefs.edit().putString(KEY_NOTIFIED, latest).apply()
    }

    private fun fetchLatestVersion(): String? {
        val conn = URL(MANIFEST_URL).openConnection() as HttpURLConnection
        conn.connectTimeout = 15_000
        conn.readTimeout = 15_000
        conn.setRequestProperty("Accept", "application/json")
        try {
            if (conn.responseCode != HttpURLConnection.HTTP_OK) {
                throw IOException("version.json respondió ${conn.responseCode}")
            }
            val body = conn.inputStream.use { input ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    out.write(buffer, 0, n)
                    if (out.size() > MAX_MANIFEST_BYTES) throw IOException("version.json demasiado grande")
                }
                out.toString(Charsets.UTF_8.name())
            }
            return JSONObject(body).optString("version").takeIf { VERSION.matches(it) }
        } finally {
            conn.disconnect()
        }
    }

    /** `false` si no se pudo mostrar (permiso denegado o avisos apagados). */
    private fun notify(version: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = NotificationManagerCompat.from(this)
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // El mismo canal que crea NotificationService en Dart.
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.update_channel_name),
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(getString(R.string.update_available_title))
            .setContentText(getString(R.string.update_available_body, version))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
        return true
    }

    companion object {
        private const val TAG = "NexoUpdateCheck"

        /** El mismo que `UpdateConfig.manifestUrl` en Dart. */
        private const val MANIFEST_URL = "https://nexo.aurx.pro/version.json"
        private const val MAX_MANIFEST_BYTES = 64 * 1024
        private val VERSION = Regex("""^\d+\.\d+\.\d+$""")

        private const val PREFS = "nexo_updates"
        private const val KEY_NOTIFIED = "notified_version"
        private const val CHANNEL_ID = "actualizaciones"

        /** El de NotificationService (Dart): el aviso de «lista» lo reemplaza. */
        private const val NOTIFICATION_ID = 40001
        private const val JOB_ID = 0x4E5855 // "NXU"

        /** Programa la revisión si no lo está ya. Sobrevive a reinicios. */
        fun schedule(context: Context) {
            val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
            if (scheduler.getPendingJob(JOB_ID) != null) return
            val job = JobInfo.Builder(JOB_ID, ComponentName(context, UpdateCheckJob::class.java))
                .setPeriodic(TimeUnit.HOURS.toMillis(24), TimeUnit.HOURS.toMillis(6))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPersisted(true)
                .build()
            scheduler.schedule(job)
        }

        fun isNewer(a: String, b: String): Boolean {
            val pa = a.split('.').map { it.toIntOrNull() ?: 0 }
            val pb = b.split('+', '-').first().split('.').map { it.toIntOrNull() ?: 0 }
            for (i in 0 until 3) {
                val x = pa.getOrElse(i) { 0 }
                val y = pb.getOrElse(i) { 0 }
                if (x != y) return x > y
            }
            return false
        }
    }
}
