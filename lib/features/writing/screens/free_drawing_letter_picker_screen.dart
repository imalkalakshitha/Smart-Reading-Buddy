import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/core/dao/free_drawing_dao.dart';
import 'package:smart_reading_buddy/features/writing/data/free_drawing_cues.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/core/router/app_router.dart';
import 'package:smart_reading_buddy/features/writing/services/character_model_service.dart';
import 'package:smart_reading_buddy/features/writing/services/free_drawing_recognizer.dart';

/// Landing screen for Free Drawing Recognition, reached from the existing
/// home-screen "Written" button. A colourful grid of every letter in the
/// account language — read from class_names.json's real class order via
/// CharacterModelService, never hard-coded — so the child can tap
/// whichever letter they want instead of following a fixed sequence.
class FreeDrawingLetterPickerScreen extends StatefulWidget {
  const FreeDrawingLetterPickerScreen({super.key});

  @override
  State<FreeDrawingLetterPickerScreen> createState() => _FreeDrawingLetterPickerScreenState();
}

// Cycled through by tile index so the grid reads as lively and colourful
// rather than a uniform spreadsheet — soft/warm, not neon, to stay
// dyslexia-friendly (high contrast text over each, not busy patterns).
const List<Color> _kTilePalette = [
  Color(0xFFFF6B6B),
  Color(0xFFFFA94D),
  Color(0xFFFFD43B),
  Color(0xFF69DB7C),
  Color(0xFF4DD4C0),
  Color(0xFF4DABF7),
  Color(0xFF9775FA),
  Color(0xFFF783AC),
];

class _FreeDrawingLetterPickerScreenState extends State<FreeDrawingLetterPickerScreen> {
  bool _loading = true;
  List<String> _upper = [];
  List<String> _lower = []; // English only
  Set<String> _completed = {};

  bool get _isSinhala => AppState.language == 'sinhala';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await CharacterModelService.instance.load();
    final classNames = CharacterModelService.instance.classNames;

    List<String> upper;
    List<String> lower;
    if (_isSinhala) {
      upper = [for (int i = FreeDrawingRecognizer.siStart; i <= FreeDrawingRecognizer.siEnd; i++) classNames[i]];
      lower = [];
    } else {
      upper = [for (int i = FreeDrawingRecognizer.enStart; i <= 25; i++) classNames[i]];
      lower = [for (int i = 26; i <= FreeDrawingRecognizer.enEnd; i++) classNames[i]];
    }

    final completed = await FreeDrawingDao.getCompletedCharacters(
      profileName: AppState.name,
      language: _isSinhala ? 'si' : 'en',
    );

    if (!mounted) return;
    setState(() {
      _upper = upper;
      _lower = lower;
      _completed = completed;
      _loading = false;
    });
  }

  Future<void> _openLetter(String letter) async {
    await Navigator.pushNamed(context, AppRouter.freeDrawingLetterLevel, arguments: letter);
    if (!mounted) return;
    _load(); // refresh stars/ticks in case that visit finished the letter
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0), // warm, soft background
      appBar: AppBar(
        backgroundColor: AppColors.writing,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pick a Letter!'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_lower.isNotEmpty) _SectionLabel('Uppercase'),
                  _LetterGrid(letters: _upper, completed: _completed, colorOffset: 0, onTap: _openLetter),
                  if (_lower.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionLabel('Lowercase'),
                    _LetterGrid(letters: _lower, completed: _completed, colorOffset: _upper.length, onTap: _openLetter),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 6),
      child: Text(
        text,
        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
      ),
    );
  }
}

class _LetterGrid extends StatelessWidget {
  final List<String> letters;
  final Set<String> completed;
  final int colorOffset;
  final ValueChanged<String> onTap;

  const _LetterGrid({
    required this.letters,
    required this.completed,
    required this.colorOffset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: letters.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, i) {
        final letter = letters[i];
        final color = _kTilePalette[(colorOffset + i) % _kTilePalette.length];
        return _LetterTile(
          letter: letter,
          color: color,
          isCompleted: completed.contains(letter),
          onTap: () => onTap(letter),
        );
      },
    );
  }
}

class _LetterTile extends StatefulWidget {
  final String letter;
  final Color color;
  final bool isCompleted;
  final VoidCallback onTap;

  const _LetterTile({
    required this.letter,
    required this.color,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  State<_LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<_LetterTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cue = cueFor(widget.letter);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.letter,
                  style: GoogleFonts.nunito(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              if (cue != null)
                Positioned(
                  top: 6,
                  right: 8,
                  child: Text(cue.emoji, style: const TextStyle(fontSize: 15)),
                ),
              if (widget.isCompleted)
                Positioned(
                  top: 4,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.star_rounded, size: 14, color: widget.color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
