import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel kHighImportanceChannel =
    AndroidNotificationChannel(
  'smokeguard_high_importance',
  'Peringatan Pelanggaran KTR (Prioritas Tinggi)',
  description:
      'Menampilkan pop-up peringatan merokok di atas layar HP (Heads-Up Notification).',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await _initLocalNotifications();
  final notif = message.notification;
  final data = message.data;
  final title = notif?.title ??
      'PERINGATAN KTR • ${data['camera_name'] ?? 'Kamera CCTV'}';
  final body = notif?.body ??
      'Terdeteksi ${data['cigarette_count'] ?? '1'} titik rokok di ${data['location'] ?? 'Kawasan Tanpa Rokok'}.';
  await showHeadsUpNotification(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    snapshotUrl: data['snapshot_url'],
    baseUrl: 'http://127.0.0.1:8000',
  );
}

Future<void> _initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(kHighImportanceChannel);
    await androidPlugin.requestNotificationsPermission();
  }
}

Future<void> showHeadsUpNotification({
  required int id,
  required String title,
  required String body,
  String? snapshotUrl,
  required String baseUrl,
}) async {
  BigPictureStyleInformation? bigPicture;
  if (snapshotUrl != null && snapshotUrl.isNotEmpty) {
    try {
      final fullUrl = snapshotUrl.startsWith('http')
          ? snapshotUrl
          : '$baseUrl$snapshotUrl';
      final res =
          await http.get(Uri.parse(fullUrl)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final bitmap = ByteArrayAndroidBitmap(res.bodyBytes);
        bigPicture = BigPictureStyleInformation(
          bitmap,
          largeIcon: bitmap,
          contentTitle: title,
          summaryText: body,
        );
      }
    } catch (_) {}
  }

  final androidDetails = AndroidNotificationDetails(
    kHighImportanceChannel.id,
    kHighImportanceChannel.name,
    channelDescription: kHighImportanceChannel.description,
    importance: Importance.max,
    priority: Priority.max,
    ticker: 'PERINGATAN PELANGGARAN MEROKOK',
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 150, 500, 150, 700]),
    fullScreenIntent: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.alarm,
    color: const Color(0xFF059669),
    styleInformation: bigPicture ?? BigTextStyleInformation(body),
  );

  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    NotificationDetails(android: androidDetails),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initLocalNotifications();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Firebase google-services.json opsional; notifikasi lokal & USB tetap berjalan penuh
  }

  runApp(const SmokeGuardApp());
}

