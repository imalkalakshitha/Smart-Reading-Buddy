import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/core/router/app_router.dart';
import 'package:smart_reading_buddy/features/pronunciation/services/calibration_service.dart';
import 'package:smart_reading_buddy/features/pronunciation/services/stt_pronunciation_scorer.dart';

// ── Calibration word definitions ──────────────────────────────────────────────

class _CalWord {
  final String word;   // must match asset filename (romanised for Sinhala)
  final String display; // shown on screen (Sinhala script if needed)
  final String emoji;
  const _CalWord(this.word, this.display, this.emoji);
}

const _wordsEn = [
  _CalWord('cat',  'cat',  '🐱'),
  _CalWord('dog',  'dog',  '🐶'),
  _CalWord('sun',  'sun',  '☀️'),
  _CalWord('fish', 'fish', '🐟'),
  _CalWord('pen',  'pen',  '✏️'),
  // extras in case some references are missing
  _CalWord('hat',  'hat',  '🎩'),
  _CalWord('cup',  'cup',  '☕'),
];

const _wordsSi = [
  _CalWord('gama', 'ගම',  '🏘️'),
  _CalWord('eka',  'එක',  '1️⃣'),
  _CalWord('kata', 'කට',  '👄'),
  _CalWord('pata', 'පත',  '📄'),
  _CalWord('mala', 'මල',  '🌸'),
  _CalWord('naya', 'නය',  '🐍'),
  _CalWord('tama', 'තම',  '🌿'),
];

const _targetWords = 5; // how many successful recordings we need

// ── Screen ────────────────────────────────────────────────────────────────────

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

enum _Phase { ready, listening, recording, scored, done }

class _CalibrationScreenState extends State<CalibrationScreen> {
  final _player = AudioPlayer();

  late final List<_CalWord> _candidates;
  int _candidateIdx = 0;
  int _successCount = 0;

  // calibration data collected so far
  final _collected = <({double dtw, double rawThreshold})>[];

  _Phase _phase = _Phase.ready;
  String _buddyMsg = 'Listen to the word first, then say it!';
  bool _saving = false;

  String get _lang =>
      AppState.language.toLowerCase().startsWith('s') ? 'si' : 'en';
  int get _gradeNum => AppState.grade == 'grade4' ? 4 : 3;

  _CalWord get _current => _candidates[_candidateIdx];

  @override
  void initState() {
    super.initState();
    _candidates = _lang == 'si' ? [..._wordsSi] : [..._wordsEn];
    _setBuddyMsg('Listen to the word first, then say it! 🎧');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setBuddyMsg(String msg) => setState(() => _buddyMsg = msg);

  // ── Audio playback ──────────────────────────────────────────────────────────

  Future<void> _playWord() async {
    if (_phase == _Phase.recording) return;
    setState(() => _phase = _Phase.listening);
    try {
      final assetPath =
          'audio/words/$_lang/grade$_gradeNum/${_current.word}.mp3';
      await _player.play(AssetSource(assetPath));
      await _player.onPlayerComplete.first;
    } catch (_) {
      // asset might not exist — just continue
    }
    if (mounted) setState(() => _phase = _Phase.ready);
  }

  // ── Recording ───────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_phase == _Phase.recording) return;
    setState(() {
      _phase = _Phase.recording;
      _buddyMsg = 'Say it now! 🎤';
    });
    await SttPronunciationScorer.startRecording(lang: _lang);
  }

  Future<void> _stopRecording() async {
    if (_phase != _Phase.recording) return;
    setState(() => _phase = _Phase.scored);

    final result = await SttPronunciationScorer.stopAndGetCalibrationScore(
      word:     _current.word,
      lang:     _lang,
      gradeNum: _gradeNum,
    );

    if (result != null) {
      _collected.add(result);
      await CalibrationService.recordScore(
        profileName:  AppState.name,
        word:         _current.word,
        dtwScore:     result.dtw,
        rawThreshold: result.rawThreshold,
      );
      _successCount++;
      _setBuddyMsg('Great job! 🌟');
    } else {
      _setBuddyMsg('Hmm, I didn\'t hear that. Try again! 📢');
    }

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    if (_successCount >= _targetWords) {
      await _finish();
    } else {
      _nextWord(result != null);
    }
  }

  void _nextWord(bool wasSuccess) {
    // advance to the next candidate; if no success, stay on same display idx
    // but move to next candidate to try a different word
    _candidateIdx++;
    if (_candidateIdx >= _candidates.length) {
      // ran out of candidates — finish with what we have
      _finish();
      return;
    }
    setState(() {
      _phase = _Phase.ready;
      _buddyMsg = wasSuccess
          ? 'Keep going! Next word... 🎉'
          : 'Let\'s try another word! 🌈';
    });
  }

