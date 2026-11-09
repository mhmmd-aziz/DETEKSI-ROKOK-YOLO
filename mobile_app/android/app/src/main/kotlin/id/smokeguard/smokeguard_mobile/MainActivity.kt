package id.smokeguard.smokeguard_mobile

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    companion object {
        @Volatile
        var isActivityVisible: Boolean = false
        const val CHANNEL_NAME = "id.smokeguard/bg_service"
        const val PREFS_NAME = "smokeguard_native_prefs"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                when (call.method) {
                    "syncConfig" -> {
                        val baseUrl = call.argument<String>("baseUrl")
                        val lastIncId = call.argument<Int>("lastIncidentId")
                        val lastTestSeq = call.argument<Int>("lastTestSeq")
                        val editor = prefs.edit()
                        if (!baseUrl.isNullOrEmpty()) {
                            editor.putString("server_base_url", baseUrl)
                        }
                        if (lastIncId != null && lastIncId >= 0) {
                            editor.putInt("last_incident_id", lastIncId)
                        }
                        if (lastTestSeq != null && lastTestSeq >= 0) {
                            editor.putInt("last_test_seq", lastTestSeq)
                        }
                        editor.apply()
                        startBgGuardService()
                        result.success(true)
                    }
                    "triggerDelayedTest" -> {
                        val delayMs = (call.argument<Int>("delayMs") ?: 3500).toLong()
                        val title = call.argument<String>("title") ?: "PERINGATAN KTR • CAM 01"
                        val body = call.argument<String>("body")
                            ?: "Uji Notifikasi Background: Terdeteksi aktivitas merokok di Kawasan Tanpa Rokok."
                        val snapshotUrl = call.argument<String>("snapshotUrl") ?: ""
                        val baseUrl = call.argument<String>("baseUrl")
                            ?: prefs.getString("server_base_url", "http://127.0.0.1:8000")
                            ?: "http://127.0.0.1:8000"

                        SmokeGuardBgService.scheduleDelayedNativeAlert(
                            applicationContext,
                            delayMs,
                            title,
                            body,
                            snapshotUrl,
                            baseUrl
                        )
                        result.success(true)
                    }
                    "isBatteryExempt" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val exempt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm.isIgnoringBatteryOptimizations(packageName)
                        } else {
                            true
                        }
                        result.success(exempt)
                    }
                    "requestBatteryExemption" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                        data = Uri.parse("package:$packageName")
                                    }
                                    startActivity(intent)
                                }
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStart() {
        super.onStart()
        isActivityVisible = true
        startBgGuardService()
    }

    override fun onResume() {
        super.onResume()
        isActivityVisible = true
    }

    override fun onPause() {
        isActivityVisible = false
        super.onPause()
    }

    override fun onStop() {
        isActivityVisible = false
        super.onStop()
    }

    private fun startBgGuardService() {
        try {
            val intent = Intent(this, SmokeGuardBgService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, intent)
            } else {
                startService(intent)
            }
        } catch (_: Exception) {}
    }
}

class SmokeGuardRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val svcIntent = Intent(context, SmokeGuardBgService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, svcIntent)
            } else {
                context.startService(svcIntent)
            }
        } catch (_: Exception) {}
    }
}

class SmokeGuardBgService : Service() {
    companion object {
        const val CRIT_CHANNEL_ID = "smokeguard_kritikal_v2"
        const val GUARD_CHANNEL_ID = "smokeguard_bg_guard_v2"
        const val FOREGROUND_ID = 9001

        fun scheduleDelayedNativeAlert(
            context: Context,
            delayMs: Long,
            title: String,
            body: String,
            snapshotUrl: String,
            baseUrl: String
        ) {
            thread(isDaemon = true, name = "SmokeGuardDelayedTest") {
                try {
                    Thread.sleep(delayMs)
                } catch (_: InterruptedException) {}

                var bmp: Bitmap? = null
                if (snapshotUrl.isNotEmpty()) {
                    try {
                        val fullSnap = if (snapshotUrl.startsWith("http")) snapshotUrl else "$baseUrl$snapshotUrl"
                        val conn = (URL(fullSnap).openConnection() as HttpURLConnection).apply {
                            connectTimeout = 2500
                            readTimeout = 2500
                        }
                        if (conn.responseCode == 200) {
                            bmp = BitmapFactory.decodeStream(conn.inputStream)
                        }
                        conn.disconnect()
                    } catch (_: Exception) {}
                }
                dispatchHeadsUpNotification(
                    context,
                    (System.currentTimeMillis() / 1000L).toInt(),
                    title,
                    body,
                    bmp
                )
            }
        }

        fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttr = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()

                val critChannel = NotificationChannel(
                    CRIT_CHANNEL_ID,
                    "Peringatan Pelanggaran KTR (Heads-Up Prioritas Tinggi)",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Menampilkan pop-up peringatan merokok di atas layar HP saat aplikasi ditutup maupun dibuka."
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 150, 500, 150, 700)
                    enableLights(true)
                    lightColor = 0xFF059669.toInt()
                    setSound(soundUri, audioAttr)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setBypassDnd(true)
                }
                nm.createNotificationChannel(critChannel)

