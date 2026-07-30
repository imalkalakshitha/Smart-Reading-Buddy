import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/reading_sentence.dart';
import '../../services/ble_command_service.dart';

// ── Performance data ───────────────────────────────────────────────────────────

enum _Perf { excellent, good, slow, verySlow }

class _Result {
  final Duration timeTaken;
  final int wordCount;
  final double expectedSecs;
  final double wpm;
  final _Perf perf;
  final String buddyCmd;

  _Result({
    required this.timeTaken,
    required this.wordCount,
    required this.expectedSecs,
  })  : wpm = _calcWpm(wordCount, timeTaken),
        perf = _calcPerf(timeTaken.inMilliseconds / 1000, expectedSecs),
        buddyCmd = _calcCmd(timeTaken.inMilliseconds / 1000, expectedSecs);

  static double _calcWpm(int words, Duration t) {
    if (t.inMilliseconds == 0) return 0;
    return words / (t.inMilliseconds / 1000) * 60;
  }

  static _Perf _calcPerf(double actual, double expected) {
    final r = actual / expected;
    if (r <= 0.8) return _Perf.excellent;
    if (r <= 1.2) return _Perf.good;
    if (r <= 1.5) return _Perf.slow;
    return _Perf.verySlow;
  }

  static String _calcCmd(double actual, double expected) {
    final r = actual / expected;
    if (r <= 0.8) return 'PLAY_EXCELLENT';
    if (r <= 1.2) return 'PLAY_GOOD';
    if (r <= 1.5) return 'PLAY_FAST';
    return 'PLAY_SLOW';
  }

  bool get isPositive =>
      perf == _Perf.excellent || perf == _Perf.good;

  String stars() {
    switch (perf) {
      case _Perf.excellent: return '⭐⭐⭐';
      case _Perf.good:      return '⭐⭐';
      case _Perf.slow:      return '⭐';
      case _Perf.verySlow:  return '';
    }
  }

  String feedback(bool si) {
    switch (perf) {
      case _Perf.excellent:
        return si ? 'නියමයි! ⭐⭐⭐ ඉතා වේගයෙන්!' : 'Excellent! ⭐⭐⭐ Super fast!';
      case _Perf.good:
        return si ? 'හොඳයි! ⭐⭐ දිගටම කරගෙන යන්න!' : 'Good job! ⭐⭐ Keep it up!';
      case _Perf.slow:
        return si ? 'තව වේගයෙන් කියවන්න! 💪' : 'Try reading a bit faster! 💪';
      case _Perf.verySlow:
        return si ? 'නැවත උත්සාහ කරන්න! 🎯' : 'Take your time, then try again! 🎯';
    }
  }

  String timeStr() {
    final s = timeTaken.inSeconds;
    final ms = (timeTaken.inMilliseconds % 1000) ~/ 100;
    return '$s.${ms}s';
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class TimedReadingScreen extends StatefulWidget {
  final TimedReadingArgs args;
  const TimedReadingScreen({super.key, required this.args});

  @override
  State<TimedReadingScreen> createState() => _TimedReadingScreenState();
}

class _TimedReadingScreenState extends State<TimedReadingScreen> {
  final _ble = BleCommandService.instance;
  final _player = AudioPlayer();
  final _tts = FlutterTts();

  late List<ReadingSentence> _sentences;
  int _index = 0;
  int _attempt = 1;

  Timer? _ticker;
  int _elapsedMs = 0;
  bool _running = false;
  bool _speaking = false;

  _Result? _result;
  int? _firstAttemptMs;

  bool get _si => widget.args.language == 'si';

  // Minimum ms before DONE is accepted (30% of expected time, floor 2s)
  int get _minMs =>
      (_current.expectedTimeSeconds * 0.30 * 1000).toInt().clamp(2000, 99999);

  @override
  void initState() {
    super.initState();
    _sentences = SentenceDatabase.getByLanguageAndDifficulty(
      widget.args.language,
      widget.args.difficulty,
    );
    if (_sentences.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
    }
    _initAudio();
  }

  Future<void> _initAudio() async {
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _speaking = false);
    });
    await _tts.setLanguage(_si ? 'si-LK' : 'en-US');
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  Future<void> _speak() async {
    if (_running) return;
    if (_speaking) {
      await _stopAudio();
      return;
    }
    setState(() => _speaking = true);
    final path = _current.audioPath;
    if (path != null) {
      try {
        await _player.play(AssetSource(path.replaceFirst('assets/', '')));
        return;
      } catch (_) {}
    }
    // fallback to TTS
    await _tts.speak(_current.text);
  }

  Future<void> _stopAudio() async {
    await _player.stop();
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _player.dispose();
    _tts.stop();
    super.dispose();
  }

  ReadingSentence get _current => _sentences[_index];

  // ── Timer control ──────────────────────────────────────────────────────────

