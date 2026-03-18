import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

// ─────────────────────────────────────────────
// Modelos
// ─────────────────────────────────────────────
enum _BreathPhase { inhale, hold, exhale, holdEmpty }

class _Technique {
  final String name;
  final String description;
  final String emoji;
  final Color color;
  final Color colorDark;
  final List<int> durations; // [inhale, hold, exhale, holdEmpty] en segundos
  final List<String> phaseLabels;

  const _Technique({
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
    required this.colorDark,
    required this.durations,
    required this.phaseLabels,
  });

  int get totalCycle => durations.reduce((a, b) => a + b);
}

// ─────────────────────────────────────────────
// Técnicas disponibles
// ─────────────────────────────────────────────
const _techniques = [
  _Technique(
    name: '4-7-8',
    description: 'Relaja el sistema nervioso y reduce la ansiedad',
    emoji: '🌙',
    color: Color(0xFF5C6BC0),
    colorDark: Color(0xFF283593),
    durations: [4, 7, 8, 0],
    phaseLabels: ['Inhala', 'Sostén', 'Exhala', ''],
  ),
  _Technique(
    name: 'Caja',
    description: 'Mejora el foco y calma la mente rápidamente',
    emoji: '⬜',
    color: Color(0xFF26A69A),
    colorDark: Color(0xFF00695C),
    durations: [4, 4, 4, 4],
    phaseLabels: ['Inhala', 'Sostén', 'Exhala', 'Sostén'],
  ),
  _Technique(
    name: 'Coherente',
    description: 'Equilibra el corazón y la mente con ritmo suave',
    emoji: '💙',
    color: Color(0xFF1976D2),
    colorDark: Color(0xFF0D47A1),
    durations: [5, 0, 5, 0],
    phaseLabels: ['Inhala', '', 'Exhala', ''],
  ),
];

