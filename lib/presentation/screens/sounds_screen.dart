import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;
import 'breathing_screen.dart';

// ─────────────────────────────────────────────
// Modelo de sonido
// ─────────────────────────────────────────────
class _Sound {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final String asset;       // ruta en assets/sounds/
  final Color color;
  final Color colorDark;

  const _Sound({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.color,
    required this.colorDark,
  });
}

const _sounds = [
  _Sound(id: 'rain',    emoji: '🌧️', title: 'Lluvia',           subtitle: 'Gotas sobre el tejado',     asset: 'assets/sounds/rain.mp3',    color: Color(0xFF1976D2), colorDark: Color(0xFF0D47A1)),
  _Sound(id: 'ocean',   emoji: '🌊', title: 'Olas del mar',     subtitle: 'Brisa y oleaje suave',      asset: 'assets/sounds/ocean.mp3',   color: Color(0xFF0097A7), colorDark: Color(0xFF006064)),
  _Sound(id: 'forest',  emoji: '🌲', title: 'Bosque',           subtitle: 'Pájaros y naturaleza',      asset: 'assets/sounds/forest.mp3',  color: Color(0xFF388E3C), colorDark: Color(0xFF1B5E20)),
  _Sound(id: 'fire',    emoji: '🔥', title: 'Chimenea',         subtitle: 'Fuego crepitante',          asset: 'assets/sounds/fire.mp3',    color: Color(0xFFE64A19), colorDark: Color(0xFFBF360C)),
  _Sound(id: 'wind',    emoji: '💨', title: 'Viento',           subtitle: 'Brisa entre los árboles',   asset: 'assets/sounds/wind.mp3',    color: Color(0xFF546E7A), colorDark: Color(0xFF263238)),
  _Sound(id: 'cafe',    emoji: '☕', title: 'Café',             subtitle: 'Ambiente acogedor',         asset: 'assets/sounds/cafe.mp3',    color: Color(0xFF795548), colorDark: Color(0xFF3E2723)),
  _Sound(id: 'tibetan', emoji: '🔔', title: 'Cuencos tibetanos',subtitle: 'Vibración meditativa',      asset: 'assets/sounds/tibetan.mp3', color: Color(0xFFF57F17), colorDark: Color(0xFFE65100)),
  _Sound(id: 'white',   emoji: '〰️', title: 'Ruido blanco',    subtitle: 'Silencio inteligente',      asset: 'assets/sounds/white.mp3',   color: Color(0xFF455A64), colorDark: Color(0xFF1C313A)),
];

