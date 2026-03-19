import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
// Respuestas locales de fallback
// ─────────────────────────────────────────────
class _LocalBrain {
  static final _rng = math.Random();

  static const _map = {
    'ansios':   ['😟 Entiendo que estás ansioso/a. La ansiedad puede ser muy agotadora.\n¿Quieres contarme qué está pasando por tu mente ahora mismo?',
                 '¿Cuándo empezaste a sentirte así? Estoy aquí para escucharte 💙'],
    'nervios':  ['Los nervios son señal de que algo te importa 💙\n¿Qué es lo que más te preocupa en este momento?'],
    'preocup':  ['Entiendo que estás preocupado/a. Es completamente válido sentirse así.\n¿Me puedes contar más sobre qué te preocupa?'],
    'triste':   ['Lo siento mucho 💙 La tristeza duele, pero no estás solo/a.\n¿Quieres contarme qué está pasando?',
                 'Estoy aquí contigo. ¿Qué está pasando en tu corazón ahora mismo?'],
    'llorar':   ['Está bien llorar, es una forma de sanar 💙\n¿Qué está pasando?'],
    'mal':      ['Lamento que no estés bien. ¿Puedes contarme un poco más?\nEstoy aquí para escucharte sin juzgar 💙'],
    'dolor':    ['El dolor emocional es tan real como el físico. Te escucho 💙\n¿Qué está pasando?'],
    'solo':     ['La soledad puede ser muy pesada. Pero aquí estoy yo 💙\n¿Quieres contarme cómo ha sido tu día?'],
    'nadie':    ['Aunque sientas que no hay nadie, aquí estoy yo. Me importa cómo te sientes 💙'],
    'estres':   ['El estrés puede volverse abrumador. Respira 🌬️\n¿Qué es lo que más te está pesando ahora mismo?'],
    'trabajo':  ['El trabajo puede consumirnos. ¿Cómo te está afectando?\nCuéntame más 💙'],
    'cansad':   ['El cansancio profundo va más allá del sueño 💙\n¿Es cansancio físico, emocional o los dos?'],
    'agotad':   ['Cuando estamos agotados todo parece más difícil. Es válido sentirse así 💙\n¿Qué te tiene tan agotado/a?'],
    'bien':     ['¡Me alegra mucho escuchar eso! 😊\n¿Qué fue lo mejor de tu día?'],
    'feliz':    ['¡Qué bueno! La felicidad merece ser celebrada 🌟\n¿Qué te tiene tan contento/a?'],
    'genial':   ['¡Genial! Eso me pone muy contento/a 😊\n¿Qué pasó hoy que te tiene así de bien?'],
    'tranquil': ['La tranquilidad es un regalo 😌\n¿Qué te ayudó a llegar a ese estado de calma?'],
    'dormir':   ['El sueño es fundamental para el bienestar 😴\n¿Qué crees que está afectando tu descanso?'],
    'insomnio': ['El insomnio puede ser agotador 😔\n¿Qué pasa por tu mente cuando no puedes dormir?'],
    'amigo':    ['Las amistades son muy importantes 💙\n¿Qué está pasando con tu amigo/a?'],
    'pareja':   ['Las relaciones pueden ser fuente de alegría y también de dolor 💙\n¿Quieres contarme qué está pasando?'],
    'familia':  ['La familia puede ser complicada 💙\n¿Qué está pasando?'],
    'ayuda':    ['Estoy aquí para acompañarte 💙\n¿Qué está pasando? Cuéntame con confianza.'],
    'no se':    ['A veces no saber es el primer paso para encontrar claridad 💙\n¿Qué sientes aunque no sepas explicarlo?'],
    'confund':  ['La confusión es válida 💙\n¿Qué es lo que más te tiene confundido/a?'],
    'respir':   ['Respirar conscientemente ayuda mucho 🌬️\nInhala 4s → sostén 4s → exhala 4s. ¿Lo intentamos?'],
    'gracias':  ['¡Con mucho gusto! Estoy aquí siempre que me necesites 💙\n¿Hay algo más que quieras compartir?'],
    'logr':     ['¡Eso es increíble! Los logros merecen ser celebrados 🏆\n¿Cómo te sientes al respecto?'],
    'orgull':   ['¡Qué bien! El orgullo propio es muy sano 🌟\n¿Qué fue lo que lograste?'],
  };

