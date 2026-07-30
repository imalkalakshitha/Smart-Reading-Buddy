import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../data/reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';
import '../../services/ble_command_service.dart';
import '../../services/reading_session_logger.dart';
import '../../services/reading_timer_service.dart';

// ── Session state machine ──────────────────────────────────────────────────────

enum _SessionState { idle, recording, result }

enum _ResultKind { fast, ok, slow }

// ── Screen ────────────────────────────────────────────────────────────────────

class ReadingSessionScreen extends StatefulWidget {
  final ReadingSessionArgs args;
  const ReadingSessionScreen({super.key, required this.args});

  @override
  State<ReadingSessionScreen> createState() => _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends State<ReadingSessionScreen>
    with SingleTickerProviderStateMixin {
  // ── Progress ──────────────────────────────────────────────────────────────
  int _sentenceIndex = 0;
  final List<SentenceResult> _results = [];

  // ── Session state ─────────────────────────────────────────────────────────
  _SessionState _state = _SessionState.idle;
  _ResultKind _resultKind = _ResultKind.ok;
  int _wordIndex = 0;
  int _elapsedMs = 0;
  int _buddyPromptsThisSentence = 0;
  String? _lastBleCommand;

  // ── Services ──────────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  final _tts = FlutterTts();
  bool _isSpeaking = false;

  // ── Timers ────────────────────────────────────────────────────────────────
  final _stopwatch = Stopwatch();
  Timer? _elapsedTimer;
  Timer? _wordTimer;
  Timer? _checkTimer;

  // ── Mic pulse animation ───────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Derived ───────────────────────────────────────────────────────────────
  String get _sentence      => widget.args.sentences[_sentenceIndex];
  List<String> get _words   => _sentence.split(' ');
  int get _wordCount        => _words.length;
  int get _expectedMs       => ReadingTimerService.expectedMs(_wordCount);
  int get _fastMs           => ReadingTimerService.fastThresholdMs(_wordCount);
  int get _slowMs           => ReadingTimerService.slowThresholdMs(_wordCount);
  int get _totalSentences   => widget.args.sentences.length;
  bool get _isSi            => AppState.language == 'sinhala';
  bool get _isLastSentence  => _sentenceIndex == _totalSentences - 1;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initTts();
  }

