import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

// ─────────────────────────────────────────────
// Stats Screen
// ─────────────────────────────────────────────
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {

  // Datos
  int    _daysActive      = 0;
  int    _currentStreak   = 0;
  int    _diaryEntries    = 0;
  int    _breathSessions  = 0;
  int    _chatMessages    = 0;
  double _wellnessLevel   = 0.0;
  List<double> _weekMoods = List.filled(7, 0.5);
  List<int>    _moodFreq  = List.filled(5, 0);

  bool _isLoading = true;
  String _selectedPeriod = 'Semana';

  // Animaciones
  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  late AnimationController _chartCtrl;
  late Animation<double>   _chartAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entryFade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entrySlide = Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _chartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _chartAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _chartCtrl, curve: Curves.easeOutCubic));

    _loadStats();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _chartCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();

    // Días activo
    _daysActive     = prefs.getInt('days_active')      ?? 7;
    _currentStreak  = prefs.getInt('current_streak')   ?? 3;
    _breathSessions = prefs.getInt('breath_sessions')  ?? 5;
    _chatMessages   = prefs.getInt('chat_messages')    ?? 12;
    _wellnessLevel  = prefs.getDouble('wellness_level') ?? 0.72;

    // Entradas del diario reales
    final raw = prefs.getString('acom_diary_entries');
    if (raw != null && raw.isNotEmpty) {
      try {
        final count = '},{'.allMatches(raw).length + 1;
        _diaryEntries = count;
      } catch (_) {
        _diaryEntries = 0;
      }
    }

    // Moods de la semana (simulados con tendencia realista)
    _weekMoods = [0.65, 0.80, 0.55, 0.90, 0.70, 0.85, _wellnessLevel];

    // Frecuencia de moods (simulada)
    _moodFreq = [3, 2, 4, 1, 2]; // genial, tranquilo, neutral, ansioso, triste

    if (!mounted) return;
    setState(() => _isLoading = false);
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () => _chartCtrl.forward());
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _entryFade,
                      child: SlideTransition(
                        position: _entrySlide,
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                          children: [
                            _buildStreakCard(),
                            const SizedBox(height: 16),
                            _buildStatsGrid(),
                            const SizedBox(height: 16),
                            _buildPeriodSelector(),
                            const SizedBox(height: 12),
                            _buildWellnessChart(),
                            const SizedBox(height: 16),
                            _buildMoodDonut(),
                            const SizedBox(height: 16),
                            _buildInsights(),
                          ],
                        ),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAB47BC)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mi progreso 📊',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Tu camino hacia el bienestar',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              // Bienestar badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text('${(_wellnessLevel * 100).toInt()}%',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const Text('bienestar', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Streak card
  // ─────────────────────────────────────────────
  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6F00), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFFF9800).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          // Flame + número
          Column(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 48)),
              Text('$_currentStreak días',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              const Text('racha actual', style: TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¡Sigue así!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  _currentStreak >= 7
                      ? '¡Una semana completa! Eso es increíble 🌟'
                      : _currentStreak >= 3
                          ? 'Vas muy bien, ¡no pares ahora!'
                          : 'Cada día que vuelves cuenta 💙',
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85), height: 1.4),
                ),
                const SizedBox(height: 12),
                // Mini calendario de racha
                Row(
                  children: List.generate(7, (i) {
                    final active = i < _currentStreak;
                    return Container(
                      width: 28, height: 28,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Colors.white : Colors.white.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Text(
                          active ? '✓' : '○',
                          style: TextStyle(
                            fontSize: 12,
                            color: active ? const Color(0xFFFF9800) : Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Stats grid
  // ─────────────────────────────────────────────
  Widget _buildStatsGrid() {
    final stats = [
      _StatItem('📅', '$_daysActive',       'Días activo',      const Color(0xFF1976D2)),
      _StatItem('📓', '$_diaryEntries',     'Entradas diario',  const Color(0xFFF57C00)),
      _StatItem('🧘', '$_breathSessions',   'Sesiones respir.', const Color(0xFF26A69A)),
      _StatItem('💬', '$_chatMessages',     'Mensajes',         const Color(0xFF7B1FA2)),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: stats.map((s) => _buildStatCard(s)).toList(),
    );
  }

  Widget _buildStatCard(_StatItem s) {
    return AnimatedBuilder(
      animation: _chartAnim,
      builder: (_, child) => Opacity(opacity: _chartAnim.value, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: s.color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: s.color)),
                  Text(s.label, style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Period selector
  // ─────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    return Row(
      children: ['Semana', 'Mes', 'Todo'].map((p) {
        final sel = _selectedPeriod == p;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedPeriod = p);
            HapticFeedback.lightImpact();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF7B1FA2) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: sel
                  ? [BoxShadow(color: const Color(0xFF7B1FA2).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
            ),
            child: Text(p,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : const Color(0xFF90A4AE),
                )),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────
  // Wellness bar chart
  // ─────────────────────────────────────────────
  Widget _buildWellnessChart() {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final today = DateTime.now().weekday - 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF7B1FA2).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.show_chart_rounded, color: Color(0xFF7B1FA2), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Nivel de bienestar semanal',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
              ),
              // Tendencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                child: const Text('↑ 12%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF388E3C))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final isToday = i == today;
                final val     = _weekMoods[i];
                return AnimatedBuilder(
                  animation: _chartAnim,
                  builder: (_, __) {
                    final h = 90 * val * _chartAnim.value;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Valor encima
                        Text('${(val * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isToday ? const Color(0xFF7B1FA2) : const Color(0xFFB0BEC5),
                            )),
                        const SizedBox(height: 3),
                        // Barra
                        Container(
                          width: 32,
                          height: h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: isToday
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFFCE93D8).withOpacity(0.6),
                                      const Color(0xFFE1BEE7).withOpacity(0.4),
                                    ],
                                  ),
                            boxShadow: isToday
                                ? [BoxShadow(color: const Color(0xFF7B1FA2).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                                : [],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(days[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                              color: isToday ? const Color(0xFF7B1FA2) : const Color(0xFF90A4AE),
                            )),
                      ],
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Mood donut chart
  // ─────────────────────────────────────────────
  Widget _buildMoodDonut() {
    const moodEmojis  = ['😊', '😌', '😐', '😟', '😔'];
    const moodLabels  = ['Genial', 'Tranquilo', 'Neutral', 'Ansioso', 'Triste'];
    const moodColors  = [
      Color(0xFF66BB6A), Color(0xFF29B6F6), Color(0xFFFFCA28),
      Color(0xFFFFA726), Color(0xFFEF5350),
    ];

    final total = _moodFreq.fold(0, (a, b) => a + b);
    final mostFreqIdx = _moodFreq.indexOf(_moodFreq.reduce(math.max));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.donut_large_rounded, color: Color(0xFF1976D2), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Moods más frecuentes',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Donut
              AnimatedBuilder(
                animation: _chartAnim,
                builder: (_, __) => SizedBox(
                  width: 130, height: 130,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      values: _moodFreq.map((v) => v.toDouble()).toList(),
                      colors: moodColors,
                      progress: _chartAnim.value,
                      total: total.toDouble(),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(moodEmojis[mostFreqIdx], style: const TextStyle(fontSize: 28)),
                          Text(moodLabels[mostFreqIdx],
                              style: const TextStyle(fontSize: 10, color: Color(0xFF607D8B), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Leyenda
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final pct = total > 0 ? (_moodFreq[i] / total * 100).toInt() : 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: moodColors[i]),
                          ),
                          const SizedBox(width: 8),
                          Text(moodEmojis[i], style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(moodLabels[i],
                                style: const TextStyle(fontSize: 12, color: Color(0xFF607D8B))),
                          ),
                          Text('$pct%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: moodColors[i],
                              )),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Insights
  // ─────────────────────────────────────────────
  Widget _buildInsights() {
    final insights = _generateInsights();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Insights de ACOM',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(insight.text,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85), height: 1.4)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<_Insight> _generateInsights() {
    final insights = <_Insight>[];

    if (_currentStreak >= 7) {
      insights.add(_Insight('🏆', '¡Llevas $_currentStreak días seguidos! Eso demuestra un compromiso real con tu bienestar.'));
    } else if (_currentStreak >= 3) {
      insights.add(_Insight('🔥', 'Llevas $_currentStreak días activo. ¡Estás construyendo un hábito saludable!'));
    } else {
      insights.add(_Insight('💪', 'Cada día que dedicas a tu bienestar emocional cuenta. ¡Sigue adelante!'));
    }

    if (_diaryEntries > 0) {
      insights.add(_Insight('📓', 'Has escrito $_diaryEntries entrada${_diaryEntries != 1 ? 's' : ''} en tu diario. Escribir es una forma poderosa de procesar emociones.'));
    } else {
      insights.add(_Insight('📓', 'Prueba escribir en tu diario. Incluso 5 minutos al día puede hacer una gran diferencia.'));
    }

    if (_breathSessions > 3) {
      insights.add(_Insight('🧘', 'Has completado $_breathSessions sesiones de respiración. Tu sistema nervioso te lo agradece.'));
    } else {
      insights.add(_Insight('🌬️', 'La respiración guiada puede reducir el estrés en minutos. Prueba una sesión hoy.'));
    }

    if (_wellnessLevel >= 0.75) {
      insights.add(_Insight('🌟', 'Tu nivel de bienestar es alto. ¡Sigue cultivando lo que te hace sentir bien!'));
    } else if (_wellnessLevel >= 0.5) {
      insights.add(_Insight('💙', 'Tu bienestar va bien. Pequeños hábitos diarios pueden llevarlo aún más alto.'));
    } else {
      insights.add(_Insight('🤗', 'Todos tenemos altibajos. Estoy aquí para acompañarte en este proceso.'));
    }

    return insights;
  }
}

// ─────────────────────────────────────────────
// Modelos auxiliares
// ─────────────────────────────────────────────
class _StatItem {
  final String emoji, value, label;
  final Color color;
  const _StatItem(this.emoji, this.value, this.label, this.color);
}

class _Insight {
  final String emoji, text;
  const _Insight(this.emoji, this.text);
}

// ─────────────────────────────────────────────
// Donut Painter
// ─────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color>  colors;
  final double       progress;
  final double       total;

  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.progress,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeW = 20.0;

    final paint = Paint()
      ..style    = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap   = StrokeCap.round;

    // Fondo
    paint.color = const Color(0xFFF0F4F8);
    canvas.drawCircle(center, radius, paint);

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * math.pi * progress;
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.05,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.values != values;
}