// ─────────────────────────────────────────────
// Breathing Screen
// ─────────────────────────────────────────────
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with TickerProviderStateMixin {

  // Técnica seleccionada
  int _techniqueIndex = 0;
  _Technique get _technique => _techniques[_techniqueIndex];

  // Estado del ejercicio
  bool _isRunning = false;
  bool _isPaused  = false;
  int  _cycleCount = 0;
  int  _targetCycles = 5;
  bool _completed = false;

  // Fase actual
  _BreathPhase _phase = _BreathPhase.inhale;
  int _phaseIndex = 0;
  int _secondsLeft = 0;
  Timer? _timer;

  // ── Animaciones ──
  // Círculo principal
  late AnimationController _circleController;
  late Animation<double>   _circleScale;

  // Olas
  late AnimationController _waveController;

  // Partículas
  late AnimationController _particleController;

  // Entrada
  late AnimationController _entryController;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  // Pulso completado
  late AnimationController _completeController;
  late Animation<double>   _completePulse;

  // Partículas generadas
  final List<_Particle> _particles = [];
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _circleScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entrySlide = Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();

    _completeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _completePulse = Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _completeController, curve: Curves.easeInOut));

    _generateParticles();
    _resetPhase();
  }

  void _generateParticles() {
    _particles.clear();
    for (int i = 0; i < 18; i++) {
      _particles.add(_Particle(
        angle: _rng.nextDouble() * 2 * math.pi,
        distance: 90 + _rng.nextDouble() * 80,
        size: 3 + _rng.nextDouble() * 5,
        speed: 0.3 + _rng.nextDouble() * 0.7,
        offset: _rng.nextDouble(),
      ));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _circleController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _entryController.dispose();
    _completeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Lógica de respiración
  // ─────────────────────────────────────────────
  void _resetPhase() {
    _phaseIndex = 0;
    _phase = _BreathPhase.inhale;
    _secondsLeft = _technique.durations[0];
  }

  void _start() {
    setState(() {
      _isRunning  = true;
      _isPaused   = false;
      _cycleCount = 0;
      _completed  = false;
    });
    _resetPhase();
    _runPhase();
    HapticFeedback.mediumImpact();
  }

  void _pause() {
    setState(() => _isPaused = true);
    _timer?.cancel();
    _circleController.stop();
    HapticFeedback.lightImpact();
  }

  void _resume() {
    setState(() => _isPaused = false);
    _runPhase();
    HapticFeedback.lightImpact();
  }

  void _stop() {
    _timer?.cancel();
    _circleController.reset();
    setState(() {
      _isRunning  = false;
      _isPaused   = false;
      _cycleCount = 0;
      _completed  = false;
    });
    _resetPhase();
    HapticFeedback.mediumImpact();
  }

  void _runPhase() {
    _timer?.cancel();

    // Saltar fases con duración 0
    while (_technique.durations[_phaseIndex] == 0) {
      _phaseIndex = (_phaseIndex + 1) % 4;
      if (_phaseIndex == 0) {
        _cycleCount++;
        if (_cycleCount >= _targetCycles) {
          _onComplete();
          return;
        }
      }
    }

    final duration = _technique.durations[_phaseIndex];
    setState(() {
      _phase      = _BreathPhase.values[_phaseIndex];
      _secondsLeft = duration;
    });

    // Animar círculo
    _circleController.duration = Duration(seconds: duration);
    if (_phaseIndex == 0) {
      // Inhala → expande
      _circleController.forward(from: 0);
    } else if (_phaseIndex == 2) {
      // Exhala → contrae
      _circleController.reverse(from: 1);
    }
    // Hold → no cambia

    HapticFeedback.selectionClick();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);

      if (_secondsLeft <= 0) {
        t.cancel();
        _phaseIndex = (_phaseIndex + 1) % 4;
        if (_phaseIndex == 0) {
          _cycleCount++;
          if (_cycleCount >= _targetCycles) {
            _onComplete();
            return;
          }
        }
        _runPhase();
      }
    });
  }

  void _onComplete() {
    _timer?.cancel();
    _circleController.reset();
    setState(() {
      _isRunning = false;
      _completed = true;
    });
    HapticFeedback.heavyImpact();
  }

  String get _phaseLabel {
    if (!_isRunning) return 'Listo para comenzar';
    if (_isPaused)   return 'En pausa';
    return _technique.phaseLabels[_phaseIndex].isNotEmpty
        ? _technique.phaseLabels[_phaseIndex]
        : '...';
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _technique.colorDark,
        body: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: Stack(
              children: [
                // Fondo animado con olas
                Positioned.fill(child: _buildBackground()),

                // Contenido
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(),
                      if (!_isRunning && !_completed) _buildTechniqueSelector(),
                      Expanded(child: _buildBreathingArea()),
                      _buildControls(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Overlay de completado
                if (_completed) _buildCompletedOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Fondo con olas
  // ─────────────────────────────────────────────
  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (_, __) {
        return CustomPaint(
          painter: _WaveBackgroundPainter(
            progress: _waveController.value,
            color: _technique.color,
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Text(
              'Respiración guiada',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Ciclos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_cycleCount/$_targetCycles 🔄',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Selector de técnica
  // ─────────────────────────────────────────────
  Widget _buildTechniqueSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elige una técnica',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_techniques.length, (i) {
              final t = _techniques[i];
              final selected = _techniqueIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _techniqueIndex = i);
                    _resetPhase();
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withOpacity(0.6)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          t.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(selected ? 1.0 : 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.durations.where((d) => d > 0).join('-')}s',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Descripción
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _technique.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Selector de ciclos
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ciclos: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              ...([3, 5, 7, 10].map((n) {
                final sel = _targetCycles == n;
                return GestureDetector(
                  onTap: () => setState(() => _targetCycles = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel
                          ? Colors.white
                          : Colors.white.withOpacity(0.15),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? _technique.colorDark : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              })),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Área de respiración
  // ─────────────────────────────────────────────
  Widget _buildBreathingArea() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Partículas
            if (_isRunning && !_isPaused)
              AnimatedBuilder(
                animation: _particleController,
                builder: (_, __) {
                  return CustomPaint(
                    size: const Size(280, 280),
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _particleController.value,
                      color: _technique.color,
                      scale: _circleScale.value,
                    ),
                  );
                },
              ),

            // Anillos exteriores
            AnimatedBuilder(
              animation: _circleController,
              builder: (_, __) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anillo 3
                    Transform.scale(
                      scale: 0.5 + _circleScale.value * 0.55,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _technique.color.withOpacity(0.06),
                        ),
                      ),
                    ),
                    // Anillo 2
                    Transform.scale(
                      scale: 0.55 + _circleScale.value * 0.45,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _technique.color.withOpacity(0.10),
                        ),
                      ),
                    ),
                    // Anillo 1
                    Transform.scale(
                      scale: 0.6 + _circleScale.value * 0.4,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _technique.color.withOpacity(0.15),
                        ),
                      ),
                    ),
                    // Círculo principal
                    Transform.scale(
                      scale: _circleScale.value,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.9),
                              _technique.color.withOpacity(0.6),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _technique.color.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isRunning && !_isPaused
                                    ? '$_secondsLeft'
                                    : _technique.emoji,
                                style: TextStyle(
                                  fontSize: _isRunning ? 42 : 36,
                                  fontWeight: FontWeight.w800,
                                  color: _technique.colorDark,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Etiqueta de fase
            Positioned(
              bottom: 10,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _phaseLabel,
                  key: ValueKey(_phaseLabel),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.9),
                    letterSpacing: 1,
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
  // Controles
  // ─────────────────────────────────────────────
  Widget _buildControls() {
    if (_completed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón stop (solo cuando corre)
          if (_isRunning) ...[
            GestureDetector(
              onTap: _stop,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.stop_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(width: 24),
          ],

          // Botón principal
          GestureDetector(
            onTap: !_isRunning
                ? _start
                : (_isPaused ? _resume : _pause),
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                !_isRunning
                    ? Icons.play_arrow_rounded
                    : (_isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded),
                color: _technique.colorDark,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Overlay completado
  // ─────────────────────────────────────────────
  Widget _buildCompletedOverlay() {
    return Positioned.fill(
      child: Container(
        color: _technique.colorDark.withOpacity(0.85),
        child: Center(
          child: AnimatedBuilder(
            animation: _completePulse,
            builder: (_, child) => Transform.scale(
              scale: _completePulse.value,
              child: child,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  '¡Ejercicio completado!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_targetCycles ciclos de ${_technique.name} completados 💙',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Tiempo total: ${(_targetCycles * _technique.totalCycle / 60).toStringAsFixed(1)} min',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Repetir
                    GestureDetector(
                      onTap: () {
                        setState(() => _completed = false);
                        _start();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Text(
                          '🔄 Repetir',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Salir
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '✅ Terminar',
                          style: TextStyle(
                            fontSize: 15,
                            color: _technique.colorDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────

class _WaveBackgroundPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _WaveBackgroundPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Ola 1
    paint.color = color.withOpacity(0.15);
    _drawWave(canvas, size, paint, progress, 0.35, 40);

    // Ola 2
    paint.color = color.withOpacity(0.10);
    _drawWave(canvas, size, paint, progress + 0.3, 0.45, 30);

    // Ola 3
    paint.color = color.withOpacity(0.07);
    _drawWave(canvas, size, paint, progress + 0.6, 0.55, 50);
  }

  void _drawWave(Canvas canvas, Size size, Paint paint,
      double progress, double heightFactor, double amplitude) {
    final path = Path();
    final y = size.height * heightFactor;
    path.moveTo(0, y);

    for (double x = 0; x <= size.width; x++) {
      final wave = amplitude *
          math.sin((x / size.width * 2 * math.pi) + (progress * 2 * math.pi));
      path.lineTo(x, y + wave);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveBackgroundPainter old) =>
      old.progress != progress;
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double speed;
  final double offset;
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    required this.offset,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;
  final double scale;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final phase = (progress * p.speed + p.offset) % 1.0;
      final currentDist = p.distance * scale * (0.7 + phase * 0.3);
      final opacity = math.sin(phase * math.pi) * 0.7;
      if (opacity <= 0) continue;

      paint.color = color.withOpacity(opacity);
      final x = center.dx + math.cos(p.angle + progress * 0.5) * currentDist;
      final y = center.dy + math.sin(p.angle + progress * 0.5) * currentDist;
      canvas.drawCircle(Offset(x, y), p.size * (0.5 + phase * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}