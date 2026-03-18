import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ─────────────────────────────────────────────
// Modelo de entrada
// ─────────────────────────────────────────────
class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final int moodIndex;
  final DateTime date;

  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.moodIndex,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'moodIndex': moodIndex,
    'date': date.toIso8601String(),
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
    id: j['id'],
    title: j['title'],
    content: j['content'],
    moodIndex: j['moodIndex'],
    date: DateTime.parse(j['date']),
  );

  DiaryEntry copyWith({String? title, String? content, int? moodIndex}) =>
      DiaryEntry(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        moodIndex: moodIndex ?? this.moodIndex,
        date: date,
      );
}

// ─────────────────────────────────────────────
// Datos de moods
// ─────────────────────────────────────────────
const _moodEmojis  = ['😊', '😌', '😐', '😟', '😔'];
const _moodLabels  = ['Genial', 'Tranquilo', 'Neutral', 'Ansioso', 'Triste'];
const _moodColors  = [
  Color(0xFF66BB6A),
  Color(0xFF29B6F6),
  Color(0xFFFFCA28),
  Color(0xFFFFA726),
  Color(0xFFEF5350),
];

// ─────────────────────────────────────────────
// Local storage helper
// ─────────────────────────────────────────────
class _DiaryStorage {
  static const _key = 'acom_diary_entries';

