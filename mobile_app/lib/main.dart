import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kDefaultLanServerUrl = 'http://192.168.1.138:8000';
const MethodChannel _bgServiceChannel = MethodChannel('id.smokeguard/bg_service');

/// Permintaan pindah tab dari luar widget (mis. notifikasi diketuk). 1 = Bukti Insiden.
final ValueNotifier<int?> kTabRequest = ValueNotifier<int?>(null);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel kHighImportanceChannel =
    AndroidNotificationChannel(
  'smokeguard_kritikal_v2',
  'Peringatan Pelanggaran KTR (Heads-Up Prioritas Tinggi)',
  description:
      'Menampilkan pop-up peringatan merokok di atas layar HP saat aplikasi ditutup maupun dibuka.',
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
  const androidSettings = AndroidInitializationSettings('ic_stat_smokeguard');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (_) => kTabRequest.value = 1,
  );

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
    icon: 'ic_stat_smokeguard',
    largeIcon: bigPicture == null
        ? const DrawableResourceAndroidBitmap('@mipmap/ic_launcher')
        : null,
    importance: Importance.max,
    priority: Priority.max,
    ticker: 'PERINGATAN PELANGGARAN MEROKOK',
    subText: 'SmokeGuard AI • Deteksi KTR',
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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await _initLocalNotifications();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}

  runApp(const SmokeGuardApp());
}

// ============================================================================
// DESIGN SYSTEM PALETTE (Architectural White & Forest Emerald — Zero AI Slop)
// ============================================================================
class SgColors {
  static const Color canvas = Color(0xFFF5F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFEEF4F1);
  static const Color border = Color(0xFFDCE7E1);
  static const Color borderSubtle = Color(0xFFE8F0EC);

  static const Color inkPrimary = Color(0xFF0A1F17);
  static const Color inkSecondary = Color(0xFF4A6358);
  static const Color inkMuted = Color(0xFF7A9488);

  static const Color emeraldPrimary = Color(0xFF059669);
  static const Color emeraldDeep = Color(0xFF047857);
  static const Color emeraldLight = Color(0xFF10B981);
  static const Color emeraldTint = Color(0xFFECFDF5);

  static const Color amberWarn = Color(0xFFD97706);
  static const Color amberTint = Color(0xFFFFFBEB);

  static const Color crimsonAlert = Color(0xFFDC2626);
  static const Color crimsonTint = Color(0xFFFEF2F2);
  static const Color crimsonBorder = Color(0xFFFECACA);
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
        scaffoldBackgroundColor: SgColors.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: SgColors.emeraldPrimary,
          primary: SgColors.emeraldPrimary,
          secondary: SgColors.emeraldDeep,
          surface: SgColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: SgColors.surface,
          foregroundColor: SgColors.inkPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: SgColors.emeraldPrimary,
          inactiveTrackColor: SgColors.surfaceSubtle,
          thumbColor: SgColors.emeraldDeep,
          overlayColor: SgColors.emeraldPrimary.withValues(alpha: 0.12),
          trackHeight: 5,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

// ============================================================================
// CUSTOM VECTOR SHIELD + APERTURE LOGO MARK (Matches Launcher & Notif Icon)
// ============================================================================
class SmokeGuardLogoMark extends StatelessWidget {
  final double size;
  const SmokeGuardLogoMark({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShieldAperturePainter(),
      ),
    );
  }
}

class _ShieldAperturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Shield path
    final shield = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..cubicTo(w * 0.66, h * 0.14, w * 0.82, h * 0.17, w * 0.88, h * 0.21)
      ..cubicTo(w * 0.90, h * 0.52, w * 0.82, h * 0.78, w * 0.50, h * 0.94)
      ..cubicTo(w * 0.18, h * 0.78, w * 0.10, h * 0.52, w * 0.12, h * 0.21)
      ..cubicTo(w * 0.18, h * 0.17, w * 0.34, h * 0.14, w * 0.50, h * 0.06)
      ..close();

    final shieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF059669), Color(0xFF065F46)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(shield, shieldPaint);

    // Subtle right-half shading for architectural depth
    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.5, 0, w * 0.5, h),
      Paint()..color = const Color(0x18000000),
    );
    canvas.restore();

    // 2. Inner Prohibition Ring + Aperture Blades
    final center = Offset(w * 0.50, h * 0.49);
    final ringRadius = w * 0.23;

    final whiteStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, ringRadius, whiteStroke);

    // Inner aperture iris circle
    canvas.drawCircle(
      center,
      ringRadius * 0.46,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035,
    );

    // Prohibition diagonal slash
    final slashOffset = ringRadius * 0.707;
    canvas.drawLine(
      Offset(center.dx - slashOffset, center.dy + slashOffset),
      Offset(center.dx + slashOffset, center.dy - slashOffset),
      whiteStroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ANIMATED PULSE INDICATOR DOT
// ============================================================================
class _RadarPulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _RadarPulseDot({required this.color, this.size = 9});

  @override
  State<_RadarPulseDot> createState() => _RadarPulseDotState();
}

