import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ─────────────────────────────────────────────
// Modelos
// ─────────────────────────────────────────────
class _Question {
  final String text;
  final List<String> options;
  const _Question({required this.text, required this.options});
}

class _Test {
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final Color colorDark;
  final List<_Question> questions;
  final List<String> levelLabels;   // bajo, moderado, alto, muy alto
  final List<Color>  levelColors;
  final List<int>    thresholds;    // puntos de corte
  final List<String> levelMessages; // mensajes por nivel
  final bool higherIsBetter;        // WHO-5 y Rosenberg: más = mejor

  const _Test({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.colorDark,
    required this.questions,
    required this.levelLabels,
    required this.levelColors,
    required this.thresholds,
    required this.levelMessages,
    this.higherIsBetter = false,
  });

  int get maxScore => questions.length * (questions.first.options.length - 1);
}

class _TestResult {
  final String testId;
  final int score;
  final int level;
  final DateTime date;
  const _TestResult({required this.testId, required this.score, required this.level, required this.date});

  Map<String, dynamic> toJson() => {'testId': testId, 'score': score, 'level': level, 'date': date.toIso8601String()};
  factory _TestResult.fromJson(Map<String, dynamic> j) => _TestResult(
    testId: j['testId'], score: j['score'], level: j['level'], date: DateTime.parse(j['date']));
}

