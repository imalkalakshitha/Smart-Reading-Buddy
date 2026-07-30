import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/pronunciation_args.dart';
import '../../data/word_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';
import '../../models/pronunciation_result.dart';
import '../../services/coaching_strategy.dart';
import '../../services/hybrid_pronunciation_scorer.dart';
import '../../services/session_logger.dart';
import '../../widgets/phoneme_image_widget.dart';

class PronunciationSessionScreen extends StatefulWidget {
  final PronunciationSessionArgs args;

  const PronunciationSessionScreen({super.key, required this.args});

  @override
  State<PronunciationSessionScreen> createState() =>
      _PronunciationSessionScreenState();
}

class _PronunciationSessionScreenState extends State<PronunciationSessionScreen>
    with TickerProviderStateMixin {
  int _wordIndex = 0;
  int _attempt = 0;
  bool _recording = false;
  bool _scoring = false;
  PronunciationResult?  _lastResult;
  bool                  _showResult  = false;
  bool                  _vmgExpanded = false;
  CoachingResponse?     _coaching;

  late AnimationController _waveCtrl;
  late AnimationController _resultCtrl;
  late final AudioPlayer _audioPlayer;
  bool _playing = false;
  final List<Map<String, dynamic>> _allAttempts = [];
  int _correct = 0;
  int _almost = 0;
  int _wrong = 0;
  int _totalXp = 0;
  final _stopwatch = Stopwatch();

  WordItem get _currentWord => widget.args.words[_wordIndex];
  int get _totalWords => widget.args.words.length;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveCtrl.dispose();
    _resultCtrl.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _playReference() async {
    if (_playing) {
      await _audioPlayer.stop();
      setState(() => _playing = false);
      return;
    }
    final lang     = AppState.language == 'sinhala' ? 'si' : 'en';
    final grade    = AppState.grade == 'grade4' ? 'grade4' : 'grade3';
    final assetPath = 'assets/audio/words/$lang/$grade/${_currentWord.pKey}.wav';
    try {
      setState(() => _playing = true);
      await _audioPlayer.play(AssetSource(assetPath.replaceFirst('assets/', '')));
    } catch (_) {
      setState(() => _playing = false);
    }
  }

  void _onHoldStart(PointerDownEvent _) {
    if (_showResult || _scoring) return;
    setState(() => _recording = true);
    _waveCtrl.repeat();
    final lang = AppState.language == 'sinhala' ? 'si' : 'en';
    HybridPronunciationScorer.startRecording(lang: lang);
  }

  void _onHoldEnd(PointerEvent _) => _stopAndScore();

  Future<void> _stopAndScore() async {
    if (!_recording) return;
    _waveCtrl.stop();
    _waveCtrl.reset();
    setState(() {
      _recording = false;
      _scoring   = true;
    });

    final lang     = AppState.language == 'sinhala' ? 'si' : 'en';
    final gradeNum = AppState.grade == 'grade4' ? 4 : 3;
    final result   = await HybridPronunciationScorer.stopAndScore(
      word:          _currentWord.pKey,
      lang:          lang,
      gradeNum:      gradeNum,
      sinhalaScript: _currentWord.word,
    );

    if (!mounted) return;
    setState(() => _scoring = false);

    // No speech detected — show a gentle prompt, don't count as an attempt.
    if (result.verdict == 'NO_SPEECH') {
      setState(() { _lastResult = result; _showResult = true; });
      _resultCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _showResult = false);
      });
      return;
    }

    // No internet for Sinhala (Gemini) scoring — show a clear message,
    // don't count as an attempt or consume a retry.
    if (result.verdict == 'NO_INTERNET') {
      setState(() { _lastResult = result; _showResult = true; });
      _resultCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _showResult = false);
      });
      return;
    }

    const scoreMap = {'OK': 0.9, 'ALMOST': 0.7, 'WRONG': 0.25};
    _allAttempts.add({
      'word':           _currentWord.word,
      'phonemes':       _currentWord.phonemes.join(','),
      'result':         result.verdict,
      'attempt_number': _attempt + 1,
      'dtw_score':      scoreMap[result.verdict] ?? 0.25,
    });

    // ── Coaching ─────────────────────────────────────────────────────────────
    final coaching = result.verdict == 'OK'
        ? CoachingStrategy.forPass(lang)
        : CoachingStrategy.forFail(
            attemptNumber: _attempt + 1,
            lang: lang,
          );

    final canAdvance = result.verdict == 'OK' || _attempt >= 2;

    setState(() {
      _lastResult = result;
      _showResult = true;
      _coaching   = coaching;
    });
    _resultCtrl.forward(from: 0);

    if (canAdvance) {
      _recordFinalResult(result);
      // On final failed attempt: expand VMG + auto-play reference so child
      // can see/hear the correct pronunciation before tapping Next.
      if (result.verdict != 'OK') {
        if (coaching.autoExpandVMG) {
          setState(() => _vmgExpanded = true);
        }
        if (coaching.playReferenceAudio) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted && !_playing) _playReference();
          });
        }
      }
    } else {
      setState(() => _attempt++);
      // On attempt-2 fail: auto-play reference after overlay dismisses.
      if (coaching.playReferenceAudio) {
        Future.delayed(const Duration(milliseconds: 2100), () {
          if (mounted && !_playing) _playReference();
        });
      }
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _showResult = false);
      });
    }
  }

  void _recordFinalResult(PronunciationResult result) {
    final best = _allAttempts
        .where((a) => a['word'] == _currentWord.word)
        .fold<String>('WRONG', (prev, a) {
      final r = a['result'] as String;
      if (r == 'OK') return 'OK';
      if (r == 'ALMOST' && prev != 'OK') return 'ALMOST';
      return prev;
    });

    if (best == 'OK') {
      _correct++;
      _totalXp += result.verdict == 'OK' ? result.xpEarned : 5;
    } else if (best == 'ALMOST') {
      _almost++;
      _totalXp += 3;
    } else {
      _wrong++;
    }
  }

  void _advance() {
    _audioPlayer.stop();
    setState(() => _playing = false);
    if (_wordIndex < _totalWords - 1) {
      setState(() {
        _wordIndex++;
        _attempt    = 0;
        _showResult  = false;
        _lastResult  = null;
        _vmgExpanded = false;
        _coaching    = null;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    _stopwatch.stop();
    final hardPhonemes = <String>[];
    for (final a in _allAttempts) {
      if (a['result'] == 'WRONG') {
        hardPhonemes.addAll((a['phonemes'] as String).split(','));
      }
    }
    final counts = <String, int>{};
    for (final p in hardPhonemes) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final top = (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => e.key)
        .toList();

    // Persist session to SQLite so dashboard XP and streak are real.
    try {
      final sessionId = await SessionLogger.saveSession(
        grade:           AppState.grade,
        language:        AppState.language,
        levelKey:        widget.args.levelKey,
        levelName:       widget.args.levelName,
        totalXp:         _totalXp,
        durationSeconds: _stopwatch.elapsed.inSeconds,
        correct:         _correct,
        almost:          _almost,
        wrong:           _wrong,
      );
      await SessionLogger.saveWordAttempts(sessionId, _allAttempts);
      // PEPA: log phoneme-level error data for parent analytics.
      await SessionLogger.savePhonemeAttempts(
        sessionId:    sessionId,
        profileName:  AppState.name,
        language:     AppState.language == 'sinhala' ? 'si' : 'en',
        wordAttempts: _allAttempts,
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRouter.pronunciationComplete,
      arguments: SessionCompleteArgs(
        correct: _correct,
        almost: _almost,
        wrong: _wrong,
        xpEarned: _totalXp,
        durationSeconds: _stopwatch.elapsed.inSeconds,
        levelName: widget.args.levelName,
        hardPhonemes: top,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pronunciation,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.args.levelName,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_wordIndex + 1} / $_totalWords',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _buildContent(),
            if (_showResult && _lastResult != null) _buildResultOverlay(),
            if (_scoring)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55000000),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.pronunciation,
                      strokeWidth: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_wordIndex + 1) / _totalWords,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.pronunciation),
            ),
          ),
          const SizedBox(height: 24),

          // Word card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(_currentWord.emoji,
                    style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  _currentWord.word,
                  style: GoogleFonts.nunito(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _currentWord.phonemes.map((p) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.pronunciation.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '/$p/',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pronunciation,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentWord.meaning,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                // ── Listen to reference button ────────────────────────────
                GestureDetector(
                  onTap: _playReference,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _playing
                          ? AppColors.pronunciation
                          : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.pronunciation
                            .withValues(alpha: _playing ? 0 : 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _playing
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 20,
                          color: _playing
                              ? Colors.white
                              : AppColors.pronunciation,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _playing
                              ? (AppState.language == 'sinhala'
                                  ? 'නිවාරණය'
                                  : 'Stop')
                              : (AppState.language == 'sinhala'
                                  ? 'ශ්‍රවණය කරන්න'
                                  : 'Listen'),
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _playing
                                ? Colors.white
                                : AppColors.pronunciation,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(
                begin: const Offset(0.92, 0.92),
                curve: Curves.easeOut,
                duration: 300.ms,
              ),

          const SizedBox(height: 24),

          // Collapsible mouth guide
          GestureDetector(
            onTap: () => setState(() => _vmgExpanded = !_vmgExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppState.language == 'sinhala'
                        ? 'කට හැඩගැසීමේ මාර්ගෝපදේශය'
                        : 'Mouth shape guide',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _vmgExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.pronunciation,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _vmgExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: PhonemeImageWidget(
                      phonemes: _currentWord.phonemes,
                      isPlaying: !_showResult && _vmgExpanded,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // Attempt dots
          if (_attempt > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${AppState.language == 'sinhala' ? 'උත්සාහය' : 'Attempt'} ${_attempt + 1}/3',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Word reminder while recording
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _recording
                ? Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.pronunciation.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: AppColors.pronunciation.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentWord.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _currentWord.word,
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.pronunciation,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Live volume indicator (only while recording)
          if (_recording)
            StreamBuilder<double>(
              stream: HybridPronunciationScorer.amplitudeStream,
              builder: (context, snap) {
                final level = snap.data ?? 0.0;
                final loud  = level > 0.25;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                        loud
                            ? (AppState.language == 'sinhala'
                                ? 'හොඳයි! 🎤'
                                : 'Good volume! 🎤')
                            : (AppState.language == 'sinhala'
                                ? 'ටිකක් ජෝරෙට් කතා කරන්! 📢'
                                : 'Speak louder! 📢'),
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

          // Waveform
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (context, child) => _Waveform(
              active: _recording,
              progress: _waveCtrl.value,
            ),
          ),

          const SizedBox(height: 20),

          // Hold-to-speak button
          Listener(
            onPointerDown:   _onHoldStart,
            onPointerUp:     _onHoldEnd,
            onPointerCancel: _onHoldEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _recording
                    ? AppColors.pronunciation
                    : AppColors.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.pronunciation,
                  width: _recording ? 0 : 3,
                ),
                boxShadow: _recording
                    ? [
                        BoxShadow(
                          color: AppColors.pronunciation.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mic_rounded,
                    size: 42,
                    color: _recording
                        ? Colors.white
                        : AppColors.pronunciation,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _recording
                        ? (AppState.language == 'sinhala' ? 'කතා කරන්න' : 'Speaking...')
                        : (AppState.language == 'sinhala' ? 'ස්පර්ශ කර කතා කරන්' : 'Hold & Speak'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _recording
                          ? Colors.white
                          : AppColors.pronunciation,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStars(int stars) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => Icon(
        i < stars ? Icons.star_rounded : Icons.star_border_rounded,
        color: i < stars ? Colors.amber : Colors.grey.shade300,
        size: 40,
      )),
    );
  }

  Widget _buildResultOverlay() {
    final result = _lastResult!;

    // ── No speech detected — show prompt and auto-dismiss ─────────────────────
    if (result.verdict == 'NO_SPEECH') {
      return Positioned.fill(
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
                  const Text('🎤', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    AppState.language == 'sinhala'
                        ? 'කරුණාකර වචනය කියන්න!'
                        : 'Please say the word!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppState.language == 'sinhala'
                        ? 'ශබ්දය අපට ඇසෙන්නේ නැත'
                        : "We couldn't hear you",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms),
      );
    }

    // ── No internet for Sinhala (Gemini) scoring ───────────────────────────────
    if (result.verdict == 'NO_INTERNET') {
      return Positioned.fill(
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
                  const Icon(Icons.wifi_off_rounded,
                      size: 56, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    AppState.language == 'sinhala'
                        ? 'අන්තර්ජාලය අවශ්‍යයි!'
                        : 'Internet needed for Sinhala practice',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppState.language == 'sinhala'
                        ? 'කරුණාකර සම්බන්ධතාවය පරීක්ෂා කර නැවත උත්සාහ කරන්න'
                        : 'Please check your connection and try again',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms),
      );
    }

    // ── Normal result ─────────────────────────────────────────────────────────
    final isOk     = result.verdict == 'OK';
    final isAlmost = result.verdict == 'ALMOST';
    final color = isOk
        ? AppColors.success
        : isAlmost
            ? AppColors.almost
            : AppColors.wrong;
    final emoji = isOk ? '🎉' : isAlmost ? '👍' : '😅';
    final label = isOk
        ? (AppState.language == 'sinhala' ? 'නියමයි!' : 'Great Job!')
        : isAlmost
            ? (AppState.language == 'sinhala' ? 'ආසන්නයි!' : 'Almost!')
            : (AppState.language == 'sinhala' ? 'නැවත උත්සාහ කරන්න' : 'Try Again');

    final canAdvance = isOk || _attempt >= 2;

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
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  // Coaching hint for non-passing results
                  if (!isOk &&
                      _coaching != null &&
                      _coaching!.buddyMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _coaching!.buddyMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (isOk || isAlmost) ...[
                    const SizedBox(height: 10),
                    _buildStars(result.stars),
                  ],
                  if (result.xpEarned > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '+${result.xpEarned} XP',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isOk ? AppColors.pronunciation : AppColors.almost,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (canAdvance)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _wordIndex < _totalWords - 1
                            ? (AppState.language == 'sinhala' ? 'ඊළඟ →' : 'Next →')
                            : (AppState.language == 'sinhala' ? 'අවසන් කරන්න ✓' : 'Finish ✓'),
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

class _Waveform extends StatelessWidget {
  final bool active;
  final double progress;

  const _Waveform({required this.active, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(
            AppState.language == 'sinhala'
                ? 'බොත්තම ස්පර්ශ කර කතා කරන්'
                : 'Hold the button and speak',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (i) {
          final h = 8 + 24 * (0.5 + 0.5 * sin((progress * 2 * pi) + i * 0.6)).abs();
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 4,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.pronunciation,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
