import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/ble_command_service.dart';
import '../audio_service.dart';
import '../eduplay_constants.dart';
import '../eduplay_engine_holder.dart';
import '../feature_builder.dart';
import '../task_repository.dart';
import 'session_result_screen.dart';

// ── Palette — matches Pronunciation/Home screen exactly (see spec) ──────
const _kPrimary = Color(0xFF2ECC71);
const _kBg = Color(0xFFFAFAF7);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kDisabledBg = Color(0xFFE5E7EB);
const _kDisabledText = Color(0xFF9CA3AF);
// Feedback overlay — wrong state uses amber, never red, per spec.
const _kCorrectIcon = Color(0xFF2ECC71);
const _kCorrectBg = Color(0xFFF0FDF4);
const _kWrongIcon = Color(0xFFF59E0B);
const _kWrongBg = Color(0xFFFFFBEB);
// Hint card / drop-slot / tile colours.
const _kHintBg = Color(0xFFFFF7ED);
const _kHintBorder = Color(0xFFF59E0B);
const _kHintText = Color(0xFF92400E);
const _kSlotFilledBg = Color(0xFFE8F8F0);
const _kSlotEmptyText = Color(0xFF9CA3AF);
const _kTileBorder = Color(0xFFE5E7EB);
const _kTileDraggingBg = Color(0xFFF0FDF4);
const _kDropTargetHover = Color(0xFFD1FAE5);

/// Route: '/eduplay/activity'. Args: {childId, activityType, level, grade,
/// language}. Handles all 5 activity types by switching on activityType.
class ActivityScreen extends StatefulWidget {
  final String childId;
  final String activityType;
  final String level;
  final String grade;
  final String language;

  const ActivityScreen({
    super.key,
    required this.childId,
    required this.activityType,
    required this.level,
    required this.grade,
    required this.language,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late List<Map<String, dynamic>> _tasks;
  int _currentIndex = 0;
  int _attemptCountThisTask = 0;

  // Session-cumulative — these feed EduPlaySessionResult at the end.
  int _totalAttempts = 0;
  int _hintsUsed = 0;
  int _audioReplayCount = 0;
  int _mistakeCount = 0;
  String _sessionMistakeType = 'none';
  late DateTime _sessionStartTime;
  int _correctCount = 0;

  String? _selectedAnswer;
  List<String?> _droppedItems = [];
  List<String> _bank = [];

  bool _showFeedback = false;
  bool _isCorrect = false;
  final Set<int> _autoPlayed = {};

  // Pre-submission hint — one per task, from the static word-hint maps
  // below (not the old per-activity-type freeform hint text).
  String? _hintText;
  bool _hintUsed = false;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _tasks = TaskRepository.instance.getTasksFor(
      activityType: widget.activityType,
      grade: widget.grade,
      language: widget.language,
      level: widget.level,
      childId: widget.childId,
    );
    _resetTaskState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlayAudio());
  }

  @override
  void dispose() {
    EduPlayAudioService.instance.stop();
    super.dispose();
  }

  Map<String, dynamic> get _task => _tasks[_currentIndex];

  void _resetTaskState() {
    _attemptCountThisTask = 0;
    _selectedAnswer = null;
    _showFeedback = false;
    // Reset on each NEW task only — not on retry (one hint per task,
    // even across retries of the same task).
    _hintText = null;
    _hintUsed = false;

    if (widget.activityType == 'letter_drag_drop' || widget.activityType == 'sentence_drag_drop') {
      final correctOrder = _stringList(_task['correct_order']);
      _droppedItems = List<String?>.filled(correctOrder.length, null);
      final items = [..._stringList(_task['tile_items'] ?? _task['scrambled_items']), ..._stringList(_task['decoy_items'])];
      items.shuffle();
      _bank = items;
    } else {
      _droppedItems = [];
      _bank = [];
    }
  }

