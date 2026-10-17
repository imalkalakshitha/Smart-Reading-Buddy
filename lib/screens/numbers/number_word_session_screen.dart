import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../dao/number_practice_dao.dart';
import '../../data/numbers_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../services/hybrid_pronunciation_scorer.dart';
import '../../services/number_answer_checker.dart';
import 'numbers_hub_screen.dart' show EnglishOnlyNote;

/// Number Word Pronunciation — shows a digit ("15"), the child says the
/// English word, scored by HybridPronunciationScorer (always 'en') and then
/// re-checked by NumberAnswerChecker for digit transcripts and -teen/-ty
/// confusion. Recording/VAD behaviour mirrors PronunciationSessionScreen.
class NumberWordSessionScreen extends StatefulWidget {
  final String levelKey;
  final String levelName;

  const NumberWordSessionScreen({
    super.key,
    required this.levelKey,
    required this.levelName,
  });

  @override
  State<NumberWordSessionScreen> createState() => _NumberWordSessionScreenState();
}

class _NumberWordSessionScreenState extends State<NumberWordSessionScreen> {
  static const int _maxFailsBeforeSkip = 3;
  static const _maxRecordingDuration = Duration(seconds: 7);
  // Same VAD values as PronunciationSessionScreen. Every number word is
  // short, so the short-word minimum listen floor always applies.
  static const double _vadSpeechThreshold = 0.12;
  static const double _vadSilenceThreshold = 0.06;
  static const Duration _vadSilenceGrace = Duration(milliseconds: 1300);
  static const Duration _minListenDuration = Duration(milliseconds: 1400);

  late List<NumberItem> _items;
  int _index = 0;
  int _failCount = 0;
  int _attemptNumber = 0;

  bool _recording = false;
  bool _scoring = false;
  bool _showResult = false;
  bool _finished = false;
  NumberWordVerdict? _verdict;

  int _correctCount = 0;
  int _totalXp = 0;
  int _teenTyCount = 0;

  Timer? _autoStopTimer;
  StreamSubscription<double>? _vadSub;
  StreamSubscription<void>? _partialSub;
  DateTime? _recordingStartedAt;
  DateTime? _firstPartialAt;
  bool _vadHasSpokenOnce = false;
  DateTime? _vadSilenceStartedAt;

  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  NumberItem get _current => _items[_index];

