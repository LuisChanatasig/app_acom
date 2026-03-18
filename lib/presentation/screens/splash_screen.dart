import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoFloat;

  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  late AnimationController _particleController;
  late Animation<double> _particleOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulse;

  late AnimationController _dotsController;

  final List<_FloatingIcon> _icons = [
    _FloatingIcon(icon: Icons.favorite_rounded,      angle: -45,  distance: 140, size: 22, delay: 0.0),
    _FloatingIcon(icon: Icons.chat_bubble_rounded,   angle: 200,  distance: 130, size: 20, delay: 0.15),
    _FloatingIcon(icon: Icons.verified_user_rounded, angle: 20,   distance: 150, size: 22, delay: 0.25),
    _FloatingIcon(icon: Icons.people_alt_rounded,    angle: 120,  distance: 145, size: 20, delay: 0.10),
    _FloatingIcon(icon: Icons.notifications_rounded, angle: 310,  distance: 135, size: 18, delay: 0.35),
    _FloatingIcon(icon: Icons.star_rounded,          angle: 250,  distance: 155, size: 16, delay: 0.20),
  ];

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.12).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    ]).animate(_logoController);
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _logoFloat = Tween(begin: 0.0, end: 1.0).animate(_logoController);

    _particleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _particleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );

    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _logoController.forward().then((_) {
      _particleController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _textController.forward();
      });
    });

    // ✅ Navega al OnboardingGate (decide si mostrar onboarding o ir al home)
    Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const OnboardingGate(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),

          Positioned(top: -60, right: -60,
              child: _GlowBlob(size: 220, color: const Color(0xFF2196F3).withOpacity(0.12))),
          Positioned(bottom: size.height * 0.15, left: -80,
              child: _GlowBlob(size: 200, color: const Color(0xFF00BCD4).withOpacity(0.10))),
          Positioned(bottom: -40, right: size.width * 0.2,
              child: _GlowBlob(size: 160, color: const Color(0xFF1E88E5).withOpacity(0.08))),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo pulsante
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Transform.scale(
                          scale: _pulse.value,
                          child: Container(
                            width: 200, height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF2196F3).withOpacity(0.18),
                                  const Color(0xFF2196F3).withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Íconos flotantes
                      AnimatedBuilder(
                        animation: _particleController,
                        builder: (_, __) {
                          return Opacity(
                            opacity: _particleOpacity.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: _icons.map((fi) {
                                final delayedOpacity = (_particleOpacity.value - fi.delay)
                                    .clamp(0.0, 1.0) / (1.0 - fi.delay).clamp(0.01, 1.0);
                                final rad = fi.angle * math.pi / 180;
                                return Transform.translate(
                                  offset: Offset(
                                    math.cos(rad) * fi.distance * delayedOpacity,
                                    math.sin(rad) * fi.distance * delayedOpacity,
                                  ),
                                  child: Opacity(
                                    opacity: delayedOpacity.clamp(0.0, 1.0),
                                    child: _IconBubble(icon: fi.icon, size: fi.size),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),

                      // Logo — ✅ ruta corregida a 'assets/logo.png'
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (_, child) => Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(scale: _logoScale.value, child: child),
                        ),
                        child: Container(
                          width: 160, height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.9),
                                blurRadius: 20,
                                offset: const Offset(-4, -4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              // ✅ CORREGIDO: 'assets/logo.png' en lugar de 'logo.png'
                              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, child) => FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(position: _textSlide, child: child),
                  ),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF29B6F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'ACOM',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 6,
                            height: 1.0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Always Count On Me',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Tu compañía emocional',
                        style: TextStyle(
                          fontSize: 15,
                          color: const Color(0xFF1565C0).withOpacity(0.65),
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 56),

                AnimatedBuilder(
                  animation: _dotsController,
                  builder: (_, __) => _LoadingDots(progress: _dotsController.value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────

class _FloatingIcon {
  final IconData icon;
  final double angle, distance, size, delay;
  const _FloatingIcon({
    required this.icon, required this.angle,
    required this.distance, required this.size, required this.delay,
  });
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final double size;
  const _IconBubble({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 20, height: size + 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.2), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF2196F3), size: size),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  final double progress;
  const _LoadingDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final phase = (progress - i * 0.2).clamp(0.0, 1.0);
        final wave  = math.sin(phase * math.pi);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 8,
          height: 8 + wave * 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Color.lerp(const Color(0xFF90CAF9), const Color(0xFF1565C0), wave),
          ),
        );
      }),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFECF4FF), Color(0xFFF8FBFF)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    paint.shader = null;
    paint.color = const Color(0xFF2196F3).withOpacity(0.04);
    const spacing = 28.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}