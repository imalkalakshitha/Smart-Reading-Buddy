import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/services/ble_command_service.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/services/feature_builder.dart';

const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B7280);
const _kOrange = Color(0xFFE67E22);
const _kAmber = Color(0xFFF39C12);

/// Route: '/eduplay/result'. Args: EduPlaySessionResult result.
class SessionResultScreen extends StatefulWidget {
  final EduPlaySessionResult result;

  const SessionResultScreen({super.key, required this.result});

  @override
  State<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends State<SessionResultScreen> {
  EduPlaySessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget, same as every other BleCommandService call site —
    // no-ops safely if nothing's connected. result.language holds
    // 'Sinhala'/'English' (populated from ActivityScreen.widget.language,
    // same field activity_screen.dart's _bleLanguageCode already maps).
    final languageCode = result.language == 'Sinhala' ? 'SI' : 'EN';
    BleCommandService.instance.send('SESSION_END:$languageCode');
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = result.accuracyPct;
    final emoji = accuracy >= 80 ? '🌟' : (accuracy >= 60 ? '👍' : '💪');
    final bandColor = accuracy >= 80 ? AppColors.primary : (accuracy >= 60 ? _kAmber : _kOrange);

    final stars = accuracy == 100
        ? 3
        : accuracy >= 80
            ? 2
            : accuracy >= 60
                ? 1
                : 0;

    var xp = 10;
    if (accuracy >= 80) xp += 5;
    if (accuracy == 100) xp += 5;

    final minutes = (result.timeSpentSec ~/ 60).toString().padLeft(2, '0');
    final seconds = (result.timeSpentSec % 60).toInt().toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 84)),
              const SizedBox(height: 12),
              Text('Activity Complete!',
                  style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kTextPrimary)),
              const SizedBox(height: 20),
              Text('${accuracy.round()}%',
                  style: GoogleFonts.nunito(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: bandColor)),
              Text('Accuracy',
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
              const SizedBox(height: 8),
              Text('Time: $minutes:$seconds',
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(Icons.star_rounded, size: 40, color: i < stars ? _kAmber : const Color(0xFFE0E0E0)),
                  const SizedBox(width: 16),
                  const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 32),
                  Text(' $xp XP',
                      style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('Attempts', '${result.attemptCount}'),
                    _stat('Hints used', '${result.hintsUsed}'),
                    _stat('Audio replays', '${result.audioReplayCount}'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.settings.name == '/eduplay/dashboard' || route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Continue', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: _kTextPrimary)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _kTextSecondary)),
      ],
    );
  }
}