  Future<void> _finish() async {
    setState(() {
      _phase = _Phase.done;
      _saving = true;
      _buddyMsg = 'Calculating your voice profile... ✨';
    });

    await CalibrationService.calculateAndSave(
      profileName: AppState.name,
      data: _collected,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      _buddyMsg = 'All done! Your voice is set up! 🎊';
    });

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
        context, AppRouter.home, (r) => false);
  }

  void _skipWord() {
    _nextWord(false);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Voice Setup 🎤',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _phase == _Phase.done
              ? _buildDone()
              : _buildCalibration(),
        ),
      ),
    );
  }

  // ── Done state ──────────────────────────────────────────────────────────────

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎊', style: TextStyle(fontSize: 80))
              .animate()
              .scale(curve: Curves.elasticOut, duration: 600.ms),
          const SizedBox(height: 24),
          Text(
            _saving ? 'Saving...' : 'You\'re all set!',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _buddyMsg,
            style: GoogleFonts.nunito(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_saving) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ],
      ),
    );
  }

  // ── Calibration word flow ───────────────────────────────────────────────────

  Widget _buildCalibration() {
    final progress = _successCount / _targetWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress bar + label
        _buildProgressRow(progress),
        const SizedBox(height: 20),

        // Buddy card
        _BuddyCard(message: _buddyMsg),
        const SizedBox(height: 24),

        // Word card
        Expanded(child: _buildWordCard()),
        const SizedBox(height: 20),

        // Action buttons
        _buildButtons(),
        const SizedBox(height: 12),

        // Skip
        if (_phase != _Phase.recording && _phase != _Phase.scored)
          Center(
            child: TextButton(
              onPressed: _skipWord,
              child: Text(
                'Skip this word',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProgressRow(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Word $_successCount of $_targetWords',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(_successCount / _targetWords * 100).round()}%',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.primaryLight,
            valueColor:
                const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _current.emoji,
            style: const TextStyle(fontSize: 90),
          ).animate(key: ValueKey(_candidateIdx)).scale(
                duration: 400.ms,
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 16),
          Text(
            _current.display,
            style: GoogleFonts.nunito(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ).animate(key: ValueKey('w$_candidateIdx')).fadeIn(),
          const SizedBox(height: 8),
          // Volume indicator while recording
          if (_phase == _Phase.recording)
            _VolumeIndicator()
                .animate()
                .fadeIn(duration: 200.ms),
          // Result indicator
          if (_phase == _Phase.scored)
            _ResultIcon(success: _collected.length == _successCount)
                .animate()
                .scale(curve: Curves.elasticOut, duration: 500.ms),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        // Listen button
        Expanded(
          child: _ActionButton(
            label: 'Listen',
            icon: Icons.volume_up_rounded,
            color: AppColors.accentBlue,
            enabled: _phase != _Phase.recording && _phase != _Phase.scored,
            onTap: _playWord,
          ),
        ),
        const SizedBox(width: 16),
        // Record button
        Expanded(
          flex: 2,
          child: _RecordButton(
            phase: _phase,
            onStart: _startRecording,
            onStop: _stopRecording,
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BuddyCard extends StatelessWidget {
  final String message;
  const _BuddyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.primaryLight, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD166),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🦉', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final _Phase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _RecordButton({
    required this.phase,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = phase == _Phase.recording;
    final busy = phase == _Phase.scored || phase == _Phase.listening;

    return GestureDetector(
      onTap: busy ? null : (isRecording ? onStop : onStart),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          color: busy
              ? Colors.grey.shade300
              : isRecording
                  ? AppColors.danger
                  : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: busy
              ? []
              : [
                  BoxShadow(
                    color: (isRecording ? AppColors.danger : AppColors.primary)
                        .withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: busy ? Colors.grey : Colors.white,
              size: 26,
            ),
            const SizedBox(width: 8),
            Text(
              isRecording ? 'Stop' : 'Say it!',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: busy ? Colors.grey : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: StreamBuilder<double>(
        stream: SttPronunciationScorer.amplitudeStream,
        builder: (context, snap) {
          final level = snap.data ?? 0.0;
          final loud = level > 0.25;
          return Column(
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
              const SizedBox(height: 6),
              Text(
                loud ? 'Good volume! 🎤' : 'Speak louder! 📢',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: loud ? AppColors.success : Colors.orange,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultIcon extends StatelessWidget {
  final bool success;
  const _ResultIcon({required this.success});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: success ? AppColors.success : AppColors.almost,
          shape: BoxShape.circle,
        ),
        child: Icon(
          success ? Icons.check_rounded : Icons.refresh_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}
