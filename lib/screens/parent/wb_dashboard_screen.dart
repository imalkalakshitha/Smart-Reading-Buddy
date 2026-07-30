import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'wb_recommended_screen.dart';

// ── Colour palette shared across all 4 WB parent screens ─────────────────────
const _kPurple    = Color(0xFF7B61FF);
const _kPurpleLt  = Color(0xFFF0EEFF);
const _kOrange    = Color(0xFFFF6B35);
const _kTeal      = Color(0xFF00B894);
const _kYellow    = Color(0xFFFFD600);
const _kRed       = Color(0xFFFF5252);
const _kRedLt     = Color(0xFFFFEBEB);
const _kBg        = Color(0xFFF8F7FF);
const _kCard      = Color(0xFFFFFFFF);
const _kDivider   = Color(0xFFEEECFF);
const _kText      = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF555577);
const _kTextLight = Color(0xFF9999BB);

// ── Static child data (would come from DB/AppState in production) ─────────────
class _Child {
  static const name        = 'Ayan';
  static const grade       = 'Grade 3';
  static const level       = 'Basic Level';
  static const languages   = 'Sinhala + English';
  static const stars       = 45;
  static const streak      = 4;
}

// ── Lesson mastery rows ───────────────────────────────────────────────────────
const _lessons = [
  ('Drag and Drop Letters',     0.82, _kTeal),
  ('Word Sound Recognition',    0.78, _kPurple),
  ('Missing Spelling Practice', 0.68, _kOrange),
  ('Sentence Drag and Drop',    0.61, _kYellow),
  ('Sentence Meaning Quiz',     0.58, _kRed),
];

// ────────────────────────────────────────────────────────────────────────────

class WBDashboardScreen extends StatefulWidget {
  const WBDashboardScreen({super.key});

  @override
  State<WBDashboardScreen> createState() => _WBDashboardScreenState();
}

class _WBDashboardScreenState extends State<WBDashboardScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: _navIndex == 0
          ? _buildDashboard()
          : _buildComingSoon(_navLabels[_navIndex]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kPurple,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
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

  // ── Dashboard body ──────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _childProfileCard(),
        const SizedBox(height: 16),
        _weakAreaAlert(),
        const SizedBox(height: 16),
        _viewRecommendedButton(),
        const SizedBox(height: 20),
        _sectionTitle('Progress Overview'),
        const SizedBox(height: 12),
        _progressGrid(),
        const SizedBox(height: 20),
        _sectionTitle('Lesson Mastery'),
        const SizedBox(height: 12),
        _lessonMasteryList(),
      ],
    );
  }

  // ── Child profile card ──────────────────────────────────────────────────────

  Widget _childProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPurple, Color(0xFF5B41DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 7),
          )
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🧒', style: TextStyle(fontSize: 34)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_Child.name,
                    style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text('${_Child.grade} · ${_Child.level}',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.85))),
                Text(_Child.languages,
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statChip('⭐', '${_Child.stars} Stars'),
                    const SizedBox(width: 8),
                    _statChip('🔥', '${_Child.streak} Day Streak'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  // ── Weak area alert card ────────────────────────────────────────────────────

  Widget _weakAreaAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kRedLt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kRed.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⚠️', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Needs Practice: Sentence Meaning',
                          style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _kRed)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Needs Practice',
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text('Most common error: Meaning mismatch',
                    style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: _kTextMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── View Recommended button ─────────────────────────────────────────────────

  Widget _viewRecommendedButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const WBRecommendedScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPurple, Color(0xFF5B41DF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: _kPurple.withOpacity(0.4),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('View Recommended Lessons',
                style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Progress grid ───────────────────────────────────────────────────────────

  Widget _progressGrid() {
    const stats = [
      ('📊', 'Overall Accuracy',   '76%',   _kPurple),
      ('🌐', 'Sinhala Accuracy',   '72%',   _kOrange),
      ('🔤', 'English Accuracy',   '80%',   _kTeal),
      ('✅', 'Exercises Done',     '24',    _kTeal),
      ('🔁', 'Avg Retry',         '1.4×',  _kYellow),
      ('⏱️', 'Avg Response',      '14s',   _kPurple),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s = stats[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: s.$4.withOpacity(0.18), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(s.$1, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(s.$3,
                  style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: s.$4)),
              const SizedBox(height: 2),
              Text(s.$2,
                  style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kTextLight),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }

  // ── Lesson mastery list ─────────────────────────────────────────────────────

  Widget _lessonMasteryList() {
    return Column(
      children: _lessons.map((lesson) {
        final pct = (lesson.$2 * 100).round();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: lesson.$3.withOpacity(0.2), width: 1),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(lesson.$1,
                        style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kText)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: lesson.$3.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$pct%',
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: lesson.$3)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: lesson.$2,
                  minHeight: 9,
                  backgroundColor: _kDivider,
                  valueColor: AlwaysStoppedAnimation(lesson.$3),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _kText));
  }

  Widget _buildComingSoon(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚧', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kText)),
          const SizedBox(height: 8),
          Text('Coming soon!',
              style: GoogleFonts.nunito(
                  fontSize: 15, color: _kTextLight)),
        ],
      ),
    );
  }

  // ── Bottom navigation ───────────────────────────────────────────────────────

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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    onTap: () => setState(() => _navIndex = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: sel
                              ? BoxDecoration(
                                  color: _kPurpleLt,
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : null,
                          child: Icon(_navIcons[i],
                              size: sel ? 24 : 20,
                              color: sel ? _kPurple : _kTextLight),
                        ),
                        const SizedBox(height: 2),
                        Text(_navLabels[i],
                            style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: sel
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: sel ? _kPurple : _kTextLight)),
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
