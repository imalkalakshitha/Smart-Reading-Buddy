import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_reading_buddy/features/numbers/dao/number_learning_dao.dart';
import 'package:smart_reading_buddy/features/numbers/data/numbers_data.dart';
import 'package:smart_reading_buddy/core/models/app_colors.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';
import 'package:smart_reading_buddy/features/numbers/services/learner_grade.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_config.dart';
import 'package:smart_reading_buddy/features/numbers/services/level_progress.dart';
import 'package:smart_reading_buddy/features/numbers/services/match_game.dart';
import 'package:smart_reading_buddy/features/numbers/services/number_words.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/learning_widgets.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/number_visuals.dart';
import 'package:smart_reading_buddy/features/numbers/screens/learning/session_summary.dart';

/// Number Match — memory cards matching digit ↔ English word ↔ quantity
/// picture (7 ↔ seven ↔ 7 apples).
///
/// Same session rules as every Numbers activity: 10 "questions" (here, 10
/// pairs, over as many boards as the level's board size needs), one point
/// per pair matched first time — see MatchGame for what counts as a
/// mistake in a memory game — 8/10 unlocks the next level, and values
/// from the last 2 sessions are used last.
class NumberMatchSessionScreen extends StatefulWidget {
  final LevelConfig level;

  const NumberMatchSessionScreen({super.key, required this.level});

  @override
  State<NumberMatchSessionScreen> createState() => _NumberMatchSessionScreenState();
}

class _NumberMatchSessionScreenState extends State<NumberMatchSessionScreen> {
  static const _instruction = 'Find the pairs that match. Tap two cards.';

  final _speaker = NumberSpeaker();
  final _sessionId = const Uuid().v4();

  List<MatchBoard>? _boards;
  int _boardIndex = 0;
  late MatchGame _game;