                val guardChannel = NotificationChannel(
                    GUARD_CHANNEL_ID,
                    "Layanan Pemantauan Latar Belakang SmokeGuard AI",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Menjaga koneksi deteksi merokok tetap aktif saat aplikasi ditutup."
                    setShowBadge(false)
                }
                nm.createNotificationChannel(guardChannel)
            }
        }

        fun dispatchHeadsUpNotification(
            context: Context,
            id: Int,
            title: String,
            message: String,
            snapshotBitmap: Bitmap?
        ) {
            ensureChannels(context)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(context, id, launchIntent, piFlags)

            val appLogoBitmap = try {
                BitmapFactory.decodeResource(context.resources, R.mipmap.ic_launcher)
            } catch (_: Exception) {
                null
            }

            val builder = NotificationCompat.Builder(context, CRIT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_smokeguard)
                .setColor(0xFF059669.toInt())
                .setContentTitle(title)
                .setContentText(message)
                .setSubText("SmokeGuard AI • Deteksi KTR")
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                .setVibrate(longArrayOf(0, 500, 150, 500, 150, 700))
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setFullScreenIntent(pendingIntent, true)

            if (snapshotBitmap != null) {
                builder.setLargeIcon(snapshotBitmap)
                builder.setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(snapshotBitmap)
                        .bigLargeIcon(appLogoBitmap)
                        .setBigContentTitle(title)
                        .setSummaryText(message)
                )
            } else {
                if (appLogoBitmap != null) {
                    builder.setLargeIcon(appLogoBitmap)
                }
                builder.setStyle(NotificationCompat.BigTextStyle().bigText(message))
            }

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(id, builder.build())
        }
    }

    @Volatile
    private var running = false
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannels(this)
        promoteToForeground()
        acquireWakeLock()
        startWatcherLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannels(this)
        promoteToForeground()
        acquireWakeLock()
        startWatcherLoop()
        return START_STICKY
    }

    private fun promoteToForeground() {
        try {
            val launchIntent = Intent(this, MainActivity::class.java)
            val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pi = PendingIntent.getActivity(this, 0, launchIntent, piFlags)

            val notification = NotificationCompat.Builder(this, GUARD_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_smokeguard)
                .setColor(0xFF059669.toInt())
                .setContentTitle("SmokeGuard AI • Proteksi KTR Aktif")
                .setContentText("Memantau deteksi rokok secara real-time di latar belakang")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .setContentIntent(pi)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    FOREGROUND_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(FOREGROUND_ID, notification)
            }
        } catch (_: Exception) {}
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "SmokeGuard::BgWatcherWakeLock"
                ).apply {
                    setReferenceCounted(false)
                    acquire()
                }
            } else if (wakeLock?.isHeld == false) {
                wakeLock?.acquire()
            }
        } catch (_: Exception) {}
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        scheduleServiceRestart()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running = false
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        scheduleServiceRestart()
        super.onDestroy()
    }

    private fun scheduleServiceRestart() {
        try {
            val restartIntent = Intent(applicationContext, SmokeGuardRestartReceiver::class.java).apply {
                action = "id.smokeguard.RESTART_BG_SERVICE"
            }
            val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_ONE_SHOT
            }
            val pi = PendingIntent.getBroadcast(applicationContext, 9902, restartIntent, piFlags)
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 900L,
                pi
            )
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

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
                    Thread.sleep(1100)
                } catch (_: InterruptedException) {
                    break
                }
            }
        }
    }

    private fun checkStatusOnce() {
        val nativePrefs = getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val savedBaseUrl = nativePrefs.getString("server_base_url", null)
            ?: flutterPrefs.getString("flutter.server_base_url", null)
            ?: "http://127.0.0.1:8000"

        val candidates = linkedSetOf(
            savedBaseUrl,
            "http://127.0.0.1:8000",
            "http://192.168.1.138:8000"
        )

        var bodyText: String? = null
        var activeUrl = savedBaseUrl

        for (candidate in candidates) {
            try {
                val url = URL("$candidate/api/status/")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 1200
                    readTimeout = 1200
                    requestMethod = "GET"
                }
                if (conn.responseCode == 200) {
                    bodyText = conn.inputStream.bufferedReader().use { it.readText() }
                    activeUrl = candidate
                    conn.disconnect()
                    break
                }
                conn.disconnect()
            } catch (_: Exception) {}
        }

        if (bodyText.isNullOrEmpty()) return

        val root = JSONObject(bodyText)

        // 1. Cek jika tombol "Uji Notifikasi" ditekan dari Web Dashboard saat aplikasi HP ditutup
        val testSeq = root.optInt("test_alert_seq", 0)
        val lastTestSeq = nativePrefs.getInt("last_test_seq", -1)
        if (lastTestSeq < 0) {
            nativePrefs.edit().putInt("last_test_seq", testSeq).apply()
        } else if (testSeq > lastTestSeq) {
            nativePrefs.edit().putInt("last_test_seq", testSeq).apply()
            val payload = root.optJSONObject("test_alert_payload") ?: root.optJSONObject("latest_incident")
            val camName = payload?.optString("camera_name", "CAM 01") ?: root.optString("camera_name", "CAM 01")
            val locName = payload?.optString("location", "Kawasan Tanpa Rokok") ?: root.optString("location", "Kawasan Tanpa Rokok")
            val snapUrl = payload?.optString("snapshot_url", "") ?: ""
            val bmp = fetchSnapshotBitmap(activeUrl, snapUrl)
            dispatchHeadsUpNotification(
                this,
                80000 + testSeq,
                "PERINGATAN KTR • $camName",
                "Uji Notifikasi Latar Belakang: Deteksi aktif di $locName.",
                bmp
            )
        }

        // 2. Cek jika ada insiden pelanggaran merokok baru dari YOLOv8 saat aplikasi HP ditutup
        val latest = root.optJSONObject("latest_incident") ?: return
        val incId = latest.optInt("id", 0)
        if (incId <= 0) return

        val lastSavedInc = nativePrefs.getInt("last_incident_id", -1)
        if (lastSavedInc < 0) {
            nativePrefs.edit().putInt("last_incident_id", incId).apply()
            return
        }

        if (incId > lastSavedInc) {
            nativePrefs.edit().putInt("last_incident_id", incId).apply()
            val camName = latest.optString("camera_name", "CAM 01")
            val locName = latest.optString("location", "Kawasan Tanpa Rokok")
            val cigCount = latest.optInt("cigarette_count", 1)
            val personCount = latest.optInt("person_count", 1)
            val maxConf = (latest.optDouble("max_confidence", 0.85) * 100.0).toInt()
            val snapUrl = latest.optString("snapshot_url", "")

            val title = "PELANGGARAN KTR • $camName"
            val msg = "Terdeteksi $cigCount titik rokok ($personCount orang) di $locName • Conf $maxConf%"
            val bmp = fetchSnapshotBitmap(activeUrl, snapUrl)

            dispatchHeadsUpNotification(this, incId, title, msg, bmp)
        }
    }

    private fun fetchSnapshotBitmap(baseUrl: String, snapUrl: String): Bitmap? {
        if (snapUrl.isEmpty()) return null
        return try {
            val fullSnap = if (snapUrl.startsWith("http")) snapUrl else "$baseUrl$snapUrl"
            val imgConn = (URL(fullSnap).openConnection() as HttpURLConnection).apply {
                connectTimeout = 2500
                readTimeout = 2500
            }
            val bmp = if (imgConn.responseCode == 200) {
                BitmapFactory.decodeStream(imgConn.inputStream)
            } else {
                null
            }
            imgConn.disconnect()
            bmp
        } catch (_: Exception) {
            null
        }
    }
}