class _RadarPulseDotState extends State<_RadarPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.4,
      height: widget.size * 2.4,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_ctrl.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + (widget.size * 1.4 * t),
                height: widget.size + (widget.size * 1.4 * t),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1.0 - t) * 0.38),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// COMPUTER VISION VIEWFINDER CORNER BRACKETS PAINTER
// ============================================================================
class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;
  const _ViewfinderCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square;

    const double pad = 12.0;
    const double len = 16.0;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + len, pad), paint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad, pad + len), paint);
    // Top-right
    canvas.drawLine(Offset(w - pad, pad), Offset(w - pad - len, pad), paint);
    canvas.drawLine(Offset(w - pad, pad), Offset(w - pad, pad + len), paint);
    // Bottom-left
    canvas.drawLine(Offset(pad, h - pad), Offset(pad + len, h - pad), paint);
    canvas.drawLine(Offset(pad, h - pad), Offset(pad, h - pad - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - pad, h - pad), Offset(w - pad - len, h - pad), paint);
    canvas.drawLine(Offset(w - pad, h - pad), Offset(w - pad, h - pad - len), paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ============================================================================
// MAIN DASHBOARD SCREEN
// ============================================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _baseUrl = 'http://127.0.0.1:8000';
  bool _connected = false;
  bool _fcmActive = false;
  bool _batteryExempt = true;

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
  List<String> _detectedServerIps = [];

  int? _lastNotifiedIncidentId;
  int? _lastTestAlertSeq;
  bool _hasSyncedInitialConfig = false;

  Timer? _statusTimer;
  Timer? _frameTimer;
  Timer? _incidentsTimer;
  bool _fetchingFrame = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    kTabRequest.addListener(_onTabRequested);
    _clearSystemAlerts();
    _consumeLaunchTarget();
    _initConnectionAndFcm();
  }

  String _normalizeServerUrl(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'/$'), '');
    if (s.isEmpty) return 'http://127.0.0.1:8000';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri != null && !uri.hasPort) {
      s = '$s:8000';
    }
    return s;
  }

  Future<void> _syncNativeBgService() async {
    try {
      await _bgServiceChannel.invokeMethod('syncConfig', {
        'baseUrl': _baseUrl,
        'lastIncidentId': _lastNotifiedIncidentId ?? -1,
        'lastTestSeq': _lastTestAlertSeq ?? -1,
      });
      final exempt =
          await _bgServiceChannel.invokeMethod<bool>('isBatteryExempt') ?? true;
      if (mounted && exempt != _batteryExempt) {
        setState(() {
          _batteryExempt = exempt;
        });
      }
    } catch (_) {}
  }

  Future<String?> _discoverLaptopIpOnNetwork() async {
    final subnets = <String>{};
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          final parts = ip.split('.');
          if (parts.length == 4 &&
              (ip.startsWith('192.168.') ||
                  ip.startsWith('172.') ||
                  ip.startsWith('10.'))) {
            subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }
        }
      }
    } catch (_) {}

    final defaultUri = Uri.tryParse(kDefaultLanServerUrl);
    if (defaultUri != null) {
      final dp = defaultUri.host.split('.');
      if (dp.length == 4) {
        subnets.add('${dp[0]}.${dp[1]}.${dp[2]}');
      }
    }
    subnets.addAll(['192.168.43', '192.168.137', '172.20.10']);

    for (final subnet in subnets) {
      for (int start = 1; start <= 254; start += 45) {
        final end = (start + 44 > 254) ? 254 : start + 44;
        final futures = <Future<String?>>[];
        for (int host = start; host <= end; host++) {
          final candidateUrl = 'http://$subnet.$host:8000';
          futures.add(() async {
            try {
              final r = await http
                  .get(Uri.parse('$candidateUrl/api/status/'))
                  .timeout(const Duration(milliseconds: 450));
              if (r.statusCode == 200 && r.body.contains('camera_name')) {
                return candidateUrl;
              }
            } catch (_) {}
            return null;
          }());
        }
        final results = await Future.wait(futures);
        for (final found in results) {
          if (found != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('server_base_url', found);
            if (mounted) {
              setState(() {
                _baseUrl = found;
                _connected = true;
              });
            }
            _syncNativeBgService();
            return found;
          }
        }
      }
    }
    return null;
  }

  Future<void> _initConnectionAndFcm() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLastId = prefs.getInt('last_notified_incident_id');
    if (savedLastId != null && savedLastId > 0) {
      _lastNotifiedIncidentId = savedLastId;
    }
    final savedUrl = prefs.getString('server_base_url');
    final candidates = <String>[
      if (savedUrl != null && savedUrl.isNotEmpty) savedUrl,
      'http://127.0.0.1:8000',
      kDefaultLanServerUrl,
      'http://10.0.2.2:8000',
    ];

    bool foundQuick = false;
    for (final c in candidates.toSet()) {
      try {
        final r = await http
            .get(Uri.parse('$c/api/status/'))
            .timeout(const Duration(milliseconds: 800));
        if (r.statusCode == 200) {
          _baseUrl = c;
          await prefs.setString('server_base_url', c);
          foundQuick = true;
          break;
        }
      } catch (_) {}
    }

    if (!foundQuick) {
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _baseUrl = savedUrl;
      }
      _discoverLaptopIpOnNetwork();
    }

    _syncNativeBgService();

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
      _registerDeviceToken(
        'flutter-android-${DateTime.now().millisecondsSinceEpoch}',
        'Flutter Android (Foreground Guard + Heads-Up)',
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
    WidgetsBinding.instance.removeObserver(this);
    kTabRequest.removeListener(_onTabRequested);
    _statusTimer?.cancel();
    _frameTimer?.cancel();
    _incidentsTimer?.cancel();
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

  /// Saat aplikasi sedang dibuka, tidak ada notifikasi melayang. Insiden baru
  /// cukup masuk ke daftar Bukti Insiden (badge angka bertambah) dan perangkat
  /// bergetar singkat. Notifikasi melayang hanya muncul ketika aplikasi ditutup.
  Future<void> _triggerAlertBothHeadsUpAndSystem({
    required int id,
    required String title,
    required String body,
    String? snapshotUrl,
  }) async {
    HapticFeedback.mediumImpact();
    _fetchIncidents();
    _clearSystemAlerts();
  }

  Future<void> _clearSystemAlerts() async {
    try {
      await _bgServiceChannel.invokeMethod('clearAlerts');
    } catch (_) {}
  }

  Future<void> _consumeLaunchTarget() async {
    try {
      final tab = await _bgServiceChannel.invokeMethod<String>('consumeLaunchTab');
      if (tab == 'incidents') {
        kTabRequest.value = 1;
      }
    } catch (_) {}
  }

  void _selectTab(int idx) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = idx;
    });
    if (idx == 0 && _sourceMode == 'webcam') {
      _updateConfig({'source_mode': 'webcam'});
    } else if (idx != 0 && _sourceMode == 'webcam') {
      _updateConfig({'stop_stream': true});
    }
    if (idx == 1) _fetchIncidents();
    if (idx == 2) _fetchMetrics();
  }

  void _onTabRequested() {
    final req = kTabRequest.value;
    if (req != null) {
      kTabRequest.value = null;
      if (mounted && req != _selectedIndex) _selectTab(req);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clearSystemAlerts();
      _consumeLaunchTarget();
      _syncNativeBgService();
      _fetchIncidents();
    }
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
            final rawIps = data['server_ips'] as List?;
            if (rawIps != null) {
              _detectedServerIps = rawIps.map((e) => e.toString()).toList();
            }

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

        // Sync test_alert_seq
        final serverTestSeq = (data['test_alert_seq'] ?? 0) as int;
        if (_lastTestAlertSeq == null) {
          _lastTestAlertSeq = serverTestSeq;
        } else if (serverTestSeq > _lastTestAlertSeq!) {
          _lastTestAlertSeq = serverTestSeq;
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

        _syncNativeBgService();
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
    HapticFeedback.selectionClick();
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/config/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<void> _handleManualCapture() async {
    HapticFeedback.mediumImpact();
    try {
      final res = await http.post(Uri.parse('$_baseUrl/api/capture/'));
      if (res.statusCode == 200) {
        _fetchIncidents();
        _fetchStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Snapshot berhasil disimpan ke Galeri Bukti.'),
              backgroundColor: SgColors.emeraldDeep,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _handleTestNotification() async {
    HapticFeedback.mediumImpact();
    try {
      await http.post(Uri.parse('$_baseUrl/api/notifications/test/'));
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Sinyal uji terkirim. Notifikasi melayang hanya tampil saat aplikasi ditutup.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: SgColors.inkPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleTestWhenAppClosed() async {
    HapticFeedback.mediumImpact();
    final latestSnap = _incidents.isNotEmpty
        ? (_incidents.first['snapshot_url'] as String? ?? '')
        : '';
    try {
      await _bgServiceChannel.invokeMethod('triggerDelayedTest', {
        'delayMs': 3500,
        'title': 'PELANGGARAN KTR • $_cameraName',
        'body':
            'Notifikasi Latar Belakang Aktif! Muncul di atas layar meskipun aplikasi ditutup.',
        'snapshotUrl': latestSnap,
        'baseUrl': _baseUrl,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sekarang tekan tombol HOME / tutup aplikasi! Notifikasi akan muncul di atas layar HP dalam 3.5 detik.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: SgColors.inkPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleClearIncidents() async {
    HapticFeedback.mediumImpact();
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
    bool isScanning = false;
    String scanMessage = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: SgColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: SgColors.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.hub_outlined, color: SgColors.emeraldPrimary, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Koneksi Server & Jaringan',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: SgColors.inkPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mendukung Kabel USB, Wi-Fi yang sama, atau Hotspot HP ke Laptop:',
                  style: TextStyle(fontSize: 12.5, color: SgColors.inkSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    labelText: 'IP Laptop / URL Backend (Port 8000)',
                    hintText: 'Contoh: 192.168.43.105',
                    filled: true,
                    fillColor: SgColors.canvas,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SgColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SgColors.emeraldDeep,
                      side: const BorderSide(color: SgColors.emeraldPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: isScanning
                        ? null
                        : () async {
                            setDialogState(() {
                              isScanning = true;
                              scanMessage =
                                  'Memindai subnet Wi-Fi / Hotspot HP...';
                            });
                            final found = await _discoverLaptopIpOnNetwork();
                            if (!ctx.mounted) return;
                            setDialogState(() {
                              isScanning = false;
                              if (found != null) {
                                controller.text = found;
                                scanMessage = 'Terhubung otomatis ke: $found';
                              } else {
                                scanMessage =
                                    'IP belum ditemukan. Pastikan Laptop & HP satu Wi-Fi/Hotspot.';
                              }
                            });
                          },
                    icon: isScanning
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar_rounded, size: 18),
                    label: Text(
                      isScanning
                          ? 'Memindai Jaringan...'
                          : 'Scan Otomatis IP Laptop (Wi-Fi / Hotspot)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                if (scanMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    scanMessage,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scanMessage.startsWith('Terhubung')
                          ? SgColors.emeraldPrimary
                          : SgColors.crimsonAlert,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      backgroundColor: SgColors.surfaceSubtle,
                      label: const Text(
                        'Kabel USB (127.0.0.1)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () =>
                          controller.text = 'http://127.0.0.1:8000',
                    ),
                    ActionChip(
                      backgroundColor: SgColors.surfaceSubtle,
                      label: Text(
                        'Wi-Fi (${Uri.tryParse(kDefaultLanServerUrl)?.host ?? '192.168.1.138'})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => controller.text = kDefaultLanServerUrl,
                    ),
                    for (final ip in _detectedServerIps)
                      if ('http://$ip:8000' != kDefaultLanServerUrl)
                        ActionChip(
                          backgroundColor: SgColors.surfaceSubtle,
                          label: Text(
                            'IP Laptop ($ip)',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () =>
                              controller.text = 'http://$ip:8000',
                        ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SgColors.emeraldPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final nextUrl = _normalizeServerUrl(controller.text);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('server_base_url', nextUrl);
                if (mounted) {
                  setState(() {
                    _baseUrl = nextUrl;
                  });
                }
                _syncNativeBgService();
                _fetchStatus();
                _fetchIncidents();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan Koneksi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAlert = _statusText == 'PELANGGARAN MEROKOK';
    final isVerifying = _statusText == 'VERIFIKASI';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: SgColors.surface,
            border: Border(
              bottom: BorderSide(color: SgColors.borderSubtle, width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const SmokeGuardLogoMark(size: 40),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'SmokeGuard AI',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: SgColors.inkPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _RadarPulseDot(
                              color: !_connected
                                  ? SgColors.crimsonAlert
                                  : isAlert
                                      ? SgColors.crimsonAlert
                                      : isVerifying
                                          ? SgColors.amberWarn
                                          : SgColors.emeraldLight,
                              size: 7,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _connected
                                    ? '$_cameraName • Frame $_currentFrame/$_totalFrames'
                                    : 'Menghubungkan ke $_baseUrl...',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: _connected
                                      ? SgColors.inkSecondary
                                      : SgColors.crimsonAlert,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildHeaderIconButton(
                    icon: Icons.notifications_active_outlined,
                    tooltip: 'Uji Notifikasi Atas Layar',
                    color: SgColors.emeraldDeep,
                    bgColor: SgColors.emeraldTint,
                    onTap: _handleTestNotification,
                  ),
                  const SizedBox(width: 7),
                  _buildHeaderIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Pengaturan IP / USB / Hotspot',
                    color: SgColors.inkSecondary,
                    bgColor: SgColors.surfaceSubtle,
                    onTap: _showServerConfigDialog,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: _selectedIndex == 0
                  ? _buildMonitorTab(isAlert, isVerifying)
                  : _selectedIndex == 1
                      ? _buildIncidentsTab()
                      : _buildMetricsTab(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SgColors.surface,
          border: Border(
            top: BorderSide(color: SgColors.borderSubtle, width: 1),
          ),
        ),
        child: NavigationBar(
          height: 66,
          backgroundColor: SgColors.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: SgColors.emeraldTint,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.videocam_outlined, color: SgColors.inkSecondary),
              selectedIcon: Icon(
                Icons.videocam_rounded,
                color: SgColors.emeraldDeep,
              ),
              label: 'Live Monitor',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _totalIncidents > 0,
                backgroundColor: SgColors.crimsonAlert,
                label: Text('$_totalIncidents'),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: SgColors.inkSecondary,
                ),
              ),
              selectedIcon: Badge(
                isLabelVisible: _totalIncidents > 0,
                backgroundColor: SgColors.crimsonAlert,
                label: Text('$_totalIncidents'),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: SgColors.emeraldDeep,
                ),
              ),
              label: 'Bukti Insiden',
            ),
            const NavigationDestination(
              icon: Icon(
                Icons.analytics_outlined,
                color: SgColors.inkSecondary,
              ),
              selectedIcon: Icon(
                Icons.analytics_rounded,
                color: SgColors.emeraldDeep,
              ),
              label: 'Evaluasi TA',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: LIVE MONITOR
  // ==========================================================================
  Widget _buildMonitorTab(bool isAlert, bool isVerifying) {
    final statusColor = isAlert
        ? SgColors.crimsonAlert
        : isVerifying
            ? SgColors.amberWarn
            : SgColors.emeraldPrimary;

    final progressRatio = _minConsecutiveFrames > 0
        ? (_consecutiveHits / _minConsecutiveFrames).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // 1. Source Switcher Segmented Bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SgColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SgColors.border),
          ),
          child: Row(
            children: [
              _buildSourceSegment(
                mode: 'cctv_demo',
                label: 'Video Uji CCTV',
                icon: Icons.movie_filter_outlined,
              ),
              const SizedBox(width: 4),
              _buildSourceSegment(
                mode: 'webcam',
                label: 'Kamera Webcam',
                icon: Icons.center_focus_strong_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Cinema Computer-Vision Viewport with Viewfinder Reticles & Pinch-Zoom
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          decoration: BoxDecoration(
            color: const Color(0xFF07140E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isAlert
                  ? SgColors.crimsonAlert
                  : isVerifying
                      ? SgColors.amberWarn
                      : SgColors.emeraldPrimary.withValues(alpha: 0.45),
              width: isAlert ? 2.2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isAlert ? SgColors.crimsonAlert : SgColors.inkPrimary)
                    .withValues(alpha: isAlert ? 0.18 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_latestFrameBytes != null)
                      InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 3.5,
                        child: Image.memory(
                          _latestFrameBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: SgColors.emeraldLight,
                                strokeWidth: 2.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _connected
                                  ? 'Memuat stream YOLOv8...'
                                  : 'Menghubungkan ke $_baseUrl...',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Computer Vision Viewfinder Reticle Overlay
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _ViewfinderCornersPainter(color: statusColor),
                      ),
                    ),

                    // Top-Left Live Status Pill
                    Positioned(
                      top: 12,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAlert
                                  ? Icons.warning_amber_rounded
                                  : isVerifying
                                      ? Icons.timelapse_rounded
                                      : Icons.verified_user_outlined,
                              color: Colors.white,
                              size: 13.5,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isAlert
                                  ? 'PELANGGARAN'
                                  : isVerifying
                                      ? 'VERIFIKASI ($_consecutiveHits/$_minConsecutiveFrames)'
                                      : 'AREA AMAN KTR',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                letterSpacing: 0.3,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Top-Right Telemetry Pill (FPS & Latency)
                    Positioned(
                      top: 12,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xBF07140E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          '${_fps.toStringAsFixed(1)} FPS • ${_inferenceMs.toStringAsFixed(0)} ms',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Smooth Temporal Verification Progress Bar
              Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                color: const Color(0xFF0A1D15),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Verifikasi $_consecutiveHits/$_minConsecutiveFrames Frame',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB7D3C6),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Conf ${(_confThreshold * 100).round()}%',
                          style: const TextStyle(
                            color: SgColors.emeraldLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progressRatio),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) => LinearProgressIndicator(
                          value: val,
                          minHeight: 5,
                          backgroundColor: const Color(0xFF163326),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Quick Stream Controls Row
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _paused
                      ? SgColors.emeraldPrimary
                      : SgColors.inkPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final next = !_paused;
                  setState(() => _paused = next);
                  _updateConfig({'paused': next});
                },
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 18,
                ),
                label: Text(
                  _paused ? 'Lanjutkan Stream' : 'Jeda Stream',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SgColors.emeraldDeep,
                  backgroundColor: SgColors.surface,
                  side: const BorderSide(color: SgColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleManualCapture,
                icon: const Icon(Icons.camera_enhance_outlined, size: 17),
                label: const Text(
                  'Ambil Snapshot',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4. Live Telemetry 2x2 Architectural Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1.55,
          children: [
            _buildTelemetryTile(
              label: 'ORANG TERDETEKSI',
              value: '$_personCount',
              unit: 'Orang di ROI',
              icon: Icons.person_search_outlined,
              accent: SgColors.emeraldPrimary,
            ),
            _buildTelemetryTile(
              label: 'PEROKOK AKTIF',
              value: '$_smokerCount',
              unit: '$_cigaretteCount Titik Rokok',
              icon: Icons.smoke_free_rounded,
              accent: _smokerCount > 0
                  ? SgColors.crimsonAlert
                  : SgColors.emeraldPrimary,
              isAlert: _smokerCount > 0,
            ),
            _buildTelemetryTile(
              label: 'MAX CONFIDENCE',
              value: '${(_maxConfidence * 100).toStringAsFixed(1)}%',
              unit: 'Ambang ${(_confThreshold * 100).round()}%',
              icon: Icons.track_changes_rounded,
              accent: SgColors.emeraldDeep,
            ),
            _buildTelemetryTile(
              label: 'AKSELERASI AI',
              value: '${_fps.toStringAsFixed(1)} FPS',
              unit: _deviceName,
              icon: Icons.memory_rounded,
              accent: SgColors.emeraldDeep,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 5. Dedicated Background Guard & Closed-App Notification Tester Card
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: SgColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SgColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: SgColors.emeraldTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: SgColors.emeraldDeep,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Proteksi Notifikasi Saat Aplikasi Ditutup',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: SgColors.inkPrimary,
                          ),
                        ),
                        Text(
                          _fcmActive
                              ? 'Foreground Service + FCM Aktif • Siap muncul di atas layar'
                              : 'Android Foreground Service Aktif • Siap muncul di atas layar',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: SgColors.emeraldPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: SgColors.emeraldTint,
                        foregroundColor: SgColors.emeraldDeep,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: _handleTestWhenAppClosed,
                      icon: const Icon(Icons.timer_outlined, size: 17),
                      label: const Text(
                        'Uji Saat Aplikasi Ditutup (3.5d)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (!_batteryExempt) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SgColors.amberWarn,
                        side: const BorderSide(color: SgColors.amberWarn),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      onPressed: () async {
                        await _bgServiceChannel
                            .invokeMethod('requestBatteryExemption');
                        _syncNativeBgService();
                      },
                      child: const Text(
                        'Izin Baterai',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 6. Real-Time YOLOv8 Engine Parameter Card
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: SgColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SgColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: SgColors.emeraldDeep,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Parameter Deteksi Real-Time YOLOv8',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: SgColors.inkPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Confidence Threshold',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: SgColors.inkSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: SgColors.emeraldTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(_confThreshold * 100).round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: SgColors.emeraldDeep,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _confThreshold.clamp(0.15, 0.85),
                min: 0.15,
                max: 0.85,
                divisions: 14,
                onChanged: (v) {
                  setState(() => _confThreshold = v);
                },
                onChangeEnd: (v) {
                  _updateConfig({'conf_threshold': v});
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Filter Temporal (Anti-Gangguan 1 Frame)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: SgColors.inkSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: SgColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$_minConsecutiveFrames Frame',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: SgColors.inkPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _minConsecutiveFrames.toDouble().clamp(3, 30),
                min: 3,
                max: 30,
                divisions: 9,
                onChanged: (v) {
                  setState(() => _minConsecutiveFrames = v.round());
                },
                onChangeEnd: (v) {
                  _updateConfig({'min_consecutive_frames': v.round()});
                },
              ),
              const Divider(color: SgColors.borderSubtle, height: 18),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Two-Stage Detection (Person ROI + Rokok)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SgColors.inkPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Mencegah objek latar/tiang kayu salah terdeteksi sebagai rokok',
                  style: TextStyle(fontSize: 11.5, color: SgColors.inkMuted),
                ),
                value: _twoStage,
                onChanged: (v) {
                  setState(() => _twoStage = v);
                  _updateConfig({'two_stage': v});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Tampilkan Bounding Box Orang (AMAN / MEROKOK)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: SgColors.inkPrimary,
                  ),
                ),
                value: _showPersonBox,
                onChanged: (v) {
                  setState(() => _showPersonBox = v);
                  _updateConfig({'show_person_box': v});
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceSegment({
    required String mode,
    required String label,
    required IconData icon,
  }) {
    final active = _sourceMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_sourceMode != mode) {
            setState(() => _sourceMode = mode);
            _updateConfig({'source_mode': mode});
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? SgColors.emeraldPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : SgColors.inkSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : SgColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryTile({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color accent,
    bool isAlert = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: isAlert ? SgColors.crimsonTint : SgColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? SgColors.crimsonBorder : SgColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isAlert ? SgColors.crimsonAlert : SgColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isAlert ? SgColors.crimsonAlert : SgColors.inkPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SgColors.inkSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 2: INCIDENT SNAPSHOT GALLERY
  // ==========================================================================
  Widget _buildIncidentsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: SgColors.surface,
            border: Border(
              bottom: BorderSide(color: SgColors.borderSubtle),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Galeri Bukti Pelanggaran ($_totalIncidents)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: SgColors.inkPrimary,
                    ),
                  ),
                  const Text(
                    'Tersimpan otomatis setelah lolos verifikasi temporal',
                    style: TextStyle(fontSize: 11.5, color: SgColors.inkMuted),
                  ),
                ],
              ),
              if (_incidents.isNotEmpty)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SgColors.crimsonAlert,
                    side: const BorderSide(color: SgColors.crimsonBorder),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: _handleClearIncidents,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text(
                    'Bersihkan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _incidents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SmokeGuardLogoMark(size: 56),
                      const SizedBox(height: 14),
                      const Text(
                        'Belum Ada Bukti Pelanggaran',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: SgColors.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Snapshot otomatis direkam saat perokok terkonfirmasi.',
                        style: TextStyle(
                          color: SgColors.inkSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
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
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: Duration(
                        milliseconds: 220 + math.min(i * 45, 250),
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, animVal, child) => Opacity(
                        opacity: animVal,
                        child: Transform.translate(
                          offset: Offset(0, (1.0 - animVal) * 14),
                          child: child,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: SgColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: SgColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showSnapshotPreviewModal(
                            fullImgUrl,
                            item,
                            confPct,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      fullImgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: SgColors.inkMuted,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: SgColors.crimsonAlert,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Conf $confPct%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(13),
                                child: Row(
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
                                              color: SgColors.inkPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${item['cigarette_count'] ?? 1} Titik Rokok • ${item['person_count'] ?? 1} Orang • ${item['timestamp'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: SgColors.inkSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.open_in_full_rounded,
                                      size: 17,
                                      color: SgColors.inkMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showSnapshotPreviewModal(
    String fullImgUrl,
    Map<String, dynamic> item,
    int confPct,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SgColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.network(fullImgUrl, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['camera_name'] ?? _cameraName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: SgColors.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lokasi: ${item['location'] ?? _location}\n'
                    'Waktu: ${item['timestamp'] ?? '-'} • Frame #${item['frame_number'] ?? 0}\n'
                    'Deteksi: ${item['cigarette_count'] ?? 1} Rokok (Confidence $confPct%)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: SgColors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: SgColors.emeraldPrimary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup Pratinjau'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 3: MODEL EVALUATION METRICS (TA)
  // ==========================================================================
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
            fontSize: 15.5,
            color: SgColors.inkPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Hasil pelatihan 50 Epoch pada 8.666 citra dataset rokok',
          style: TextStyle(fontSize: 12, color: SgColors.inkSecondary),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1.55,
          children: [
            _buildTelemetryTile(
              label: 'mAP@50 (VALIDASI)',
              value: '$valMap50%',
              unit: '1.726 Citra Validasi',
              icon: Icons.verified_outlined,
              accent: SgColors.emeraldPrimary,
            ),
            _buildTelemetryTile(
              label: 'mAP@50 (TESTING)',
              value: '$testMap50%',
              unit: '872 Citra Testing',
              icon: Icons.fact_check_outlined,
              accent: SgColors.emeraldPrimary,
            ),
            _buildTelemetryTile(
              label: 'PRECISION / RECALL',
              value: '$valPrec% / $valRec%',
              unit: '50 Epoch Training',
              icon: Icons.insights_rounded,
              accent: SgColors.emeraldDeep,
            ),
            _buildTelemetryTile(
              label: 'TOTAL DATASET',
              value: '8.666',
              unit: '6.068 Train • 1.726 Val',
              icon: Icons.dataset_outlined,
              accent: SgColors.emeraldDeep,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SgColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SgColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Arsitektur Two-Stage YOLOv8 + Filter Temporal',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: SgColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _buildStageRow(
                step: '01',
                title: 'Tahap 1 — Person ROI Detection (YOLOv8n)',
                desc:
                    'Mendeteksi koordinat manusia terlebih dahulu sehingga objek statis latar belakang (seperti tiang kayu atau perabot) tidak memicu false positive.',
              ),
              const SizedBox(height: 10),
              _buildStageRow(
                step: '02',
                title: 'Tahap 2 — Upper-Body HD Cropping (640x640)',
                desc:
                    'Memotong area kepala hingga tangan pada resolusi asli sebelum di-upscale ke model best.pt sehingga objek rokok berukuran kecil tetap tajam.',
              ),
              const SizedBox(height: 10),
              _buildStageRow(
                step: '03',
                title: 'Tahap 3 — Verifikasi Temporal & Background FCM Guard',
                desc:
                    'Memastikan deteksi konsisten selama N frame berturut-turut sebelum menyimpan bukti snapshot dan memicu Heads-Up Notification di atas layar HP.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageRow({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: SgColors.emeraldTint,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              color: SgColors.emeraldDeep,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: SgColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: SgColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
