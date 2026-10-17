import 'dart:math' show Random;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/data/encoding_data.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/services/ble_command_service.dart';
import 'package:smart_reading_buddy/features/eduplay_encoding/widgets/buddy_feedback_overlay.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _WordItem {
  final String id;
  final String word;
  bool isUsed;

  _WordItem({required this.id, required this.word, this.isUsed = false});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SentenceBuildingScreen extends StatefulWidget {
  final EncodingArgs args;
  const SentenceBuildingScreen({super.key, required this.args});

  @override
  State<SentenceBuildingScreen> createState() => _SentenceBuildingScreenState();
}

class _SentenceBuildingScreenState extends State<SentenceBuildingScreen> {
  late final List<String> _sentences;
  int _sentenceIndex = 0;
  int _totalXp = 0;
  int _attemptCount = 0;

  // Per-sentence state
  late List<String> _correctWords;
  late List<_WordItem> _trayItems;
  Map<int, String> _placedIds = {};   // boxIndex → item.id
  Set<int> _lockedBoxes = {};         // correctly placed on previous attempts
  bool _showOverlay = false;
  bool _overlayCorrect = false;
  bool _isThirdAttempt = false;

  // Tracks which box each item is placed in (for re-placement)
  final Map<String, int> _itemBox = {};

  late final AudioPlayer _player;
  int _idSeed = 0;

  // widget.args.language already holds 'en'/'si' (see EncodingArgs) — just
  // needs uppercasing to match the BLE command format, unlike other
  // modules' language fields which needed a comparison/mapping.
  String get _bleLanguageCode => widget.args.language.toUpperCase();

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _sentences = List<String>.from(
        sentenceData[widget.args.sentenceKey] ?? ['I eat rice'])
      ..shuffle();
    _loadSentence();
    BleCommandService.instance.send('WELCOME:$_bleLanguageCode');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ── Sentence setup ──────────────────────────────────────────────────────────

  void _loadSentence() {
    final sentence = _sentences[_sentenceIndex];
    _correctWords = sentence.split(' ');

    // Decoy words: pick random words from word bank not in sentence
    final pool = (wordData[widget.args.wordKey] ?? [])
        .where((w) => !_correctWords.contains(w))
        .toList()
      ..shuffle(Random());
    final decoys = pool.take(3).toList();

    final all = [..._correctWords, ...decoys];
    all.shuffle(Random());

    _trayItems = all
        .map((w) => _WordItem(id: 'si${_idSeed++}_$w', word: w))
        .toList();
    _placedIds = {};
    _lockedBoxes = {};
    _itemBox.clear();
    _attemptCount = 0;
  }

  String get _currentSentence => _sentences[_sentenceIndex];

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _onClear() {
    setState(() {
      for (final t in _trayItems) {
        t.isUsed = false;
      }
      _placedIds = {};
      _itemBox.clear();
      // Locked boxes retain their words
      for (final box in _lockedBoxes) {
        final itemId = _lockedIds[box];
        if (itemId != null) {
          _placedIds[box] = itemId;
          _findItem(itemId)?.isUsed = true;
        }
      }
    });
  }

  // Tracks locked item ids separately so clear can restore them
  final Map<int, String> _lockedIds = {};

  void _onDone() {
    if (_placedIds.length + _lockedBoxes.length <
        _correctWords.length) {
      // Not all boxes filled
      BleCommandService.instance.send('RETRY:$_bleLanguageCode');
      setState(() {
        _overlayCorrect = false;
        _attemptCount++;
        _isThirdAttempt = _attemptCount >= 3;
        _showOverlay = true;
      });
      return;
    }

    // Check all boxes
    var allCorrect = true;
    final newLocked = <int>{};

    for (var i = 0; i < _correctWords.length; i++) {
      if (_lockedBoxes.contains(i)) {
        newLocked.add(i); // already locked
        continue;
      }
      final itemId = _placedIds[i];
      if (itemId == null) {
        allCorrect = false;
        continue;
      }
      final item = _findItem(itemId);
      if (item != null && item.word == _correctWords[i]) {
        newLocked.add(i);
        _lockedIds[i] = itemId;
      } else {
        allCorrect = false;
        // Return wrong word to tray
        if (item != null) {
          item.isUsed = false;
          _itemBox.remove(item.id);
        }
        _placedIds.remove(i);
      }
    }

    _attemptCount++;
    BleCommandService.instance.send(allCorrect ? 'PRAISE:$_bleLanguageCode' : 'RETRY:$_bleLanguageCode');

    setState(() {
      _lockedBoxes = newLocked;
      _overlayCorrect = allCorrect;
      _isThirdAttempt = !allCorrect && _attemptCount >= 3;
      _showOverlay = true;
      if (allCorrect) _totalXp += 15;
    });
  }

