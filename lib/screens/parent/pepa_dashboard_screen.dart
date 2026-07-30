import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_colors.dart';
import '../../services/pepa_analyzer.dart';
import '../../services/session_logger.dart';

class PEPADashboardScreen extends StatefulWidget {
  final String profileName;

  const PEPADashboardScreen({super.key, required this.profileName});

  @override
  State<PEPADashboardScreen> createState() => _PEPADashboardScreenState();
}

class _PEPADashboardScreenState extends State<PEPADashboardScreen> {
  PEPAReport? _report;
  bool _loading = true;
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await PEPAAnalyzer.generateReport(
      profileName: widget.profileName,
      days:        _selectedDays,
    );
    if (mounted) setState(() { _report = r; _loading = false; });
  }

  Future<void> _seedTestData() async {
    // Inserts realistic test rows so the dashboard can be previewed without
    // completing real sessions. Safe to run multiple times (adds more data).
    const phonemes = [
      ('th', 'en', 12, 8),   // 67% error — flagged
      ('r',  'en', 10, 7),   // 70% error — flagged
      ('sh', 'en',  9, 5),   // 56% error — flagged
      ('w',  'en',  8, 2),   // 25% error — middle
      ('b',  'en',  7, 1),   // 14% error — strong
      ('p',  'en',  6, 0),   //  0% error — strong
      ('ch', 'en',  5, 2),   // 40% error — borderline flagged
      ('l',  'en',  5, 4),   // 80% error — flagged
      ('k',  'en',  4, 1),   // 25% error — middle
      ('s',  'en',  4, 0),   //  0% error — strong
    ];

    final wordAttempts = <Map<String, dynamic>>[];
    for (final (phoneme, _, total, incorrect) in phonemes) {
      for (int i = 0; i < total; i++) {
        wordAttempts.add({
          'word':           'test_${phoneme}_$i',
          'phonemes':       phoneme,
          'result':         i >= incorrect ? 'OK' : 'WRONG',
          'attempt_number': 1,
          'dtw_score':      0.0,
        });
      }
    }

    await SessionLogger.savePhonemeAttempts(
      sessionId:    9999,
      profileName:  widget.profileName,
      language:     'en',
      wordAttempts: wordAttempts,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test data inserted — reloading…')),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: AppColors.pronunciation,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'PEPA — Sound Analysis',
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined, color: Colors.white),
            tooltip: 'Insert test data',
            onPressed: _seedTestData,
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range_rounded, color: Colors.white),
            tooltip: 'Time window',
            onSelected: (v) { _selectedDays = v; _load(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7,  child: Text('Last 7 days')),
              PopupMenuItem(value: 14, child: Text('Last 14 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.pronunciation))
          : _report == null || !_report!.hasData
              ? _buildEmpty()
              : _buildDashboard(_report!),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📊', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No data yet',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a pronunciation session\nto see sound analysis here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Main dashboard ─────────────────────────────────────────────────────────

  Widget _buildDashboard(PEPAReport r) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOverview(r),
        const SizedBox(height: 16),
        if (r.flagged.isNotEmpty) ...[
          _buildFlagged(r.flagged),
          const SizedBox(height: 16),
        ],
        if (r.strong.isNotEmpty) ...[
          _buildStrong(r.strong),
          const SizedBox(height: 16),
        ],
        if (r.allStats.isNotEmpty) ...[
          _buildBarChart(r.allStats),
          const SizedBox(height: 16),
        ],
        if (r.flagged.isNotEmpty) _buildRecommendations(r.flagged.first),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Overview card ──────────────────────────────────────────────────────────

  Widget _buildOverview(PEPAReport r) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.bar_chart_rounded,
            label: 'Overview — last $_selectedDays days',
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Words practised',  value: '${r.totalWordsAttempted}'),
          _StatRow(label: 'Sounds tracked',   value: '${r.allStats.length}'),
          _StatRow(
            label: 'Sounds needing attention',
            value: '${r.flagged.length}',
            valueColor: r.flagged.isEmpty ? AppColors.success : AppColors.wrong,
          ),
        ],
      ),
    );
  }

  // ── Flagged phonemes ───────────────────────────────────────────────────────

  Widget _buildFlagged(List<PhonemeStats> flagged) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.wrong,
            label: 'Needs attention (> 40 % errors)',
          ),
          const SizedBox(height: 8),
          Text(
            'These sounds have high error rates. Extra practice recommended.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...flagged.take(6).map((s) => _PhonemeRow(stat: s, isError: true)),
        ],
      ),
    );
  }

  // ── Strong phonemes ────────────────────────────────────────────────────────

  Widget _buildStrong(List<PhonemeStats> strong) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.success,
            label: 'Mastered (< 20 % errors)',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: strong.take(8).map((s) => Chip(
              label: Text(
                '${s.displayName}  ${s.errorRate.toStringAsFixed(0)}%',
                style: GoogleFonts.nunito(fontSize: 12),
              ),
              backgroundColor: const Color(0xFFE1F5EE),
              side: BorderSide.none,
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── Bar chart ──────────────────────────────────────────────────────────────

  Widget _buildBarChart(List<PhonemeStats> stats) {
    // Top 10 by total attempts
    final top = (stats.toList()
          ..sort((a, b) => b.totalAttempts.compareTo(a.totalAttempts)))
        .take(10)
        .toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.analytics_rounded,
            label: 'Error rates by sound',
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barGroups: top.asMap().entries.map((e) {
                  final idx  = e.key;
                  final stat = e.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY:          stat.errorRate,
                        color:        stat.isFlagged
                            ? AppColors.wrong
                            : AppColors.success,
                        width:        18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= top.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            top[i].phoneme,
                            style: GoogleFonts.nunito(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: GoogleFonts.nunito(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData:   const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Legend(color: AppColors.wrong,   label: '≥ 40 % error'),
              const SizedBox(width: 16),
              _Legend(color: AppColors.success, label: '< 40 % error'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────────────────────

  Widget _buildRecommendations(PhonemeStats top) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.lightbulb_rounded,
            iconColor: Color(0xFFFFD166),
            label: 'Recommendations',
          ),
          const SizedBox(height: 12),
          Text(
            'Priority sound: ${top.displayName}  '
            '(${top.errorRate.toStringAsFixed(0)}% error rate)',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '• Practise 5–10 minutes daily on words with this sound\n'
            '• Use the mouth-shape guide in the app\n'
            '• Celebrate every improvement, however small\n'
            '• Ask the teacher for targeted word lists',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    iconColor;

  const _CardTitle({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.pronunciation,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
}

class _StatRow extends StatelessWidget {
  final String  label;
  final String  value;
  final Color?  valueColor;

  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary)),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}

class _PhonemeRow extends StatelessWidget {
  final PhonemeStats stat;
  final bool         isError;

  const _PhonemeRow({required this.stat, required this.isError});

  @override
  Widget build(BuildContext context) {
    final bg    = isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
    final fg    = isError ? AppColors.wrong         : AppColors.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${stat.errorRate.toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.displayName,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${stat.incorrectAttempts} / ${stat.totalAttempts} attempts incorrect',
                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color  color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );
}
