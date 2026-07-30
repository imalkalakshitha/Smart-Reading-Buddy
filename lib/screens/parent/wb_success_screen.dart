import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'wb_models.dart';
import 'wb_dashboard_screen.dart';

const _kPurple    = Color(0xFF7B61FF);
const _kPurpleLt  = Color(0xFFF0EEFF);
const _kOrange    = Color(0xFFFF6B35);
const _kTeal      = Color(0xFF00B894);
const _kTealLt    = Color(0xFFE6FAF5);
const _kBg        = Color(0xFFF8F7FF);
const _kCard      = Color(0xFFFFFFFF);
const _kDivider   = Color(0xFFEEECFF);
const _kText      = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF555577);
const _kTextLight = Color(0xFF9999BB);

class WBSuccessScreen extends StatefulWidget {
  final WBRecommendation lesson;

  const WBSuccessScreen({super.key, required this.lesson});

  @override
  State<WBSuccessScreen> createState() => _WBSuccessScreenState();
}

class _WBSuccessScreenState extends State<WBSuccessScreen> {
  late final ConfettiController _confetti;
  int _navIndex = 3; // "Assigned" tab highlighted

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBody(),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              colors: const [
                _kPurple, _kTeal, _kOrange,
                Color(0xFFFFD600), Color(0xFFFF6B6B),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kPurple,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text('Learning Journey',
          style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
      actions: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 26),
              onPressed: () {},
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _kOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kPurple, width: 1.5),
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      children: [
        // ── Success hero ──────────────────────────────────────────────────────
        Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _kTealLt,
                shape: BoxShape.circle,
                border: Border.all(color: _kTeal, width: 3),
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Exercise Assigned Successfully!',
                style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _kText),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '${widget.lesson.title} has been added to Ayan\'s learning journey.',
              style: GoogleFonts.nunito(
                  fontSize: 14, color: _kTextMid, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),

        const SizedBox(height: 24),

        _summaryCard(),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kPurpleLt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Ayan can now see this practice activity on the child home screen.",
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kPurple,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Primary action
        ElevatedButton(
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (_) => const WBDashboardScreen()),
            (r) => false,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPurple,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.dashboard_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Back to Dashboard',
                  style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Secondary action
        OutlinedButton(
          onPressed: () => setState(() => _navIndex = 3),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: _kPurple, width: 1.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_turned_in_rounded,
                  color: _kPurple, size: 20),
              const SizedBox(width: 8),
              Text('View Assigned Exercises',
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kPurple)),
            ],
          ),
        ),

        const SizedBox(height: 28),

        Text('What would you like to do next?',
            style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _kText)),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _supportCard('📈', 'Track Progress',
                  "See Ayan's trends", _kTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _supportCard('🤝', 'Parental Support',
                  'Tips to help Ayan', _kPurple),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _supportCardWide('🔮', 'Next Recommendations',
            'Get the next best lesson for Ayan', _kOrange),
      ],
    );
  }

  Widget _summaryCard() {
    final rows = [
      (Icons.book_rounded,            'Lesson',  widget.lesson.title),
      (Icons.child_care_rounded,      'Child',   'Ayan'),
      (Icons.pending_rounded,         'Status',  'Pending'),
      (Icons.checklist_rounded,       'Tasks',   '5'),
      (Icons.calendar_today_rounded,  'Due',     'This week'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kDivider, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          final isStatus = row.$2 == 'Status';
          return Column(
            children: [
              Row(
                children: [
                  Icon(row.$1, color: _kPurple, size: 20),
                  const SizedBox(width: 12),
                  Text(row.$2,
                      style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kTextLight)),
                  const Spacer(),
                  isStatus
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Pending',
                              style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: _kOrange)),
                        )
                      : Flexible(
                          child: Text(row.$3,
                              style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _kText),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis)),
                ],
              ),
              if (i < rows.length - 1) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: _kDivider),
                const SizedBox(height: 10),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _supportCard(
      String emoji, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(title,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _kText)),
          const SizedBox(height: 3),
          Text(subtitle,
              style:
                  GoogleFonts.nunito(fontSize: 11, color: _kTextLight),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _supportCardWide(
      String emoji, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color)),
                Text(subtitle,
                    style: GoogleFonts.nunito(
                        fontSize: 12, color: _kTextMid)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
        ],
      ),
    );
  }

  static const _navLabels = [
    'Dashboard', 'Progress', 'Picks', 'Assigned', 'Profile'
  ];
  static const _navIcons = [
    Icons.dashboard_rounded,
    Icons.bar_chart_rounded,
    Icons.auto_awesome_rounded,
    Icons.assignment_turned_in_rounded,
    Icons.person_rounded,
  ];

  Widget _buildBottomNav() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 66,
            child: Row(
              children: List.generate(_navLabels.length, (i) {
                final sel = _navIndex == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i == 0) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const WBDashboardScreen()),
                          (r) => false,
                        );
                      } else {
                        setState(() => _navIndex = i);
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: sel
                              ? BoxDecoration(
                                  color: _kPurpleLt,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                )
                              : null,
                          child: Icon(_navIcons[i],
                              size: sel ? 24 : 20,
                              color:
                                  sel ? _kPurple : _kTextLight),
                        ),
                        const SizedBox(height: 2),
                        Text(_navLabels[i],
                            style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: sel
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color:
                                    sel ? _kPurple : _kTextLight)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: bottomPad),
        ],
      ),
    );
  }
}