  void _onOverlayDismiss() => setState(() => _showOverlay = false);

  void _onNext() {
    setState(() {
      _showOverlay = false;
      _lockedIds.clear();
      if (_sentenceIndex < _sentences.length - 1) {
        _sentenceIndex++;
        _loadSentence();
      } else {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _playAudio() async {
    try {
      final filename = _currentSentence
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-z_඀-෿]'), '');
      await _player.play(
          AssetSource('audio/sentences/${widget.args.language}/$filename.mp3'));
    } catch (_) {}
  }

  _WordItem? _findItem(String id) {
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
    final sentence = _currentSentence;
    final total = _sentences.length;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.reading,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSi ? 'වාක්‍ය ගොඩනැගීම' : 'Sentence Building',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.white),
            ),
            Text(
              isSi
                  ? 'පියවරෙන් පියවර වාක්‍ය හදන්න!'
                  : 'Build fun sentences step by step!',
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '⚡ $_totalXp XP',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(isSi, sentence, total),
          if (_showOverlay)
            BuddyFeedbackOverlay(
              isCorrect: _overlayCorrect,
              isThirdAttempt: _isThirdAttempt,
              xpGain: 15,
              revealAnswer:
                  _isThirdAttempt ? _currentSentence : null,
              onDismiss: _onOverlayDismiss,
              onNext: _onNext,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isSi, String sentence, int total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          _ProgressRow(current: _sentenceIndex + 1, total: total)
              .animate()
              .fadeIn(),

          const SizedBox(height: 14),

          // Main card
          _buildMainCard(isSi, sentence)
              .animate()
              .fadeIn(delay: 100.ms)
              .slideY(begin: 0.15, curve: Curves.easeOut),

          const SizedBox(height: 16),

          // Word tray label
          Text(
            isSi ? 'වචන තෝරන්න:' : 'Word Tray:',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 10),

          // Word tray (Wrap)
          _buildWordTray()
              .animate()
              .fadeIn(delay: 220.ms)
              .slideY(begin: 0.2, curve: Curves.easeOut),

          const SizedBox(height: 16),

          // Buttons
          _buildButtons(isSi).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 16),

          // Buddy card
          BuddyStatusCard(word: sentence, isSinhala: isSi)
              .animate()
              .fadeIn(delay: 360.ms),
        ],
      ),
    );
  }

  // ── Main card ───────────────────────────────────────────────────────────────

  Widget _buildMainCard(bool isSi, String sentence) {
    // Emoji: pick based on first word or default
    final firstWord = _correctWords.isNotEmpty ? _correctWords[0] : '';
    final emoji = wordEmojiFor(firstWord);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Emoji area + speaker
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF5FB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 60)),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _playAudio,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00B4A6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volume_up_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Drop boxes (Wrap)
          _buildDropBoxes(isSi),

          const SizedBox(height: 8),

          Text(
            isSi ? '＋ ඇදගෙන දාන්න' : '＋ Drag & Drop',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  // ── Drop boxes (numbered) ───────────────────────────────────────────────────

  Widget _buildDropBoxes(bool isSi) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_correctWords.length, (i) {
        final isLocked = _lockedBoxes.contains(i);
        final placedId = _placedIds[i];
        final placedItem = placedId != null ? _findItem(placedId) : null;
        final isFilled = placedItem != null || isLocked;

        return DragTarget<String>(
          onWillAcceptWithDetails: (details) => !isLocked,
          onAcceptWithDetails: (details) {
            final newItem = _findItem(details.data);
            if (newItem == null || isLocked) return;

            setState(() {
              // If this box already had a word, return it to tray
              final prevId = _placedIds[i];
              if (prevId != null) {
                final prev = _findItem(prevId);
                if (prev != null) prev.isUsed = false;
                _itemBox.remove(prevId);
              }

              // If the new item was placed elsewhere, free that box
              final prevBox = _itemBox[newItem.id];
              if (prevBox != null && prevBox != i) {
                _placedIds.remove(prevBox);
              }

              _placedIds[i] = newItem.id;
              newItem.isUsed = true;
              _itemBox[newItem.id] = i;
            });
          },
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            Color borderColor;
            Color bgColor;

            if (isLocked) {
              borderColor = AppColors.primary;
              bgColor = AppColors.primary.withOpacity(0.1);
            } else if (isFilled) {
              borderColor = AppColors.reading;
              bgColor = AppColors.reading.withOpacity(0.08);
            } else if (isHovering) {
              borderColor = AppColors.reading;
              bgColor = AppColors.reading.withOpacity(0.06);
            } else {
              borderColor = Colors.transparent;
              bgColor = Colors.white;
            }

            final displayWord = isLocked && !isFilled
                ? (_lockedIds[i] != null
                    ? (_findItem(_lockedIds[i]!)?.word ?? '')
                    : '')
                : (placedItem?.word ?? '');

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minWidth: 60, minHeight: 42),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: isFilled || isHovering
                    ? Border.all(color: borderColor, width: 2)
                    : null,
              ),
              child: isFilled
                  ? _buildFilledWordBox(
                      i + 1, displayWord, isLocked)
                  : _SentenceDashedBox(
                      number: i + 1, isHovering: isHovering),
            );
          },
        );
      }),
    );
  }

  Widget _buildFilledWordBox(int num, String word, bool locked) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: locked ? AppColors.primary : AppColors.reading,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$num',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            word,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: locked ? AppColors.primaryDark : AppColors.reading,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (locked)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.lock_rounded,
                size: 12, color: AppColors.primary),
          ),
      ],
    );
  }

  // ── Word tray ────────────────────────────────────────────────────────────────

  Widget _buildWordTray() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _trayItems.map((item) => _WordCard(item: item)).toList(),
    );
  }

  // ── Buttons ─────────────────────────────────────────────────────────────────

  Widget _buildButtons(bool iSi) {
    return Row(
      children: [
        Expanded(
          child: _PillButton(
            label: iSi ? '🗑 හිස් කරන්න' : '🗑 Clear',
            color: Colors.white,
            textColor: AppColors.textPrimary,
            borderColor: AppColors.divider,
            onTap: _onClear,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PillButton(
            label: iSi ? '✓ හරි' : '✓ Done',
            color: AppColors.reading,
            textColor: Colors.white,
            onTap: _onDone,
          ),
        ),
      ],
    );
  }
}