// ─────────────────────────────────────────────
// Tests clínicos validados
// ─────────────────────────────────────────────
const _tests = [
  _Test(
    id: 'gad7',
    emoji: '😟',
    title: 'Ansiedad',
    subtitle: 'GAD-7 · 7 preguntas · ~3 min',
    description: 'Escala validada para identificar síntomas de ansiedad generalizada en las últimas 2 semanas.',
    color: Color(0xFF1976D2),
    colorDark: Color(0xFF0D47A1),
    levelLabels: ['Mínima', 'Leve', 'Moderada', 'Severa'],
    levelColors: [Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFFFFA726), Color(0xFFEF5350)],
    thresholds: [5, 10, 15],
    levelMessages: [
      'Tus niveles de ansiedad son mínimos. ¡Sigue cuidándote!',
      'Experimentas algo de ansiedad. Técnicas de relajación pueden ayudarte.',
      'Tu ansiedad es moderada. Sería valioso conversar con un profesional.',
      'Tu ansiedad es significativa. Te recomendamos buscar apoyo profesional pronto.',
    ],
    questions: [
      _Question(text: 'Me he sentido nervioso/a, ansioso/a o muy alterado/a', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'No he podido dejar de preocuparme o no he podido controlar la preocupación', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'Me he preocupado demasiado por diferentes cosas', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'He tenido dificultad para relajarme', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'Me he sentido tan inquieto/a que no podía quedarme quieto/a', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'Me he irritado o enfadado fácilmente', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'He sentido miedo, como si algo terrible pudiera pasar', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
    ],
  ),
  _Test(
    id: 'phq9',
    emoji: '😔',
    title: 'Estado de ánimo',
    subtitle: 'PHQ-9 · 9 preguntas · ~4 min',
    description: 'Herramienta de autoconocimiento sobre el estado de ánimo en las últimas 2 semanas.',
    color: Color(0xFF5C6BC0),
    colorDark: Color(0xFF283593),
    levelLabels: ['Mínimo', 'Leve', 'Moderado', 'Severo'],
    levelColors: [Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFFFFA726), Color(0xFFEF5350)],
    thresholds: [5, 10, 15],
    levelMessages: [
      'Tu estado de ánimo se encuentra bien. ¡Sigue así!',
      'Hay algunos días difíciles. Hablar con alguien de confianza puede ayudar.',
      'Estás pasando por un período desafiante. Un profesional puede acompañarte.',
      'Es importante que busques apoyo profesional. No estás solo/a.',
    ],
    questions: [
      _Question(text: 'Poco interés o placer en hacer las cosas', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'Me he sentido decaído/a, deprimido/a o sin esperanza', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'He tenido problemas para dormir o dormir demasiado', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'Me he sentido cansado/a o con poca energía', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'He tenido poco apetito o comido en exceso', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'Me he sentido mal conmigo mismo/a', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'He tenido dificultad para concentrarme', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'Me he movido o hablado tan lento que otros lo notaron', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
      _Question(text: 'He tenido pensamientos de que estaría mejor muerto/a o de hacerme daño', options: ['Ningún día', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días']),
    ],
  ),
  _Test(
    id: 'pss',
    emoji: '😤',
    title: 'Nivel de estrés',
    subtitle: 'PSS · 10 preguntas · ~4 min',
    description: 'Escala de Estrés Percibido para evaluar cómo de estresante has percibido tu vida el último mes.',
    color: Color(0xFFE64A19),
    colorDark: Color(0xFFBF360C),
    levelLabels: ['Bajo', 'Moderado', 'Alto'],
    levelColors: [Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFFEF5350)],
    thresholds: [14, 27],
    levelMessages: [
      'Tu nivel de estrés es manejable. ¡Bien hecho!',
      'Tienes un estrés moderado. Incorporar pausas activas puede ayudarte.',
      'Tu nivel de estrés es elevado. Hablar con un profesional sería muy beneficioso.',
    ],
    questions: [
      _Question(text: 'Te has sentido afectado/a por algo inesperado', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Te has sentido incapaz de controlar las cosas importantes', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Te has sentido nervioso/a o estresado/a', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Has manejado exitosamente los problemas irritantes de la vida', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Has sentido que has afrontado efectivamente los cambios importantes', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Has confiado en tu capacidad para manejar problemas personales', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Has sentido que las cosas van bien', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Has sido incapaz de controlar las dificultades de tu vida', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Has podido controlar las dificultades de tu vida', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
      _Question(text: 'Has sentido que llevas el control de las cosas', options: ['Nunca', 'Casi nunca', 'A veces', 'Bastante a menudo', 'Muy a menudo']),
    ],
  ),
  _Test(
    id: 'who5',
    emoji: '🌟',
    title: 'Bienestar general',
    subtitle: 'WHO-5 · 5 preguntas · ~2 min',
    description: 'Índice de Bienestar de la OMS. Evalúa tu bienestar emocional en las últimas 2 semanas.',
    color: Color(0xFF388E3C),
    colorDark: Color(0xFF1B5E20),
    levelLabels: ['Bajo', 'Moderado', 'Bueno', 'Excelente'],
    levelColors: [Color(0xFFEF5350), Color(0xFFFFCA28), Color(0xFF66BB6A), Color(0xFF26A69A)],
    thresholds: [35, 50, 70],
    levelMessages: [
      'Tu bienestar está bajo. Es importante que busques apoyo.',
      'Tu bienestar es moderado. Pequeños hábitos pueden mejorarlo.',
      'Tu bienestar es bueno. ¡Sigue cultivando lo que funciona!',
      'Tu bienestar es excelente. ¡Eso es maravilloso!',
    ],
    higherIsBetter: true,
    questions: [
      _Question(text: 'Me he sentido alegre y de buen humor', options: ['En ningún momento', 'En algún momento', 'Menos de la mitad del tiempo', 'Más de la mitad del tiempo', 'La mayor parte del tiempo', 'Todo el tiempo']),
      _Question(text: 'Me he sentido tranquilo/a y relajado/a', options: ['En ningún momento', 'En algún momento', 'Menos de la mitad del tiempo', 'Más de la mitad del tiempo', 'La mayor parte del tiempo', 'Todo el tiempo']),
      _Question(text: 'Me he sentido activo/a y con vigor', options: ['En ningún momento', 'En algún momento', 'Menos de la mitad del tiempo', 'Más de la mitad del tiempo', 'La mayor parte del tiempo', 'Todo el tiempo']),
      _Question(text: 'Me he despertado sintiéndome fresco/a y descansado/a', options: ['En ningún momento', 'En algún momento', 'Menos de la mitad del tiempo', 'Más de la mitad del tiempo', 'La mayor parte del tiempo', 'Todo el tiempo']),
      _Question(text: 'Mi vida cotidiana ha estado llena de cosas que me interesan', options: ['En ningún momento', 'En algún momento', 'Menos de la mitad del tiempo', 'Más de la mitad del tiempo', 'La mayor parte del tiempo', 'Todo el tiempo']),
    ],
  ),
  _Test(
    id: 'sleep',
    emoji: '😴',
    title: 'Calidad del sueño',
    subtitle: '8 preguntas · ~3 min',
    description: 'Evaluación de la calidad y los patrones de sueño en la última semana.',
    color: Color(0xFF0097A7),
    colorDark: Color(0xFF006064),
    levelLabels: ['Buena', 'Regular', 'Mala'],
    levelColors: [Color(0xFF66BB6A), Color(0xFFFFCA28), Color(0xFFEF5350)],
    thresholds: [10, 18],
    levelMessages: [
      '¡Tu sueño es de buena calidad! Sigue con tus rutinas.',
      'Tu sueño tiene algunas áreas de mejora. Una rutina antes de dormir puede ayudar.',
      'Tu sueño está siendo afectado significativamente. Considera consultar a un especialista.',
    ],
    questions: [
      _Question(text: '¿Cuánto tiempo tardas en quedarte dormido/a?', options: ['Menos de 15 min', '15-30 min', '30-60 min', 'Más de 60 min']),
      _Question(text: '¿Con qué frecuencia te despiertas durante la noche?', options: ['Nunca', '1-2 veces', '3-4 veces', 'Más de 4 veces']),
      _Question(text: '¿Cómo calificarías la calidad de tu sueño en general?', options: ['Muy buena', 'Bastante buena', 'Bastante mala', 'Muy mala']),
      _Question(text: '¿Con qué frecuencia has tenido problemas para dormir?', options: ['Nunca', 'Menos de una vez/semana', '1-2 veces/semana', 'Más de 3 veces/semana']),
      _Question(text: '¿Has tomado medicamentos para dormir?', options: ['Nunca', 'Menos de una vez/semana', '1-2 veces/semana', 'Más de 3 veces/semana']),
      _Question(text: '¿Has tenido problemas para mantenerte despierto/a durante el día?', options: ['Nunca', 'Raramente', 'A veces', 'Frecuentemente']),
      _Question(text: '¿Qué tanto problema has tenido para mantener el entusiasmo?', options: ['Ninguno', 'Muy poco', 'Algo', 'Mucho']),
      _Question(text: '¿Cómo te has sentido al despertar?', options: ['Muy descansado/a', 'Algo descansado/a', 'Cansado/a', 'Muy cansado/a']),
    ],
  ),
  _Test(
    id: 'rosenberg',
    emoji: '💪',
    title: 'Autoestima',
    subtitle: 'Rosenberg · 10 preguntas · ~3 min',
    description: 'Escala de Autoestima de Rosenberg, una de las más utilizadas para medir la autoestima global.',
    color: Color(0xFF7B1FA2),
    colorDark: Color(0xFF4A148C),
    levelLabels: ['Baja', 'Media-baja', 'Media-alta', 'Alta'],
    levelColors: [Color(0xFFEF5350), Color(0xFFFFA726), Color(0xFF66BB6A), Color(0xFF26A69A)],
    thresholds: [15, 25, 30],
    levelMessages: [
      'Tu autoestima podría fortalecerse. Hablar con un profesional puede ser muy útil.',
      'Tu autoestima está en proceso. El autocuidado y el apoyo pueden ayudarte a crecer.',
      'Tienes una autoestima positiva. ¡Sigue cultivándola!',
      'Tu autoestima es sólida. ¡Es un gran activo para tu bienestar!',
    ],
    higherIsBetter: true,
    questions: [
      _Question(text: 'Siento que soy una persona digna de aprecio, al menos en igual medida que los demás', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'Estoy convencido/a de que tengo cualidades buenas', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'Soy capaz de hacer las cosas tan bien como la mayoría de la gente', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'Tengo una actitud positiva hacia mí mismo/a', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'En general, estoy satisfecho/a conmigo mismo/a', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'Siento que no tengo mucho de lo que estar orgulloso/a', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'En general, me inclino a pensar que soy un/a fracasado/a', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'Me gustaría poder sentir más respeto por mí mismo/a', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'A veces me siento verdaderamente inútil', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
      _Question(text: 'A veces creo que no soy buena persona', options: ['Muy en desacuerdo', 'En desacuerdo', 'De acuerdo', 'Muy de acuerdo']),
    ],
  ),
];

// ─────────────────────────────────────────────
// Storage
// ─────────────────────────────────────────────
class _AssessmentStorage {
  static const _key = 'acom_assessments';

  static Future<List<_TestResult>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_key);
    if (raw == null) return [];
    final list  = jsonDecode(raw) as List;
    return list.map((e) => _TestResult.fromJson(e)).toList();
  }

  static Future<void> save(List<_TestResult> results) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(results.map((r) => r.toJson()).toList()));
  }

  static Future<void> addResult(_TestResult result) async {
    final all = await load();
    all.add(result);
    await save(all);
  }

  static Future<_TestResult?> lastResult(String testId) async {
    final all = await load();
    final filtered = all.where((r) => r.testId == testId).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered.first;
  }
}