  List<String> _stringList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((e) => e.toString()).toList();
  }

  void _autoPlayAudio() {
    if (_autoPlayed.contains(_currentIndex)) return;
    _autoPlayed.add(_currentIndex);
    final path = _task['audio_available'] == true ? _task['audio_path'] as String? : null;
    EduPlayAudioService.instance.playTask(path);
  }

  void _replayAudio() {
    final path = _task['audio_available'] == true ? _task['audio_path'] as String? : null;
    if (path == null) return;
    setState(() => _audioReplayCount++);
    EduPlayAudioService.instance.playTask(path);
  }

  void _onHintTap() {
    if (_hintUsed) return; // only one hint per task
    setState(() {
      _hintText = _getHint(_task);
      _hintUsed = true;
      _hintsUsed++;
    });
  }

  String? _getHint(Map<String, dynamic> task) {
    final lang = task['language'] as String? ?? 'English';
    final text = (task['target_text'] as String? ?? '').toLowerCase().trim();
    if (lang == 'English') return _enHints[text];
    return _siHints[text];
  }

  @override
  Widget build(BuildContext context) {
    if (_tasks.isEmpty) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: _kTextPrimary)),
        body: Center(
          child: Text('No tasks available for this level yet.',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: _kTextSecondary)),
        ),
      );
    }

    final audioAvailable = _task['audio_available'] == true;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: Text(
          kActivityDisplayNames[widget.activityType] ?? widget.activityType,
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text('${_currentIndex + 1} / ${_tasks.length}',
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: _kTextSecondary)),
            ),
          ),
          Tooltip(
            message: audioAvailable ? 'Play audio' : 'Audio not available for this item',
            child: IconButton(
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(Icons.volume_up_rounded, color: audioAvailable ? _kPrimary : const Color(0xFFCCCCCC)),
              onPressed: audioAvailable ? _replayAudio : null,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: _currentIndex / _tasks.length,
            minHeight: 6,
            backgroundColor: _kBorder,
            color: _kPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildActivityBody()),
                if (_hintText != null) _buildHintCard(),
                _buildActionRow(),
              ],
            ),
            if (_showFeedback) _buildFeedbackOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Activity bodies ─────────────────────────────────────────────────
  // Each returns content only — no Submit/Clear/Hint buttons, those are
  // shared across all 5 types in _buildActionRow below.

  Widget _buildActivityBody() {
    switch (widget.activityType) {
      case 'letter_drag_drop':
        return _buildDragDrop(isLetters: true);
      case 'sentence_drag_drop':
        return _buildDragDrop(isLetters: false);
      case 'word_recognition':
        return _buildWordRecognition();
      case 'fill_blanks_word':
        return _buildFillBlanks();
      case 'sentence_quiz':
        return _buildSentenceQuiz();
      default:
        return const SizedBox.shrink();
    }
  }

  bool get _canSubmit {
    if (widget.activityType == 'letter_drag_drop' || widget.activityType == 'sentence_drag_drop') {
      return _droppedItems.isNotEmpty && _droppedItems.every((e) => e != null);
    }
    return _selectedAnswer != null;
  }

  void _onSubmit() {
    if (widget.activityType == 'letter_drag_drop' || widget.activityType == 'sentence_drag_drop') {
      _submit(_droppedItems.map((e) => e!).toList());
    } else {
      _submit([_selectedAnswer!]);
    }
  }

  Widget _buildDragDrop({required bool isLetters}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_task['prompt_text'] as String? ?? 'Put them in order',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: _kTextSecondary)),
        ),
        Expanded(
          flex: 2,
          child: Center(child: _buildDropSlots(isLetters: isLetters)),
        ),
        const Divider(color: _kBorder, height: 1),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [for (final item in _bank) _draggableTile(item)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropSlots({required bool isLetters}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _droppedItems.length; i++)
          DragTarget<String>(
            onAcceptWithDetails: (details) => _onDropInto(i, details.data),
            builder: (context, candidate, rejected) {
              final filled = _droppedItems[i] != null;
              final hovering = candidate.isNotEmpty;
              return Container(
                width: isLetters ? 52 : null,
                constraints: isLetters ? null : const BoxConstraints(minWidth: 70),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovering ? _kDropTargetHover : (filled ? _kSlotFilledBg : Colors.white),
                  border: Border.all(color: _kPrimary, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _droppedItems[i] ?? '—',
                  style: filled
                      ? GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kPrimary)
                      : GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w400, letterSpacing: 0.3, color: _kSlotEmptyText),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _draggableTile(String item) {
    return Draggable<String>(
      data: item,
      feedback: _tile(item, dragging: true),
      childWhenDragging: Opacity(opacity: 0.3, child: _tile(item)),
      child: _tile(item),
    );
  }

  Widget _tile(String text, {bool dragging = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dragging ? _kTileDraggingBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kTileBorder, width: 1.5),
        boxShadow: dragging ? const [BoxShadow(color: Color(0x33000000), blurRadius: 8)] : null,
      ),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary)),
    );
  }

  void _onDropInto(int slotIndex, String item) {
    setState(() {
      _bank.remove(item);
      final existing = _droppedItems[slotIndex];
      if (existing != null) _bank.add(existing);
      _droppedItems[slotIndex] = item;
    });
  }

  void _clearDrops() {
    setState(() {
      _bank.addAll(_droppedItems.whereType<String>());
      _droppedItems = List<String?>.filled(_droppedItems.length, null);
    });
  }

  Widget _buildWordRecognition() {
    final options = _stringList(_task['options']);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(_task['prompt_text'] as String? ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary)),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.8,
            children: [for (final option in options) _optionButton(option)],
          ),
        ],
      ),
    );
  }

  Widget _buildFillBlanks() {
    final options = _stringList(_task['options']);
    final blankText = _task['blank_text'] as String? ?? '';
    final display = _selectedAnswer == null ? blankText : blankText.replaceFirst('_', _selectedAnswer!);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _kBorder),
            ),
            child: Text(display,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary)),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [for (final option in options) _optionButton(option)],
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceQuiz() {
    final options = _stringList(_task['options']);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(_task['target_text'] as String? ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary)),
          ),
          const SizedBox(height: 16),
          Text(_task['question_text'] as String? ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 0.3, color: _kTextSecondary)),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [for (final option in options) _optionButton(option)],
          ),
        ],
      ),
    );
  }

  Widget _optionButton(String option) {
    final selected = _selectedAnswer == option;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Material(
        color: selected ? _kPrimary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedAnswer = selected ? null : option),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? _kPrimary : const Color(0xFFE0E0E0), width: 2),
            ),
            child: Text(
              option,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: selected ? Colors.white : _kTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared hint card + action row (all 5 activity types) ────────────

  Widget _buildHintCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kHintBg,
        border: Border.all(color: _kHintBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: _kHintBorder, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_hintText!,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.3, color: _kHintText)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    final isDragDrop = widget.activityType == 'letter_drag_drop' || widget.activityType == 'sentence_drag_drop';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _hintUsed ? null : _onHintTap,
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text(_hintUsed ? 'Hint used' : 'Hint',
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kHintBorder,
              side: BorderSide(color: _hintUsed ? _kBorder : _kHintBorder),
              disabledForegroundColor: _kDisabledText,
              minimumSize: const Size(90, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(width: 8),
          if (isDragDrop) ...[
            OutlinedButton(
              onPressed: _clearDrops,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kTextSecondary,
                side: const BorderSide(color: _kBorder),
                minimumSize: const Size(80, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Clear', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: _canSubmit ? _onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kDisabledBg,
                disabledForegroundColor: _kDisabledText,
                elevation: 0,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Submit', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Validation ──────────────────────────────────────────────────────

  void _submit(List<String> answer) {
    _attemptCountThisTask++;
    _totalAttempts++;

    bool correct;
    String mistakeType;

    switch (widget.activityType) {
      case 'letter_drag_drop':
        correct = _listEquals(answer, _stringList(_task['correct_order']));
        mistakeType = 'letter_order_error';
        break;
      case 'sentence_drag_drop':
        correct = _listEquals(answer, _stringList(_task['correct_order']));
        mistakeType = 'sentence_order_error';
        break;
      case 'word_recognition':
        correct = answer.first == _task['correct_answer'];
        mistakeType = 'sound_confusion';
        break;
      case 'fill_blanks_word':
        correct = answer.first == _task['correct_answer'];
        mistakeType = 'missing_letter';
        break;
      case 'sentence_quiz':
        correct = answer.first == _task['correct_answer'];
        mistakeType = 'meaning_error';
        break;
      default:
        correct = false;
        mistakeType = 'none';
    }

    if (correct) {
      _correctCount++;
    } else {
      _mistakeCount++;
      _sessionMistakeType = mistakeType;
    }

    final task = _task;
    BleCommandService.instance.send(
      correct ? (task['buddy_positive'] as String? ?? '') : (task['buddy_corrective'] as String? ?? ''),
    );

    setState(() {
      _isCorrect = correct;
      _showFeedback = true;
    });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── Feedback overlay ─────────────────────────────────────────────────

  Widget _buildFeedbackOverlay() {
    final task = _task;
    final canSkip = _attemptCountThisTask >= 3;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _isCorrect ? _kCorrectBg : _kWrongBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCorrect ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: _isCorrect ? _kCorrectIcon : _kWrongIcon,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isCorrect ? 'Well done!' : 'Try again!',
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  (_isCorrect ? task['buddy_positive'] : task['buddy_corrective']) as String? ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w400, letterSpacing: 0.3, color: _kTextPrimary),
                ),
                if (_isCorrect) ...[
                  const SizedBox(height: 10),
                  Text('+10 XP',
                      style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kPrimary)),
                ],
                const SizedBox(height: 20),
                if (_isCorrect)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _advance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text('Next', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _retry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kWrongIcon,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: Text('Try Again', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                          ),
                        ),
                      ),
                      if (canSkip) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _advance,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                side: const BorderSide(color: _kTextSecondary),
                              ),
                              child: Text('Skip', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _showFeedback = false;
      _selectedAnswer = null;
      if (widget.activityType == 'letter_drag_drop' || widget.activityType == 'sentence_drag_drop') {
        _bank.addAll(_droppedItems.whereType<String>());
        _droppedItems = List<String?>.filled(_droppedItems.length, null);
      }
    });
  }

  void _advance() {
    if (_currentIndex < _tasks.length - 1) {
      setState(() {
        _currentIndex++;
        _resetTaskState();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlayAudio());
    } else {
      _finishSession();
    }
  }

  void _finishSession() {
    final elapsedSec = DateTime.now().difference(_sessionStartTime).inSeconds.toDouble();
    final accuracyPct = _tasks.isEmpty ? 0.0 : (_correctCount / _tasks.length) * 100.0;

    final result = EduPlaySessionResult(
      sessionId: DateTime.now().microsecondsSinceEpoch.toString(),
      childId: widget.childId,
      taskId: _task['task_id'] as String,
      activityType: widget.activityType,
      language: widget.language,
      grade: widget.grade,
      level: widget.level,
      accuracyPct: accuracyPct,
      timeSpentSec: elapsedSec,
      attemptCount: _totalAttempts,
      hintsUsed: _hintsUsed,
      audioReplayCount: _audioReplayCount,
      mistakeCount: _mistakeCount,
      mistakeType: _sessionMistakeType,
      isCorrect: _mistakeCount == 0,
    );

    // Most-recently-practiced task stands in for "this session's task" —
    // the engine's onSessionComplete(result, task) signature takes one
    // task map, but a session spans several; the spec doesn't say which,
    // so using the last one practiced (most representative of what the
    // recommendation should react to).
    EduPlayEngineHolder.instance.onSessionComplete(result, _task);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SessionResultScreen(result: result)),
    );
  }

  static const Map<String, String> _enHints = {
    'animal': 'A living creature that moves and breathes',
    'apple': 'A round fruit — red or green',
    'beach': 'Sandy place next to the ocean',
    'beautiful': 'Something that looks very nice',
    'bread': 'Soft baked food made from flour',
    'bright': 'Full of light',
    'brother': 'A boy who is part of your family',
    'butterfly': 'An insect with colourful wings that flies',
    'cat': 'A small furry pet that says meow',
    'chair': 'You sit on this',
    'classroom': 'The room where you go to learn at school',
    'computer': 'A machine used to work, learn and play',
    'daily': 'Something that happens every single day',
    'dog': 'A loyal pet that barks and wags its tail',
    'eat': 'What you do when you are hungry',
    'evening': 'The end of the day, just before night',
    'everyday': 'Each and every day without stopping',
    'fish': 'An animal that lives in water and swims',
    'green': 'The colour of leaves and grass',
    'happy': 'How you feel when something makes you smile',
    'healthy': 'Good for your body — keeps you strong',
    'homework': 'School work you do at home',
    'horse': 'A large animal you can ride',
    'ice': 'Water that has become very cold and solid',
    'jump': 'To leap up off the ground into the air',
    'kite': 'A toy that flies in the wind on a long string',
    'large': 'Very big in size',
    'light': 'Makes a dark place bright so you can see',
    'market': 'A place where people buy and sell things',
    'morning': 'The beginning of the day when the sun rises',
    'mother': 'Your mum — she takes care of you',
    'open': 'To move something so it is no longer closed',
    'orange': 'A round citrus fruit with a bright colour',
    'paper': 'A thin flat sheet you write or draw on',
    'pen': 'You use this to write in ink',
    'pencil': 'You write and draw with this — it has a rubber end',
    'picture': 'An image, photo or drawing',
    'pig': 'A farm animal that rolls in mud and oinks',
    'plant': 'A living thing that grows in soil and needs water',
    'rain': 'Water that falls from clouds in the sky',
    'rainbow': 'Colourful arc that appears in the sky after rain',
    'rings': 'Circular shapes — like a ring on a finger',
    'river': 'Water that flows through the land to the sea',
    'rock': 'A hard lump of stone found on the ground',
    'ship': 'A very large boat that travels on the sea',
    'story': 'Words that tell about people, places and things',
    'student': 'A person who goes to school to learn',
    'sun': 'The big bright star that shines in the sky during the day',
    'sunshine': 'The warm bright light that comes from the sun',
    'table': 'A piece of furniture with a flat top — you put things on it',
    'tasty': 'Something that is very nice to eat',
    'teacher': 'A person who helps you learn at school',
    'tiger': 'A big wild cat with orange and black stripes',
    'village': 'A small community where people live together',
    'water': 'Clear liquid you drink — fish live in it too',
    'weather': 'How the sky is — sunny, rainy, windy or cloudy',
    'window': 'A glass opening in a wall that lets in light',
  };

  // SINHALA HINTS — unicode escaped (safe on all platforms)
  static const Map<String, String> _siHints = {
    'අත්සන': 'ඔබගේ නම ලියා කරන සලකුණ',
    'අවධානය': 'යම් දෙයකට හොඳින් සිත යොමු කිරීම',
    'අවබෝධය': 'යම් දෙයක් හොඳින් තේරුම් ගැනීම',
    'ආරක්ෂාව': 'අනතුරකින් බේරී සිටීම',
    'ඇස': 'අපට දේවල් බලන්න උදව් කරන ශරීර කොටස',
    'ඊතලය': 'යන දිශාව පෙන්වන සලකුණ',
    'උදැල්ල': 'බිම හාරන්න භාවිත කරන උපකරණයක්',
    'උර': 'අපගේ අතට ඉහළින් ඇති ශරීර කොටස',
    'එක': 'ගණන 1',
    'ඔය': 'ගඟකට වඩා කුඩා ජල මාර්ගයක්',
    'කැමැත්ත': 'යමක් කිරීමට ඇති ආශාව',
    'කියවීම': 'පොතක හෝ ලියවිල්ලක ඇති දේ තේරුම් ගැනීම',
    'කිරිබත්': 'කිරි සහ සහල් වලින් සාදන ආහාරයක්',
    'කුරුල්ලා': 'පියාසර කරන පිහාටු සහිත සතෙක්',
    'කුසලතා': 'යමක් හොඳින් කිරීමට ඇති හැකියාව',
    'කෙසෙල්': 'කහ පාටට ඉදෙන රසවත් පලතුරක්',
    'ගණිතය': 'අංක සහ ගණන් ගැන ඉගෙන ගන්නා විෂයක්',
    'ගම': 'මිනිසුන් ජීවත් වන කුඩා ප්‍රදේශයක්',
    'ගායනය': 'ගීතයක් කටහඬින් ගායනා කිරීම',
    'ගැහැනිය': 'වැඩිහිටි කාන්තාවක්',
    'ගුරුතුමා': 'පාසලේදී අපට උගන්වන පිරිමි ගුරුවරයෙක්',
    'චීනය': 'ආසියාවේ පිහිටි විශාල රටක්',
    'ජනතාව': 'යම් ප්‍රදේශයක ජීවත් වන මිනිසුන්',
    'තාරාවා': 'ජලයේ පිහිනන කුරුල්ලෙක්',
    'තීන්ත': 'ලිවීමට හෝ චිත්‍ර ඇඳීමට භාවිත කරන දියරයක්',
    'තොවිලය': 'ශ්‍රී ලංකාවේ සාම්ප්‍රදායික ශාන්තිකර්මයක්',
    'නිගමනය': 'යම් දෙයක් ගැන අවසානයේ ලබාගන්නා අදහස',
    'නියර': 'කුඹුරක කොටස් වෙන් කරන උස් පටිය',
    'නිර්මාණශීලී': 'අලුත් දේවල් නිර්මාණය කිරීමට ඇති හැකියාව',
    'ප්‍රයත්නය': 'යමක් කිරීමට දරන උත්සාහය',
    'ප්‍රායෝගික': 'සැබෑ ජීවිතයේදී භාවිත කළ හැකි',
    'පැන්සල්': 'ලිවීමට සහ ඇඳීමට භාවිත කරන උපකරණයක්',
    'පිරිසිදු': 'කුණු හෝ අපිරිසිදු දේ නැති',
    'පිළිතුරු': 'ප්‍රශ්නයකට දෙන උත්තරය',
    'පිළිහුඩුවා': 'කුඩා කුරුල්ලන් අල්ලා කන දඩයම්කාරී කුරුල්ලෙක්',
    'පූජාව': 'ආගමික ගෞරවයෙන් පූජා කරන දෙයක්',
    'බෑගය': 'දේවල් දමාගෙන යාමට භාවිත කරන භාණ්ඩයක්',
    'මුරුක්කු': 'පිටිවලින් සාදන රසවත් කැවිලි වර්ගයක්',
    'මුහුද': 'විශාල ලුණු වතුර සහිත ජල ප්‍රදේශයක්',
    'රූපකය': 'යම් දෙයක් වෙනත් දෙයකට සමාන කර පෙන්වන භාෂා භාවිතයක්',
    'ලස්සන': 'බලන්නට ඉතා ප්‍රියජනක',
    'වරලස': 'හිස මත ඇති කෙස් සමූහය',
    'වලාකුළු': 'අහසේ පෙනෙන සුදු හෝ කළු ජලවාෂ්ප සමූහයක්',
    'විචාරය': 'යම් දෙයක් ගැන සිතා බලා අදහස් දැක්වීම',
    'විස්තරය': 'යම් දෙයක් ගැන පැහැදිලිව කියන තොරතුරු',
    'වේවැල': 'වේවැල් වැනි ශාකයකින් සාදන දිගු කෝටුවක්',
    'සංකල්ප': 'යම් දෙයක් ගැන සිතේ ඇති අදහස්',
    'සංවාදය': 'දෙදෙනෙකු හෝ කිහිපදෙනෙකු අතර සිදුවන කතාබහ',
    'සංවිධානය': 'යම් කාර්යයක් ක්‍රමවත් ලෙස සකස් කිරීම',
    'සටහන්': 'මතක තබා ගැනීමට ලියා තබන කරුණු',
    'සම්පූර්ණණ': 'අවශ්‍ය සියලු දේම ඇතුළත්',
    'සිංහයා': 'වනාන්තරයේ රජු ලෙස හඳුන්වන විශාල සතෙක්',
    'සිතියම': 'ස්ථාන සහ ප්‍රදේශ පෙන්වන රූපයක්',
    'සීගිරිය': 'ශ්‍රී ලංකාවේ ප්‍රසිද්ධ පුරාණ ගල් බලකොටුවක්',
    'සෞඛ්‍යය': 'ශරීරය සහ මනස නිරෝගීව තිබීම',
  };
}
