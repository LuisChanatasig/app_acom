import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'home_screen.dart';
import '/services/biometric_service.dart';

// ─────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────q
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: _LoginBody(),
    );
  }
}

// ─────────────────────────────────────────────
// Auth modes
// ─────────────────────────────────────────────
enum _AuthMode { login, register, forgotPassword }

// ─────────────────────────────────────────────
// Main body
// ─────────────────────────────────────────────
class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody>
    with TickerProviderStateMixin {

  _AuthMode _mode = _AuthMode.login;

  // Hero float
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  // Card slide
  late AnimationController _cardController;
  late Animation<double> _cardSlide;

  // Mode switch
  late AnimationController _modeController;
  late Animation<double> _modeFade;

  // Form keys
  final _loginFormKey   = GlobalKey<FormState>();
  final _regFormKey     = GlobalKey<FormState>();
  final _forgotFormKey  = GlobalKey<FormState>();

  // Controllers
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _email2Ctrl   = TextEditingController();
  final _pass2Ctrl    = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _forgotCtrl   = TextEditingController();

  bool _obscurePass   = true;
  bool _obscurePass2  = true;
  bool _obscureConf   = true;
  bool _isLoading     = false;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _cardSlide = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    _cardController.forward();

    _modeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _modeFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _modeController, curve: Curves.easeIn),
    );
    _modeController.forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _cardController.dispose();
    _modeController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _email2Ctrl.dispose();
    _pass2Ctrl.dispose();
    _confirmCtrl.dispose();
    _forgotCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_mode == mode) return;
    _modeController.reverse().then((_) {
      setState(() => _mode = mode);
      _modeController.forward();
    });
  }

  Future<void> _submit() async {
    final valid = switch (_mode) {
      _AuthMode.login          => _loginFormKey.currentState?.validate() ?? false,
      _AuthMode.register       => _regFormKey.currentState?.validate() ?? false,
      _AuthMode.forgotPassword => _forgotFormKey.currentState?.validate() ?? false,
    };
    if (!valid) return;

    setState(() => _isLoading = true);

    AuthResult result;

    switch (_mode) {
      case _AuthMode.login:
        result = await FirebaseService.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        break;
      case _AuthMode.register:
        result = await FirebaseService.signUpWithEmail(
          email:    _email2Ctrl.text.trim(),
          password: _pass2Ctrl.text,
          name:     _nameCtrl.text.trim(),
        );
        break;
      case _AuthMode.forgotPassword:
        result = await FirebaseService.sendPasswordReset(_forgotCtrl.text.trim());
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (result == AuthResult.success) {
          _showSnack("¡Enlace enviado a tu correo! 📩");
          _switchMode(_AuthMode.login);
        } else {
          _showSnack(result.message);
        }
        return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == AuthResult.success) {
      // Cargar datos desde la nube
      await FirebaseService.loadAllFromCloud();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      _showSnack(result.message);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _loginWithBiometric() async {
    final available = await BiometricService.isAvailable();
    if (!available) {
      _showSnack('❌ Tu dispositivo no tiene biométrico configurado');
      return;
    }

    setState(() => _isLoading = true);
    final result = await BiometricService.authenticate();
    setState(() => _isLoading = false);

    switch (result) {
      case BiometricResult.success:
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 600),
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        }
        break;
      case BiometricResult.notEnrolled:
        _showSnack('⚠️ No tienes huella registrada en el dispositivo');
        break;
      case BiometricResult.lockedOut:
        _showSnack('🔒 Demasiados intentos. Intenta más tarde');
        break;
      case BiometricResult.notAvailable:
        _showSnack('❌ Biométrico no disponible en este dispositivo');
        break;
      default:
        _showSnack('❌ No se pudo autenticar, intenta de nuevo');
    }
  }

  // ── Build ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF29B6F6)],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Decorative circles
          Positioned(top: -40, left: -40,
            child: _Circle(size: 180, color: Colors.white.withOpacity(0.06))),
          Positioned(top: 60, right: -30,
            child: _Circle(size: 120, color: Colors.white.withOpacity(0.05))),
          Positioned(top: screenH * 0.18, left: 20,
            child: _Circle(size: 60, color: Colors.white.withOpacity(0.07))),

          // Wave divider
          Positioned(
            top: screenH * 0.30,
            left: 0, right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 60),
              painter: _WavePainter(),
            ),
          ),

          // Content
          Column(
            children: [
              // ── Hero ──
              SizedBox(
                height: screenH * 0.35,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Robot + halo
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: child,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Halo ring
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            // Logo
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Wordmark
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFB3E5FC)],
                        ).createShader(b),
                        child: const Text(
                          'ACOM',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Always Count On Me',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.75),
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Card ──
              Expanded(
                child: AnimatedBuilder(
                  animation: _cardSlide,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _cardSlide.value * 300),
                    child: child,
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F9FF),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                        child: AnimatedBuilder(
                          animation: _modeFade,
                          builder: (_, child) => Opacity(opacity: _modeFade.value, child: child),
                          child: _buildFormContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Form content switcher ──────────────────
  Widget _buildFormContent() {
    return switch (_mode) {
      _AuthMode.login         => _buildLogin(),
      _AuthMode.register      => _buildRegister(),
      _AuthMode.forgotPassword => _buildForgot(),
    };
  }

  // ─────────────────────────────────────────────
  // LOGIN FORM
  // ─────────────────────────────────────────────
  Widget _buildLogin() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab selector
          _ModeTabBar(current: _mode, onSelect: _switchMode),
          const SizedBox(height: 28),

          const _SectionTitle('Bienvenido de vuelta 👋'),
          const SizedBox(height: 6),
          const _SubTitle('Inicia sesión para continuar'),
          const SizedBox(height: 24),

          _AcomField(
            controller: _emailCtrl,
            label: 'Correo electrónico',
            hint: 'hola@ejemplo.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),

          _AcomField(
            controller: _passCtrl,
            label: 'Contraseña',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscurePass,
            onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
            validator: _validatePass,
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _switchMode(_AuthMode.forgotPassword),
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: Color(0xFF1976D2), fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 8),
          _SubmitButton(label: 'Iniciar sesión', loading: _isLoading, onTap: _submit),
          const SizedBox(height: 20),

          // Biometric
          Center(
            child: _BiometricButton(onTap: _loginWithBiometric),
          ),

          const SizedBox(height: 20),
          const _Divider(label: 'O continúa con'),
          const SizedBox(height: 16),

          _SocialRow(onTap: (p) async {
                if (p == 'Google') {
                  setState(() => _isLoading = true);
                  final result = await FirebaseService.signInWithGoogle();
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  if (result == AuthResult.success) {
                    await FirebaseService.loadAllFromCloud();
                    if (!mounted) return;
                    Navigator.pushReplacement(context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 600),
                        pageBuilder: (_, __, ___) => const HomeScreen(),
                        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                      ));
                  } else {
                    _showSnack(result.message);
                  }
                } else {
                  _showSnack('Próximamente: $p');
                }
              }),

          const SizedBox(height: 24),
          Center(
            child: _SwitchModeText(
              question: '¿No tienes cuenta?',
              action: 'Regístrate',
              onTap: () => _switchMode(_AuthMode.register),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // REGISTER FORM
  // ─────────────────────────────────────────────
  Widget _buildRegister() {
    return Form(
      key: _regFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModeTabBar(current: _mode, onSelect: _switchMode),
          const SizedBox(height: 28),

          const _SectionTitle('Crea tu cuenta 🚀'),
          const SizedBox(height: 6),
          const _SubTitle('Únete a la comunidad ACOM'),
          const SizedBox(height: 24),

          _AcomField(
            controller: _nameCtrl,
            label: 'Nombre completo',
            hint: 'Tu nombre',
            icon: Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: 16),

          _AcomField(
            controller: _email2Ctrl,
            label: 'Correo electrónico',
            hint: 'hola@ejemplo.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),

          _AcomField(
            controller: _pass2Ctrl,
            label: 'Contraseña',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscurePass2,
            onToggleObscure: () => setState(() => _obscurePass2 = !_obscurePass2),
            validator: _validatePass,
          ),
          const SizedBox(height: 16),

          _AcomField(
            controller: _confirmCtrl,
            label: 'Confirmar contraseña',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscureConf,
            onToggleObscure: () => setState(() => _obscureConf = !_obscureConf),
            validator: (v) =>
                v != _pass2Ctrl.text ? 'Las contraseñas no coinciden' : null,
          ),
          const SizedBox(height: 24),

          _SubmitButton(label: 'Crear cuenta', loading: _isLoading, onTap: _submit),
          const SizedBox(height: 20),
          const _Divider(label: 'O regístrate con'),
          const SizedBox(height: 16),
          _SocialRow(onTap: (p) => _showSnack('Registrando con $p...')),

          const SizedBox(height: 24),
          Center(
            child: _SwitchModeText(
              question: '¿Ya tienes cuenta?',
              action: 'Inicia sesión',
              onTap: () => _switchMode(_AuthMode.login),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FORGOT PASSWORD FORM
  // ─────────────────────────────────────────────
  Widget _buildForgot() {
    return Form(
      key: _forgotFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back
          GestureDetector(
            onTap: () => _switchMode(_AuthMode.login),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Color(0xFF1976D2)),
                const SizedBox(width: 6),
                Text('Volver',
                    style: TextStyle(
                        color: const Color(0xFF1976D2),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Robot illustration area
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE3F2FD),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const _SectionTitle('¿Olvidaste tu contraseña? 🔑'),
          const SizedBox(height: 8),
          const _SubTitle(
            'Sin problema. Ingresa tu correo y te enviaremos un enlace para restablecerla.',
          ),
          const SizedBox(height: 24),

          _AcomField(
            controller: _forgotCtrl,
            label: 'Correo electrónico',
            hint: 'hola@ejemplo.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 28),

          _SubmitButton(
              label: 'Enviar enlace de recuperación',
              loading: _isLoading,
              onTap: _submit),
        ],
      ),
    );
  }

  // ── Validators ────────────────────────────
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
    final re = RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$');
    return re.hasMatch(v.trim()) ? null : 'Correo no válido';
  }

  String? _validatePass(String? v) {
    if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _ModeTabBar extends StatelessWidget {
  final _AuthMode current;
  final void Function(_AuthMode) onSelect;
  const _ModeTabBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Tab(label: 'Ingresar',   active: current == _AuthMode.login,
              onTap: () => onSelect(_AuthMode.login)),
          _Tab(label: 'Registrarse', active: current == _AuthMode.register,
              onTap: () => onSelect(_AuthMode.register)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1976D2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ] : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF1976D2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Color(0xFF0D47A1),
      height: 1.2,
    ),
  );
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      color: Color(0xFF78909C),
      height: 1.4,
    ),
  );
}

class _AcomField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _AcomField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Color(0xFF0D47A1)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF1976D2), size: 20),
            suffixIcon: onToggleObscure != null
                ? GestureDetector(
                    onTap: onToggleObscure,
                    child: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF90A4AE),
                      size: 20,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCEEFF), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _SubmitButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF90CAF9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: const Color(0xFF1565C0).withOpacity(0.4),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BiometricButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDCEEFF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2196F3).withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              color: Color(0xFF1976D2),
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Acceso biométrico',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF78909C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: const Color(0xFFCFE2FF), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB0BEC5))),
        ),
        Expanded(child: Divider(color: const Color(0xFFCFE2FF), thickness: 1)),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  final void Function(String) onTap;
  const _SocialRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SocialBtn(label: 'Google',   icon: Icons.g_mobiledata_rounded,  color: const Color(0xFFDB4437), onTap: onTap),
        _SocialBtn(label: 'Facebook', icon: Icons.facebook_rounded,       color: const Color(0xFF1877F2), onTap: onTap),
        _SocialBtn(label: 'Apple',    icon: Icons.apple_rounded,          color: const Color(0xFF1C1C1E), onTap: onTap),
      ],
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final void Function(String) onTap;
  const _SocialBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        width: 88,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCEEFF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _SwitchModeText extends StatelessWidget {
  final String question;
  final String action;
  final VoidCallback onTap;
  const _SwitchModeText({required this.question, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Color(0xFF78909C)),
        children: [
          TextSpan(text: '$question '),
          WidgetSpan(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                action,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Decorative helpers
// ─────────────────────────────────────────────

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5F9FF)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 40)
      ..cubicTo(size.width * 0.25, 0, size.width * 0.75, 60, size.width, 20)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}