// ─────────────────────────────────────────────
// Assessment Screen (menú principal)
// ─────────────────────────────────────────────
class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen>
    with SingleTickerProviderStateMixin {

  final Map<String, _TestResult?> _lastResults = {};
  bool _isLoading = true;

  late AnimationController _entryCtrl;
  late Animation<double>   _entryFade;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entryFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _loadResults();
  }

  @override
  void dispose() { _entryCtrl.dispose(); super.dispose(); }

  Future<void> _loadResults() async {
    for (final t in _tests) {
      _lastResults[t.id] = await _AssessmentStorage.lastResult(t.id);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    _entryCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: FadeTransition(
                    opacity: _entryFade,
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      children: [
                        _buildDisclaimer(),
                        const SizedBox(height: 16),
                        ..._tests.map((t) => _TestCard(
                          test: t,
                          lastResult: _lastResults[t.id],
                          onTap: () => _startTest(t),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAB47BC)],
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
                    Text('Autoevaluaciones 🧠', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Herramientas de autoconocimiento', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('${_tests.length} tests', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Estas herramientas son para autoconocimiento únicamente. Los resultados NO son un diagnóstico clínico y no reemplazan la evaluación de un profesional de salud mental.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startTest(_Test test) async {
    final result = await Navigator.push<_TestResult>(
      context,
      MaterialPageRoute(builder: (_) => _TestScreen(test: test)),
    );
    if (result != null) {
      await _AssessmentStorage.addResult(result);
      setState(() => _lastResults[test.id] = result);
    }
  }
}

// ─────────────────────────────────────────────
// Test Card
// ─────────────────────────────────────────────
class _TestCard extends StatelessWidget {
  final _Test test;
  final _TestResult? lastResult;
  final VoidCallback onTap;
  const _TestCard({required this.test, required this.lastResult, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasResult = lastResult != null;
    final levelColor = hasResult ? test.levelColors[lastResult!.level] : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: hasResult ? Border.all(color: levelColor!.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [BoxShadow(color: test.color.withOpacity(0.10), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(height: 4, decoration: BoxDecoration(
              color: hasResult ? levelColor : test.color.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            )),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: test.color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(test.emoji, style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(test.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                        Text(test.subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE))),
                        if (hasResult) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: levelColor!.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              '${test.levelLabels[lastResult!.level]} · ${_formatDate(lastResult!.date)}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: levelColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: test.color, size: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ─────────────────────────────────────────────
// Test Screen (preguntas)
// ─────────────────────────────────────────────
class _TestScreen extends StatefulWidget {
  final _Test test;
  const _TestScreen({required this.test, super.key});

  @override
  State<_TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<_TestScreen> with SingleTickerProviderStateMixin {
  int _currentQ   = 0;
  final List<int> _answers = [];
  bool _showResult = false;
  late int _score;
  late int _level;

  late AnimationController _qAnim;
  late Animation<double>   _qFade;
  late Animation<Offset>   _qSlide;

  @override
  void initState() {
    super.initState();
    _qAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _qFade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _qAnim, curve: Curves.easeOut));
    _qSlide = Tween(begin: const Offset(0.1, 0), end: Offset.zero).animate(CurvedAnimation(parent: _qAnim, curve: Curves.easeOutCubic));
    _qAnim.forward();
  }

  @override
  void dispose() { _qAnim.dispose(); super.dispose(); }

  void _answer(int value) async {
    HapticFeedback.lightImpact();
    _answers.add(value);

    if (_currentQ < widget.test.questions.length - 1) {
      await _qAnim.reverse();
      setState(() => _currentQ++);
      _qAnim.forward();
    } else {
      _calculateResult();
    }
  }

  void _calculateResult() {
    _score = _answers.fold(0, (sum, v) => sum + v);

    // Normalizar WHO-5 a porcentaje (0-100)
    if (widget.test.id == 'who5') _score = (_score * 4);

    // Calcular nivel
    _level = 0;
    for (int i = 0; i < widget.test.thresholds.length; i++) {
      if (widget.test.higherIsBetter) {
        if (_score >= widget.test.thresholds[i]) _level = i + 1;
      } else {
        if (_score >= widget.test.thresholds[i]) _level = i + 1;
      }
    }
    if (_level >= widget.test.levelLabels.length) _level = widget.test.levelLabels.length - 1;

    setState(() => _showResult = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F6FF),
      body: _showResult ? _buildResult() : _buildQuestion(),
    );
  }

  // ── Pregunta ──────────────────────────────
  Widget _buildQuestion() {
    final q    = widget.test.questions[_currentQ];
    final prog = (_currentQ + 1) / widget.test.questions.length;

    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.test.colorDark, widget.test.color],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(width: 40, height: 40,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.test.emoji} ${widget.test.title}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('Pregunta ${_currentQ + 1} de ${widget.test.questions.length}',
                                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      ),
                      Text('${(_currentQ + 1)}/${widget.test.questions.length}',
                          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: prog,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Pregunta + opciones
        Expanded(
          child: FadeTransition(
            opacity: _qFade,
            child: SlideTransition(
              position: _qSlide,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Durante las últimas 2 semanas...',
                        style: TextStyle(fontSize: 12, color: Color(0xFF90A4AE), fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    Text(q.text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1), height: 1.3)),
                    const SizedBox(height: 28),
                    ...q.options.asMap().entries.map((e) {
                      return GestureDetector(
                        onTap: () => _answer(e.key),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: widget.test.color.withOpacity(0.2)),
                            boxShadow: [BoxShadow(color: widget.test.color.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.test.color.withOpacity(0.10)),
                                child: Center(child: Text('${e.key}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.test.color))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14, color: Color(0xFF37474F), height: 1.3))),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.test.color.withOpacity(0.5)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Resultado ─────────────────────────────
  Widget _buildResult() {
    final test    = widget.test;
    final color   = test.levelColors[_level];
    final label   = test.levelLabels[_level];
    final message = test.levelMessages[_level];
    final pct     = test.id == 'who5' ? _score : (_score / test.maxScore * 100).toInt();
    final needsHelp = _level >= test.levelLabels.length - 1;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [test.colorDark, test.color], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final result = _TestResult(testId: test.id, score: _score, level: _level, date: DateTime.now());
                      Navigator.pop(context, result);
                    },
                    child: Container(width: 40, height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)),
                  ),
                  const SizedBox(width: 12),
                  Text('${test.emoji} Resultado · ${test.title}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Score circle
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.12),
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$pct${test.id == 'who5' ? '' : ''}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: color)),
                      Text(test.id == 'who5' ? 'puntos' : 'pts', style: TextStyle(fontSize: 12, color: color.withOpacity(0.7))),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(label, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                  child: Text(message, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: color, height: 1.5, fontWeight: FontWeight.w500)),
                ),

                const SizedBox(height: 20),

                // Niveles
                _buildLevelBar(test, _level),

                const SizedBox(height: 20),

                // Referral si nivel alto
                if (needsHelp || _level >= test.levelLabels.length - 2)
                  _buildReferral(test, _level),

                const SizedBox(height: 16),

                // Botón guardar y salir
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final result = _TestResult(testId: test.id, score: _score, level: _level, date: DateTime.now());
                      Navigator.pop(context, result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: test.color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Guardar resultado', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: () {
                    setState(() { _currentQ = 0; _answers.clear(); _showResult = false; });
                    _qAnim.forward(from: 0);
                  },
                  child: Text('Repetir test', style: TextStyle(color: test.color, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBar(_Test test, int currentLevel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Escala de referencia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
          const SizedBox(height: 12),
          Row(
            children: List.generate(test.levelLabels.length, (i) {
              final isActive = i == currentLevel;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? test.levelColors[i] : test.levelColors[i].withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(test.levelLabels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                              color: isActive ? test.levelColors[i] : const Color(0xFFB0BEC5))),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReferral(_Test test, int level) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('💙', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Apoyo profesional', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
          const SizedBox(height: 10),
          Text(
            level >= test.levelLabels.length - 1
                ? 'Tus resultados sugieren que podrías beneficiarte significativamente de apoyo profesional. No estás solo/a.'
                : 'Hablar con un profesional de salud mental puede ser muy valioso en este momento.',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85), height: 1.4),
          ),
          const SizedBox(height: 14),

          // Línea de crisis
          _ReferralBtn(icon: '🆘', label: 'Línea de crisis', sublabel: 'Colombia: 106 · México: 800-290-0024', color: const Color(0xFFEF5350)),
          const SizedBox(height: 8),
          _ReferralBtn(icon: '👨‍⚕️', label: 'Buscar psicólogo', sublabel: 'Directorio de profesionales en tu área', color: const Color(0xFF26A69A)),
          const SizedBox(height: 8),
          _ReferralBtn(icon: '📋', label: 'Compartir resultados', sublabel: 'Muestra este resultado a tu profesional', color: const Color(0xFF7B1FA2)),
        ],
      ),
    );
  }
}

class _ReferralBtn extends StatelessWidget {
  final String icon, label, sublabel;
  final Color color;
  const _ReferralBtn({required this.icon, required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(sublabel, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
        ],
      ),
    );
  }
}