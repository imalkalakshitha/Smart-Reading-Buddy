import 'number_question.dart';

enum AnswerResult {
  correct,
  wrong,

  /// First step of a two-step question is right; the question continues
  /// (e.g. recognition with colouring: the number was found, now colour).
  stepDone,
}

/// Checks a child's response against the generated question itself — no
/// stored answer keys.
///
/// Response shapes: Recognition/Patterns/Counting/Calculation/PlaceValue/
/// Comparison → the tapped option (int); Recognition's colouring step →
/// [QuantityResponse]; Build/Formation → the digits placed, in slot order
/// (`List<int>`); Ordering → the numbers in the order placed (`List<int>`).
class NumberAnswerCheck {
  NumberAnswerCheck._();

  static AnswerResult evaluate(NumberQuestion q, Object? response) {
    if (q is RecognitionQuestion && q.colourQuantity) {
      if (response is int) {
        return response == q.answer ? AnswerResult.stepDone : AnswerResult.wrong;
      }
      return response is QuantityResponse && response.count == q.answer
          ? AnswerResult.correct
          : AnswerResult.wrong;
    }
    return isCorrect(q, response) ? AnswerResult.correct : AnswerResult.wrong;
  }

  /// Whether [response] fully answers [q]. For a two-step question this is
  /// the final step (see [evaluate] for the step-by-step result).
  static bool isCorrect(NumberQuestion q, Object? response) {
    return switch (q) {
      RecognitionQuestion() => q.colourQuantity
          ? response is QuantityResponse && response.count == q.answer
          : response is int && response == q.answer,
      PatternQuestion() => response is int && response == q.answer,
      CountingQuestion() => response is int && response == q.answer,
      CalculationQuestion() => response is int && response == q.answer,
      PlaceValueQuestion() => response is int && response == q.answer,
      ComparisonQuestion() => response is int && response == q.answer,
      // Compared digit by digit, so "047" never passes for 47.
      BuildQuestion() => response is List<int> && _listEq(response, q.answerDigits),
      FormationQuestion() => response is List<int> && _listEq(response, q.answerDigits),
      OrderingQuestion() => response is List<int> && _listEq(response, q.answer),
    };
  }

  /// The correct answer as display text, for the gentle reveal after the
  /// last try.
  static String answerText(NumberQuestion q) {
    return switch (q) {
      RecognitionQuestion() => '${q.answer}',
      PatternQuestion() => '${q.answer}',
      BuildQuestion() => '${q.answer}',
      OrderingQuestion() => q.answer.join(', '),
      CountingQuestion() => '${q.answer}',
      FormationQuestion() => '${q.answer}',
      CalculationQuestion() => '${q.answer}',
      PlaceValueQuestion() => '${q.answer}',
      ComparisonQuestion() => '${q.answer}',
    };
  }

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