  void _start() {
    _stopAudio();
    setState(() {
      _elapsedMs = 0;
      _running = true;
      _result = null;
      _speaking = false;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _elapsedMs += 100);
    });
    _ble.send('PLAY_START');
  }

  void _stop() {
    if (_elapsedMs < _minMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _si
                ? 'වාක්‍යය කියවා ඉවර කරන්න!'
                : 'Finish reading the sentence first!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.wrong,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    final taken = Duration(milliseconds: _elapsedMs);
    final r = _Result(
      timeTaken: taken,
      wordCount: _current.wordCount,
      expectedSecs: _current.expectedTimeSeconds,
    );
    _firstAttemptMs ??= _elapsedMs;
    setState(() {
      _running = false;
      _result = r;
    });
    _ble.send(r.buddyCmd);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _tryAgain() {
    setState(() {
      _attempt++;
      _elapsedMs = 0;
      _result = null;
    });
  }

  void _next() {
    _stopAudio();
    if (_index < _sentences.length - 1) {
      _ble.send('PLAY_NEXT');
      setState(() {
        _index++;
        _attempt = 1;
        _elapsedMs = 0;
        _result = null;
        _firstAttemptMs = null;
        _speaking = false;
      });
    } else {
      _ble.send('PLAY_COMPLETE');
      Navigator.pop(context);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _timerLabel() {
    final s = _elapsedMs ~/ 1000;
    final ds = (_elapsedMs % 1000) ~/ 100;
    return '$s.$ds';
  }

  String? _improvement() {
    final first = _firstAttemptMs;
    final cur = _result?.timeTaken.inMilliseconds;
    if (first == null || cur == null || _attempt < 2) return null;
    final pct = ((first - cur) / first * 100).abs();
    return cur < first
        ? '↑ ${pct.toStringAsFixed(1)}% ${_si ? "වේගවත්" : "faster"}'
        : '↓ ${pct.toStringAsFixed(1)}% ${_si ? "මන්දගාමී" : "slower"}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_sentences.isEmpty) return const Scaffold(body: SizedBox());

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6B8A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_si ? "වාක්‍යය" : "Sentence"} ${_index + 1}/${_sentences.length}',
          style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _ble.connected,
            builder: (_, conn, __) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Icon(
                    conn
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: Colors.white.withOpacity(conn ? 1.0 : 0.45),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Buddy',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: Colors.white.withOpacity(conn ? 1.0 : 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Attempt badge
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_si ? "උත්සාහය" : "Attempt"} $_attempt',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sentence card
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _current.text,
                          style: GoogleFonts.nunito(
                            fontSize: _si ? 22 : 24,
                            height: 1.7,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Hear-it button (disabled while timer is running)
                        AnimatedOpacity(
                          opacity: _running ? 0.3 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: GestureDetector(
                            onTap: _speak,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: _speaking
                                    ? AppColors.primary
                                    : AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _speaking
                                        ? Icons.stop_rounded
                                        : Icons.volume_up_rounded,
                                    color: _speaking
                                        ? Colors.white
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _speaking
                                        ? (_si ? 'නවතන්න' : 'Stop')
                                        : (_si ? 'අසන්න' : 'Hear it'),
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _speaking
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(
                    begin: const Offset(0.95, 0.95),
                    curve: Curves.easeOut,
                    duration: 300.ms,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Timer display
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _running
                        ? AppColors.primary
                        : AppColors.divider,
                    width: 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_running)
                      const Icon(Icons.timer_rounded,
                          color: AppColors.primary, size: 28),
                    if (_running) const SizedBox(width: 8),
                    Text(
                      _timerLabel(),
                      style: GoogleFonts.nunito(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: _running
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      's',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _running
                            ? AppColors.primaryLight
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Control button
              if (!_running && _result == null)
                _BigButton(
                  label: _si ? 'START' : 'START READING',
                  icon: Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  onTap: _start,
                ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.elasticOut,
                  duration: 500.ms,
                ),

              if (_running)
                _BigButton(
                  label: _si ? 'ඉවරයි!' : 'I\'M DONE!',
                  icon: Icons.stop_rounded,
                  color: AppColors.wrong,
                  onTap: _stop,
                ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.elasticOut,
                  duration: 400.ms,
                ),

              // Result card
              if (_result != null) ...[
                _ResultCard(
                  result: _result!,
                  isSinhala: _si,
                  improvement: _improvement(),
                ).animate().slideY(begin: 0.3, curve: Curves.easeOut),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _tryAgain,
                        icon: const Icon(Icons.replay_rounded),
                        label: Text(
                          _si ? 'නැවත' : 'Try Again',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A6B8A),
                          side: const BorderSide(color: Color(0xFF1A6B8A), width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          _index < _sentences.length - 1
                              ? (_si ? 'ඊළඟ →' : 'Next →')
                              : (_si ? 'අවසන් ✓' : 'Finish ✓'),
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6B8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 30),
        label: Text(
          label,
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
          shadowColor: color.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _Result result;
  final bool isSinhala;
  final String? improvement;

  const _ResultCard({
    required this.result,
    required this.isSinhala,
    this.improvement,
  });

  @override
  Widget build(BuildContext context) {
    final bg = result.isPositive
        ? const Color(0xFFE1F5EE)
        : const Color(0xFFFFF3E0);
    final accent = result.isPositive ? AppColors.success : AppColors.almost;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            result.feedback(isSinhala),
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                label: isSinhala ? 'වේගය' : 'Speed',
                value: '${result.wpm.toStringAsFixed(1)} WPM',
                color: accent,
              ),
              _StatChip(
                label: isSinhala ? 'කාලය' : 'Time',
                value: result.timeStr(),
                color: accent,
              ),
            ],
          ),
          if (improvement != null) ...[
            const SizedBox(height: 8),
            Text(
              improvement!,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
