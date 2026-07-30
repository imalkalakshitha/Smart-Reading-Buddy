import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/timed_reading_data.dart';
import '../../models/app_colors.dart';
import '../../models/app_state.dart';
import '../../router/app_router.dart';
import '../../services/ble_command_service.dart';

class TimedReadingLevelScreen extends StatefulWidget {
  const TimedReadingLevelScreen({super.key});

  @override
  State<TimedReadingLevelScreen> createState() =>
      _TimedReadingLevelScreenState();
}

class _TimedReadingLevelScreenState extends State<TimedReadingLevelScreen> {
  bool get _si => AppState.language == 'sinhala';
  final _ble = BleCommandService.instance;

  void _onConnect() {
    _ble.scanAndConnect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _si ? 'Buddy සොයමින්…' : 'Scanning for Buddy…',
          style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _launch(String difficulty) {
    final lang = AppState.language == 'sinhala' ? 'si' : 'en';
    Navigator.pushNamed(
      context,
      AppRouter.timedReadingSession,
      arguments: TimedReadingArgs(language: lang, difficulty: difficulty),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6B8A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _si ? '⏱️ කාලය නියම කළ කියවීම' : '⏱️ Timed Reading',
          style: GoogleFonts.nunito(
              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _ble.connected,
            builder: (_, conn, __) => IconButton(
              icon: Icon(
                conn ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                color: Colors.white,
              ),
              tooltip: conn
                  ? (_si ? 'Buddy සම්බන්ධයි' : 'Buddy Connected')
                  : (_si ? 'Buddy සොයන්න' : 'Find Buddy'),
              onPressed: conn ? null : _onConnect,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Text(
              _si ? 'අභ්‍යාස ලෙහෙසිකම තෝරන්න' : 'Select difficulty level',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),
            _DifficultyCard(
              icon: '🐢',
              label: _si ? 'ලෙහෙසි' : 'Easy',
              sublabel: _si ? 'කෙටි වාක්‍ය — 90 WPM ඉලක්කය'
                            : 'Short sentences — 90 WPM target',
              gradientColors: const [Color(0xFF56CCF2), Color(0xFF2F80ED)],
              delay: 150,
              onTap: () => _launch('short'),
            ),
            const SizedBox(height: 16),
            _DifficultyCard(
              icon: '🐇',
              label: _si ? 'මධ්‍යම' : 'Medium',
              sublabel: _si ? 'මධ්‍යම වාක්‍ය — 75 WPM ඉලක්කය'
                            : 'Medium sentences — 75 WPM target',
              gradientColors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
              delay: 250,
              onTap: () => _launch('medium'),
            ),
            const SizedBox(height: 16),
            _DifficultyCard(
              icon: '🦅',
              label: _si ? 'අභියෝගාත්මක' : 'Challenging',
              sublabel: _si ? 'දිගු වාක්‍ය — 60 WPM ඉලක්කය'
                            : 'Long sentences — 60 WPM target',
              gradientColors: const [Color(0xFFEB3349), Color(0xFFF45C43)],
              delay: 350,
              onTap: () => _launch('long'),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('ℹ️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _si
                          ? 'START ඔබා කියවා I\'M DONE! ඔබන්න. ඔබේ WPM ලකුණ දිස්වේ.'
                          : 'Tap START, read the sentence aloud, then tap I\'M DONE! to see your WPM score.',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 450.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatefulWidget {
  final String icon;
  final String label;
  final String sublabel;
  final List<Color> gradientColors;
  final int delay;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradientColors,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<_DifficultyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors[0].withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(widget.icon, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.sublabel,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: widget.delay.ms).fadeIn().slideX(begin: 0.3);
  }
}