  static const _generic = [
    'Cuéntame más sobre eso 💙 ¿Cómo te hace sentir?',
    'Te escucho. ¿Hay algo específico que quieras explorar?',
    'Gracias por compartirlo conmigo 💙 ¿Desde cuándo te sientes así?',
    'Entiendo. ¿Qué crees que está detrás de ese sentimiento?',
    'Aprecio que confíes en mí 💙 ¿Hay algo más que quieras contarme?',
    '¿Cómo has manejado situaciones similares antes?',
    'Eso suena importante. ¿Quieres profundizar más?',
    '¿Qué necesitarías ahora mismo para sentirte un poco mejor?',
    'Lo que describes tiene mucho sentido 💙 ¿Qué te gustaría que pasara?',
    '¿Has podido hablar con alguien más sobre esto?',
  ];

  static const _questions = [
    'Es una buena pregunta para reflexionar 💙 ¿Qué crees tú?',
    'Me parece importante que te hagas esa pregunta. ¿Qué respuesta sientes más verdadera?',
    'A veces las respuestas están dentro de nosotros 💙 ¿Qué sientes cuando lo piensas?',
    'Es algo en lo que vale la pena profundizar. ¿Quieres explorarlo juntos?',
  ];

  static String respond(String input) {
    final lower = input.toLowerCase();
    for (final entry in _map.entries) {
      if (lower.contains(entry.key)) {
        final list = entry.value;
        return list[_rng.nextInt(list.length)];
      }
    }
    if (lower.contains('?') || lower.startsWith('qué') || lower.startsWith('cómo') || lower.startsWith('por qué')) {
      return _questions[_rng.nextInt(_questions.length)];
    }
    return _generic[_rng.nextInt(_generic.length)];
  }
}

// ─────────────────────────────────────────────
// Gemini Service
// ─────────────────────────────────────────────
class _GeminiService {
  static const _model   = 'gemini-2.0-flash';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static String buildSystemPrompt({int? moodIndex, String? userName}) {
    final name    = (userName?.isNotEmpty == true) ? userName! : 'amigo/a';
    final moodCtx = _moodContext(moodIndex);
    return '''Eres ACOM (Always Count On Me), un compañero emocional cálido, empático y comprensivo.
Tu misión es acompañar emocionalmente a $name con presencia genuina, sin juzgar.

PERSONALIDAD:
- Eres cálido, cercano y genuinamente curioso por el bienestar de la persona
- Usas un tono conversacional natural, no clínico ni robótico
- Validas las emociones antes de ofrecer perspectivas o sugerencias
- Haces preguntas abiertas para profundizar, una a la vez
- Usas emojis con moderación para expresar calidez 💙
- SIEMPRE respondes en español
- Mantén respuestas concisas (2-4 párrafos máximo)

CONTEXTO EMOCIONAL ACTUAL:
$moodCtx

DIRECTRICES:
- Escucha activamente y refleja lo que escuchas
- No des consejos no solicitados; primero acompaña
- Si detectas señales de crisis, sugiere ayuda profesional con calidez
- Recuerda el contexto de la conversación para dar continuidad
- Nunca finjas ser humano si te preguntan directamente

PROHIBICIONES:
- No diagnostiques condiciones mentales
- No prescribas medicamentos
- No des información médica específica''';
  }

  static String _moodContext(int? i) {
    if (i == null) return 'El usuario no ha indicado su estado emocional.';
    const moods = [
      'El usuario se siente GENIAL 😊. Celebra con él/ella y explora qué genera ese bienestar.',
      'El usuario se siente TRANQUILO 😌. Acompaña esa serenidad e invita a la reflexión.',
      'El usuario se siente NEUTRAL 😐. Explora con curiosidad qué hay detrás.',
      'El usuario se siente ANSIOSO 😟. Prioriza la validación y la calma.',
      'El usuario se siente TRISTE 😔. Ofrece presencia y escucha sin apresurarte.',
    ];
    return i < moods.length ? moods[i] : moods[2];
  }

  static Future<String> sendMessage({
    required List<Map<String, dynamic>> history,
    required String systemPrompt,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) throw Exception('sin_api_key');

    final contents = <Map<String, dynamic>>[];
    contents.add({'role': 'user', 'parts': [{'text': 'Instrucciones del sistema:\n$systemPrompt'}]});
    contents.add({'role': 'model', 'parts': [{'text': 'Entendido. Seré ACOM, tu compañero emocional 💙'}]});
    contents.addAll(history);

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': contents,
        'generationConfig': {'temperature': 0.85, 'maxOutputTokens': 512, 'topP': 0.9},
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
          {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_MEDIUM_AND_ABOVE'},
        ],
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }
    throw Exception('error_${response.statusCode}');
  }
}