  @override
  void initState() {
    super.initState();
    _items = NumbersData.forLevel(widget.levelKey)..shuffle();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.38);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _vadSub?.cancel();
    _partialSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_recording || _scoring) return;
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(_current.word);
    if (mounted) setState(() => _speaking = false);
  }

  void _onMicTap() {
    if (_showResult || _scoring || _recording) return;
    _tts.stop();
    setState(() {
      _recording = true;
      _speaking = false;
    });
    _vadHasSpokenOnce = false;
    _vadSilenceStartedAt = null;
    _recordingStartedAt = DateTime.now();
    _firstPartialAt = null;
    _partialSub?.cancel();
    _partialSub = HybridPronunciationScorer.onPartialResult.listen((_) {
      _firstPartialAt ??= DateTime.now();
    });
    HybridPronunciationScorer.startRecording(lang: 'en');
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(_maxRecordingDuration, _stopAndScore);
    _vadSub?.cancel();
    _vadSub = HybridPronunciationScorer.amplitudeStream.listen(_onVadSample);
  }

  void _onVadSample(double amplitude) {
    if (!_recording) return;
    if (amplitude >= _vadSpeechThreshold) {
      _vadHasSpokenOnce = true;
      _vadSilenceStartedAt = null;
      return;
    }
    if (!_vadHasSpokenOnce) return;
    if (amplitude < _vadSilenceThreshold) {
      _vadSilenceStartedAt ??= DateTime.now();
      if (DateTime.now().difference(_vadSilenceStartedAt!) >= _vadSilenceGrace) {
        if (DateTime.now().difference(_recordingStartedAt!) < _minListenDuration) return;
        _stopAndScore();
      }
    } else {
      _vadSilenceStartedAt = null;
    }
  }

  Future<void> _stopAndScore() async {
    if (!_recording) return;
    _autoStopTimer?.cancel();
    _vadSub?.cancel();
    _vadSub = null;
    await _partialSub?.cancel();
    _partialSub = null;
    setState(() {
      _recording = false;
      _scoring = true;
    });

    final gradeNum = AppState.grade == 'grade4' ? 4 : 3;
    // The digit form is passed as the expected word: Android's STT usually
    // writes numbers as digits, so a correct "15" is an exact match and
    // doesn't trigger the scorer's WRONG-only extra recording. The word
    // form is handled by NumberAnswerChecker.
    final result = await HybridPronunciationScorer.stopAndScore(
      word: _current.digits,
      lang: 'en',
      gradeNum: gradeNum,
    );
    final verdict = await NumberAnswerChecker.check(target: _current, result: result);
    if (!mounted) return;

    final responseMs = (_firstPartialAt != null && _recordingStartedAt != null)
        ? _firstPartialAt!.difference(_recordingStartedAt!).inMilliseconds
        : null;

    if (verdict.verdict != 'NO_SPEECH') {
      _attemptNumber++;
      NumberPracticeDao.saveNumberWordAttempt(
        profileName: AppState.name,
        levelKey: widget.levelKey,
        item: _current.digits,
        recognizedText: result.rawTranscript,
        verdict: verdict.verdict,
        score: verdict.stars / 3,
        responseMs: responseMs,
        teenTyError: verdict.teenTyConfusion,
        attemptNumber: _attemptNumber,
      ).catchError((Object e) => debugPrint('[Numbers] save failed: $e'));
    }

    setState(() {
      _scoring = false;
      _verdict = verdict;
      _showResult = true;
      if (verdict.verdict == 'OK') {
        _correctCount++;
        _totalXp += verdict.xpEarned;
      } else {
        _failCount++;
        if (verdict.teenTyConfusion) _teenTyCount++;
      }
    });

    final isOk = verdict.verdict == 'OK';
    if (!isOk && _failCount < _maxFailsBeforeSkip) {
      // Same as PronunciationSessionScreen: wrong attempts auto-dismiss so
      // the child can try again. The -teen/-ty tip stays up longer to read.
      final hold = verdict.teenTyConfusion ? 3500 : 1800;
      Future.delayed(Duration(milliseconds: hold), () {
        if (mounted && _verdict == verdict) setState(() => _showResult = false);
      });
    }
  }

  void _advance() {
    if (_index >= _items.length - 1) {
      setState(() {
        _showResult = false;
        _finished = true;
      });
      return;
    }
    setState(() {
      _index++;
      _failCount = 0;
      _attemptNumber = 0;
      _showResult = false;
      _verdict = null;
    });
  }

  void _restart() {
    setState(() {
      _items = NumbersData.forLevel(widget.levelKey)..shuffle();
      _index = 0;
      _failCount = 0;
      _attemptNumber = 0;
      _correctCount = 0;
      _totalXp = 0;
      _teenTyCount = 0;
      _verdict = null;
      _showResult = false;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The result popup sits over the WHOLE Scaffold (app bar, body and the
    // system-inset area below it), not inside the body: a Stack in the body
    // only gets the scroll view's shrink-wrapped height, so the dim used to
    // stop ~70% down the screen. The transparent Material gives the popup's
    // text a Material ancestor outside the Scaffold.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          _buildScaffold(),
          if (!_finished && _showResult && _verdict != null) _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pronunciation,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.levelName,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: _finished ? _buildSummary() : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final showHint = _failCount > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (AppState.language == 'sinhala') ...[
            const EnglishOnlyNote(),
            const SizedBox(height: 16),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_index + 1) / _items.length,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation(AppColors.pronunciation),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Say this number!',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _current.digits,
                  style: GoogleFonts.nunito(
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: showHint
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Hint: ${_current.word}',
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pronunciation,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _speak,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _speaking ? AppColors.pronunciation : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.pronunciation.withValues(alpha: _speaking ? 0 : 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                          size: 20,
                          color: _speaking ? Colors.white : AppColors.pronunciation,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _speaking ? 'Stop' : 'Listen',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _speaking ? Colors.white : AppColors.pronunciation,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate(key: ValueKey(_index)).fadeIn().scale(
                begin: const Offset(0.92, 0.92),
                curve: Curves.easeOut,
                duration: 300.ms,
              ),
          const SizedBox(height: 24),
          if (_failCount > 0)
            Text(
              'Attempt ${_failCount + 1}/$_maxFailsBeforeSkip',
              style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 16),
          if (_recording)
            StreamBuilder<double>(
              stream: HybridPronunciationScorer.amplitudeStream,
              builder: (context, snap) {
                final level = snap.data ?? 0.0;
                final loud = level > 0.25;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: level,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            loud ? AppColors.success : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loud ? 'Good volume! 🎤' : 'Speak louder! 📢',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: loud ? AppColors.success : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _onMicTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _recording ? AppColors.pronunciation : AppColors.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.pronunciation, width: _recording ? 0 : 3),
                boxShadow: _recording
                    ? [
                        BoxShadow(
                          color: AppColors.pronunciation.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: _scoring
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.pronunciation,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 42,
                          color: _recording ? Colors.white : AppColors.pronunciation,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _recording ? 'Listening...' : 'Tap to speak',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _recording ? Colors.white : AppColors.pronunciation,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildResultOverlay() {
    final v = _verdict!;
    final canAdvance = v.verdict == 'OK' || _failCount >= _maxFailsBeforeSkip;
    final isSkip = canAdvance && v.verdict != 'OK';
    final isLast = _index >= _items.length - 1;

    late final String emoji;
    late final String label;
    late final Color color;
    String? detail;
    switch (v.verdict) {
      case 'OK':
        emoji = '🎉';
        label = 'Great Job!';
        color = AppColors.success;
      case 'ALMOST':
        emoji = '👍';
        label = 'Almost!';
        color = AppColors.almost;
      case 'NO_SPEECH':
        emoji = '🎤';
        label = 'Please say the number!';
        color = Colors.orange;
        detail = "We couldn't hear you";
      default:
        emoji = v.teenTyConfusion ? '👂' : '💪';
        label = 'Nice try! One more time';
        color = AppColors.wrong;
        if (v.teenTyConfusion && v.heardValue != null) {
          detail = 'That sounded like ${v.heardValue} 🙂';
        }
    }

    return Positioned.fill(
      child: GestureDetector(
        onTap: canAdvance ? _advance : null,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (v.tip != null) ...[
                    const SizedBox(height: 14),
                    StressTip(tip: v.tip!),
                  ],
                  if (v.verdict == 'OK' || v.verdict == 'ALMOST') ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Icon(
                          i < v.stars ? Icons.star_rounded : Icons.star_border_rounded,
                          color: i < v.stars ? Colors.amber : Colors.grey.shade300,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                  if (v.xpEarned > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '+${v.xpEarned} XP',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: v.verdict == 'OK' ? AppColors.pronunciation : AppColors.almost,
                      ),
                    ),
                  ],
                  if (canAdvance) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSkip ? AppColors.wrong : color,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        isSkip
                            ? 'Skip this number ⏭'
                            : (isLast ? 'Finish ✓' : 'Next →'),
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildSummary() {
    final total = _items.length;
    final great = _correctCount >= (total * 0.8);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(great ? '🏆' : '🌟', style: const TextStyle(fontSize: 80))
              .animate()
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.easeOutBack),
          const SizedBox(height: 12),
          Text(
            great ? 'Amazing counting!' : 'Well done!',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _SummaryStat(label: 'Numbers said right', value: '$_correctCount / $total'),
          const SizedBox(height: 10),
          _SummaryStat(label: 'XP earned', value: '+$_totalXp'),
          if (_teenTyCount > 0) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.almost.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '👂 Teen or ty? Remember: TEEN numbers stress the end (fif-TEEN), '
                'TY numbers stress the start (FIF-ty).',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          _PillButton(label: 'Play again 🔁', color: AppColors.pronunciation, onTap: _restart),
          const SizedBox(height: 12),
          _PillButton(
            label: 'Back to Numbers',
            color: AppColors.reading,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// "fif-TEEN — stress the end", with the stressed (upper-case) syllable
/// highlighted.
class StressTip extends StatelessWidget {
  final String tip;

  const StressTip({super.key, required this.tip});

  @override
  Widget build(BuildContext context) {
    final parts = tip.split(' — ');
    final syllables = parts.first.split('-');
    final hint = parts.length > 1 ? parts[1] : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.pronunciation.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                for (var i = 0; i < syllables.length; i++) ...[
                  if (i > 0) const TextSpan(text: '-'),
                  TextSpan(
                    text: syllables[i],
                    style: syllables[i] == syllables[i].toUpperCase()
                        ? const TextStyle(color: AppColors.pronunciation, fontSize: 30)
                        : null,
                  ),
                ],
              ],
            ),
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          if (hint.isNotEmpty)
            Text(
              hint,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PillButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }
}
