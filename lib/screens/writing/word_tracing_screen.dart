import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/encoding_data.dart';
import '../../data/writing_data.dart';
import '../../models/app_colors.dart';
import '../../services/ble_command_service.dart';
import '../../services/writing_session_logger.dart';
import '../../widgets/buddy_feedback_overlay.dart';
import '../../widgets/tracing_canvas.dart';

class WordTracingScreen extends StatefulWidget {
  final WritingArgs args;
  const WordTracingScreen({super.key, required this.args});

  @override
  State<WordTracingScreen> createState() => _WordTracingScreenState();
}

class _WordTracingScreenState extends State<WordTracingScreen>
    with TickerProviderStateMixin {
  late final List<String> _words;
  int _wordIndex = 0;

  // Per-word state
  int _activeLetter = 0;           // which letter of the word is active
  List<double> _letterAccuracy = [];// accuracy per letter
  int _attemptCount = 0;
  int _totalXp = 0;
  bool _sessionSaved = false;

  // UI
  bool _showOverlay = false;
  bool _overlayCorrect = false;
  bool _isThirdAttempt = false;

  // Canvas key per letter
  final Map<int, GlobalKey<TracingCanvasState>> _canvasKeys = {};

  // TTS
  late final FlutterTts _tts;
  bool _isSpeaking = false;

  // Buddy
  late final AnimationController _buddyCtrl;

  bool get _isSi => widget.args.isSinhala;
  String get _currentWord => _words[_wordIndex];
  List<String> get _wordLetters {
    final w = _currentWord.toUpperCase();
    if (_isSi) return splitToLetters(_currentWord, true);
    return w.split('');
  }
  double get _wordAccuracy {
    if (_letterAccuracy.isEmpty) return 0;
    final filled = _letterAccuracy.where((a) => a > 0).toList();
    if (filled.isEmpty) return 0;
    return filled.reduce((a, b) => a + b) / filled.length;
  }

  @override
  void initState() {
    super.initState();
    _words = getWritingWords(widget.args.language, widget.args.grade);
    _tts = FlutterTts();
    _initTts();
    _buddyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _initWord();
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(_isSi ? 0.3 : 0.4);
    await _tts.setPitch(_isSi ? 0.9 : 1.0);
    await _tts.setLanguage(_isSi ? 'si-LK' : 'en-US');
    _tts.setCompletionHandler(() { if (mounted) setState(() => _isSpeaking = false); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => _isSpeaking = false); });
    await _speakWord();
  }

  @override
  void dispose() {
    _tts.stop();
    _buddyCtrl.dispose();
    super.dispose();
  }

  void _initWord() {
    final letters = _wordLetters;
    _activeLetter = 0;
    _letterAccuracy = List.filled(letters.length, 0.0);
    _attemptCount = 0;
    _sessionSaved = false;
    _canvasKeys.clear();
    for (int i = 0; i < letters.length; i++) {
      _canvasKeys[i] = GlobalKey<TracingCanvasState>();
    }
  }

  Future<void> _speakWord() async {
    if (_isSpeaking) { await _tts.stop(); setState(() => _isSpeaking = false); return; }
    setState(() => _isSpeaking = true);
    await _tts.speak(_currentWord);
  }

  GlobalKey<TracingCanvasState> _keyFor(int idx) {
    _canvasKeys[idx] ??= GlobalKey<TracingCanvasState>();
    return _canvasKeys[idx]!;
  }

  void _onAccuracyChanged(int letterIdx, double acc) {
    if (mounted) setState(() {
      if (letterIdx < _letterAccuracy.length) _letterAccuracy[letterIdx] = acc;
    });
  }

  void _onClear() {
    _canvasKeys[_activeLetter]?.currentState?.clearCanvas();
    setState(() { if (_activeLetter < _letterAccuracy.length) _letterAccuracy[_activeLetter] = 0; });
  }

  void _onHint() => _canvasKeys[_activeLetter]?.currentState?.showHint();

  void _onDone() {
    final acc = _wordAccuracy;
    _attemptCount++;
    final passed = acc >= 65;

    if (passed && !_sessionSaved) {
      _sessionSaved = true;
      final xp = xpForAccuracy(acc);
      _totalXp += xp;
      _saveSession(xp, acc);
      BleCommandService.instance.send('GOOD_JOB');
    } else if (_attemptCount >= 3) {
      BleCommandService.instance.send('TRY_AGAIN');
    }

    setState(() {
      _overlayCorrect = passed;
      _isThirdAttempt = !passed && _attemptCount >= 3;
      _showOverlay = true;
    });
  }

  Future<void> _saveSession(int xp, double acc) async {
    await WritingSessionLogger.saveSession(
      profileId: widget.args.profileId,
      letter: _currentWord,
      language: widget.args.language,
      grade: widget.args.grade,
      accuracy: acc,
      xpEarned: xp,
    );
  }

  void _onOverlayDismiss() {
    setState(() => _showOverlay = false);
    if (_overlayCorrect) _advanceWord();
  }

  void _onNext() {
    setState(() => _showOverlay = false);
    _advanceWord();
  }

  void _advanceWord() {
    if (_wordIndex < _words.length - 1) {
      setState(() {
        _wordIndex++;
        _initWord();
      });
      Future.delayed(const Duration(milliseconds: 400), _speakWord);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final word = _currentWord;
    final letters = _wordLetters;
    final emoji = wordEmojiFor(word);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.writing,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isSi ? 'වචන ${_wordIndex + 1} / ${_words.length}' : 'Word ${_wordIndex + 1} of ${_words.length}',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(child: Text('⚡ $_totalXp XP',
                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded, color: Colors.white),
            onPressed: _speakWord,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress
              _WordProgressBar(current: _wordIndex + 1, total: _words.length),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      // Word header card (emoji + word text + accuracy)
                      _buildWordHeader(word, emoji, letters).animate().fadeIn().slideY(begin: -0.15),

                      const SizedBox(height: 14),

                      // Letter tabs
                      _LetterTabBar(
                        letters: letters,
                        active: _activeLetter,
                        accuracies: _letterAccuracy,
                        onSelect: (i) => setState(() => _activeLetter = i),
                      ).animate().fadeIn(delay: 80.ms),

                      const SizedBox(height: 12),

                      // Active letter tracing canvas
                      _buildActiveCanvas(letters),

                      const SizedBox(height: 14),

                      // Buttons
                      _buildButtons(),

                      const SizedBox(height: 14),

                      // Buddy
                      _WordBuddyCard(
                        accuracy: _wordAccuracy,
                        isSi: _isSi,
                        ctrl: _buddyCtrl,
                        lettersDone: _letterAccuracy.where((a) => a >= 70).length,
                        total: letters.length,
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_showOverlay)
            BuddyFeedbackOverlay(
              isCorrect: _overlayCorrect,
              isThirdAttempt: _isThirdAttempt,
              xpGain: xpForAccuracy(_wordAccuracy),
              revealAnswer: _isThirdAttempt ? word : null,
              onDismiss: _overlayCorrect ? _onNext : _onOverlayDismiss,
              onNext: _onNext,
            ),
        ],
      ),
    );
  }

  Widget _buildWordHeader(String word, String emoji, List<String> letters) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.writing.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 48))),
          ),
          const SizedBox(width: 16),
          // Word + accuracy
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(word,
                    style: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.writing)),
                const SizedBox(height: 6),
                // Per-letter mini accuracy bar
                Row(
                  children: List.generate(letters.length, (i) {
                    final acc = i < _letterAccuracy.length ? _letterAccuracy[i] : 0.0;
                    final color = acc >= 70 ? AppColors.success : acc > 0 ? AppColors.almost : AppColors.divider;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: i < letters.length - 1 ? 3 : 0),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  _wordAccuracy > 0 ? '${_wordAccuracy.round()}% overall' : _isSi ? 'ලිවීම ආරම්භ කරන්න' : 'Start tracing',
                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCanvas(List<String> letters) {
    if (_activeLetter >= letters.length) return const SizedBox();
    final letter = letters[_activeLetter];
    final strokes = getLetterStrokes(letter, _isSi) ?? [];
    final key = _keyFor(_activeLetter);

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 5))],
        border: Border.all(color: AppColors.writing.withOpacity(0.2), width: 1.5),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: (strokes.isEmpty && !_isSi)
                ? Center(child: Text(letter,
                    style: GoogleFonts.nunito(fontSize: 130, fontWeight: FontWeight.w900,
                        color: AppColors.writing.withOpacity(0.07))))
                : TracingCanvas(
                    key: key,
                    templateStrokes: strokes,
                    tolerance: 28.0,
                    onAccuracyChanged: (acc) => _onAccuracyChanged(_activeLetter, acc),
                    letter: _isSi ? letter : null,
                    isSinhala: _isSi,
                  ),
          ),
          // Letter overlay label top-left
          Positioned(
            top: 10, left: 14,
            child: Text(letter,
                style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w900,
                    color: AppColors.writing.withOpacity(0.25))),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms);
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(child: _WBtn(icon: Icons.delete_outline_rounded, label: _isSi ? 'හිස්' : 'Clear', color: Colors.white, textColor: AppColors.textPrimary, borderColor: AppColors.divider, onTap: _onClear)),
        const SizedBox(width: 10),
        Expanded(child: _WBtn(icon: Icons.lightbulb_outline_rounded, label: _isSi ? 'ඉඟිය' : 'Hint', color: const Color(0xFFFFF3CD), textColor: const Color(0xFF856404), onTap: _onHint)),
        const SizedBox(width: 10),
        Expanded(child: _WBtn(icon: Icons.check_circle_outline_rounded, label: _isSi ? 'සම්පූර්ණයි' : 'Done', color: AppColors.writing, textColor: Colors.white, onTap: _onDone)),
      ],
    );
  }
}