  @override
  void dispose() {
    _cancelTimers();
    _pulseCtrl.dispose();
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── TTS setup ─────────────────────────────────────────────────────────────

  Future<void> _initTts() async {
    await _tts.setLanguage(_isSi ? 'si-LK' : 'en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _toggleSpeak() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(_sentence);
  }

  // ── Mic recording ─────────────────────────────────────────────────────────

  Future<void> _onMicDown() async {
    if (_state == _SessionState.idle) {
      await _startRecording();
    }
  }

  Future<void> _onMicUp() async {
    if (_state == _SessionState.recording) {
      await _stopRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            _isSi
                ? 'මයික්‍රෝෆෝන් අවසරය ලබා දෙන්න'
                : 'Please allow microphone access in settings',
            style: GoogleFonts.nunito(color: Colors.white),
          ),
          backgroundColor: AppColors.wrong,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/srb_reading_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
      path: path,
    );

    _stopwatch
      ..reset()
      ..start();

    _pulseCtrl.repeat(reverse: true);

    setState(() {
      _state = _SessionState.recording;
      _wordIndex = 0;
      _elapsedMs = 0;
      _buddyPromptsThisSentence = 0;
    });

    _ble('PLAY_START');
    _startTimers();
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    _stopwatch.stop();
    _cancelTimers();
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    final elapsed = _stopwatch.elapsedMilliseconds;
    final kind = elapsed <= _fastMs
        ? _ResultKind.fast
        : elapsed <= _expectedMs
            ? _ResultKind.ok
            : _ResultKind.slow;

    final wasFast = kind == _ResultKind.fast || kind == _ResultKind.ok;

    _results.add(SentenceResult(
      sentence: _sentence,
      timeTakenMs: elapsed,
      wasFast: wasFast,
      buddyPromptsCount: _buddyPromptsThisSentence,
    ));

    _ble('PLAY_NEXT');
    if (wasFast) _ble('GOOD_JOB');

    setState(() {
      _elapsedMs = elapsed;
      _resultKind = kind;
      _state = _SessionState.result;
    });
  }

  // ── Timer helpers ─────────────────────────────────────────────────────────

  void _startTimers() {
    // Refresh elapsed display every 100 ms
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs = _stopwatch.elapsedMilliseconds);
    });

    // Slow-threshold check every 500 ms
    _checkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_stopwatch.elapsedMilliseconds >= _slowMs &&
          _buddyPromptsThisSentence == 0) {
        _buddyPromptsThisSentence++;
        _ble('PLAY_FAST');
      }
    });

    // Word highlight advance
    final interval = ReadingTimerService.wordIntervalMs(_wordCount);
    _wordTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
      if (!mounted) return;
      setState(() {
        if (_wordIndex < _wordCount - 1) _wordIndex++;
      });
    });
  }

  void _cancelTimers() {
    _elapsedTimer?.cancel();
    _checkTimer?.cancel();
    _wordTimer?.cancel();
    _elapsedTimer = null;
    _checkTimer = null;
    _wordTimer = null;
  }

  void _ble(String cmd) {
    BleCommandService.instance.send(cmd);
    setState(() => _lastBleCommand = cmd);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _resetForRepeat() {
    setState(() {
      _state = _SessionState.idle;
      _wordIndex = 0;
      _elapsedMs = 0;
      _buddyPromptsThisSentence = 0;
      _lastBleCommand = null;
    });
  }

  void _onNext() {
    if (_isLastSentence) {
      _finish();
      return;
    }
    setState(() {
      _sentenceIndex++;
      _state = _SessionState.idle;
      _wordIndex = 0;
      _elapsedMs = 0;
      _buddyPromptsThisSentence = 0;
      _lastBleCommand = null;
    });
  }

  void _finish() {
    ReadingSessionLogger.save(
      grade: widget.args.grade,
      level: widget.args.level,
      levelName: widget.args.levelName,
      results: _results,
    );
    Navigator.pushReplacementNamed(
      context,
      AppRouter.readingComplete,
      arguments: ReadingCompleteArgs(
        results: _results,
        grade: widget.args.grade,
        level: widget.args.level,
        levelName: widget.args.levelName,
        sentences: widget.args.sentences,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_sentenceIndex + 1) / _totalSentences,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation(AppColors.reading),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    // Result banner
                    if (_state == _SessionState.result) ...[
                      _buildResultBanner(),
                      const SizedBox(height: 14),
                    ],

                    // Sentence card
                    _buildSentenceCard(),
                    const SizedBox(height: 16),

                    // Time comparison
                    _buildTimeRow(),
                    const SizedBox(height: 20),

                    // Mic button (idle + recording)
                    if (_state != _SessionState.result) ...[
                      _buildMicButton(),
                      const SizedBox(height: 20),
                    ],

                    // Speed chips
                    _buildSpeedChips(),
                    const SizedBox(height: 20),

                    // Action buttons
                    _buildButtons(),
                    const SizedBox(height: 20),

                    // Buddy card
                    _buildBuddyCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.reading, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          '${_isSi ? 'වාක්‍යය' : 'Sentence'} ${_sentenceIndex + 1} / $_totalSentences',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.reading,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        // BLE command badge
        if (_lastBleCommand != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _BleBadge(command: _lastBleCommand!),
            ),
          ),
      ],
    );
  }

  // ── Result banner ─────────────────────────────────────────────────────────

  Widget _buildResultBanner() {
    final (label, color, icon) = switch (_resultKind) {
      _ResultKind.fast => (
          _isSi ? 'නියමයි!' : 'Well Done!',
          AppColors.primary,
          '⭐',
        ),
      _ResultKind.ok => (
          _isSi ? 'හොඳයි!' : 'Good job!',
          AppColors.reading,
          '👍',
        ),
      _ResultKind.slow => (
          _isSi ? 'නැවත උත්සාහ කරන්න' : 'Try Again',
          const Color(0xFFE67E22),
          '🔄',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().scale(
          begin: const Offset(0.85, 0.85),
          curve: Curves.elasticOut,
          duration: 500.ms,
        );
  }

  // ── Sentence card ─────────────────────────────────────────────────────────

  Widget _buildSentenceCard() {
    final resultColor = switch (_resultKind) {
      _ResultKind.fast => AppColors.primary,
      _ResultKind.ok   => AppColors.reading,
      _ResultKind.slow => const Color(0xFFE67E22),
    };

    // highlight color changes by state
    Color wordHighlight() {
      if (_state == _SessionState.idle) return AppColors.reading;
      if (_state == _SessionState.recording) return AppColors.reading;
      return resultColor;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(_sentenceIndex),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TTS button row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _toggleSpeak,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isSpeaking
                          ? AppColors.reading.withValues(alpha: 0.15)
                          : const Color(0xFFF0F4FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      color: AppColors.reading,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Sentence with word highlighting
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: _words.asMap().entries.map((e) {
                  final idx = e.key;
                  final word = e.value;
                  final active = idx == _wordIndex;
                  return TextSpan(
                    text: idx < _words.length - 1 ? '$word ' : word,
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.75,
                      color: active
                          ? wordHighlight()
                          : AppColors.textPrimary,
                      backgroundColor: active
                          ? wordHighlight().withValues(alpha: 0.13)
                          : Colors.transparent,
                      decoration: active && _state == _SessionState.recording
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: wordHighlight(),
                      decorationThickness: 2,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Progress bar (result state only)
            if (_state == _SessionState.result) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_elapsedMs / _slowMs).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(resultColor),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSi ? 'ඉලක්ක කාලය' : 'Target',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  Text(
                    _isSi ? 'හෙමින්' : 'Too slow',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Time row ──────────────────────────────────────────────────────────────

  Widget _buildTimeRow() {
    final actualSecs = (_elapsedMs / 1000).toStringAsFixed(1);
    final expectedSecs = (_expectedMs / 1000).toStringAsFixed(1);

    final actualColor = _state != _SessionState.result
        ? AppColors.textSecondary
        : switch (_resultKind) {
            _ResultKind.fast => AppColors.primary,
            _ResultKind.ok   => AppColors.reading,
            _ResultKind.slow => AppColors.wrong,
          };

    final actualBg = _state != _SessionState.result
        ? Colors.white
        : switch (_resultKind) {
            _ResultKind.fast => const Color(0xFFE8F8EF),
            _ResultKind.ok   => const Color(0xFFE8F2FB),
            _ResultKind.slow => const Color(0xFFFDECEA),
          };

    return Row(
      children: [
        Expanded(
          child: _TimeCard(
            label: _isSi ? 'අපේක්ෂිත' : 'Expected',
            value: '${expectedSecs}s',
            valueColor: AppColors.reading,
            bgColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TimeCard(
            label: _isSi ? 'ඔබේ කාලය' : 'Actual',
            value: _elapsedMs == 0 ? '0s' : '${actualSecs}s',
            valueColor: actualColor,
            bgColor: actualBg,
          ),
        ),
      ],
    );
  }

  // ── Mic button ────────────────────────────────────────────────────────────

  Widget _buildMicButton() {
    final isRecording = _state == _SessionState.recording;
    final btnColor = isRecording ? AppColors.wrong : AppColors.reading;

    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => _onMicDown(),
          onTapUp: (_) => _onMicUp(),
          onTapCancel: () => _onMicUp(),
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: isRecording ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: btnColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: btnColor.withValues(alpha: 0.4),
                    blurRadius: isRecording ? 24 : 14,
                    spreadRadius: isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isRecording
              ? (_isSi ? 'කියවමින් රඳවා ගන්න — ඇඟිල්ල ඉවත් කර නවත්වන්න' : 'Hold while reading — lift to stop')
              : (_isSi ? 'මයිකය ඔබාගෙන කියවන්න' : 'Hold mic and read aloud'),
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── Speed chips ───────────────────────────────────────────────────────────

  Widget _buildSpeedChips() {
    final chips = [
      (
        _isSi ? 'හොඳ කියවීම!' : 'Good Reading!',
        AppColors.primary,
        _state == _SessionState.result
            ? (_resultKind == _ResultKind.fast || _resultKind == _ResultKind.ok)
            : _state == _SessionState.recording && _elapsedMs <= _expectedMs,
      ),
      (
        _isSi ? 'නැවත උත්සාහ' : 'Try Again',
        const Color(0xFFE67E22),
        _state == _SessionState.result && _resultKind == _ResultKind.slow,
      ),
      (
        _isSi ? 'වේගෙන් කියවන්න!' : 'Read Faster!',
        AppColors.wrong,
        _state == _SessionState.recording && _elapsedMs > _slowMs,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: chips.map((c) {
        final active = c.$3;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? c.$2.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: active ? c.$2 : AppColors.divider,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            c.$1,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? c.$2 : AppColors.textHint,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildButtons() {
    final isSlow = _resultKind == _ResultKind.slow && _state == _SessionState.result;
    final nextActive = _state == _SessionState.result;

    if (isSlow) {
      // Slow: repeat full width, next grayed beneath
      return Column(
        children: [
          _btn(
            label: _isSi ? '🔁 නැවත කියවන්න' : '🔁 Repeat Reading',
            color: const Color(0xFFE67E22),
            onTap: _resetForRepeat,
          ),
          const SizedBox(height: 10),
          _btn(
            label: _isSi
                ? (_isLastSentence ? 'අවසන් කරන්න' : 'ඊළඟ →')
                : (_isLastSentence ? 'Finish' : 'Next Sentence →'),
            color: AppColors.textHint,
            onTap: _onNext,
          ),
        ],
      );
    }

    // Normal layout: repeat + next side by side
    return Row(
      children: [
        // Repeat
        GestureDetector(
          onTap: _state == _SessionState.recording ? null : _resetForRepeat,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.reading.withValues(alpha: 0.4)),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.replay_rounded,
              color: _state == _SessionState.recording
                  ? AppColors.textHint
                  : AppColors.reading,
              size: 26,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Next / Finish
        Expanded(
          child: GestureDetector(
            onTap: nextActive ? _onNext : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: nextActive ? AppColors.reading : AppColors.divider,
                borderRadius: BorderRadius.circular(16),
                boxShadow: nextActive
                    ? [
                        BoxShadow(
                          color: AppColors.reading.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLastSentence
                        ? (_isSi ? 'අවසන් කරන්න' : 'Finish')
                        : (_isSi ? 'ඊළඟ වාක්‍යය' : 'Next Sentence'),
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: nextActive ? Colors.white : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: nextActive ? Colors.white : AppColors.textHint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _btn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Buddy card ────────────────────────────────────────────────────────────

  Widget _buildBuddyCard() {
    final (msg, color) = switch (_state) {
      _SessionState.idle => (
          _isSi
              ? 'මයිකය ඔබා කියවීම ආරම්භ කරන්න! 📖'
              : 'Tap the mic and start reading! 📖',
          AppColors.reading,
        ),
      _SessionState.recording => (
          _isSi ? 'Buddy ඇහෙනවා... දිගටම කියවන්න! 🎤' : 'Buddy is listening... Keep going! 🎤',
          AppColors.reading,
        ),
      _SessionState.result => switch (_resultKind) {
          _ResultKind.fast => (
              _isSi
                  ? 'නියමයි! ඔබ කියවීමේ තරුවක්! ⭐⭐⭐'
                  : 'Great job! You\'re a reading star! ⭐⭐⭐',
              AppColors.primary,
            ),
          _ResultKind.ok => (
              _isSi ? 'හොඳයි! දිගටම කරගෙන යන්න! 👍' : 'Good reading! Keep it up! 👍',
              AppColors.reading,
            ),
          _ResultKind.slow => (
              _isSi
                  ? 'නැවත උත්සාහ කරන්න! ඔබට කළ හැකිය! 💪'
                  : 'Let\'s try that one again! You can do it! 💪',
              const Color(0xFFE67E22),
            ),
        },
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🤖', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await _tts.speak(msg.replaceAll(RegExp(r'[⭐👍🎤📖💪🔄🤖]'), ''));
            },
            child: Icon(Icons.volume_up_rounded, color: color, size: 22),
          ),
        ],
      ),
    );
  }
}

// ── Time card widget ──────────────────────────────────────────────────────────

class _TimeCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color bgColor;

  const _TimeCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── BLE badge ─────────────────────────────────────────────────────────────────

class _BleBadge extends StatelessWidget {
  final String command;
  const _BleBadge({required this.command});

  Color get _color => switch (command) {
        'GOOD_JOB'   => AppColors.primary,
        'PLAY_FAST'  => AppColors.wrong,
        'PLAY_NEXT'  => AppColors.reading,
        _            => AppColors.textHint,
      };

  String get _label => switch (command) {
        'PLAY_START' => '▶ START',
        'PLAY_NEXT'  => '▶ NEXT',
        'PLAY_FAST'  => '⚡ FASTER',
        'GOOD_JOB'   => '⭐ GREAT',
        _            => command,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth_rounded, color: _color, size: 11),
          const SizedBox(width: 3),
          Text(
            _label,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _color,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
