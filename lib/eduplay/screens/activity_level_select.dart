import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../eduplay_constants.dart';
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
class ActivityLevelSelectScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: Text(
          kActivityDisplayNames[activityType] ?? activityType,
          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: _kTextPrimary),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _LevelCard(
              level: 'Basic',
              description: 'Build your foundation',
              taskCount: TaskRepository.instance
                  .getTasksFor(
                    activityType: activityType,
                    grade: grade,
                    language: language,
                    level: 'Basic',
                    childId: childId,
                  )
                  .length,
              onTap: () => _start(context, 'Basic'),
            ),
            const SizedBox(height: 14),
            _LevelCard(
              level: 'Advanced',
              description: 'Level up your skills',
              taskCount: TaskRepository.instance
                  .getTasksFor(
                    activityType: activityType,
                    grade: grade,
                    language: language,
                    level: 'Advanced',
                    childId: childId,
                  )
                  .length,
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
          childId: childId,
          activityType: activityType,
          level: level,
          grade: grade,
          language: language,
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String level;
  final String description;
  final int taskCount;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.description,
    required this.taskCount,
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
                                taskCount > 0 ? '$taskCount tasks available' : 'No tasks available yet',
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