// ── Word progress bar ─────────────────────────────────────────────────────────

class _WordProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _WordProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.writing,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: current / total),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: v, minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.25),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
    );
  }
}

// ── Letter tab bar ────────────────────────────────────────────────────────────

class _LetterTabBar extends StatelessWidget {
  final List<String> letters;
  final int active;
  final List<double> accuracies;
  final ValueChanged<int> onSelect;
  const _LetterTabBar({required this.letters, required this.active, required this.accuracies, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(letters.length, (i) {
          final isActive = i == active;
          final acc = i < accuracies.length ? accuracies[i] : 0.0;
          final Color dotColor = acc >= 70 ? AppColors.success : acc > 0 ? AppColors.almost : Colors.transparent;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? AppColors.writing : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive ? AppColors.writing : AppColors.divider,
                  width: 1.5,
                ),
                boxShadow: isActive ? [BoxShadow(color: AppColors.writing.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
              ),
              child: Row(
                children: [
                  Text(letters[i],
                      style: GoogleFonts.nunito(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: isActive ? Colors.white : AppColors.textPrimary)),
                  if (acc > 0) ...[
                    const SizedBox(width: 5),
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Buddy card ────────────────────────────────────────────────────────────────

class _WordBuddyCard extends StatelessWidget {
  final double accuracy;
  final bool isSi;
  final AnimationController ctrl;
  final int lettersDone;
  final int total;
  const _WordBuddyCard({required this.accuracy, required this.isSi, required this.ctrl, required this.lettersDone, required this.total});

  String get _msg {
    if (accuracy == 0) return isSi ? '✏️ ලිවීම ආරම්භ කරන්න!' : '✏️ Tap a letter tab and start tracing!';
    if (lettersDone == total) return isSi ? '⭐⭐⭐ සියලු අකුරු ලිව්වා!' : '⭐⭐⭐ All letters traced! Tap Done!';
    if (accuracy >= 70) return isSi ? '⭐ හොඳයි! ඊළඟ අකුර ලිවීමට සූදානම්!' : '⭐ Great! Move to the next letter!';
    return isSi ? '💪 ලප රේඛා අනුගමනය කරන්න!' : '💪 Follow the dotted guide carefully!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.writing.withOpacity(0.2)),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: ctrl,
            builder: (_, __) => Transform.rotate(
              angle: (ctrl.value - 0.5) * 0.15,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.writing.withOpacity(0.1), shape: BoxShape.circle),
                child: const Center(child: Text('🦉', style: TextStyle(fontSize: 24))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_msg,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

// ── Simple button ─────────────────────────────────────────────────────────────

class _WBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;
  const _WBtn({required this.icon, required this.label, required this.color, required this.textColor, required this.onTap, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
          boxShadow: color == Colors.white ? null : [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
