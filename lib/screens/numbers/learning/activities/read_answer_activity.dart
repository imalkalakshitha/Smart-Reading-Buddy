import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../models/app_colors.dart';
import '../../../../services/numbers/number_question.dart';
import '../choice_options.dart';
import '../learning_widgets.dart';

/// Read & Answer — the sentence is read aloud with each word highlighted as
/// it's spoken, then the question is read; the child taps one of 4 answers.
/// Replay (the session's speaker button) fires [replaySignal] to re-read.
class ReadAnswerActivity extends StatefulWidget {
  final ReadAnswerQuestion question;
  final SubmitAnswer onSubmit;
  final bool enabled;
  final bool revealed;
  final NumberSpeaker speaker;
  final Listenable replaySignal;

  const ReadAnswerActivity({
    super.key,
    required this.question,
    required this.onSubmit,
    required this.enabled,
    required this.revealed,
    required this.speaker,
    required this.replaySignal,
  });

  @override
  State<ReadAnswerActivity> createState() => _ReadAnswerActivityState();
}

class _ReadAnswerActivityState extends State<ReadAnswerActivity> {
  TextRange? _word;

  @override
  void initState() {
    super.initState();
    widget.replaySignal.addListener(_read);
    _read();
  }

  @override
  void dispose() {
    widget.replaySignal.removeListener(_read);
    super.dispose();
  }

  Future<void> _read() async {
    final q = widget.question;
    await widget.speaker.sayWithProgress(q.sentence, (range) {
      if (mounted) setState(() => _word = range);
    });
    if (mounted) widget.speaker.say(q.question);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primaryLight, width: 1.5),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📖', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              _sentence(q.sentence),
            ],
          ),
        ),
        const SizedBox(height: 28),
        ChoiceOptions(
          options: q.options,
          answer: q.answer,
          onSubmit: widget.onSubmit,
          enabled: widget.enabled,
          revealed: widget.revealed,
          fontSize: 40,
        ),
      ],
    );
  }

  /// The sentence, word by word, with the word being spoken highlighted.
  Widget _sentence(String text) {
    final base = GoogleFonts.nunito(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.6,
      letterSpacing: 0.6,
      wordSpacing: 4,
    );
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final m in RegExp(r'\S+').allMatches(text)) {
      if (m.start > pos) spans.add(TextSpan(text: text.substring(pos, m.start)));
      final w = _word;
      final active = w != null && w.start < m.end && w.end > m.start;
      spans.add(TextSpan(
        text: m.group(0),
        style: active
            ? const TextStyle(
                backgroundColor: Color(0xFFFFF0B3),
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              )
            : null,
      ));
      pos = m.end;
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