// ─────────────────────────────────────────────
// Chat Screen
// ─────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final int?    initialMood;
  final String? userName;
  const ChatScreen({super.key, this.initialMood, this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {

  final _scrollController = ScrollController();
  final _textController   = TextEditingController();
  final _focusNode        = FocusNode();

  late AnimationController _headerPulse;
  late Animation<double>   _pulseAnim;

  final List<_Message>             _messages   = [];
  final List<Map<String, dynamic>> _apiHistory = [];

  bool   _isAcomTyping    = false;
  bool   _showSuggestions = true;
  bool   _usingGemini     = true; // indica si gemini está activo
  late   String _systemPrompt;

  final List<String> _suggestions = [
    '😊 Me siento bien hoy',
    '😟 Estoy ansioso',
    '💬 Solo quiero hablar',
    '😴 No dormí bien',
    '🌟 Quiero compartir algo',
    '😔 Me siento solo',
  ];

  @override
  void initState() {
    super.initState();
    _headerPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _headerPulse, curve: Curves.easeInOut));

    _systemPrompt = _GeminiService.buildSystemPrompt(
      moodIndex: widget.initialMood,
      userName:  widget.userName,
    );

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
  // Lógica
  // ─────────────────────────────────────────────
  void _sendWelcome() async {
    final name    = widget.userName?.isNotEmpty == true ? widget.userName! : null;
    final greeting = name != null ? 'Hola, $name! 👋' : 'Hola! 👋';
    await _addAcomMessage('$greeting\n${_moodWelcome(widget.initialMood)}');
  }

  String _moodWelcome(int? mood) {
    switch (mood) {
      case 0: return 'Me alegra verte tan bien hoy 😊 ¿Qué fue lo mejor de tu día?';
      case 1: return 'Qué bueno que estés tranquilo/a 😌 ¿Quieres reflexionar sobre algo?';
      case 2: return '¿Cómo va el día? Estoy aquí para lo que necesites 💙';
      case 3: return 'Veo que estás sintiendo algo de ansiedad 😟 Estoy aquí. ¿Qué está pasando?';
      case 4: return 'Lamento que estés pasando un momento difícil 💙 No estás solo/a. ¿Qué tienes en el corazón?';
      default: return 'Soy ACOM, tu compañero emocional. ¿Cómo estás hoy? Puedes contarme lo que quieras 💙';
    }
  }

  Future<void> _addAcomMessage(String text) async {
    if (!mounted) return;
    setState(() {
      _isAcomTyping = true;
      _messages.add(_Message(text: '', sender: _Sender.acom, time: DateTime.now(), isTyping: true));
    });
    _scrollToBottom();

    final words = text.split(' ').length;
    final delay = math.max(700, math.min(words * 75, 2500));
    await Future.delayed(Duration(milliseconds: delay));

    if (!mounted) return;
    setState(() {
      _isAcomTyping = false;
      _messages.removeLast();
      _messages.add(_Message(text: text, sender: _Sender.acom, time: DateTime.now()));
    });
    _scrollToBottom(delayed: true);
    HapticFeedback.selectionClick();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isAcomTyping) return;

    _textController.clear();
    setState(() {
      _showSuggestions = false;
      _messages.add(_Message(text: trimmed, sender: _Sender.user, time: DateTime.now()));
      _isAcomTyping = true;
      _messages.add(_Message(text: '', sender: _Sender.acom, time: DateTime.now(), isTyping: true));
    });
    _apiHistory.add({'role': 'user', 'parts': [{'text': trimmed}]});
    _scrollToBottom(delayed: true);
    HapticFeedback.lightImpact();

    String response;

    // Intentar Gemini primero
    if (_usingGemini) {
      try {
        response = await _GeminiService.sendMessage(
          history:      List.from(_apiHistory),
          systemPrompt: _systemPrompt,
        );
        _apiHistory.add({'role': 'model', 'parts': [{'text': response}]});
      } catch (e) {
        // Gemini falló → usar respuestas locales
        setState(() => _usingGemini = false);
        response = _LocalBrain.respond(trimmed);
      }
    } else {
      // Ya sabemos que Gemini no funciona → local directo
      response = _LocalBrain.respond(trimmed);
    }

    if (!mounted) return;
    setState(() {
      _isAcomTyping = false;
      _messages.removeLast();
      _messages.add(_Message(text: response, sender: _Sender.acom, time: DateTime.now()));
    });
    _scrollToBottom(delayed: true);
    HapticFeedback.selectionClick();
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
    delayed ? Future.delayed(const Duration(milliseconds: 100), scroll) : scroll();
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _apiHistory.clear();
      _showSuggestions = true;
      _usingGemini = true; // reintentar gemini en nueva conversación
    });
    Future.delayed(const Duration(milliseconds: 300), _sendWelcome);
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
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            if (_showSuggestions && _messages.length <= 1) _buildSuggestions(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ClipOval(
                    child: Padding(padding: const EdgeInsets.all(6),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ACOM',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                    Row(
                      children: [
                        Container(width: 7, height: 7,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF69F0AE))),
                        const SizedBox(width: 5),
                        Text(
                          _isAcomTyping
                              ? 'Escribiendo...'
                              : _usingGemini
                                  ? 'IA · Siempre aquí 💙'
                                  : 'En línea · siempre aquí 💙',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showChatOptions,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                  child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg     = _messages[i];
        final isFirst = i == 0 || _messages[i - 1].sender != msg.sender;
        return _MessageBubble(message: msg, isFirst: isFirst,
            key: ValueKey('$i-${msg.time.millisecondsSinceEpoch}'));
      },
    );
  }

  Widget _buildSuggestions() {
    return Container(
      color: const Color(0xFFF0F6FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text('Sugerencias rápidas',
                style: TextStyle(fontSize: 12, color: const Color(0xFF1976D2).withOpacity(0.7),
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _sendMessage(_suggestions[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBDEFB), width: 1.5),
                  ),
                  child: Text(_suggestions[i],
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0), fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(left: 16, right: 16, top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
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
                      maxLines: 4, minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF0D47A1)),
                      decoration: const InputDecoration(
                        hintText: 'Escríbeme lo que sientes...',
                        hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('😊', style: TextStyle(fontSize: 20)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _textController,
            builder: (_, __) {
              final hasText = _textController.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: () => _sendMessage(_textController.text),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: hasText && !_isAcomTyping
                          ? [const Color(0xFF1565C0), const Color(0xFF29B6F6)]
                          : [const Color(0xFFCFD8DC), const Color(0xFFECEFF1)],
                    ),
                    boxShadow: hasText && !_isAcomTyping
                        ? [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Icon(Icons.send_rounded,
                      color: hasText && !_isAcomTyping ? Colors.white : const Color(0xFF90A4AE), size: 20),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCFD8DC), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Opciones del chat',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(_usingGemini ? Icons.psychology_rounded : Icons.offline_bolt_rounded,
                      color: const Color(0xFF1976D2), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _usingGemini
                          ? 'ACOM te escucha · ${_apiHistory.length ~/ 2} mensajes en esta conversación'
                          : 'ACOM te escucha · Respuestas personalizadas',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _OptionTile(icon: Icons.refresh_rounded, label: 'Nueva conversación', color: const Color(0xFF1976D2),
                onTap: () { Navigator.pop(context); _clearConversation(); }),
            _OptionTile(icon: Icons.delete_outline_rounded, label: 'Borrar historial', color: const Color(0xFFEF5350),
                onTap: () { Navigator.pop(context); _clearConversation(); }),
            _OptionTile(icon: Icons.bookmark_outline_rounded, label: 'Guardar conversación', color: const Color(0xFF26A69A),
                onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final _Message message;
  final bool isFirst;
  const _MessageBubble({required this.message, required this.isFirst, super.key});
  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale, _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim    = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale   = Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack));
    _opacity = Tween(begin: 0.0,  end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _slide   = Tween(
      begin: Offset(widget.message.sender == _Sender.user ? 0.1 : -0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

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
            padding: EdgeInsets.only(bottom: 6, top: widget.isFirst ? 10 : 2),
            child: Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser && widget.isFirst) ...[
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                        boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.15), blurRadius: 8)]),
                    child: ClipOval(child: Padding(padding: const EdgeInsets.all(4),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain))),
                  ),
                  const SizedBox(width: 8),
                ] else if (!isUser) ...[
                  const SizedBox(width: 40),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isUser ? const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                          ) : null,
                          color: isUser ? null : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 20),
                          ),
                          boxShadow: [BoxShadow(
                            color: isUser ? const Color(0xFF1565C0).withOpacity(0.3) : const Color(0xFF1976D2).withOpacity(0.08),
                            blurRadius: 12, offset: const Offset(0, 4),
                          )],
                        ),
                        child: widget.message.isTyping
                            ? const _TypingDots()
                            : Text(widget.message.text,
                                style: TextStyle(fontSize: 15, height: 1.45,
                                    color: isUser ? Colors.white : const Color(0xFF1A237E))),
                      ),
                      if (!widget.message.isTyping)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                          child: Text(
                            '${widget.message.time.hour.toString().padLeft(2,'0')}:${widget.message.time.minute.toString().padLeft(2,'0')}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFFB0BEC5)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isUser) const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Typing Dots
// ─────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final bounce = math.sin((_ctrl.value - i * 0.15).clamp(0.0, 1.0) * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8, height: 8 + bounce * 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Color.lerp(const Color(0xFFBBDEFB), const Color(0xFF1976D2), bounce),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Option Tile
// ─────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label, required this.color, required this.onTap});

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
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}