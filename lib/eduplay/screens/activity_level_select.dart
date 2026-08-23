import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../eduplay_constants.dart';
import '../eduplay_si_text.dart';
import '../task_repository.dart';
import 'activity_screen.dart';

const _kPrimary = Color(0xFF2ECC71);
const _kBg = Color(0xFFFAFAF7);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

/// Route: '/eduplay/level-select'. Args: {childId, activityType, grade,
/// language}. grade/language come from the child's locked profile
/// (passed down from the dashboard, which already loaded it) — never a
/// UI-visible choice on this screen.
///
/// Stateful (not the original Stateless version) because getTasksFor() is
/// now async — it seeds its shuffle from a DB-backed attempt count so
/// session rotation works (see task_repository.dart), so the two task
/// counts shown here have to be loaded before the cards can render.
class ActivityLevelSelectScreen extends StatefulWidget {
  final String childId;
  final String activityType;
  final String grade;
  final String language;

  const ActivityLevelSelectScreen({
    super.key,
    required this.childId,
    required this.activityType,
    required this.grade,
    required this.language,
  });

  @override
  State<ActivityLevelSelectScreen> createState() => _ActivityLevelSelectScreenState();
}

class _ActivityLevelSelectScreenState extends State<ActivityLevelSelectScreen> {
  bool _loading = true;
  int _basicCount = 0;
  int _advancedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final basic = await TaskRepository.instance.getTasksFor(
      activityType: widget.activityType,
      grade: widget.grade,
      language: widget.language,
      level: 'Basic',
      childId: widget.childId,
    );
    final advanced = await TaskRepository.instance.getTasksFor(
      activityType: widget.activityType,
      grade: widget.grade,
      language: widget.language,
      level: 'Advanced',
      childId: widget.childId,
    );
    if (!mounted) return;
    setState(() {
      _basicCount = basic.length;
      _advancedCount = advanced.length;
      _loading = false;
    });
  }

  bool get _isSinhala => widget.language == 'Sinhala';

  @override
  Widget build(BuildContext context) {
    final isSinhala = _isSinhala;
    final activityName = isSinhala
        ? (EduPlaySiText.activityNames[widget.activityType] ?? widget.activityType)
        : (kActivityDisplayNames[widget.activityType] ?? widget.activityType);
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: Text(
          activityName,
          // Matches Timed Reading / Pronunciation's level-select header
          // standard (fontSize 20, w800) — was 18/w700, the same drift
          // flagged for Timed Reading's level-card title before that got
          // aligned.
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: _kTextPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kPrimary))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _LevelCard(
                    level: isSinhala ? EduPlaySiText.levelBasic : 'Basic',
                    description: isSinhala ? EduPlaySiText.buildFoundation : 'Build your foundation',
                    taskCount: _basicCount,
                    isSinhala: isSinhala,
                    onTap: () => _start(context, 'Basic'),
                  ),
                  const SizedBox(height: 14),
                  _LevelCard(
                    level: isSinhala ? EduPlaySiText.levelAdvanced : 'Advanced',
                    description: isSinhala ? EduPlaySiText.levelUpSkills : 'Level up your skills',
                    taskCount: _advancedCount,
                    isSinhala: isSinhala,
                    onTap: () => _start(context, 'Advanced'),
                  ),
                ],
              ),
            ),
    );
  }

  void _start(BuildContext context, String level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityScreen(
          childId: widget.childId,
          activityType: widget.activityType,
          level: level,
          grade: widget.grade,
          language: widget.language,
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String level;
  final String description;
  final int taskCount;
  final bool isSinhala;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.description,
    required this.taskCount,
    required this.isSinhala,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = taskCount > 0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                constraints: const BoxConstraints(minHeight: 120),
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                ),
              ),
              Expanded(
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.5,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(level,
                                  style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary)),
                              const SizedBox(height: 6),
                              Text(description,
                                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.3, color: _kTextSecondary)),
                              const SizedBox(height: 8),
                              Text(
                                taskCount > 0
                                    ? (isSinhala ? EduPlaySiText.nTasksAvailable(taskCount) : '$taskCount tasks available')
                                    : (isSinhala ? EduPlaySiText.noTasksAvailable : 'No tasks available yet'),
                                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: _kPrimary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: _kPrimary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
