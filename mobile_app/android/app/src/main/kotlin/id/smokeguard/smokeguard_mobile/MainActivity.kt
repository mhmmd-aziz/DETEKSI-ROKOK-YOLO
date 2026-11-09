package id.smokeguard.smokeguard_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    companion object {
        @Volatile
        var isActivityVisible: Boolean = false
    }

    override fun onStart() {
        super.onStart()
        isActivityVisible = true
        try {
            val intent = Intent(this, SmokeGuardBgService::class.java)
            startService(intent)
        } catch (_: Exception) {}
    }

    override fun onStop() {
        isActivityVisible = false
        super.onStop()
    }
}

class SmokeGuardBgService : Service() {
    @Volatile
    private var running = false

    override fun onCreate() {
        super.onCreate()
        ensureHighChannel()
        startWatcherLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureHighChannel()
        startWatcherLoop()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Keep service alive even if user swipes the Flutter app away from Recent Apps
        try {
            val restartIntent = Intent(applicationContext, SmokeGuardBgService::class.java)
            startService(restartIntent)
        } catch (_: Exception) {}
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureHighChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                "smokeguard_high_importance",
                "Peringatan Pelanggaran KTR (Prioritas Tinggi)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Menampilkan pop-up peringatan merokok di atas layar HP."
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 150, 500, 150, 700)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun startWatcherLoop() {
        if (running) return
        running = true
        thread(isDaemon = true, name = "SmokeGuardBgWatcher") {
            while (running) {
                try {
                    if (!MainActivity.isActivityVisible) {
                        checkStatusOnce()
                    }
                } catch (_: Exception) {}
                try {
                    Thread.sleep(1500)
                } catch (_: InterruptedException) {
                    break
                }
            }
        }
    }

    private fun checkStatusOnce() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val baseUrl = prefs.getString("flutter.server_base_url", "http://127.0.0.1:8000")
            ?: "http://127.0.0.1:8000"

        val url = URL("$baseUrl/api/status/")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            connectTimeout = 1500
            readTimeout = 1500
            requestMethod = "GET"
        }

        if (conn.responseCode != 200) {
            conn.disconnect()
            return
        }

        val bodyText = conn.inputStream.bufferedReader().use { it.readText() }
        conn.disconnect()

        val root = JSONObject(bodyText)
        val latest = root.optJSONObject("latest_incident") ?: return
        val incId = latest.optInt("id", 0)
        if (incId <= 0) return

        val lastSaved = prefs.getLong("flutter.last_notified_incident_id", -1L).toInt()
        if (lastSaved < 0) {
            prefs.edit().putLong("flutter.last_notified_incident_id", incId.toLong()).apply()
            return
        }

        if (incId > lastSaved) {
            prefs.edit().putLong("flutter.last_notified_incident_id", incId.toLong()).apply()
            val camName = latest.optString("camera_name", "CAM 01")
            val locName = latest.optString("location", "Kawasan Tanpa Rokok")
            val cigCount = latest.optInt("cigarette_count", 1)
            val personCount = latest.optInt("person_count", 1)
            val maxConf = (latest.optDouble("max_confidence", 0.85) * 100.0).toInt()
            val snapUrl = latest.optString("snapshot_url", "")

            val title = "PELANGGARAN KTR • $camName"
            val msg = "Terdeteksi $cigCount titik rokok ($personCount orang) di $locName • Conf $maxConf%"

            var bmp: Bitmap? = null
            if (snapUrl.isNotEmpty()) {
                try {
                    val fullSnap = if (snapUrl.startsWith("http")) snapUrl else "$baseUrl$snapUrl"
                    val imgConn = (URL(fullSnap).openConnection() as HttpURLConnection).apply {
                        connectTimeout = 2500
                        readTimeout = 2500
                    }
                    if (imgConn.responseCode == 200) {
                        bmp = BitmapFactory.decodeStream(imgConn.inputStream)
                    }
                    imgConn.disconnect()
                } catch (_: Exception) {}
            }

            showNativeHeadsUp(incId, title, msg, bmp)
        }
    }

    private fun showNativeHeadsUp(id: Int, title: String, message: String, bitmap: Bitmap?) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, id, launchIntent, piFlags)

        val builder = NotificationCompat.Builder(this, "smokeguard_high_importance")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
            .setVibrate(longArrayOf(0, 500, 150, 500, 150, 700))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)

        if (bitmap != null) {
            builder.setLargeIcon(bitmap)
            builder.setStyle(
                NotificationCompat.BigPictureStyle()
                    .bigPicture(bitmap)
                    .setBigContentTitle(title)
                    .setSummaryText(message)
            )
        } else {
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(message))
        }

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(id, builder.build())
    }
}
