import 'dart:math' show Random, min;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/encoding_data.dart';
import '../../models/app_colors.dart';
import '../../widgets/buddy_feedback_overlay.dart';

// ── Tile data model ───────────────────────────────────────────────────────────

class _TrayItem {
  final String id;
  final String letter;
  bool isUsed;
  _TrayItem({required this.id, required this.letter, this.isUsed = false});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WordBuildingScreen extends StatefulWidget {
  final EncodingArgs args;
  const WordBuildingScreen({super.key, required this.args});

  @override
  State<WordBuildingScreen> createState() => _WordBuildingScreenState();
}

class _WordBuildingScreenState extends State<WordBuildingScreen> {
  late final List<String> _words;
  int _wordIndex = 0;
  int _totalXp = 0;
  int _attemptCount = 0;

  late List<String> _letters;
  late List<_TrayItem> _trayItems;
  Map<int, String> _placedIds = {};
  bool _showOverlay = false;
  bool _overlayCorrect = false;
  bool _isThirdAttempt = false;
  bool _hintVisible = false;

  late final FlutterTts _tts;
  bool _isSpeaking = false;
  int _idSeed = 0;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _words = List<String>.from(wordData[widget.args.wordKey] ?? ['Cat'])
      ..shuffle();
    _loadWord();
    _initTts().then((_) => _playAudio());
  }

