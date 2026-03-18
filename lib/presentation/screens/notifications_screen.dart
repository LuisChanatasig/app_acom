import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// ─────────────────────────────────────────────
// Notification Service
// ─────────────────────────────────────────────
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    // Timezone offset para LATAM
    final offset = DateTime.now().timeZoneOffset.inHours;
    String tzName = 'America/Bogota';
    if (offset == -6) tzName = 'America/Mexico_City';
    if (offset == -3) tzName = 'America/Sao_Paulo';
    if (offset == -4) tzName = 'America/Caracas';
    if (offset == -5) tzName = 'America/Bogota';
    tz.setLocalLocation(tz.getLocation(tzName));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notificación tocada: \${details.payload}');
      },
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  static Future<bool> hasPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  static Future<bool> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final hasPerms = await hasPermission();
      if (!hasPerms) {
        final granted = await requestPermission();
        if (!granted) return false;
      }

      final scheduledTime = _nextInstanceOf(hour, minute);
      debugPrint('Programando notificación \$id para: \$scheduledTime');

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'acom_daily_\$id',
            'ACOM Recordatorios',
            channelDescription: 'Recordatorios diarios de ACOM',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            color: const Color(0xFF1565C0),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      debugPrint('Error programando notificación: \$e');
      return false;
    }
  }

  // Notificación inmediata para probar
  static Future<void> sendTest({required String title, required String body}) async {
    await _plugin.show(
      999, title, body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'acom_test', 'ACOM Test',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    debugPrint('Notificación \$id cancelada');
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('Todas las notificaciones canceladas');
  }

  static Future<List<PendingNotificationRequest>> getPending() =>
      _plugin.pendingNotificationRequests();

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

// ─────────────────────────────────────────────
// Notification config model
// ─────────────────────────────────────────────
class _NotifConfig {
  final int id;
  final String key;
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final int defaultHour;
  final int defaultMinute;
  final List<String> messages;

  const _NotifConfig({
    required this.id,
    required this.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.defaultHour,
    required this.defaultMinute,
    required this.messages,
  });
}

const _configs = [
  _NotifConfig(
    id: 1,
    key: 'morning_motivation',
    emoji: '🌅',
    title: 'Motivación matutina',
    subtitle: 'Empieza el día con energía positiva',
    color: Color(0xFFFF9800),
    defaultHour: 8,
    defaultMinute: 0,
    messages: [
      '¡Buenos días! Hoy es un nuevo comienzo 🌟 ¿Listo para conquistar el día?',
      '☀️ Cada mañana es una oportunidad de ser mejor. ¡Tú puedes!',
      '🌈 Recuerda: eres más fuerte de lo que crees. ¡Buenos días!',
      '💪 Un nuevo día, una nueva oportunidad. ¡Haz que cuente!',
      '🦋 Buenos días. Respira profundo y comienza con calma.',
    ],
  ),
  _NotifConfig(
    id: 2,
    key: 'mood_checkin',
    emoji: '💙',
    title: 'Check-in emocional',
    subtitle: '¿Cómo te sientes en este momento?',
    color: Color(0xFF1976D2),
    defaultHour: 12,
    defaultMinute: 0,
    messages: [
      '💙 ¡Hola! ¿Cómo estás hoy? Abre ACOM y cuéntame.',
      '😊 Es hora de tu check-in emocional. ¿Cómo va tu día?',
      '🤗 Un momento para ti: ¿cómo te sientes ahora mismo?',
      '💬 ACOM te está pensando. ¿Cómo está tu corazón hoy?',
    ],
  ),
  _NotifConfig(
    id: 3,
    key: 'breathing',
    emoji: '🧘',
    title: 'Ejercicio de respiración',
    subtitle: 'Tómate 5 minutos para respirar y relajarte',
    color: Color(0xFF26A69A),
    defaultHour: 15,
    defaultMinute: 0,
    messages: [
      '🧘 Es hora de respirar. 5 minutos de calma pueden cambiar tu tarde.',
      '🌊 Pausa. Respira. Todo estará bien. Abre tu ejercicio de respiración.',
      '💨 Tu cuerpo necesita oxígeno y tu mente necesita paz. ¡Respira!',
      '🍃 Tómate un descanso. Un ejercicio de respiración te espera.',
    ],
  ),
  _NotifConfig(
    id: 4,
    key: 'diary',
    emoji: '📓',
    title: 'Escribe en tu diario',
    subtitle: 'Reflexiona sobre tu día y tus pensamientos',
    color: Color(0xFFF57C00),
    defaultHour: 21,
    defaultMinute: 0,
    messages: [
      '📓 ¿Cómo fue tu día? Escríbelo en tu diario antes de dormir.',
      '✍️ Es hora de reflexionar. Tu diario te está esperando.',
      '🌙 Antes de cerrar los ojos, ¿qué quieres recordar de hoy?',
      '📝 Unos minutos de escritura pueden aclarar la mente. ¡Inténtalo!',
    ],
  ),
];

// ─────────────────────────────────────────────
// Notifications Screen
// ─────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {

  // Estado de cada notificación
  final Map<String, bool>      _enabled = {};
  final Map<String, TimeOfDay> _times   = {};
  bool _isLoading   = true;
  bool _hasPermission = true;

  late AnimationController _entryAnim;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entryFade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut));
    _entrySlide = Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
    _loadPrefs();
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    await NotificationService.init();
    final prefs = await SharedPreferences.getInstance();

    for (final c in _configs) {
      _enabled[c.key] = prefs.getBool('notif_enabled_${c.key}') ?? false;
      final h = prefs.getInt('notif_hour_${c.key}')   ?? c.defaultHour;
      final m = prefs.getInt('notif_minute_${c.key}') ?? c.defaultMinute;
      _times[c.key] = TimeOfDay(hour: h, minute: m);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _entryAnim.forward();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in _configs) {
      await prefs.setBool('notif_enabled_${c.key}', _enabled[c.key] ?? false);
      await prefs.setInt('notif_hour_${c.key}',   _times[c.key]?.hour   ?? c.defaultHour);
      await prefs.setInt('notif_minute_${c.key}', _times[c.key]?.minute ?? c.defaultMinute);
    }
  }

  Future<void> _toggle(_NotifConfig config, bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        setState(() => _hasPermission = false);
        _showSnack('❌ Permiso de notificaciones denegado. Actívalo en ajustes del sistema.');
        return;
      }
    }

    setState(() => _enabled[config.key] = value);
    await _savePrefs();

    if (value) {
      final t = _times[config.key]!;
      final msgs = config.messages;
      final body  = msgs[DateTime.now().millisecond % msgs.length];
      await NotificationService.scheduleDaily(
        id: config.id,
        title: '${config.emoji} ${config.title}',
        body: body,
        hour: t.hour,
        minute: t.minute,
      );
      _showSnack('✅ Recordatorio activado a las ${_formatTime(t)}');
    } else {
      await NotificationService.cancel(config.id);
      _showSnack('🔕 Recordatorio desactivado');
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _pickTime(_NotifConfig config) async {
    final current = _times[config.key] ?? TimeOfDay(hour: config.defaultHour, minute: config.defaultMinute);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: config.color,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
          timePickerTheme: TimePickerThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    setState(() => _times[config.key] = picked);
    await _savePrefs();

    // Reprogramar si está activo
    if (_enabled[config.key] == true) {
      await NotificationService.cancel(config.id);
      final msgs = config.messages;
      final body  = msgs[DateTime.now().millisecond % msgs.length];
      await NotificationService.scheduleDaily(
        id: config.id,
        title: '${config.emoji} ${config.title}',
        body: body,
        hour: picked.hour,
        minute: picked.minute,
      );
      _showSnack('🕐 Hora actualizada a las ${_formatTime(picked)}');
    }
    HapticFeedback.selectionClick();
  }

  Future<void> _disableAll() async {
    for (final c in _configs) {
      setState(() => _enabled[c.key] = false);
    }
    await _savePrefs();
    await NotificationService.cancelAll();
    _showSnack('🔕 Todas las notificaciones desactivadas');
    HapticFeedback.mediumImpact();
  }

  Future<void> _enableAll() async {
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      _showSnack('❌ Permiso denegado. Actívalo en ajustes del sistema.');
      return;
    }
    for (final c in _configs) {
      setState(() => _enabled[c.key] = true);
      final t = _times[c.key]!;
      final msgs = c.messages;
      final body  = msgs[DateTime.now().millisecond % msgs.length];
      await NotificationService.scheduleDaily(
        id: c.id,
        title: '${c.emoji} ${c.title}',
        body: body,
        hour: t.hour,
        minute: t.minute,
      );
    }
    await _savePrefs();
    _showSnack('🔔 Todas las notificaciones activadas');
    HapticFeedback.mediumImpact();
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F6FF),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                  : FadeTransition(
                      opacity: _entryFade,
                      child: SlideTransition(
                        position: _entrySlide,
                        child: _buildContent(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    final activeCount = _enabled.values.where((v) => v).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF29B6F6)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notificaciones 🔔',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('Recordatorios para tu bienestar',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  // Badge activas
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$activeCount/${_configs.length} activas',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Progreso
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activeCount == 0
                            ? 'Ninguna activa'
                            : activeCount == _configs.length
                                ? '¡Todas activas! 🎉'
                                : '$activeCount notificación${activeCount > 1 ? 'es' : ''} activa${activeCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: activeCount / _configs.length,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Botones globales
              Row(
                children: [
                  Expanded(
                    child: _HeaderBtn(
                      label: 'Activar todas',
                      icon: Icons.notifications_active_rounded,
                      onTap: _enableAll,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeaderBtn(
                      label: 'Desactivar todas',
                      icon: Icons.notifications_off_rounded,
                      onTap: _disableAll,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Content
  // ─────────────────────────────────────────────
  Widget _buildContent() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // Aviso de permiso
        if (!_hasPermission) _buildPermissionBanner(),

        // Info card
        _buildInfoCard(),
        const SizedBox(height: 20),

        // Tarjetas de notificación
        ..._configs.map((c) => _NotifCard(
          config: c,
          enabled: _enabled[c.key] ?? false,
          time: _times[c.key] ?? TimeOfDay(hour: c.defaultHour, minute: c.defaultMinute),
          onToggle: (v) => _toggle(c, v),
          onPickTime: () => _pickTime(c),
        )),

        const SizedBox(height: 20),
        _buildTestCard(),
        const SizedBox(height: 16),
        _buildTipsCard(),
      ],
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Permiso de notificaciones denegado. Ve a Ajustes del sistema para activarlo.',
              style: TextStyle(fontSize: 13, color: Color(0xFFEF5350)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFE8F5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Activa los recordatorios que más te ayuden. Puedes personalizar la hora de cada uno.',
              style: TextStyle(fontSize: 13, color: Color(0xFF1565C0), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return GestureDetector(
      onTap: () async {
        final granted = await NotificationService.requestPermission();
        if (!granted) {
          _showSnack('❌ Permiso denegado. Actívalo en Ajustes del sistema.');
          return;
        }
        await NotificationService.sendTest(
          title: '🔔 ACOM — Prueba exitosa',
          body: '¡Las notificaciones funcionan correctamente! 🎉',
        );
        _showSnack('✅ Notificación de prueba enviada — revisa la barra de estado');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF29B6F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Enviar notificación de prueba',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🌟', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Recomendación ACOM',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
            ],
          ),
          const SizedBox(height: 12),
          _TipRow(emoji: '🌅', text: 'Motivación a las 8:00 AM para empezar con energía'),
          _TipRow(emoji: '💙', text: 'Check-in al mediodía para revisar cómo va tu día'),
          _TipRow(emoji: '🧘', text: 'Respiración a las 3:00 PM para el bajón de la tarde'),
          _TipRow(emoji: '📓', text: 'Diario a las 9:00 PM para reflexionar antes de dormir'),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
// Notification Card
// ─────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final _NotifConfig config;
  final bool enabled;
  final TimeOfDay time;
  final void Function(bool) onToggle;
  final VoidCallback onPickTime;

  const _NotifCard({
    required this.config,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? config.color.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: enabled
                ? config.color.withOpacity(0.15)
                : const Color(0xFF1976D2).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de color top
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            decoration: BoxDecoration(
              color: enabled ? config.color : const Color(0xFFECEFF1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // Icono
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: enabled
                            ? config.color.withOpacity(0.12)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(config.emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: enabled ? const Color(0xFF0D47A1) : const Color(0xFF90A4AE),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            config.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: enabled
                                  ? const Color(0xFF607D8B)
                                  : const Color(0xFFB0BEC5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Toggle
                    Switch.adaptive(
                      value: enabled,
                      onChanged: onToggle,
                      activeColor: config.color,
                    ),
                  ],
                ),

                // Hora (solo si está activo)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: enabled
                      ? Column(
                          children: [
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF0F4F8)),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: onPickTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: config.color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: config.color.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.access_time_rounded,
                                        color: config.color, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hora programada: ${_fmt(time)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: config.color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.edit_rounded,
                                        color: config.color.withOpacity(0.6),
                                        size: 14),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Preview del mensaje
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.format_quote_rounded,
                                      color: Color(0xFFB0BEC5), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      config.messages.first,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF90A4AE),
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String emoji;
  final String text;
  const _TipRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF607D8B), height: 1.4)),
          ),
        ],
      ),
    );
  }
}