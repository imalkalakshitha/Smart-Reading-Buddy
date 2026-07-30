import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'wb_models.dart';
import 'wb_apply_screen.dart';

const _kPurple    = Color(0xFF7B61FF);
const _kPurpleLt  = Color(0xFFF0EEFF);
const _kBg        = Color(0xFFF8F7FF);
const _kCard      = Color(0xFFFFFFFF);
const _kDivider   = Color(0xFFEEECFF);
const _kText      = Color(0xFF1A1A2E);
const _kTextMid   = Color(0xFF555577);
const _kTextLight = Color(0xFF9999BB);

class WBRecommendedScreen extends StatefulWidget {
  const WBRecommendedScreen({super.key});

  @override
  State<WBRecommendedScreen> createState() => _WBRecommendedScreenState();
}

class _WBRecommendedScreenState extends State<WBRecommendedScreen> {
  int _selectedIndex = 0; // Sentence Meaning Quiz pre-selected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildFooter(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kPurple,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Recommended Lessons',
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
            child: const Text('🧒', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kPurpleLt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _kPurple.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              const Text('🦉', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ayan needs more practice in sentence meaning and spelling.',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kPurple),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recommended for Ayan',
                style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kText)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _kPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('3 Lessons Found',
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ],
        ),

        const SizedBox(height: 14),

        ...List.generate(wbRecommendations.length, (i) {
          final r = wbRecommendations[i];
          final selected = _selectedIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedIndex = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? r.priorityColor.withOpacity(0.07)
                      : _kCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? r.priorityColor : _kDivider,
                    width: selected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? r.priorityColor.withOpacity(0.15)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: r.priorityColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(r.icon,
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected ? r.priorityColor : _kTextLight,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: r.priorityColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(r.priority,
                                style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                          const SizedBox(height: 6),
                          Text(r.title,
                              style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: _kText)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.flag_rounded,
                                  size: 13, color: _kTextLight),
                              const SizedBox(width: 4),
                              Text(r.reason,
                                  style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _kTextLight,
                                      fontStyle: FontStyle.italic)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(r.description,
                              style: GoogleFonts.nunito(
                                  fontSize: 13, color: _kTextMid)),
                        ],
                      ),
                    ),
                    if (i == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('AI Pick',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF5252))),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFooter() {
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
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WBApplyScreen(
                      lesson: wbRecommendations[_selectedIndex],
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Apply',
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
}
