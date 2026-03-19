import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_screen.dart';
import 'breathing_screen.dart';
import 'diary_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'sounds_screen.dart';
import 'stats_screen.dart';           // ← NUEVO

// ─────────────────────────────────────────────
// Modelos de datos locales
// ─────────────────────────────────────────────
class _Conversation {
  final String title;
  final String preview;
  final String time;
  final String emoji;
  const _Conversation({
    required this.title,
    required this.preview,
    required this.time,
    required this.emoji,
  });
}

class _MoodOption {
  final String emoji;
  final String label;
  final Color color;
  const _MoodOption({required this.emoji, required this.label, required this.color});
}

// ─────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {

  late AnimationController _entryController;
  late Animation<double> _headerFade;
  late Animation<double> _cardsFade;
  late Animation<Offset> _headerSlide;
  late Animation<Offset> _cardsSlide;

  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  int? _selectedMood;
  int _navIndex = 0;

  final String _userName = 'Fernando';
  final List<_MoodOption> _moods = const [
    _MoodOption(emoji: '😊', label: 'Genial',    color: Color(0xFF66BB6A)),
    _MoodOption(emoji: '😌', label: 'Tranquilo', color: Color(0xFF29B6F6)),
    _MoodOption(emoji: '😐', label: 'Neutral',   color: Color(0xFFFFCA28)),
    _MoodOption(emoji: '😟', label: 'Ansioso',   color: Color(0xFFFFA726)),
    _MoodOption(emoji: '😔', label: 'Triste',    color: Color(0xFFEF5350)),
  ];

  final List<_Conversation> _conversations = const [
    _Conversation(title: 'Sobre mi día',      preview: 'Hoy me fue bien en el trabajo aunque estaba nervioso...', time: 'Hace 2h', emoji: '☀️'),
    _Conversation(title: 'Mis miedos',        preview: 'Me cuesta hablar de esto pero creo que necesito...',      time: 'Ayer',    emoji: '🌙'),
    _Conversation(title: 'Logros de la semana', preview: 'Terminé el proyecto y me sentí muy orgulloso de...',    time: 'Lun',     emoji: '🏆'),
  ];

  final List<double> _weekStats = [0.6, 0.8, 0.5, 0.9, 0.7, 0.85, 0.75];
  final List<String> _weekDays  = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _headerFade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _headerSlide = Tween(begin: const Offset(0, -0.15), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _cardsFade   = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _cardsSlide  = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween(begin: -6.0, end: 6.0).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _greetingEmoji {
    final h = DateTime.now().hour;
    if (h < 12) return '🌅';
    if (h < 18) return '☀️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F6FF),
        extendBody: true,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: FadeTransition(opacity: _cardsFade, child: SlideTransition(position: _cardsSlide, child: _buildMoodCard()))),
            SliverToBoxAdapter(child: FadeTransition(opacity: _cardsFade, child: SlideTransition(position: _cardsSlide, child: _buildQuickActions()))),
            SliverToBoxAdapter(child: FadeTransition(opacity: _cardsFade, child: SlideTransition(position: _cardsSlide, child: _buildWeekStats()))),
            SliverToBoxAdapter(child: FadeTransition(opacity: _cardsFade, child: SlideTransition(position: _cardsSlide, child: _buildConversations()))),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: _buildFAB(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF29B6F6)], stops: [0.0, 0.55, 1.0]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _goToProfile,
                        child: Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2), border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5)),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      GestureDetector(
                        onTap: _goToNotifications,
                        child: Stack(children: [
                          Container(width: 42, height: 42,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22)),
                          Positioned(top: 8, right: 8,
                              child: Container(width: 9, height: 9, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF6B6B)))),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_greeting $_greetingEmoji', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w400, letterSpacing: 0.3)),
                            const SizedBox(height: 4),
                            Text('$_userName,', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.25), width: 1)),
                              child: const Text('¿Cómo te sientes hoy?', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, child) => Transform.translate(offset: Offset(0, _floatAnim.value), child: child),
                        child: GestureDetector(
                          onTap: _goToChat,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1))),
                              Container(
                                width: 82, height: 82,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]),
                                child: ClipOval(child: Padding(padding: const EdgeInsets.all(10), child: Image.asset('assets/logo.png', fit: BoxFit.contain))),
                              ),
                              Positioned(bottom: 4, child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFF29B6F6), borderRadius: BorderRadius.circular(10),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)]),
                                child: const Text('¡Chatea! 💬', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                              )),
                            ],
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
      ),
    );
  }

  Widget _buildMoodCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.favorite_rounded, color: Color(0xFF1976D2), size: 18)),
              const SizedBox(width: 10),
              const Text('¿Cómo te sientes ahora?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
            ]),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_moods.length, (i) {
                final m = _moods[i];
                final selected = _selectedMood == i;
                return GestureDetector(
                  onTap: () { setState(() => _selectedMood = i); HapticFeedback.lightImpact(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected ? m.color.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? m.color : Colors.transparent, width: 2),
                    ),
                    child: Column(children: [
                      Text(m.emoji, style: TextStyle(fontSize: selected ? 30 : 26)),
                      const SizedBox(height: 4),
                      Text(m.label, style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? m.color : const Color(0xFF90A4AE))),
                    ]),
                  ),
                );
              }),
            ),
            if (_selectedMood != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _goToChat,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_moods[_selectedMood!].color, _moods[_selectedMood!].color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Cuéntame más ${_moods[_selectedMood!].emoji}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    // ── PATRÓN PARA AGREGAR BOTONES ──────────────────────────────────────
    // 1. Crea el archivo nueva_pantalla.dart en la misma carpeta
    // 2. Importa arriba: import 'nueva_pantalla.dart';
    // 3. Agrega un _QuickAction aquí con su onTap: _goToNuevaPantalla
    // 4. Crea el método _goToNuevaPantalla() abajo en la sección Navegación
    // ─────────────────────────────────────────────────────────────────────
    final actions = [
      _QuickAction(icon: Icons.chat_bubble_rounded,      label: 'Nuevo\nchat',  color: const Color(0xFF1976D2), onTap: _goToChat),
      _QuickAction(icon: Icons.self_improvement_rounded, label: 'Respirar',     color: const Color(0xFF26A69A), onTap: _goToBreathing),
      _QuickAction(icon: Icons.music_note_rounded,       label: 'Sonidos',      color: const Color(0xFF6A1B9A), onTap: _goToSounds),
      _QuickAction(icon: Icons.book_rounded,             label: 'Mi\ndiario',   color: const Color(0xFFF57C00), onTap: _goToDiary),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Acciones rápidas'),
          const SizedBox(height: 12),
          Row(children: actions.map((a) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _QuickActionBtn(action: a)))).toList()),
        ],
      ),
    );
  }

  Widget _buildWeekStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.insights_rounded, color: Color(0xFF7B1FA2), size: 18)),
              const SizedBox(width: 10),
              const Expanded(child: Text('Tu semana emocional', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)))),
              // ── Tap → va a estadísticas detalladas ──
              GestureDetector(
                onTap: _goToStats,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Ver más →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7B1FA2))),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_weekStats.length, (i) {
                  final isToday = i == DateTime.now().weekday - 1;
                  return _Bar(value: _weekStats[i], day: _weekDays[i], isToday: isToday);
                }),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Text('🌟', style: TextStyle(fontSize: 18)),
                SizedBox(width: 10),
                Expanded(child: Text('¡Tu bienestar mejoró esta semana! Sigue así.', style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversations() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader(title: 'Conversaciones recientes'),
              TextButton(onPressed: () => _showSnack('Ver todas próximamente'), child: const Text('Ver todas', style: TextStyle(color: Color(0xFF1976D2), fontSize: 13))),
            ],
          ),
          const SizedBox(height: 8),
          ..._conversations.map((c) => _ConversationTile(conv: c, onTap: _goToChat)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.10), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded,          label: 'Inicio',   index: 0, current: _navIndex, onTap: (i) => setState(() => _navIndex = i)),
              _NavItem(icon: Icons.chat_bubble_rounded,   label: 'Chat',     index: 1, current: _navIndex, onTap: (i) { setState(() => _navIndex = i); _goToChat(); }),
              const SizedBox(width: 56),
              _NavItem(icon: Icons.bar_chart_rounded,     label: 'Progreso', index: 2, current: _navIndex, onTap: (i) { setState(() => _navIndex = i); _goToStats(); }),
              _NavItem(icon: Icons.person_rounded,        label: 'Perfil',   index: 3, current: _navIndex, onTap: (i) { setState(() => _navIndex = i); _goToProfile(); }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: _goToChat,
      child: Container(
        width: 62, height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF29B6F6)]),
          boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipOval(child: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/logo.png', fit: BoxFit.contain))),
      ),
    );
  }

  // ── NAVEGACIÓN ─────────────────────────────────────────────────────────
  // PATRÓN: copia uno de estos métodos, cambia el nombre y la Screen destino
  // ─────────────────────────────────────────────────────────────────────────

  void _goToChat() => Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (c, a, s) => const ChatScreen(),
    transitionsBuilder: (c, a, s, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));

  void _goToBreathing() => Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (c, a, s) => const BreathingScreen(),
    transitionsBuilder: (c, a, s, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));

  void _goToDiary() => Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (c, a, s) => const DiaryScreen(),
    transitionsBuilder: (c, a, s, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));

  void _goToSounds() => Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (c, a, s) => SoundsScreen(),
    transitionsBuilder: (c, a, s, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));

  void _goToNotifications() => Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (c, a, s) => const NotificationsScreen(),
    transitionsBuilder: (c, a, s, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));

  void _goToProfile() => Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (c, a, s) => const ProfileScreen(),
    transitionsBuilder: (c, a, s, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));

  // ── NUEVO: Estadísticas ───────────────────────────────────────────────
  void _goToStats() => Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (c, a, s) => const StatsScreen(),
    transitionsBuilder: (c, a, s, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  ));

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF1565C0),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))]),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1)));
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
}

