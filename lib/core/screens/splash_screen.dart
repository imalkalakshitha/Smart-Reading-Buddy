import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/core/models/app_text.dart';
import 'package:smart_reading_buddy/core/models/local_storage.dart';
import 'package:smart_reading_buddy/core/router/app_router.dart';
import 'package:smart_reading_buddy/core/widgets/loading_dots.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  bool _showDots = false;
  bool _showProgress = false;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _runSequence();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSequence() async {
    // 1400ms: show loading dots
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _showDots = true);

    // 1800ms: start progress bar
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _showProgress = true);
    _progressCtrl.forward();

    // 2600ms: navigate
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final language = await LocalStorage.getLanguage();
    if (!mounted) return;

    if (language == null) {
      Navigator.pushReplacementNamed(context, AppRouter.language);
    } else {
      AppState.setLanguage(language);
      Navigator.pushReplacementNamed(context, AppRouter.profiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Center content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Owl in green circle — scales in with elastic bounce
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x402ECC71),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text('🦉', style: TextStyle(fontSize: 64)),
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      ),

                  const SizedBox(height: 28),

                  // App name
                  Text(
                    'Smart Reading Buddy',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    '${AppText.learningIsFun} / Learning is fun!',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate(delay: 1000.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),

                  // Loading dots
                  AnimatedOpacity(
                    opacity: _showDots ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: const LoadingDots(),
                  ),
                ],
              ),
            ),

            // Progress bar at very bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _progressCtrl,
                builder: (_, __) => LinearProgressIndicator(
                  value: _showProgress ? _progressCtrl.value : 0,
                  minHeight: 4,
                  backgroundColor: AppColors.divider,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