  /// Cards currently shown face up but not matched (a mismatch on show).
  final Set<int> _peek = {};
  bool _busy = false;
  int _pairsDone = 0;
  int _score = 0;
  DateTime _lastMatchAt = DateTime.now();
  /// Inline feedback card under the instruction (see FeedbackSlot).
  FeedbackMessage? _message;
  int _messageId = 0;
  Timer? _messageTimer;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageTimer?.cancel();
    _speaker.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final avoid = await NumberLearningDao.recentQuestionKeys(AppState.name, widget.level.id);
    final boards = MatchBoardGenerator().generateSession(widget.level, avoidKeys: avoid);
    if (!mounted) return;
    setState(() {
      _boards = boards;
      _game = MatchGame(boards.first);
      _lastMatchAt = DateTime.now();
    });
    _speaker.say(_instruction);
  }

  String _spoken(MatchCard c) => switch (c.form) {
        CardForm.picture => '${NumberWords.of(c.value)} apples',
        _ => NumberWords.of(c.value),
      };

  void _showMessage(String emoji, String text, FeedbackTone tone) {
    _messageTimer?.cancel();
    setState(() => _message = FeedbackMessage(++_messageId, emoji, text, tone));
    _messageTimer = Timer(kWrongResetDelay, () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _tap(int i) {
    if (_busy || _finished) return;
    final r = _game.flip(i);
    final card = _game.board.cards[i];
    switch (r.outcome) {
      case FlipOutcome.ignored:
        return;
      case FlipOutcome.firstUp:
        _messageTimer?.cancel();
        setState(() => _message = null);
        _speaker.say(_spoken(card));
      case FlipOutcome.match:
        _onMatch(card.value);
      case FlipOutcome.mismatch:
        setState(() {
          _peek.addAll([r.first!, r.second!]);
          _busy = true;
        });
        _showMessage('💪', "Let's try again!", FeedbackTone.tryAgain);
        _speaker.say("${_spoken(card)}. Let's try again!");
        _timer = Timer(kWrongResetDelay, () {
          if (!mounted) return;
          setState(() {
            _peek.clear();
            _busy = false;
          });
        });
    }
  }

  void _onMatch(int value) {
    final point = _game.pairScore(value);
    final now = DateTime.now();
    NumberLearningDao.saveAttempt(
      profileName: AppState.name,
      sessionId: _sessionId,
      level: widget.level,
      questionIndex: _pairsDone,
      questionKey: _game.board.pairKey(value),
      correct: true,
      attempts: _game.tries[value] ?? 1,
      timeMs: now.difference(_lastMatchAt).inMilliseconds,
      score: point,
      grade: LearnerGrade.fromProfile(AppState.grade).grade,
    ).catchError((Object e) => debugPrint('[NumberMatch] save failed: $e'));
    _lastMatchAt = now;
    setState(() {
      _score += point;
      _pairsDone++;
    });
    _showMessage('🎉', 'Great match!', FeedbackTone.good);
    _speaker.say('${NumberWords.of(value)}. Great match!');

    if (_pairsDone >= MatchBoardGenerator.pairsPerSession) {
      _timer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _finished = true);
        _speaker.say(_score >= LevelProgressRules.passScore ? 'Well done! Level passed!' : 'Well done!');
      });
    } else if (_game.done) {
      setState(() => _busy = true);
      _timer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _boardIndex++;
          _game = MatchGame(_boards![_boardIndex]);
          _message = null;
          _busy = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: LearningColors.accent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Number Match · ${widget.level.title}',
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_boards == null) {
      return const Center(child: CircularProgressIndicator(color: LearningColors.accent));
    }
    if (_finished) {
      return SessionSummaryView(
        score: _score,
        total: MatchBoardGenerator.pairsPerSession,
        onPlayAgain: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => NumberMatchSessionScreen(level: widget.level),
        )),
        onBack: () => Navigator.pop(context, true),
      );
    }
    final cards = _game.board.cards;
    final cols = cards.length <= 6 ? 3 : 4;
    return Column(
      children: [
        // Fixed top: progress, the instruction, and the feedback card slot.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _pairsDone / MatchBoardGenerator.pairsPerSession,
                        minHeight: 10,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation(LearningColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Pairs $_pairsDone / ${MatchBoardGenerator.pairsPerSession}',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              InstructionBar(prompt: 'Find the pairs', onReplay: () => _speaker.say(_instruction)),
              FeedbackSlot(message: _message),
            ],
          ),
        ),
        // The board, centred vertically in the space left.
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (box.maxHeight - 20).clamp(0.0, double.infinity)),
                child: Center(
                  child: GridView.count(
                    key: ValueKey(_boardIndex),
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                    children: [for (var i = 0; i < cards.length; i++) _card(i)],
                  ).animate(key: ValueKey('b$_boardIndex')).fadeIn(duration: 300.ms),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(int i) {
    final card = _game.board.cards[i];
    final matched = _game.matched.contains(i);
    final up = matched || _peek.contains(i) || _game.faceUp == i;
    final (bg, border) = matched
        ? (LearningColors.correctSurface, LearningColors.correct)
        : _peek.contains(i)
            ? (LearningColors.wrongFill, LearningColors.wrongBorder)
            : up
                ? (Colors.white, LearningColors.accent)
                : (LearningColors.accent, LearningColors.accent);
    final tile = GestureDetector(
      onTap: up ? null : () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: up ? 3 : 1.5),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Center(
          child: up
              ? FittedBox(fit: BoxFit.scaleDown, child: _face(card))
              : const Text('?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ),
    );
    if (!_peek.contains(i)) return tile;
    // A mismatched pair: 🔄 + one gentle shake, then both flip back.
    return gentleShake(Stack(
      clipBehavior: Clip.none,
      children: [tile, const Positioned(top: -8, right: -8, child: RetryBadge())],
    ));
  }

  Widget _face(MatchCard c) => switch (c.form) {
        CardForm.digit => Text(
            '${c.value}',
            style: GoogleFonts.nunito(fontSize: 56, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
        CardForm.word => Text(
            NumbersData.wordFor(c.value) ?? '${c.value}',
            style: GoogleFonts.nunito(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
        CardForm.picture => ObjectGrid(count: c.value, object: 'apple', size: 22),
      };
}
