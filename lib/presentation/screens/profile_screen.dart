import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'login_screen.dart';

// ─────────────────────────────────────────────
// Modelos
// ─────────────────────────────────────────────
class _Achievement {
  final String emoji;
  final String title;
  final String desc;
  final bool unlocked;
  const _Achievement({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.unlocked,
  });
}

// ─────────────────────────────────────────────
// Profile Screen
// ─────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {

  // Datos del usuario
  String _name    = 'Fernando';
  String _email   = 'fernando@ejemplo.com';
  String _lang    = 'Español';
  bool   _isLoading = true;

  // Animaciones
  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  late AnimationController _avatarCtrl;
  late Animation<double>   _avatarScale;

  late AnimationController _statsCtrl;
  late Animation<double>   _statsAnim;

  // Stats locales
  int    _daysActive    = 0;
  int    _diaryEntries  = 0;
  int    _breathSessions = 0;
  double _wellnessLevel  = 0.0;

  // Logros
  late List<_Achievement> _achievements;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _entryFade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entrySlide = Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _avatarCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _avatarScale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut));

    _statsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _statsAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _statsCtrl, curve: Curves.easeOutCubic));

    _loadData();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _avatarCtrl.dispose();
    _statsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar datos guardados
    _name   = prefs.getString('user_name')  ?? 'Fernando';
    _email  = prefs.getString('user_email') ?? 'fernando@ejemplo.com';
    _lang   = prefs.getString('user_lang')  ?? 'Español';

    // Stats
    _daysActive     = prefs.getInt('days_active')      ?? 7;
    _diaryEntries   = prefs.getInt('diary_entries')    ?? 0;
    _breathSessions = prefs.getInt('breath_sessions')  ?? 3;
    _wellnessLevel  = prefs.getDouble('wellness_level') ?? 0.72;

    // Calcular entradas del diario reales
    final raw = prefs.getString('acom_diary_entries');
    if (raw != null) {
      final list = raw.split('},{').length;
      _diaryEntries = list;
    }

    // Logros
    _achievements = [
      _Achievement(emoji: '🌟', title: 'Primer paso',      desc: 'Iniciaste tu viaje con ACOM',            unlocked: true),
      _Achievement(emoji: '💬', title: 'Primer chat',      desc: 'Tuviste tu primera conversación',        unlocked: true),
      _Achievement(emoji: '📓', title: 'Diario activo',    desc: 'Escribiste tu primera entrada',          unlocked: _diaryEntries > 0),
      _Achievement(emoji: '🧘', title: 'Respira',          desc: 'Completaste un ejercicio de respiración', unlocked: _breathSessions > 0),
      _Achievement(emoji: '🔥', title: 'Racha de 7 días',  desc: 'Usaste ACOM 7 días seguidos',            unlocked: _daysActive >= 7),
      _Achievement(emoji: '💪', title: 'Constancia',       desc: 'Escribiste 5 entradas en el diario',     unlocked: _diaryEntries >= 5),
      _Achievement(emoji: '🏆', title: 'Campeón',          desc: 'Completaste 30 días con ACOM',           unlocked: _daysActive >= 30),
      _Achievement(emoji: '❤️', title: 'Bienestar',        desc: 'Alcanzaste nivel de bienestar alto',     unlocked: _wellnessLevel >= 0.8),
    ];

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Lanzar animaciones en secuencia
    _avatarCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _entryCtrl.forward();
      _statsCtrl.forward();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name',  _name);
    await prefs.setString('user_email', _email);
    await prefs.setString('user_lang',  _lang);
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
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _entryFade,
                      child: SlideTransition(
                        position: _entrySlide,
                        child: Column(
                          children: [
                            _buildStatsRow(),
                            _buildWellnessCard(),
                            _buildAchievements(),
                            _buildSettings(),
                            _buildLogoutBtn(),
                            const SizedBox(height: 40),
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
  // Header con avatar
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF29B6F6)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            children: [
              // Top bar
              Row(
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
                    child: Text('Mi Perfil',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  // Editar
                  GestureDetector(
                    onTap: _showEditProfile,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Avatar
              ScaleTransition(
                scale: _avatarScale,
                child: GestureDetector(
                  onTap: _showEditProfile,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF29B6F6), Color(0xFF1565C0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _name.isNotEmpty ? _name[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Badge editar
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF29B6F6),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Nombre
              Text(
                _name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 10),

              // Badge idioma
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌍', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      _lang,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
  // Stats row
  // ─────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(child: _StatCard(value: '$_daysActive', label: 'Días activo', emoji: '🔥', color: const Color(0xFFFF9800))),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_diaryEntries', label: 'Entradas', emoji: '📓', color: const Color(0xFFF57C00))),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(value: '$_breathSessions', label: 'Respiración', emoji: '🧘', color: const Color(0xFF26A69A))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Wellness level card
  // ─────────────────────────────────────────────
  Widget _buildWellnessCard() {
    final pct = (_wellnessLevel * 100).toInt();
    final color = pct >= 75
        ? const Color(0xFF66BB6A)
        : pct >= 50
            ? const Color(0xFF29B6F6)
            : pct >= 25
                ? const Color(0xFFFFCA28)
                : const Color(0xFFEF5350);

    final label = pct >= 75
        ? 'Excelente 🌟'
        : pct >= 50
            ? 'Bueno 😊'
            : pct >= 25
                ? 'Regular 😐'
                : 'Bajo 😔';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.favorite_rounded, size: 18, color: Color(0xFF1976D2)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Nivel de bienestar semanal',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barra animada
            AnimatedBuilder(
              animation: _statsAnim,
              builder: (_, __) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$pct%',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1,
                            )),
                        Text('Meta: 80%',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _wellnessLevel * _statsAnim.value,
                        backgroundColor: const Color(0xFFF0F4F8),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 12,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            // Mini barras días
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['L','M','X','J','V','S','D'].asMap().entries.map((e) {
                final h = [0.6, 0.8, 0.5, 0.9, 0.7, 0.85, 0.75][e.key];
                final isToday = e.key == DateTime.now().weekday - 1;
                return Column(
                  children: [
                    AnimatedBuilder(
                      animation: _statsAnim,
                      builder: (_, __) => Container(
                        width: 20,
                        height: 40 * h * _statsAnim.value,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isToday ? color : color.withOpacity(0.25),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(e.value,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                          color: isToday ? color : const Color(0xFFB0BEC5),
                        )),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Logros
  // ─────────────────────────────────────────────
  Widget _buildAchievements() {
    final unlocked = _achievements.where((a) => a.unlocked).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFF9800), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Logros',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$unlocked/${_achievements.length}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF9800))),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Grid de logros
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: _achievements.length,
              itemBuilder: (_, i) {
                final a = _achievements[i];
                return GestureDetector(
                  onTap: () => _showAchievementDetail(a),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: a.unlocked ? 1.0 : 0.35,
                    child: Container(
                      decoration: BoxDecoration(
                        color: a.unlocked
                            ? const Color(0xFFFFF8E1)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: a.unlocked
                              ? const Color(0xFFFFCC02).withOpacity(0.5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(a.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            a.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: a.unlocked
                                  ? const Color(0xFF5D4037)
                                  : const Color(0xFFB0BEC5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Settings
  // ─────────────────────────────────────────────
  Widget _buildSettings() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
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
          children: [
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Editar perfil',
              subtitle: _name,
              color: const Color(0xFF1976D2),
              onTap: _showEditProfile,
            ),
            _Divider(),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Cambiar contraseña',
              subtitle: '••••••••',
              color: const Color(0xFF7B1FA2),
              onTap: _showChangePassword,
            ),
            _Divider(),
            _SettingsTile(
              icon: Icons.language_rounded,
              label: 'Idioma',
              subtitle: _lang,
              color: const Color(0xFF26A69A),
              onTap: _showLanguagePicker,
            ),
            _Divider(),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'Acerca de ACOM',
              subtitle: 'Versión 1.0.0',
              color: const Color(0xFF90A4AE),
              onTap: _showAbout,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Logout
  // ─────────────────────────────────────────────
  Widget _buildLogoutBtn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: _confirmLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFEF5350), size: 20),
              SizedBox(width: 8),
              Text('Cerrar sesión',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF5350))),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Dialogs / Sheets
  // ─────────────────────────────────────────────
  void _showEditProfile() {
    final nameCtrl  = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFD8DC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Editar perfil',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
              const SizedBox(height: 20),
              _SheetField(controller: nameCtrl,  label: 'Nombre',  icon: Icons.person_outline_rounded),
              const SizedBox(height: 14),
              _SheetField(controller: emailCtrl, label: 'Correo',  icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _name  = nameCtrl.text.trim().isNotEmpty  ? nameCtrl.text.trim()  : _name;
                      _email = emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : _email;
                    });
                    await _saveData();
                    if (mounted) Navigator.pop(context);
                    _showSnack('✅ Perfil actualizado');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Guardar cambios',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCFD8DC), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Cambiar contraseña',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
                const SizedBox(height: 20),
                _SheetField(controller: currentCtrl, label: 'Contraseña actual', icon: Icons.lock_outline, obscure: obscure1,
                    onToggle: () => setSheetState(() => obscure1 = !obscure1)),
                const SizedBox(height: 12),
                _SheetField(controller: newCtrl, label: 'Nueva contraseña', icon: Icons.lock_outline, obscure: obscure2,
                    onToggle: () => setSheetState(() => obscure2 = !obscure2)),
                const SizedBox(height: 12),
                _SheetField(controller: confirmCtrl, label: 'Confirmar contraseña', icon: Icons.lock_outline, obscure: obscure3,
                    onToggle: () => setSheetState(() => obscure3 = !obscure3)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (newCtrl.text != confirmCtrl.text) {
                        _showSnack('❌ Las contraseñas no coinciden');
                        return;
                      }
                      if (newCtrl.text.length < 6) {
                        _showSnack('❌ Mínimo 6 caracteres');
                        return;
                      }
                      Navigator.pop(context);
                      _showSnack('✅ Contraseña actualizada');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B1FA2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Actualizar contraseña',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    final langs = ['Español', 'English', 'Português', 'Français'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCFD8DC), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Selecciona idioma',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
            const SizedBox(height: 16),
            ...langs.map((l) => GestureDetector(
              onTap: () async {
                setState(() => _lang = l);
                await _saveData();
                if (mounted) Navigator.pop(context);
                _showSnack('🌍 Idioma cambiado a $l');
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _lang == l ? const Color(0xFFE3F2FD) : const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _lang == l ? const Color(0xFF1976D2) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(_langEmoji(l), style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Text(l, style: TextStyle(
                      fontSize: 15,
                      fontWeight: _lang == l ? FontWeight.w700 : FontWeight.w400,
                      color: _lang == l ? const Color(0xFF1565C0) : const Color(0xFF37474F),
                    )),
                    if (_lang == l) ...[
                      const Spacer(),
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF1976D2), size: 20),
                    ],
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', width: 80, height: 80),
            const SizedBox(height: 12),
            const Text('ACOM',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1565C0), letterSpacing: 4)),
            const Text('Always Count On Me',
                style: TextStyle(fontSize: 12, color: Color(0xFF90A4AE))),
            const SizedBox(height: 12),
            const Text('Versión 1.0.0',
                style: TextStyle(fontSize: 14, color: Color(0xFF607D8B))),
            const SizedBox(height: 8),
            const Text(
              'Tu compañía emocional — siempre aquí para ti 💙',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF90A4AE)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF1565C0))),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetail(_Achievement a) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(a.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 10),
            Text(a.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
            const SizedBox(height: 6),
            Text(a.desc, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF607D8B))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: a.unlocked ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                a.unlocked ? '✅ Desbloqueado' : '🔒 Bloqueado',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: a.unlocked ? const Color(0xFF388E3C) : const Color(0xFF90A4AE),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF1565C0))),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
        content: const Text('Se cerrará tu sesión actual. Tus datos locales se conservarán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 600),
                  pageBuilder: (_, __, ___) => const LoginScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
                (route) => false,
              );
            },
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────
  String _langEmoji(String l) {
    switch (l) {
      case 'Español':    return '🇪🇸';
      case 'English':    return '🇺🇸';
      case 'Português':  return '🇧🇷';
      case 'Français':   return '🇫🇷';
      default:           return '🌍';
    }
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
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFF90A4AE), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon, required this.label,
    required this.subtitle, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCFD8DC), size: 22),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: Color(0xFFF0F4F8)),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggle;
  final TextInputType? keyboard;
  const _SheetField({
    required this.controller, required this.label, required this.icon,
    this.obscure = false, this.onToggle, this.keyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          style: const TextStyle(fontSize: 15, color: Color(0xFF0D47A1)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF1976D2), size: 20),
            suffixIcon: onToggle != null
                ? GestureDetector(
                    onTap: onToggle,
                    child: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: const Color(0xFF90A4AE), size: 20,
                    ),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FBFF),
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
          ),
        ),
      ],
    );
  }
}