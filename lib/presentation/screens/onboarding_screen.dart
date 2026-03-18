import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'package:local_auth/local_auth.dart';

// ─────────────────────────────────────────────
// Onboarding Gate — decide si mostrar onboarding o ir al home
// ─────────────────────────────────────────────
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final done  = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    if (done) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D47A1),
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ─────────────────────────────────────────────
// Onboarding Screen
// ─────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Datos recopilados
  String _userName       = '';
  int    _initialMood    = 2;
  bool   _notifsEnabled  = false;
  bool   _bioEnabled     = false;

  // Animación de entrada por página
  late AnimationController _slideCtrl;
  late Animation<double>   _slideAnim;

  // Float del robot
  late AnimationController _floatCtrl;
  late Animation<double>   _floatAnim;

  final _nameCtrl = TextEditingController();

  final List<String> _moodEmojis  = ['😊', '😌', '😐', '😟', '😔'];
  final List<String> _moodLabels  = ['Genial', 'Tranquilo', 'Neutral', 'Ansioso', 'Triste'];
  final List<Color>  _moodColors  = [
    const Color(0xFF66BB6A),
    const Color(0xFF29B6F6),
    const Color(0xFFFFCA28),
    const Color(0xFFFFA726),
    const Color(0xFFEF5350),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatAnim = Tween(begin: -10.0, end: 10.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _slideCtrl.dispose();
    _floatCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Navegación ────────────────────────────
  void _next() {
    if (_currentPage == 2 && _nameCtrl.text.trim().isEmpty) {
      _showSnack('Por favor ingresa tu nombre 😊');
      return;
    }
    if (_currentPage < 4) {
      _slideCtrl.reset();
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      _slideCtrl.forward();
      HapticFeedback.lightImpact();
    } else {
      _finish();
    }
  }

  void _skip() {
    _slideCtrl.reset();
    _pageCtrl.animateToPage(
      4,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    _slideCtrl.forward();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.setString('user_name',    _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Usuario');
    await prefs.setInt('initial_mood',    _initialMood);
    await prefs.setBool('notifs_enabled', _notifsEnabled);
    await prefs.setBool('bio_enabled',    _bioEnabled);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // Fondo degradado que cambia con la página
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _pageGradient(_currentPage),
                ),
              ),
            ),

            // Decoraciones de fondo
            ..._buildBgDecorations(),

            // Contenido principal
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  _buildTopBar(),

                  // Páginas
                  Expanded(
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: [
                        _buildPage0(), // Bienvenida
                        _buildPage1(), // Funciones
                        _buildPage2(), // Nombre
                        _buildPage3(), // Mood inicial
                        _buildPage4(), // Notifs + biométrico
                      ],
                    ),
                  ),

                  // Bottom controls
                  _buildBottomControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Top bar con dots y skip
  // ─────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots indicadores
          Row(
            children: List.generate(5, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white
                      : Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Skip
          if (_currentPage < 4)
            GestureDetector(
              onTap: _skip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Saltar',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
              ),
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Página 0 — Bienvenida
  // ─────────────────────────────────────────────
  Widget _buildPage0() {
    return FadeTransition(
      opacity: _slideAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Robot flotando
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: child,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halos
                  Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  // Logo
                  Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  // Íconos flotantes alrededor
                  ..._buildFloatingIcons(),
                ],
              ),
            ),

            const SizedBox(height: 40),

            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Colors.white, Color(0xFFB3E5FC)],
              ).createShader(b),
              child: const Text(
                'ACOM',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Always Count On Me',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Tu compañero emocional de confianza.\nSiempre aquí para escucharte 💙',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.85),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Página 1 — Funciones
  // ─────────────────────────────────────────────
  Widget _buildPage1() {
    final features = [
      _Feature('💬', 'Chat emocional',      'Habla con ACOM cuando lo necesites'),
      _Feature('🧘', 'Respiración guiada',  'Ejercicios para calmar la ansiedad'),
      _Feature('📓', 'Diario emocional',    'Escribe y guarda tus pensamientos'),
      _Feature('🔔', 'Recordatorios',       'Notificaciones para tu bienestar'),
      _Feature('📊', 'Tu progreso',         'Estadísticas de tu bienestar semanal'),
    ];

    return FadeTransition(
      opacity: _slideAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Qué puedes hacer\ncon ACOM?',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Todo lo que necesitas para cuidar tu bienestar emocional.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ...features.asMap().entries.map((e) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + e.key * 100),
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(30 * (1 - v), 0), child: child),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(e.value.emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.value.title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text(e.value.desc,
                                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white.withOpacity(0.5), size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Página 2 — Nombre
  // ─────────────────────────────────────────────
  Widget _buildPage2() {
    return FadeTransition(
      opacity: _slideAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👋', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              '¿Cómo te llamas?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Me gustaría conocerte para\npoder acompañarte mejor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Campo de nombre
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D47A1),
                ),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'Tu nombre aquí...',
                  hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 20),

            if (_nameCtrl.text.trim().isNotEmpty)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                builder: (_, v, child) => Opacity(opacity: v, child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '¡Hola ${_nameCtrl.text.trim()}! 😊 Encantado de conocerte.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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
  // Página 3 — Mood inicial
  // ─────────────────────────────────────────────
  Widget _buildPage3() {
    return FadeTransition(
      opacity: _slideAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _moodEmojis[_initialMood],
              style: const TextStyle(fontSize: 70),
            ),
            const SizedBox(height: 14),

            Text(
              _nameCtrl.text.trim().isNotEmpty
                  ? '¿Cómo te sientes hoy,\n${_nameCtrl.text.trim()}?'
                  : '¿Cómo te sientes hoy?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),
            Text(
              'Cuéntame tu estado de ánimo inicial para personalizar tu experiencia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),

            // Mood selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final selected = _initialMood == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _initialMood = i);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(_moodEmojis[i],
                            style: TextStyle(fontSize: selected ? 34 : 28)),
                        const SizedBox(height: 4),
                        Text(
                          _moodLabels[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            color: Colors.white.withOpacity(selected ? 1.0 : 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Mensaje según mood
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(_initialMood),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _moodMessage(_initialMood),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
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
  // Página 4 — Notificaciones + Biométrico
  // ─────────────────────────────────────────────
  Widget _buildPage4() {
    return FadeTransition(
      opacity: _slideAnim,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚙️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text(
              'Configura tu experiencia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Personaliza ACOM para que se adapte a ti.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.8),
              ),
            ),

            const SizedBox(height: 32),

            // Notificaciones
            _ConfigCard(
              emoji: '🔔',
              title: 'Activar notificaciones',
              subtitle: 'Recordatorios diarios para tu bienestar',
              enabled: _notifsEnabled,
              onToggle: (v) async {
                if (v) {
                  final granted = await NotificationService.requestPermission();
                  setState(() => _notifsEnabled = granted);
                  if (granted) {
                    _showSnack('✅ Notificaciones activadas');
                  } else {
                    _showSnack('❌ Permiso denegado');
                  }
                } else {
                  setState(() => _notifsEnabled = false);
                }
              },
            ),

            const SizedBox(height: 12),

            // Biométrico
            _ConfigCard(
              emoji: '🔐',
              title: 'Acceso biométrico',
              subtitle: 'Entra con huella o Face ID',
              enabled: _bioEnabled,
              onToggle: (v) async {
                if (v) {
                  try {
                    final auth = LocalAuthentication();
                    final available = await auth.canCheckBiometrics;
                    if (!available) {
                      _showSnack('❌ Tu dispositivo no soporta biométrico');
                      return;
                    }
                    final ok = await auth.authenticate(
                      localizedReason: 'Confirma tu identidad para activar el acceso biométrico',
                      options: const AuthenticationOptions(biometricOnly: false),
                    );
                    setState(() => _bioEnabled = ok);
                    if (ok) _showSnack('✅ Acceso biométrico activado');
                  } catch (_) {
                    _showSnack('❌ No se pudo activar el biométrico');
                  }
                } else {
                  setState(() => _bioEnabled = false);
                }
              },
            ),

            const SizedBox(height: 24),

            // Info de que se puede cambiar después
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Puedes cambiar estos ajustes en cualquier momento desde tu perfil.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.4,
                      ),
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

  // ─────────────────────────────────────────────
  // Bottom controls
  // ─────────────────────────────────────────────
  Widget _buildBottomControls() {
    final isLast = _currentPage == 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      child: Row(
        children: [
          // Botón atrás
          if (_currentPage > 0)
            GestureDetector(
              onTap: () {
                _slideCtrl.reset();
                _pageCtrl.previousPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
                _slideCtrl.forward();
              },
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            )
          else
            const SizedBox(width: 52),

          const SizedBox(width: 16),

          // Botón siguiente / empezar
          Expanded(
            child: GestureDetector(
              onTap: _next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLast ? '¡Empezar! 🚀' : 'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _pageGradient(_currentPage).first,
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: _pageGradient(_currentPage).first, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  List<Color> _pageGradient(int page) {
    switch (page) {
      case 0: return [const Color(0xFF0D47A1), const Color(0xFF1976D2), const Color(0xFF29B6F6)];
      case 1: return [const Color(0xFF1A237E), const Color(0xFF3949AB), const Color(0xFF5C6BC0)];
      case 2: return [const Color(0xFF006064), const Color(0xFF00838F), const Color(0xFF26C6DA)];
      case 3: return [const Color(0xFF1B5E20), const Color(0xFF388E3C), const Color(0xFF66BB6A)];
      case 4: return [const Color(0xFF4A148C), const Color(0xFF7B1FA2), const Color(0xFFAB47BC)];
      default: return [const Color(0xFF0D47A1), const Color(0xFF1976D2)];
    }
  }

  List<Widget> _buildBgDecorations() {
    return [
      Positioned(top: -60, right: -60,
          child: _Circle(220, Colors.white.withOpacity(0.05))),
      Positioned(bottom: 100, left: -80,
          child: _Circle(200, Colors.white.withOpacity(0.04))),
      Positioned(top: 200, right: 40,
          child: _Circle(60, Colors.white.withOpacity(0.06))),
    ];
  }

  List<Widget> _buildFloatingIcons() {
    final icons = [
      _FloatIcon(Icons.favorite_rounded,     -80.0, -60.0),
      _FloatIcon(Icons.chat_bubble_rounded,   80.0, -50.0),
      _FloatIcon(Icons.self_improvement_rounded, -90.0, 50.0),
      _FloatIcon(Icons.book_rounded,          85.0,  55.0),
      _FloatIcon(Icons.notifications_rounded,  0.0, -90.0),
    ];
    return icons.map((fi) => Positioned(
      left:  100 + fi.dx,
      top:   100 + fi.dy,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.15),
        ),
        child: Icon(fi.icon, color: Colors.white.withOpacity(0.8), size: 18),
      ),
    )).toList();
  }

  String _moodMessage(int i) {
    const msgs = [
      '¡Qué bien! Me alegra que te sientas genial hoy. Vamos a mantener esa energía 🌟',
      'La tranquilidad es un regalo. Aprovecha este momento de calma 😌',
      'Un día neutro es una oportunidad para construir algo mejor 💪',
      'Entiendo que estás ansioso. Estoy aquí para ayudarte a calmarte 🤗',
      'Lo siento. Recuerda que no estás solo, aquí estoy para ti 💙',
    ];
    return msgs[i];
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.black87,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────
class _Feature {
  final String emoji, title, desc;
  const _Feature(this.emoji, this.title, this.desc);
}

class _FloatIcon {
  final IconData icon;
  final double dx, dy;
  const _FloatIcon(this.icon, this.dx, this.dy);
}

Widget _Circle(double size, Color color) => Container(
  width: size, height: size,
  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
);

class _ConfigCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool enabled;
  final void Function(bool) onToggle;
  const _ConfigCard({
    required this.emoji, required this.title,
    required this.subtitle, required this.enabled, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: onToggle,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}