class SmokeGuardApp extends StatelessWidget {
  const SmokeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmokeGuard AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F9F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669),
          primary: const Color(0xFF059669),
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F291E),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _baseUrl = 'http://127.0.0.1:8000';
  bool _connected = false;
  bool _fcmActive = false;

  // Live Telemetry State
  String _cameraName = 'CAM 01 - CCTV Indoor (Demo)';
  String _location = 'Gedung Utama Lt. 1 (Kawasan Tanpa Rokok)';
  String _sourceMode = 'cctv_demo';
  bool _twoStage = true;
  bool _showPersonBox = true;
  double _confThreshold = 0.45;
  int _minConsecutiveFrames = 12;
  int _consecutiveHits = 0;
  bool _paused = false;
  int _currentFrame = 0;
  int _totalFrames = 240;
  int _personCount = 0;
  int _smokerCount = 0;
  int _cigaretteCount = 0;
  double _maxConfidence = 0.0;
  double _fps = 0.0;
  double _inferenceMs = 0.0;
  String _statusText = 'AMAN';
  String _deviceName = 'GPU CUDA Active';
  int _totalIncidents = 0;

  Uint8List? _latestFrameBytes;
  List<Map<String, dynamic>> _incidents = [];
  Map<String, dynamic>? _metrics;

  int? _lastNotifiedIncidentId;
  bool _hasSyncedInitialConfig = false;
  Map<String, dynamic>? _inAppBannerAlert;
  Timer? _bannerDismissTimer;

  Timer? _statusTimer;
  Timer? _frameTimer;
  Timer? _incidentsTimer;
  bool _fetchingFrame = false;

  @override
  void initState() {
    super.initState();
    _initConnectionAndFcm();
  }

  Future<void> _initConnectionAndFcm() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLastId = prefs.getInt('last_notified_incident_id');
    if (savedLastId != null && savedLastId > 0) {
      _lastNotifiedIncidentId = savedLastId;
    }
    final savedUrl = prefs.getString('server_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    } else {
      // Auto-probe USB localhost (127.0.0.1:8000) then LAN IP (192.168.1.138:8000)
      final candidates = [
        'http://127.0.0.1:8000',
        'http://192.168.1.138:8000',
        'http://10.0.2.2:8000',
      ];
      for (final c in candidates) {
        try {
          final r = await http
              .get(Uri.parse('$c/api/status/'))
              .timeout(const Duration(milliseconds: 900));
          if (r.statusCode == 200) {
            _baseUrl = c;
            await prefs.setString('server_base_url', c);
            break;
          }
        } catch (_) {}
      }
    }

    // Setup FCM if available
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final fcmToken = await messaging.getToken();
      if (fcmToken != null && fcmToken.isNotEmpty) {
        _fcmActive = true;
        _registerDeviceToken(fcmToken, 'Flutter Android FCM Native');
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notif = message.notification;
        final data = message.data;
        final title = notif?.title ??
            'PERINGATAN KTR • ${data['camera_name'] ?? _cameraName}';
        final body = notif?.body ??
            'Terdeteksi aktivitas merokok di ${data['location'] ?? _location}.';
        _triggerAlertBothHeadsUpAndSystem(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          snapshotUrl: data['snapshot_url'],
        );
      });
    } catch (_) {
      // Register USB/Wi-Fi device identifier so backend tracks connected Flutter app
      _registerDeviceToken(
        'flutter-android-${DateTime.now().millisecondsSinceEpoch}',
        'Flutter Android (High-Importance Heads-Up)',
      );
    }

    _fetchStatus();
    _fetchIncidents();
    _fetchMetrics();

    _statusTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _fetchStatus(),
    );
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 85),
      (_) => _fetchLatestFrame(),
    );
    _incidentsTimer = Timer.periodic(
      const Duration(milliseconds: 2200),
      (_) => _fetchIncidents(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _frameTimer?.cancel();
    _incidentsTimer?.cancel();
    _bannerDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _registerDeviceToken(String token, String label) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'device_label': label,
          'platform': 'Flutter Android Native',
        }),
      );
    } catch (_) {}
  }

  Future<void> _triggerAlertBothHeadsUpAndSystem({
    required int id,
    required String title,
    required String body,
    String? snapshotUrl,
  }) async {
    if (mounted) {
      setState(() {
        _inAppBannerAlert = {
          'title': title,
          'body': body,
          'snapshot_url': snapshotUrl,
        };
      });
      _bannerDismissTimer?.cancel();
      _bannerDismissTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) {
          setState(() {
            _inAppBannerAlert = null;
          });
        }
      });
    }

    await showHeadsUpNotification(
      id: id,
      title: title,
      body: body,
      snapshotUrl: snapshotUrl,
      baseUrl: _baseUrl,
    );
  }

  Future<void> _fetchLatestFrame() async {
    if (_selectedIndex != 0 || _fetchingFrame) return;
    _fetchingFrame = true;
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/frame/'))
          .timeout(const Duration(milliseconds: 1200));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && mounted) {
        setState(() {
          _latestFrameBytes = res.bodyBytes;
          _connected = true;
        });
      }
    } catch (_) {
      // ignore transient frame error
    } finally {
      _fetchingFrame = false;
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/status/'))
          .timeout(const Duration(milliseconds: 1800));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _connected = true;
            _cameraName = data['camera_name'] ?? _cameraName;
            _location = data['location'] ?? _location;
            _currentFrame = (data['current_frame'] ?? 0) as int;
            _totalFrames = (data['total_frames'] ?? 240) as int;
            _personCount = (data['person_count'] ?? 0) as int;
            _smokerCount = (data['smoker_count'] ?? 0) as int;
            _cigaretteCount = (data['cigarette_count'] ?? 0) as int;
            _consecutiveHits = (data['consecutive_hits'] ?? 0) as int;
            _maxConfidence = ((data['max_confidence'] ?? 0.0) as num).toDouble();
            _fps = ((data['fps'] ?? 0.0) as num).toDouble();
            _inferenceMs = ((data['inference_ms'] ?? 0.0) as num).toDouble();
            _statusText = data['status'] ?? 'AMAN';
            _deviceName = data['device_name'] ?? _deviceName;
            _totalIncidents = (data['total_incidents'] ?? 0) as int;

            if (!_hasSyncedInitialConfig) {
              _hasSyncedInitialConfig = true;
              _sourceMode = data['source_mode'] ?? 'cctv_demo';
              _twoStage = data['two_stage'] ?? true;
              _showPersonBox = data['show_person_box'] ?? true;
              _confThreshold =
                  ((data['conf_threshold'] ?? 0.45) as num).toDouble();
              _minConsecutiveFrames =
                  (data['min_consecutive_frames'] ?? 12) as int;
              _paused = data['paused'] ?? false;
            }
          });
        }

        final latestInc = data['latest_incident'] as Map<String, dynamic>?;
        if (latestInc != null && latestInc['id'] != null) {
          final incId = latestInc['id'] as int;
          if (_lastNotifiedIncidentId == null) {
            _lastNotifiedIncidentId = incId;
            SharedPreferences.getInstance().then(
              (p) => p.setInt('last_notified_incident_id', incId),
            );
          } else if (incId > _lastNotifiedIncidentId!) {
            _lastNotifiedIncidentId = incId;
            SharedPreferences.getInstance().then(
              (p) => p.setInt('last_notified_incident_id', incId),
            );
            final confPct =
                (((latestInc['max_confidence'] ?? 0.85) as num) * 100).round();
            final title =
                'PELANGGARAN KTR • ${latestInc['camera_name'] ?? _cameraName}';
            final body =
                'Terdeteksi ${latestInc['cigarette_count'] ?? 1} titik rokok (${latestInc['person_count'] ?? 1} orang) di ${latestInc['location'] ?? _location} • Conf $confPct%';
            await _triggerAlertBothHeadsUpAndSystem(
              id: incId,
              title: title,
              body: body,
              snapshotUrl: latestInc['snapshot_url'] as String?,
            );
            _fetchIncidents();
          }
        } else {
          _lastNotifiedIncidentId ??= 0;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connected = false;
        });
      }
    }
  }

  Future<void> _fetchIncidents() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/incidents/?limit=30'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawList = (data['incidents'] as List?) ?? [];
        setState(() {
          _incidents =
              rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMetrics() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/model-metrics/'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _metrics = jsonDecode(res.body) as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateConfig(Map<String, dynamic> payload) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/config/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<void> _handleManualCapture() async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/api/capture/'));
      if (res.statusCode == 200) {
        _fetchIncidents();
        _fetchStatus();
      }
    } catch (_) {}
  }

  Future<void> _handleTestNotification() async {
    try {
      await http.post(Uri.parse('$_baseUrl/api/notifications/test/'));
    } catch (_) {}
    final latestSnap = _incidents.isNotEmpty
        ? (_incidents.first['snapshot_url'] as String?)
        : null;
    await _triggerAlertBothHeadsUpAndSystem(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'PERINGATAN KTR • $_cameraName',
      body:
          'Uji Notifikasi Atas Layar: Terdeteksi aktivitas merokok di $_location.',
      snapshotUrl: latestSnap,
    );
  }

  Future<void> _handleClearIncidents() async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/api/incidents/'));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _incidents = [];
        });
        _fetchStatus();
      }
    } catch (_) {}
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: _baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Pengaturan Koneksi Server',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih mode koneksi ke Backend Django (Port 8000):',
              style: TextStyle(fontSize: 13, color: Color(0xFF476658)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'URL Backend Django',
                hintText: 'http://127.0.0.1:8000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('USB (127.0.0.1:8000)'),
                  onPressed: () =>
                      controller.text = 'http://127.0.0.1:8000',
                ),
                ActionChip(
                  label: const Text('Wi-Fi LAN (192.168.1.138)'),
                  onPressed: () =>
                      controller.text = 'http://192.168.1.138:8000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final nextUrl = controller.text.trim().replaceAll(RegExp(r'/$'), '');
              if (nextUrl.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('server_base_url', nextUrl);
                setState(() {
                  _baseUrl = nextUrl;
                });
                _fetchStatus();
                _fetchIncidents();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlert = _statusText == 'PELANGGARAN MEROKOK';
    final isVerifying = _statusText == 'VERIFIKASI';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SmokeGuard AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F291E),
                    ),
                  ),
                  Text(
                    _connected
                        ? '$_cameraName • Frame $_currentFrame/$_totalFrames'
                        : 'Menghubungkan ke $_baseUrl...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _connected
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Uji Notifikasi Atas Layar',
            onPressed: _handleTestNotification,
            icon: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF059669),
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan Server IP / USB',
            onPressed: _showServerConfigDialog,
            icon: const Icon(
              Icons.settings_ethernet_rounded,
              color: Color(0xFF476658),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildMonitorTab(isAlert, isVerifying),
              _buildIncidentsTab(),
              _buildMetricsTab(),
            ],
          ),

          // In-App Top Heads-Up Notification Banner
          if (_inAppBannerAlert != null)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Material(
                elevation: 14,
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF0F291E),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _inAppBannerAlert!['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _inAppBannerAlert!['body'] ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFFD1FAE5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                _inAppBannerAlert = null;
                              });
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: const Color(0xFF06281B),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              setState(() {
                                _inAppBannerAlert = null;
                                _selectedIndex = 1;
                              });
                            },
                            child: const Text(
                              'Lihat Bukti Snapshot',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD1FAE5),
        onDestinationSelected: (idx) {
          setState(() {
            _selectedIndex = idx;
          });
          if (idx != 0 && _sourceMode == 'webcam') {
            _updateConfig({'stop_stream': true});
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(
              Icons.videocam_rounded,
              color: Color(0xFF047857),
            ),
            label: 'Live Monitor',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _totalIncidents > 0,
              label: Text('$_totalIncidents'),
              backgroundColor: const Color(0xFF059669),
              child: const Icon(Icons.photo_camera_outlined),
            ),
            selectedIcon: const Icon(
              Icons.photo_camera_rounded,
              color: Color(0xFF047857),
            ),
            label: 'Bukti Snapshot',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(
              Icons.analytics_rounded,
              color: Color(0xFF047857),
            ),
            label: 'Evaluasi TA',
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorTab(bool isAlert, bool isVerifying) {
    final verifyPct = (_consecutiveHits /
            (_minConsecutiveFrames > 0 ? _minConsecutiveFrames : 1))
        .clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Status Banner Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isAlert
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAlert
                  ? const Color(0xFFFECACA)
                  : const Color(0xFFA7F3D0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAlert
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: isAlert
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAlert
                      ? 'TERKONFIRMASI MEROKOK ($_cigaretteCount Titik Rokok)'
                      : isVerifying
                          ? 'VERIFIKASI DETEKSI ($_consecutiveHits/$_minConsecutiveFrames Frame)'
                          : 'ZONA AMAN • BEBAS ASAP ROKOK',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isAlert
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF065F46),
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF059669),
                ),
                onPressed: _handleTestNotification,
                icon: const Icon(Icons.notifications_active_rounded, size: 16),
                label: const Text(
                  'Uji Notif',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Video Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EEE8)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: const Color(0xFF0B1711),
                  child: _latestFrameBytes != null
                      ? Image.memory(
                          _latestFrameBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _connected
                                    ? 'Memuat frame kamera...'
                                    : 'Menunggu koneksi ke $_baseUrl',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    ChoiceChip(
                      label: const Text('CCTV Demo'),
                      selected: _sourceMode == 'cctv_demo',
                      onSelected: (_) {
                        setState(() {
                          _sourceMode = 'cctv_demo';
                          _paused = false;
                        });
                        _updateConfig({
                          'source_mode': 'cctv_demo',
                          'paused': false,
                        });
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Kamera Webcam'),
                      selected: _sourceMode == 'webcam',
                      onSelected: (_) {
                        setState(() {
                          _sourceMode = 'webcam';
                          _paused = false;
                        });
                        _updateConfig({
                          'source_mode': 'webcam',
                          'paused': false,
                        });
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final next = !_paused;
                        setState(() => _paused = next);
                        _updateConfig({'paused': next});
                      },
                      icon: Icon(
                        _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 17,
                      ),
                      label: Text(_paused ? 'Lanjut' : 'Jeda'),
                    ),
                    FilledButton.icon(
                      onPressed: _handleManualCapture,
                      icon: const Icon(Icons.camera_alt_rounded, size: 16),
                      label: const Text('Snapshot'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2x2 KPI Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.75,
          children: [
            _buildKpiCard(
              label: 'Orang di Kamera',
              value: '$_personCount Orang',
              sub: 'Merokok: $_smokerCount Orang',
              icon: Icons.groups_rounded,
              isDanger: false,
            ),
            _buildKpiCard(
              label: 'Titik Rokok',
              value: '$_cigaretteCount Batang',
              sub: 'Conf Maks: ${(_maxConfidence * 100).toStringAsFixed(0)}%',
              icon: Icons.smoking_rooms_rounded,
              isDanger: _cigaretteCount > 0,
            ),
            _buildKpiCard(
              label: 'Kecepatan AI',
              value: '${_fps.toStringAsFixed(1)} FPS',
              sub: 'Inferensi: ${_inferenceMs.toStringAsFixed(1)} ms',
              icon: Icons.speed_rounded,
              isDanger: false,
            ),
            _buildKpiCard(
              label: 'Notifikasi Mobile',
              value: _fcmActive ? 'FCM + Lokal' : 'Heads-Up Aktif',
              sub: 'Total Bukti: $_totalIncidents',
              icon: Icons.notifications_active_rounded,
              isDanger: false,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // AI Controls Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EEE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pengaturan Deteksi AI Real-Time',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFF0F291E),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mode Two-Stage (Anti-Tiang)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Deteksi orang dulu (ROI) baru deteksi rokok',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _twoStage,
                activeThumbColor: const Color(0xFF059669),
                onChanged: (val) {
                  setState(() => _twoStage = val);
                  _updateConfig({'two_stage': val});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Tampilkan Kotak Orang',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Kotak Hijau (AMAN), Kuning (VERIFIKASI), Merah (MEROKOK)',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _showPersonBox,
                activeThumbColor: const Color(0xFF059669),
                onChanged: (val) {
                  setState(() => _showPersonBox = val);
                  _updateConfig({'show_person_box': val});
                },
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Confidence Threshold Rokok',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '${(_confThreshold * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _confThreshold.clamp(0.15, 0.85),
                min: 0.15,
                max: 0.85,
                divisions: 14,
                activeColor: const Color(0xFF059669),
                onChanged: (val) {
                  setState(() => _confThreshold = val);
                  _updateConfig({'conf_threshold': val});
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Snapshot (Min Frame Berturut)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    '$_minConsecutiveFrames Frame',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _minConsecutiveFrames.toDouble().clamp(5, 25),
                min: 5,
                max: 25,
                divisions: 20,
                activeColor: const Color(0xFF059669),
                onChanged: (val) {
                  final v = val.round();
                  setState(() => _minConsecutiveFrames = v);
                  _updateConfig({'min_consecutive_frames': v});
                },
              ),
              LinearProgressIndicator(
                value: verifyPct,
                minHeight: 7,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: const Color(0xFFE2EEE8),
                color: verifyPct >= 1.0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF10B981),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required bool isDanger,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDanger
              ? const Color(0xFFFECACA)
              : const Color(0xFFE2EEE8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF476658),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDanger
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F291E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF759485),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDanger
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 19,
              color: isDanger
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Galeri Bukti Pelanggaran Terkonfirmasi',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F291E),
                  ),
                ),
              ),
              if (_incidents.isNotEmpty)
                TextButton.icon(
                  onPressed: _handleClearIncidents,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  label: const Text(
                    'Bersihkan',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _incidents.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada snapshot pelanggaran terkonfirmasi.',
                    style: TextStyle(color: Color(0xFF759485)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _incidents.length,
                  itemBuilder: (ctx, i) {
                    final item = _incidents[i];
                    final snapUrl = item['snapshot_url'] as String? ?? '';
                    final fullImgUrl = snapUrl.startsWith('http')
                        ? snapUrl
                        : '$_baseUrl$snapUrl';
                    final confPct =
                        (((item['max_confidence'] ?? 0.0) as num) * 100)
                            .round();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2EEE8)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              fullImgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item['camera_name'] ?? _cameraName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item['cigarette_count'] ?? 1} Titik Rokok • ${item['timestamp'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF476658),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Text(
                                    'Conf $confPct%',
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricsTab() {
    final valMap50 = _metrics?['val_map50'] ?? 94.7;
    final testMap50 = _metrics?['test_map50'] ?? 94.2;
    final valPrec = _metrics?['val_precision'] ?? 93.8;
    final valRec = _metrics?['val_recall'] ?? 89.3;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'Evaluasi Performa Model YOLOv8 (Tugas Akhir)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF0F291E),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            _buildKpiCard(
              label: 'mAP@50 (Validasi)',
              value: '$valMap50%',
              sub: '1.726 Citra Validasi',
              icon: Icons.verified_rounded,
              isDanger: false,
            ),
            _buildKpiCard(
              label: 'mAP@50 (Testing)',
              value: '$testMap50%',
              sub: '872 Citra Testing',
              icon: Icons.fact_check_rounded,
              isDanger: false,
            ),
            _buildKpiCard(
              label: 'Precision & Recall',
              value: '$valPrec% / $valRec%',
              sub: '50 Epoch Training',
              icon: Icons.insights_rounded,
              isDanger: false,
            ),
            _buildKpiCard(
              label: 'Total Dataset',
              value: '8.666 Citra',
              sub: '6.068 Train • 1.726 Val',
              icon: Icons.dataset_rounded,
              isDanger: false,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EEE8)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arsitektur Two-Stage YOLOv8 + Temporal Filter',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              SizedBox(height: 10),
              Text(
                '1. Tahap 1 (Person ROI): Mendeteksi tubuh manusia terlebih dahulu menggunakan YOLOv8n sehingga objek statis seperti tiang kayu tidak salah terdeteksi.\n\n'
                '2. Tahap 2 (HD Upper-Body Crop): Memotong area kepala hingga tangan pada resolusi asli lalu di-upscale ke 640x640 agar batang rokok kecil terlihat tajam.\n\n'
                '3. Tahap 3 (Temporal Filter + FCM Heads-Up): Hanya menyimpan snapshot & memicu notifikasi atas layar (Importance.max) jika rokok terdeteksi konsisten minimal N frame berturut-turut.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF476658),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