class _QuickActionBtn extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionBtn({required this.action});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: action.onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: action.color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: action.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(action.icon, color: action.color, size: 22)),
        const SizedBox(height: 8),
        Text(action.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: action.color, height: 1.2)),
      ]),
    ),
  );
}

class _Bar extends StatelessWidget {
  final double value;
  final String day;
  final bool isToday;
  const _Bar({required this.value, required this.day, required this.isToday});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Container(
        width: 28, height: 60 * value,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: isToday
              ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1565C0), Color(0xFF29B6F6)])
              : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [const Color(0xFF90CAF9).withOpacity(0.6), const Color(0xFFBBDEFB).withOpacity(0.4)]),
          boxShadow: isToday ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
      ),
      const SizedBox(height: 6),
      Text(day, style: TextStyle(fontSize: 11, fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
          color: isToday ? const Color(0xFF1565C0) : const Color(0xFF90A4AE))),
    ],
  );
}

class _ConversationTile extends StatelessWidget {
  final _Conversation conv;
  final VoidCallback onTap;
  const _ConversationTile({required this.conv, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 3))]),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(conv.emoji, style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(conv.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
          const SizedBox(height: 3),
          Text(conv.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE))),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(conv.time, style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5))),
          const SizedBox(height: 6),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFFCFD8DC)),
        ]),
      ]),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: active ? const Color(0xFFE3F2FD) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: active ? const Color(0xFF1565C0) : const Color(0xFFB0BEC5), size: 22),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? const Color(0xFF1565C0) : const Color(0xFFB0BEC5))),
        ]),
      ),
    );
  }
}