// ─────────────────────────────────────────────
// Sounds Screen
// ─────────────────────────────────────────────
class SoundsScreen extends StatefulWidget {
  final bool fromBreathing;
  const SoundsScreen({super.key, this.fromBreathing = false});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen>
    with TickerProviderStateMixin {

  // Un AudioPlayer por sonido
  final Map<String, AudioPlayer> _players = {};
  final Map<String, double>      _volumes  = {};
  final Map<String, bool>        _playing  = {};
  bool _anyPlaying = false;

  // Animaciones
  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  late AnimationController _waveCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entryFade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entrySlide = Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    // Inicializar players y volúmenes
    for (final s in _sounds) {
      _players[s.id] = AudioPlayer();
      _volumes[s.id] = 0.7;
      _playing[s.id] = false;
    }

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _waveCtrl.dispose();
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Lógica de audio
  // ─────────────────────────────────────────────
  Future<void> _toggleSound(_Sound sound) async {
    final player  = _players[sound.id]!;
    final playing = _playing[sound.id]!;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      if (playing) {
        await player.pause();
        setState(() {
          _playing[sound.id] = false;
          _anyPlaying = _playing.values.any((v) => v);
        });
      } else {
        // Cargar y reproducir en loop
        await player.setAsset(sound.asset);
        await player.setVolume(_volumes[sound.id]!);
        await player.setLoopMode(LoopMode.one);
        await player.play();
        setState(() {
          _playing[sound.id] = true;
          _anyPlaying = true;
        });
      }
    } catch (e) {
      _showSnack('❌ No se pudo cargar "${sound.title}". Verifica el archivo de audio.');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _setVolume(_Sound sound, double volume) async {
    setState(() => _volumes[sound.id] = volume);
    if (_playing[sound.id] == true) {
      await _players[sound.id]?.setVolume(volume);
    }
  }

  Future<void> _stopAll() async {
    for (final s in _sounds) {
      await _players[s.id]?.pause();
      setState(() => _playing[s.id] = false);
    }
    setState(() => _anyPlaying = false);
    HapticFeedback.mediumImpact();
  }

  Future<void> _pauseAll() async {
    for (final s in _sounds) {
      if (_playing[s.id] == true) {
        await _players[s.id]?.pause();
        setState(() => _playing[s.id] = false);
      }
    }
    setState(() => _anyPlaying = false);
    HapticFeedback.lightImpact();
  }

  Future<void> _resumeAll() async {
    bool any = false;
    for (final s in _sounds) {
      if (_players[s.id]?.processingState == ProcessingState.ready) {
        await _players[s.id]?.play();
        setState(() => _playing[s.id] = true);
        any = true;
      }
    }
    setState(() => _anyPlaying = any);
    HapticFeedback.lightImpact();
  }

  int get _activeCount => _playing.values.where((v) => v).length;

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Column(
          children: [
            _buildHeader(),
            if (_anyPlaying) _buildNowPlayingBar(),
            Expanded(
              child: FadeTransition(
                opacity: _entryFade,
                child: SlideTransition(
                  position: _entrySlide,
                  child: _buildGrid(),
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
          colors: [Color(0xFF0D1B3E), Color(0xFF1A237E), Color(0xFF283593)],
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
                    onTap: () {
                      _stopAll();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sonidos relajantes 🎵',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('Mezcla sonidos para crear tu ambiente',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                      ],
                    ),
                  ),

                  // Contador activos
                  if (_activeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Wave animada
                          AnimatedBuilder(
                            animation: _waveCtrl,
                            builder: (_, __) => Row(
                              children: List.generate(3, (i) {
                                final h = 4.0 + 6 * math.sin((_waveCtrl.value * 2 * math.pi) + i * 1.2).abs();
                                return Container(
                                  width: 3, height: h,
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('$_activeCount activo${_activeCount > 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Botones globales
              Row(
                children: [
                  Expanded(
                    child: _HeaderBtn(
                      icon: Icons.stop_rounded,
                      label: 'Detener todo',
                      onTap: _stopAll,
                      enabled: _anyPlaying,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Ir a respiración con sonido
                  Expanded(
                    child: _HeaderBtn(
                      icon: Icons.self_improvement_rounded,
                      label: 'Respirar con sonido',
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 400),
                            pageBuilder: (c, a, s) => const BreathingScreen(),
                            transitionsBuilder: (c, a, s, child) => SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1), end: Offset.zero,
                              ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                          ),
                        );
                      },
                      enabled: true,
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
  // Now playing bar
  // ─────────────────────────────────────────────
  Widget _buildNowPlayingBar() {
    final activeSounds = _sounds.where((s) => _playing[s.id] == true).toList();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Wave indicator
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) => Row(
              children: List.generate(4, (i) {
                final h = 8.0 + 12 * math.sin((_waveCtrl.value * 2 * math.pi) + i * 0.8).abs();
                return Container(
                  width: 3, height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activeSounds.map((s) => s.emoji).join('  '),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          // Pause/Resume
          GestureDetector(
            onTap: _anyPlaying ? _pauseAll : _resumeAll,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
              child: Icon(
                _anyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Grid de sonidos
  // ─────────────────────────────────────────────
  Widget _buildGrid() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Info card
        _buildInfoCard(),
        const SizedBox(height: 16),

        // Grid 2 columnas
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: _sounds.length,
          itemBuilder: (_, i) => _SoundCard(
            sound: _sounds[i],
            isPlaying: _playing[_sounds[i].id] ?? false,
            volume: _volumes[_sounds[i].id] ?? 0.7,
            onTap: () => _toggleSound(_sounds[i]),
            onVolumeChange: (v) => _setVolume(_sounds[i], v),
            waveAnim: _waveCtrl,
          ),
        ),

        const SizedBox(height: 20),
        _buildAssetsInfo(),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Puedes mezclar varios sonidos a la vez. Ajusta el volumen de cada uno con el slider.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📁', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Archivos de audio requeridos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Agrega estos archivos en assets/sounds/ de tu proyecto:',
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 8),
          ..._sounds.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(
                  s.asset.split('/').last,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64B5F6),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 10),
          Text(
            '💡 Descarga sonidos gratis en freesound.org o zapsplat.com',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF1A237E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }
}

// ─────────────────────────────────────────────
// Sound Card
// ─────────────────────────────────────────────
class _SoundCard extends StatelessWidget {
  final _Sound sound;
  final bool isPlaying;
  final double volume;
  final VoidCallback onTap;
  final void Function(double) onVolumeChange;
  final AnimationController waveAnim;

  const _SoundCard({
    required this.sound,
    required this.isPlaying,
    required this.volume,
    required this.onTap,
    required this.onVolumeChange,
    required this.waveAnim,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPlaying
                ? [sound.colorDark, sound.color]
                : [const Color(0xFF0D1B3E), const Color(0xFF1A237E)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPlaying ? sound.color.withOpacity(0.6) : Colors.white.withOpacity(0.08),
            width: isPlaying ? 2 : 1,
          ),
          boxShadow: isPlaying
              ? [BoxShadow(
                  color: sound.color.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sound.emoji, style: const TextStyle(fontSize: 32)),

                  // Play indicator o botón
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPlaying
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white.withOpacity(0.08),
                    ),
                    child: isPlaying
                        ? AnimatedBuilder(
                            animation: waveAnim,
                            builder: (_, __) => Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (i) {
                                  final h = 4.0 + 6 * math.sin((waveAnim.value * 2 * math.pi) + i * 1.0).abs();
                                  return Container(
                                    width: 2.5, height: h,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, color: Colors.white54, size: 18),
                  ),
                ],
              ),

              const Spacer(),

              // Título
              Text(
                sound.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sound.subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),

              const SizedBox(height: 10),

              // Slider de volumen (solo cuando está activo)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: isPlaying
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.volume_down_rounded,
                                  color: Colors.white.withOpacity(0.5), size: 14),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                                    thumbColor: Colors.white,
                                    overlayColor: Colors.white.withOpacity(0.1),
                                  ),
                                  child: Slider(
                                    value: volume,
                                    min: 0.0,
                                    max: 1.0,
                                    onChanged: onVolumeChange,
                                  ),
                                ),
                              ),
                              Icon(Icons.volume_up_rounded,
                                  color: Colors.white.withOpacity(0.5), size: 14),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  const _HeaderBtn({required this.icon, required this.label, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: enabled ? Colors.white : Colors.white30, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? Colors.white : Colors.white30,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}