// ── Word card (Draggable) ─────────────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  final _WordItem item;
  const _WordCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final child = _CardShape(word: item.word, faded: item.isUsed);

    if (item.isUsed) return child;

    return Draggable<String>(
      data: item.id,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.08,
          child: _CardShape(word: item.word, elevated: true),
        ),
      ),
      childWhenDragging: _CardShape(word: item.word, faded: true),
      child: child,
    );
  }
}

class _CardShape extends StatelessWidget {
  final String word;
  final bool faded;
  final bool elevated;

  const _CardShape({
    required this.word,
    this.faded = false,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: faded ? 0.38 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: faded ? AppColors.divider : AppColors.primaryLight,
            width: 1.5,
          ),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ]
              : [
                  const BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  )
                ],
        ),
        child: Text(
          word,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: faded ? AppColors.textHint : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ── Sentence dashed drop box ──────────────────────────────────────────────────

class _SentenceDashedBox extends StatelessWidget {
  final int number;
  final bool isHovering;
  const _SentenceDashedBox({required this.number, this.isHovering = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: isHovering ? AppColors.reading : AppColors.divider,
        radius: 10,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          '$number',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, this.radius = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        Radius.circular(radius),
      ));

    const dashLen = 5.0;
    const gapLen = 4.0;
    var distance = 0.0;

    for (final metric in path.computeMetrics()) {
      distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ── Progress row ──────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressRow({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sentence $current of $total',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${((current / total) * 100).round()}%',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.reading,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: current / total),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (_, v, __) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.reading),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pill button ───────────────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _PillButton({
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
          borderRadius: BorderRadius.circular(50),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
          boxShadow: color == Colors.white
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
