import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_reading_buddy/screens/numbers/learning/learning_widgets.dart';

/// OptionGrid layout: options are always centred — never a lone option
/// left-aligned.
void main() {
  Future<List<Rect>> layout(WidgetTester tester, {required double width, required int count}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: OptionGrid(children: [
              for (var i = 0; i < count; i++) SizedBox(key: ValueKey(i), height: 60),
            ]),
          ),
        ),
      ),
    ));
    return [for (var i = 0; i < count; i++) tester.getRect(find.byKey(ValueKey(i)))];
  }

  testWidgets('3 options fit in one row at phone width (410 px − 40 px padding)', (tester) async {
    final r = await layout(tester, width: 370, count: 3);
    expect(r.map((e) => e.top).toSet().length, 1, reason: 'all in one row');
    expect(r[0].width, closeTo(r[2].width, 0.01));
  });

  testWidgets('3 options on a narrow screen: 2 + 1, the last one centred', (tester) async {
    final r = await layout(tester, width: 250, count: 3);
    expect(r[0].top, r[1].top);
    expect(r[2].top, greaterThan(r[0].top));
    final rowCentre = (r[0].left + r[1].right) / 2;
    expect(r[2].center.dx, closeTo(rowCentre, 0.5), reason: 'odd last option is centred');
    expect(r[2].width, closeTo(r[0].width, 0.5), reason: 'same width as the others');
  });

  testWidgets('4 options are a 2 × 2 grid; 2 options share one row', (tester) async {
    final four = await layout(tester, width: 370, count: 4);
    expect(four.map((e) => e.top).toSet().length, 2);
    final two = await layout(tester, width: 370, count: 2);
    expect(two[0].top, two[1].top);
  });
}