  static Future<List<DiaryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => DiaryEntry.fromJson(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> save(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}

// ─────────────────────────────────────────────
// Diary Screen
// ─────────────────────────────────────────────
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> with TickerProviderStateMixin {

  List<DiaryEntry> _entries    = [];
  List<DiaryEntry> _filtered   = [];
  bool _isLoading              = true;
  bool _calendarView           = false;
  String _searchQuery          = '';
  DateTime _calendarMonth      = DateTime.now();
  DateTime? _selectedDay;

  final _searchCtrl = TextEditingController();

  late AnimationController _entryAnim;
  late Animation<double>   _entryFade;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _entryFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut));
    _loadEntries();
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final entries = await _DiaryStorage.load();
    if (!mounted) return;
    setState(() {
      _entries  = entries;
      _filtered = entries;
      _isLoading = false;
    });
    _entryAnim.forward();
  }

  void _applySearch(String q) {
    setState(() {
      _searchQuery = q;
      _filtered = q.isEmpty
          ? _entries
          : _entries.where((e) =>
              e.title.toLowerCase().contains(q.toLowerCase()) ||
              e.content.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  // ─────────────────────────────────────────────
  // CRUD
  // ─────────────────────────────────────────────
  Future<void> _createEntry() async {
    final result = await Navigator.push<DiaryEntry>(
      context,
      MaterialPageRoute(builder: (_) => const _EntryEditorScreen()),
    );
    if (result == null) return;
    setState(() {
      _entries.insert(0, result);
      _filtered = _searchQuery.isEmpty
          ? _entries
          : _entries.where((e) =>
              e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              e.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    });
    await _DiaryStorage.save(_entries);
    HapticFeedback.mediumImpact();
  }

  Future<void> _editEntry(DiaryEntry entry) async {
    final result = await Navigator.push<DiaryEntry>(
      context,
      MaterialPageRoute(builder: (_) => _EntryEditorScreen(entry: entry)),
    );
    if (result == null) return;
    setState(() {
      final idx = _entries.indexWhere((e) => e.id == result.id);
      if (idx != -1) _entries[idx] = result;
      _applySearch(_searchQuery);
    });
    await _DiaryStorage.save(_entries);
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar entrada?',
            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
      _applySearch(_searchQuery);
    });
    await _DiaryStorage.save(_entries);
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
        body: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildViewToggle(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
                  : FadeTransition(
                      opacity: _entryFade,
                      child: _calendarView ? _buildCalendarView() : _buildListView(),
                    ),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(),
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
          colors: [Color(0xFFF57C00), Color(0xFFFF9800), Color(0xFFFFB74D)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mi Diario 📓',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('Tus pensamientos, siempre contigo',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              // Contador
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_entries.length} entradas',
                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Search bar
  // ─────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF57C00).withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _applySearch,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0D47A1)),
          decoration: InputDecoration(
            hintText: 'Buscar en tu diario...',
            hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFF57C00), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      _applySearch('');
                    },
                    child: const Icon(Icons.close_rounded, color: Color(0xFFB0BEC5), size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // View toggle
  // ─────────────────────────────────────────────
  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _ToggleBtn(
              icon: Icons.list_rounded,
              label: 'Lista',
              active: !_calendarView,
              onTap: () => setState(() => _calendarView = false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ToggleBtn(
              icon: Icons.calendar_month_rounded,
              label: 'Calendario',
              active: _calendarView,
              onTap: () => setState(() => _calendarView = true),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Lista de entradas
  // ─────────────────────────────────────────────
  Widget _buildListView() {
    if (_filtered.isEmpty) return _buildEmptyState();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _EntryCard(
        entry: _filtered[i],
        onTap: () => _editEntry(_filtered[i]),
        onDelete: () => _deleteEntry(_filtered[i]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Calendario
  // ─────────────────────────────────────────────
  Widget _buildCalendarView() {
    return Column(
      children: [
        _buildCalendarHeader(),
        _buildCalendarGrid(),
        const Divider(height: 1, color: Color(0xFFE3F2FD)),
        Expanded(child: _buildDayEntries()),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => setState(() =>
                _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1)),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: const Icon(Icons.chevron_left_rounded, color: Color(0xFFF57C00)),
            ),
          ),
          Text(
            _monthName(_calendarMonth),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1)),
          ),
          GestureDetector(
            onTap: () => setState(() =>
                _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1)),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Color(0xFFF57C00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Dom

    final entryDays = <int, int>{};
    for (final e in _entries) {
      if (e.date.year == _calendarMonth.year && e.date.month == _calendarMonth.month) {
        entryDays[e.date.day] = e.moodIndex;
      }
    }

    final days = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Días de la semana
          Row(
            children: days.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF90A4AE),
                    )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Grilla
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startWeekday) return const SizedBox.shrink();
              final day = i - startWeekday + 1;
              final isToday = today.year == _calendarMonth.year &&
                  today.month == _calendarMonth.month &&
                  today.day == day;
              final isSelected = _selectedDay?.year == _calendarMonth.year &&
                  _selectedDay?.month == _calendarMonth.month &&
                  _selectedDay?.day == day;
              final moodIdx = entryDays[day];

              return GestureDetector(
                onTap: () => setState(() =>
                    _selectedDay = DateTime(_calendarMonth.year, _calendarMonth.month, day)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFFF57C00)
                        : isToday
                            ? const Color(0xFFFFF3E0)
                            : moodIdx != null
                                ? _moodColors[moodIdx].withOpacity(0.15)
                                : Colors.transparent,
                    border: isToday && !isSelected
                        ? Border.all(color: const Color(0xFFF57C00), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: moodIdx != null && !isSelected
                        ? Text(_moodEmojis[moodIdx], style: const TextStyle(fontSize: 14))
                        : Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : isToday
                                      ? const Color(0xFFF57C00)
                                      : const Color(0xFF37474F),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayEntries() {
    final day = _selectedDay;
    if (day == null) {
      return const Center(
        child: Text('Toca un día para ver sus entradas',
            style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
      );
    }

    final dayEntries = _entries.where((e) =>
        e.date.year == day.year &&
        e.date.month == day.month &&
        e.date.day == day.day).toList();

    if (dayEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              'Sin entradas el ${day.day}/${day.month}',
              style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: dayEntries.map((e) => _EntryCard(
        entry: e,
        onTap: () => _editEntry(e),
        onDelete: () => _deleteEntry(e),
      )).toList(),
    );
  }

  // ─────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📓', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Tu diario está vacío',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron entradas para "$_searchQuery"'
                : 'Toca el botón + para escribir tu primera entrada',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF90A4AE)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────
  Widget _buildFAB() {
    return GestureDetector(
      onTap: _createEntry,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFF57C00), Color(0xFFFFB74D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF57C00).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  String _monthName(DateTime d) {
    const months = ['Enero','Febrero','Marzo','Abril','Mayo','Junio',
        'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────────────────────
// Entry Card
// ─────────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _EntryCard({required this.entry, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final mood  = _moodColors[entry.moodIndex];
    final emoji = _moodEmojis[entry.moodIndex];
    final label = _moodLabels[entry.moodIndex];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: mood.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color bar top
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [mood, mood.withOpacity(0.4)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Mood badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: mood.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: mood)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Fecha
                      Text(
                        _formatDate(entry.date),
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
                      ),
                      const SizedBox(width: 8),
                      // Eliminar
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFEF5350), size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF607D8B), height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 13, color: Color(0xFFB0BEC5)),
                      const SizedBox(width: 4),
                      const Text('Toca para editar',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB0BEC5))),
                      const Spacer(),
                      Text(
                        _formatTime(entry.date),
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['ene','feb','mar','abr','may','jun',
        'jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
// Toggle button
// ─────────────────────────────────────────────
class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF57C00) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF57C00).withOpacity(active ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : const Color(0xFF90A4AE)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF90A4AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Entry Editor Screen (crear / editar)
// ─────────────────────────────────────────────
class _EntryEditorScreen extends StatefulWidget {
  final DiaryEntry? entry;
  const _EntryEditorScreen({this.entry});

  @override
  State<_EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends State<_EntryEditorScreen> {
  final _titleCtrl   = TextEditingController();
  final _contentCtrl = TextEditingController();
  int _selectedMood  = 0;
  bool _hasChanges   = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleCtrl.text   = widget.entry!.title;
      _contentCtrl.text = widget.entry!.content;
      _selectedMood     = widget.entry!.moodIndex;
    }
    _titleCtrl.addListener(() => setState(() => _hasChanges = true));
    _contentCtrl.addListener(() => setState(() => _hasChanges = true));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title   = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor completa el título y el contenido'),
          backgroundColor: const Color(0xFFF57C00),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final entry = _isEditing
        ? widget.entry!.copyWith(title: title, content: content, moodIndex: _selectedMood)
        : DiaryEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            content: content,
            moodIndex: _selectedMood,
            date: DateTime.now(),
          );

    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final mood = _moodColors[_selectedMood];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F6FF),
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [mood.withOpacity(0.9), mood],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEditing ? 'Editar entrada' : 'Nueva entrada 📝',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      // Guardar
                      GestureDetector(
                        onTap: _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            'Guardar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: mood,
                            ),
                          ),
                        ),
                      ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fecha
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 14, color: Color(0xFFF57C00)),
                          const SizedBox(width: 6),
                          Text(
                            _formatFullDate(widget.entry?.date ?? DateTime.now()),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF607D8B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Mood selector
                    const Text('¿Cómo te sientes?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(5, (i) {
                        final sel = _selectedMood == i;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedMood = i);
                            HapticFeedback.lightImpact();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: sel ? _moodColors[i].withOpacity(0.15) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel ? _moodColors[i] : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(_moodEmojis[i],
                                    style: TextStyle(fontSize: sel ? 28 : 24)),
                                const SizedBox(height: 3),
                                Text(_moodLabels[i],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                      color: sel ? _moodColors[i] : const Color(0xFF90A4AE),
                                    )),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // Título
                    const Text('Título',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFE0B2), width: 1.5),
                      ),
                      child: TextField(
                        controller: _titleCtrl,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: 'Ej: Un día especial...',
                          hintStyle: TextStyle(color: Color(0xFFB0BEC5)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contenido
                    const Text('¿Qué tienes en mente?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFE0B2), width: 1.5),
                      ),
                      child: TextField(
                        controller: _contentCtrl,
                        maxLines: 10,
                        minLines: 6,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF37474F), height: 1.6),
                        decoration: const InputDecoration(
                          hintText: 'Escribe libremente... Este es tu espacio seguro 💙',
                          hintStyle: TextStyle(color: Color(0xFFB0BEC5)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(DateTime d) {
    const days   = ['lunes','martes','miércoles','jueves','viernes','sábado','domingo'];
    const months = ['enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${days[d.weekday - 1]}, ${d.day} de ${months[d.month - 1]} de ${d.year}';
  }
}