import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'wb_models.dart';
import 'wb_success_screen.dart';

const _kPurple    = Color(0xFF7B61FF);
const _kPurpleLt  = Color(0xFFF0EEFF);
const _kOrange    = Color(0xFFFF6B35);
const _kTeal      = Color(0xFF00B894);
const _kBg        = Color(0xFFF8F7FF);
const _kCard      = Color(0xFFFFFFFF);
const _kDivider   = Color(0xFFEEECFF);
const _kText      = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF555577);
const _kTextLight = Color(0xFF9999BB);

class WBApplyScreen extends StatelessWidget {
  final WBRecommendation lesson;

  const WBApplyScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildFooter(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _kPurple,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Apply Exercise',
          style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.25),
            child: const Text('👨', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      children: [
        _exerciseSummaryCard(),
        const SizedBox(height: 16),
        _assignmentDetailCard(),
        const SizedBox(height: 16),
        _diagnosticCard(),
        const SizedBox(height: 16),
        _journeyPreviewCard(),
      ],
    );
  }

  Widget _exerciseSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            lesson.priorityColor,
            lesson.priorityColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: lesson.priorityColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(lesson.icon,
                  style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title,
                    style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text('Grade 3 Basic',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _whitePill('📝', '5 tasks'),
                    const SizedBox(width: 8),
                    _whitePill('⭐', lesson.priority),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whitePill(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _assignmentDetailCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('📋', 'Assignment Details'),
          const SizedBox(height: 14),
          _detailRow(Icons.child_care_rounded, 'Target Learner',
              'Ayan', _kPurple),
          const SizedBox(height: 10),
          _detailRow(Icons.lightbulb_rounded, 'Learning Focus',
              'Meaning Understanding', _kTeal),
        ],
      ),
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kTextLight)),
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _kText)),
          ],
        ),
      ],
    );
  }

  Widget _diagnosticCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('🔍', 'Why this exercise?'),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: lesson.priorityColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_rounded,
                    size: 16, color: _kTextLight),
                const SizedBox(width: 6),
                Text('Diagnostic Flag: ',
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextLight)),
                Flexible(
                  child: Text(lesson.reason,
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: lesson.priorityColor,
                          fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ayan needs more practice understanding who, what, and action in a sentence.',
            style: GoogleFonts.nunito(
                fontSize: 14, color: _kTextMid, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _journeyPreviewCard() {
    const steps = [
      ('1', '👨', 'Parent Assigns'),
      ('2', '✅', 'Practice Ready'),
      ('3', '🧒', 'Child Journey'),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('🗺️', 'What happens next?'),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final color = i == 0
                  ? _kPurple
                  : i == 1
                      ? _kTeal
                      : _kOrange;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(step.$2,
                                  style:
                                      const TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Step ${step.$1}',
                              style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _kTextLight)),
                          Text(step.$3,
                              style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: _kText),
                              textAlign: TextAlign.center,
                              maxLines: 2),
                        ],
                      ),
                    ),
                    if (i < steps.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 28),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: _kTextLight, size: 18),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPurpleLt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "This practice will appear in Ayan's Journey screen.",
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kPurple),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kDivider, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: _kTextLight, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kTextMid)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WBSuccessScreen(lesson: lesson),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTeal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_turned_in_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Apply Exercise',
                      style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kDivider, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _kText)),
      ],
    );
  }
}
