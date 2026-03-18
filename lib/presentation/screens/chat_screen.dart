import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

// ─────────────────────────────────────────────
// Modelos
// ─────────────────────────────────────────────
enum _Sender { user, acom }

class _Message {
  final String text;
  final _Sender sender;
  final DateTime time;
  final bool isTyping;

  const _Message({
    required this.text,
    required this.sender,
    required this.time,
    this.isTyping = false,
  });
}

// ─────────────────────────────────────────────
// Chat Screen
// ─────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {

  final _scrollController = ScrollController();
  final _textController   = TextEditingController();
  final _focusNode        = FocusNode();

  late AnimationController _headerPulse;
  late Animation<double>   _pulseAnim;

  final List<_Message> _messages = [];
  bool _isAcomTyping = false;
  bool _showSuggestions = true;

  // Sugerencias iniciales
  final List<String> _suggestions = [
    '😊 Me siento bien hoy',
    '😟 Estoy ansioso',
    '💬 Solo quiero hablar',
    '😴 No dormí bien',
    '🌟 Quiero compartir algo',
    '😔 Me siento solo',
  ];

  // Respuestas de ACOM según palabras clave
  final Map<String, List<String>> _responses = {
    'bien':     ['¡Me alegra mucho escuchar eso! 😊 ¿Qué fue lo mejor de tu día?', '¡Qué bueno! Cuéntame más, ¿qué te hizo sentir así?'],
    'ansioso':  ['Entiendo cómo te sientes. La ansiedad puede ser difícil. 🤗\n¿Quieres que hagamos juntos un ejercicio de respiración?', 'Estoy aquí contigo. ¿Puedes contarme qué está pasando por tu mente?'],
    'hablar':   ['Claro, estoy aquí para ti. 💙 Puedes contarme lo que quieras, sin filtros.', 'Me encanta que estés aquí. ¿Por dónde quieres empezar?'],
    'dormí':    ['El descanso es muy importante para tu bienestar. 😴\n¿Qué crees que afectó tu sueño esta noche?', 'Eso puede afectar mucho cómo te sientes. ¿Quieres hablar de lo que te tiene en mente?'],
    'solo':     ['No estás solo, aquí estoy yo. 🤗\nCuéntame cómo te has sentido últimamente.', 'Gracias por compartirlo conmigo. La soledad duele, ¿qué está pasando?'],
    'compartir':['¡Adelante! Me encanta escucharte. ¿Qué tienes en mente? 🌟', 'Estoy todo oídos. Cuéntame todo 😊'],
    'triste':   ['Lo siento mucho. 💙 Estoy aquí contigo.\n¿Quieres contarme qué está pasando?', 'Tu tristeza es válida. No tienes que enfrentarla solo/a. ¿Qué ocurrió?'],
    'mal':      ['Lamento que no estés bien. 🤗\n¿Puedes contarme un poco más sobre cómo te sientes?', 'Estoy aquí para acompañarte. ¿Qué está pasando?'],
    'gracias':  ['¡De nada! Para eso estoy. 💙 ¿Hay algo más en lo que pueda ayudarte?', '¡Siempre! Recuerda que puedes hablar conmigo cuando quieras. 😊'],
    'default':  [
      'Entiendo. Cuéntame más sobre eso. 💙',
      'Gracias por compartirlo conmigo. ¿Cómo te hace sentir eso?',
      'Estoy aquí escuchándote. ¿Hay algo específico que te pese?',
      'Te escucho. 🤗 ¿Quieres explorar ese sentimiento juntos?',
      'Valoro mucho que confíes en mí. ¿Qué más puedes contarme?',
    ],
  };

  @override
  void initState() {
    super.initState();

    _headerPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _headerPulse, curve: Curves.easeInOut),
    );

    // Mensaje de bienvenida
    Future.delayed(const Duration(milliseconds: 400), _sendWelcome);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _headerPulse.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Lógica de mensajes
  // ─────────────────────────────────────────────
  void _sendWelcome() async {
    await _acomType('¡Hola! Soy ACOM 👋\n¿Cómo estás hoy? Puedes contarme todo, estoy aquí para ti. 💙');
  }

  Future<void> _acomType(String text) async {
    if (!mounted) return;

    // Mostrar burbuja de typing
    setState(() {
      _isAcomTyping = true;
      _messages.add(_Message(
        text: '',
        sender: _Sender.acom,
        time: DateTime.now(),
        isTyping: true,
      ));
    });
    _scrollToBottom();

    // Simular tiempo de escritura proporcional al texto
    final delay = math.max(1200, math.min(text.length * 28, 3000));
    await Future.delayed(Duration(milliseconds: delay));

    if (!mounted) return;

    // Reemplazar typing por mensaje real
    setState(() {
      _isAcomTyping = false;
      _messages.removeLast();
      _messages.add(_Message(
        text: text,
        sender: _Sender.acom,
        time: DateTime.now(),
      ));
    });
    _scrollToBottom(delayed: true);
    HapticFeedback.selectionClick();
  }

  void _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isAcomTyping) return;

    _textController.clear();
    setState(() {
      _showSuggestions = false;
      _messages.add(_Message(
        text: trimmed,
        sender: _Sender.user,
        time: DateTime.now(),
      ));
    });
    _scrollToBottom(delayed: true);
    HapticFeedback.lightImpact();

    // Buscar respuesta
    await Future.delayed(const Duration(milliseconds: 600));
    final response = _findResponse(trimmed.toLowerCase());
    await _acomType(response);
  }

  String _findResponse(String input) {
    for (final key in _responses.keys) {
      if (key != 'default' && input.contains(key)) {
        final list = _responses[key]!;
        return list[math.Random().nextInt(list.length)];
      }
    }
    final defaults = _responses['default']!;
    return defaults[math.Random().nextInt(defaults.length)];
  }

  void _scrollToBottom({bool delayed = false}) {
    final scroll = () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    };
    if (delayed) {
      Future.delayed(const Duration(milliseconds: 100), scroll);
    } else {
      scroll();
    }
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
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            if (_showSuggestions && _messages.length <= 1)
              _buildSuggestions(),
            _buildInputBar(),
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
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF29B6F6)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Row(
            children: [
              // Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),

              const SizedBox(width: 12),

              // Avatar robot
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: child,
                ),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACOM',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF69F0AE),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isAcomTyping ? 'Escribiendo...' : 'En línea · siempre aquí 💙',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Opciones
              GestureDetector(
                onTap: () => _showChatOptions(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.more_vert_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Lista de mensajes
  // ─────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final isFirst = i == 0 || _messages[i - 1].sender != msg.sender;
        return _MessageBubble(
          message: msg,
          isFirst: isFirst,
          key: ValueKey('$i-${msg.time.millisecondsSinceEpoch}'),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Sugerencias rápidas
  // ─────────────────────────────────────────────
  Widget _buildSuggestions() {
    return Container(
      color: const Color(0xFFF0F6FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'Sugerencias rápidas',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF1976D2).withOpacity(0.7),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () => _sendMessage(_suggestions[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBBDEFB), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1976D2).withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _suggestions[i],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Input bar
  // ─────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          // Campo de texto
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFBBDEFB), width: 1.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF0D47A1),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Escríbeme lo que sientes...',
                        hintStyle: TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  // Emoji btn
                  GestureDetector(
                    onTap: () {},
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('😊', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Send button
          AnimatedBuilder(
            animation: _textController,
            builder: (_, __) {
              final hasText = _textController.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: () => _sendMessage(_textController.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: hasText && !_isAcomTyping
                          ? [const Color(0xFF1565C0), const Color(0xFF29B6F6)]
                          : [const Color(0xFFCFD8DC), const Color(0xFFECEFF1)],
                    ),
                    boxShadow: hasText && !_isAcomTyping
                        ? [BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )]
                        : [],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: hasText && !_isAcomTyping
                        ? Colors.white
                        : const Color(0xFF90A4AE),
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Chat options bottom sheet ──────────────
  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCFD8DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Opciones del chat',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 20),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Borrar conversación',
              color: const Color(0xFFEF5350),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _messages.clear();
                  _showSuggestions = true;
                });
                Future.delayed(
                  const Duration(milliseconds: 300), _sendWelcome);
              },
            ),
            _OptionTile(
              icon: Icons.bookmark_outline_rounded,
              label: 'Guardar conversación',
              color: const Color(0xFF1976D2),
              onTap: () => Navigator.pop(context),
            ),
            _OptionTile(
              icon: Icons.share_outlined,
              label: 'Compartir resumen',
              color: const Color(0xFF26A69A),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Burbuja de mensaje
// ─────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final _Message message;
  final bool isFirst;

  const _MessageBubble({
    required this.message,
    required this.isFirst,
    super.key,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {

  late AnimationController _anim;
  late Animation<double>   _scale;
  late Animation<double>   _opacity;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOut),
    );
    _slide = Tween(
      begin: Offset(widget.message.sender == _Sender.user ? 0.1 : -0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.sender == _Sender.user;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: 6,
              top: widget.isFirst ? 10 : 2,
            ),
            child: Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar ACOM
                if (!isUser && widget.isFirst) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1976D2).withOpacity(0.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (!isUser) ...[
                  const SizedBox(width: 40),
                ],

                // Bubble
                Flexible(
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isUser
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1565C0),
                                    Color(0xFF1976D2),
                                  ],
                                )
                              : null,
                          color: isUser ? null : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isUser
                                  ? const Color(0xFF1565C0).withOpacity(0.3)
                                  : const Color(0xFF1976D2).withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: widget.message.isTyping
                            ? const _TypingDots()
                            : Text(
                                widget.message.text,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isUser
                                      ? Colors.white
                                      : const Color(0xFF1A237E),
                                  height: 1.45,
                                ),
                              ),
                      ),
                      if (!widget.message.isTyping)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                          child: Text(
                            _formatTime(widget.message.time),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFB0BEC5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Espacio derecha usuario
                if (isUser) const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
// Typing dots animados
// ─────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
      height: 20,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final phase = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
              final bounce = math.sin(phase * math.pi);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8 + bounce * 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Color.lerp(
                    const Color(0xFFBBDEFB),
                    const Color(0xFF1976D2),
                    bounce,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Option tile (bottom sheet)
// ─────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}