  Future<void> _initTts() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    if (widget.args.isSinhala) {
      await _tts.setLanguage('si-LK');
      await _tts.setSpeechRate(0.3);
      await _tts.setPitch(0.9);
    } else {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.38);
      await _tts.setPitch(1.0);
    }
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // ── Word setup ──────────────────────────────────────────────────────────────

  void _loadWord() {
    final word = _words[_wordIndex];
    _letters = splitToLetters(word, widget.args.isSinhala);
    final decoys = generateDecoys(_letters, widget.args.isSinhala, count: 3);
    final all = [..._letters, ...decoys]..shuffle(Random());
    _trayItems =
        all.map((l) => _TrayItem(id: 'w${_idSeed++}_$l', letter: l)).toList();
    _placedIds = {};
    _attemptCount = 0;
    _hintVisible = false;
  }

  String get _currentWord => _words[_wordIndex];

  String get _levelLabel {
    final isSi = widget.args.isSinhala;
    final g = widget.args.grade;
    final l = widget.args.level;
    if (isSi) return 'ශ්‍රේණිය $g · මට්ටම $l';
    return 'Grade $g · Level $l';
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _onClear() {
    setState(() {
      for (final t in _trayItems) {
        t.isUsed = false;
      }
      _placedIds = {};
    });
  }

  void _onCheck() {
    if (_placedIds.length < _letters.length) {
      _attemptCount++;
      setState(() {
        _overlayCorrect = false;
        _isThirdAttempt = _attemptCount >= 3;
        _showOverlay = true;
      });
      return;
    }
    setState(() {
      _totalXp += 10;
      _overlayCorrect = true;
      _isThirdAttempt = false;
      _showOverlay = true;
    });
  }

  void _onOverlayDismiss() => setState(() => _showOverlay = false);

  void _onNext() {
    setState(() {
      _showOverlay = false;
      _isSpeaking = false;
      if (_wordIndex < _words.length - 1) {
        _wordIndex++;
        _loadWord();
      } else {
        Navigator.pop(context);
        return;
      }
    });
    Future.delayed(const Duration(milliseconds: 400), _playAudio);
  }

  Future<void> _playAudio() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(_currentWord);
  }

  void _showHint() {
    setState(() => _hintVisible = true);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  _TrayItem? _findItem(String id) {
    try {
      return _trayItems.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSi = widget.args.isSinhala;
    final word = _currentWord;
    final total = _words.length;

    return Scaffold(
      backgroundColor: AppColors.primarySurface,
      appBar: _buildAppBar(isSi, total),
      body: Stack(
        children: [
          _buildBody(isSi, word, total),
          if (_showOverlay)
            BuddyFeedbackOverlay(
              isCorrect: _overlayCorrect,
              isThirdAttempt: _isThirdAttempt,
              xpGain: 10,
              revealAnswer: _overlayCorrect ? null : word,
              onDismiss: _overlayCorrect ? _onNext : _onOverlayDismiss,
              onNext: _onNext,
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isSi, int total) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryLight, width: 1.5),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
      title: Text(
        isSi ? 'වචන ගොඩනැගීම' : 'Word Building',
        style: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isSi
                  ? 'වදන ${_wordIndex + 1}/$total'
                  : 'Word ${_wordIndex + 1}/$total',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.black12),
      ),
    );
  }

  Widget _buildBody(bool isSi, String word, int total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress section
          _buildProgressSection(isSi, total).animate().fadeIn(),

          const SizedBox(height: 14),

          // Buddy status card
          _BuddyCard(
            isSinhala: isSi,
            isSpeaking: _isSpeaking,
            onSpeakerTap: _playAudio,
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 14),

          // Main word card
          _buildWordCard(isSi, word)
              .animate()
              .fadeIn(delay: 140.ms)
              .slideY(begin: 0.08, curve: Curves.easeOut),

          const SizedBox(height: 16),

          // Clear + Check buttons
          _buildActionButtons(isSi).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 12),

          // Hint button
          Center(
            child: GestureDetector(
              onTap: _showHint,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: AppColors.primaryLight, width: 1.5),
                ),
                child: Text(
                  isSi ? '💡 උදව් අවශ්‍යද?' : '💡 Need Help?',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 240.ms),
        ],
      ),
    );
  }

  // ── Progress section ─────────────────────────────────────────────────────────

  Widget _buildProgressSection(bool isSi, int total) {
    final progress = (_wordIndex + 1) / total;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _levelLabel,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '$_totalXp XP',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (_, v, __) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 9,
              backgroundColor: Colors.white,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  // ── Word card ────────────────────────────────────────────────────────────────

  Widget _buildWordCard(bool isSi, String word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryLight, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Emoji + audio button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.primaryLight, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    wordEmojiFor(word),
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  // Large play button
                  GestureDetector(
                    onTap: _playAudio,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: _isSpeaking ? 0.55 : 0.30),
                            blurRadius: _isSpeaking ? 18 : 8,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isSpeaking
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Listen Again label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primaryLight, width: 1.2),
                    ),
                    child: Text(
                      isSi ? '🔊 නැවත' : '🔊 Listen',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Attempt indicator
          if (_attemptCount > 0 && !_showOverlay)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final used = i < _attemptCount;
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: used
                          ? AppColors.wrong
                          : AppColors.divider,
                    ),
                  );
                }),
              ),
            ),

          // Drop slots with slot numbers
          _buildDropBoxes(),

          const SizedBox(height: 10),

          // Instruction text
          Text(
            isSi
                ? '👆 අකුරු ඇදගෙන "$word" ගොඩනඟන්න'
                : '👆 Drag letters to build: $word',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 20),

          // Letter tray
          _buildLetterTray(),
        ],
      ),
    );
  }

  // ── Drop boxes with slot numbers ─────────────────────────────────────────────

  Widget _buildDropBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = _letters.length;
        const spacing = 10.0;
        final maxSize = 70.0;
        final slotSize = min(
          maxSize,
          (constraints.maxWidth - (n - 1) * spacing) / n,
        ).clamp(42.0, maxSize);

        return Column(
          children: [
            // Slot numbers row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(n, (i) {
                return Container(
                  width: slotSize,
                  margin: EdgeInsets.only(left: i == 0 ? 0 : spacing),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 4),

            // Hint letters row (visible 2.5 s when hint tapped)
            AnimatedOpacity(
              opacity: _hintVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(n, (i) {
                  final filled = _placedIds.containsKey(i);
                  return Container(
                    width: slotSize,
                    margin: EdgeInsets.only(left: i == 0 ? 0 : spacing),
                    child: Center(
                      child: Text(
                        filled ? '' : _letters[i],
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 4),

            // Slot drag targets row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(n, (i) {
                final placedId = _placedIds[i];
                final placedItem =
                    placedId != null ? _findItem(placedId) : null;
                final isFilled = placedItem != null;

                return Container(
                  margin: EdgeInsets.only(left: i == 0 ? 0 : spacing),
                  child: DragTarget<String>(
                    onWillAcceptWithDetails: (details) {
                      if (isFilled) return false;
                      final item = _findItem(details.data);
                      return item != null &&
                          item.letter == _letters[i];
                    },
                    onAcceptWithDetails: (details) {
                      final item = _findItem(details.data);
                      if (item == null) return;
                      setState(() {
                        _placedIds[i] = item.id;
                        item.isUsed = true;
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isHovering = candidateData.isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: slotSize,
                        height: slotSize,
                        decoration: BoxDecoration(
                          color: isFilled
                              ? AppColors.primary.withValues(alpha: 0.10)
                              : isHovering
                                  ? AppColors.primary
                                      .withValues(alpha: 0.15)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isHovering
                                ? AppColors.primary
                                : isFilled
                                    ? AppColors.primary
                                    : AppColors.primaryLight,
                            width: isHovering ? 2.5 : 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                          boxShadow: isHovering
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: isFilled
                            ? _buildFilledSlot(
                                placedItem.letter, slotSize)
                            : _DashedSlotPainter(isHovering: isHovering),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilledSlot(String letter, double size) {
    return Stack(
      children: [
        Center(
          child: Text(
            letter,
            style: GoogleFonts.nunito(
              fontSize: size * 0.40,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const Positioned(
          top: 4,
          right: 4,
          child: Icon(Icons.check_circle_rounded,
              size: 14, color: AppColors.primary),
        ),
      ],
    )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          curve: Curves.elasticOut,
          duration: 450.ms,
        )
        .fadeIn(duration: 200.ms);
  }

  // ── Letter tray ──────────────────────────────────────────────────────────────

  Widget _buildLetterTray() {
    const tileColors = [
      Color(0xFF6CC4E8), // soft blue — correct letters
      Color(0xFF2ECC71), // green
      Color(0xFFFFD166), // yellow
      Color(0xFFFF6B6B), // coral
      Color(0xFF9B59B6), // purple
      Color(0xFFE8E8E8), // light grey — decoys
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 12,
      children: _trayItems.asMap().entries.map((e) {
        final i = e.key;
        final item = e.value;
        final color = tileColors[i % tileColors.length];
        return _LetterTile(item: item, color: color);
      }).toList(),
    );
  }

  // ── Action buttons ───────────────────────────────────────────────────────────

  Widget _buildActionButtons(bool isSi) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: isSi ? '🗑 හිස් කරන්න' : '🗑 Clear',
            color: const Color(0xFFF5F5F5),
            textColor: AppColors.textSecondary,
            borderColor: AppColors.divider,
            onTap: _onClear,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: isSi ? '✓ සරිකරන්න' : '✓ Check',
            color: AppColors.primary,
            textColor: Colors.white,
            onTap: _onCheck,
          ),
        ),
      ],
    );
  }
}

// ── Buddy Status Card ─────────────────────────────────────────────────────────

class _BuddyCard extends StatelessWidget {
  final bool isSinhala;
  final bool isSpeaking;
  final VoidCallback onSpeakerTap;

  const _BuddyCard({
    required this.isSinhala,
    required this.isSpeaking,
    required this.onSpeakerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.primaryLight, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Owl in yellow circle
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSinhala ? 'Buddy කියයි:' : 'Buddy says:',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
                Text(
                  isSinhala
                      ? 'හොඳින් ශ්‍රවණය කරන්න! 🎧'
                      : 'Listen carefully! 🎧',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Speaker icon button
          GestureDetector(
            onTap: onSpeakerTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    isSpeaking ? AppColors.primary : AppColors.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: Icon(
                isSpeaking
                    ? Icons.stop_rounded
                    : Icons.volume_up_rounded,
                color: isSpeaking ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Letter tile (Draggable) ───────────────────────────────────────────────────

class _LetterTile extends StatelessWidget {
  final _TrayItem item;
  final Color color;

  const _LetterTile({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    if (item.isUsed) {
      return _TileShape(letter: item.letter, color: color, opacity: 0.22);
    }

    return Draggable<String>(
      data: item.id,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.12,
          child: _TileShape(letter: item.letter, color: color, elevated: true),
        ),
      ),
      childWhenDragging:
          _TileShape(letter: item.letter, color: color, opacity: 0.22),
      child: _TileShape(letter: item.letter, color: color),
    );
  }
}

class _TileShape extends StatelessWidget {
  final String letter;
  final Color color;
  final double opacity;
  final bool elevated;

  const _TileShape({
    required this.letter,
    required this.color,
    this.opacity = 1.0,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        color.computeLuminance() > 0.55 ? const Color(0xFF2D2D2D) : Colors.white;

    return Opacity(
      opacity: opacity,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Chunky tactile bottom shadow
            BoxShadow(
              color: color.withValues(alpha: elevated ? 0.55 : 0.40),
              blurRadius: elevated ? 14 : 2,
              spreadRadius: 0,
              offset: Offset(0, elevated ? 8 : 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            letter,
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dashed slot overlay (drawn with CustomPaint) ──────────────────────────────

class _DashedSlotPainter extends StatelessWidget {
  final bool isHovering;
  const _DashedSlotPainter({this.isHovering = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: isHovering ? AppColors.primary : AppColors.primaryLight,
        strokeWidth: isHovering ? 2.5 : 2.0,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _DashedBorderPainter({required this.color, this.strokeWidth = 2.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const radius = Radius.circular(14);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        radius,
      ));

    const dashLen = 5.0, gapLen = 4.5;
    var distance = 0.0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final end = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLen + gapLen;
      }
      distance = 0;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
          boxShadow: color == Colors.white ||
                  color == const Color(0xFFF5F5F5)
              ? null
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.38),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
