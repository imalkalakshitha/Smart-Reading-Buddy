import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stub, per spec ("View full progress" → EduPlayProgressScreen, stub ok).
class EduPlayProgressScreen extends StatelessWidget {
  final String childId;

  const EduPlayProgressScreen({super.key, required this.childId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: Text('My Progress',
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: const Color(0xFF1A1A1A))),
      ),
      body: Center(
        child: Text('Full progress view coming soon.',
            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: const Color(0xFF6B7280))),
      ),
    );
  }
}
