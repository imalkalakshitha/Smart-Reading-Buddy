import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/app_colors.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartReadingBuddy());
}

class SmartReadingBuddy extends StatelessWidget {
  const SmartReadingBuddy({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Reading Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: GoogleFonts.nunitoTextTheme(),
        scaffoldBackgroundColor: AppColors.pageBg,
        useMaterial3: true,
      ),
      // Splash is always the entry point — it handles the routing logic
      initialRoute: AppRouter.splash,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
