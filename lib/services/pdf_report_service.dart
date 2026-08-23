import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'cross_language_analyzer.dart';
import 'pdf_si_text.dart';

/// Builds the "Speech Progress Summary" (clinical referral) PDF for a
/// child's Pronunciation module data. All input is data already loaded by
/// ParentPronunciationAnalyticsScreen — this service does no querying of
/// its own, just layout.
///
/// English uses the pdf package's built-in Base14 Helvetica (no embedding
/// needed — Latin glyphs are always available). Sinhala text is rendered
/// entirely through an embedded Noto Sans Sinhala TTF
/// (assets/fonts/NotoSansSinhala-Regular.ttf) — PDF canvases have no OS
/// font-fallback the way a Flutter widget tree does, so without this the
/// Sinhala report would render as empty boxes/tofu.
class PdfReportService {
  static Future<Uint8List> generate({
    required String childName,
    required String? grade, // 'Grade 3' / 'Grade 4' / null
    required bool sinhala,
    required int sessionCount,
    required double accuracy, // 0..1
    required int wordsPracticed,
    required List<Map<String, dynamic>> phonemeStats, // phoneme, language, total, incorrect
    required List<CrossLanguagePattern> crossPatterns,
    required List<Map<String, dynamic>> substitutionPatterns, // expected_phoneme, produced_phoneme, language, occurrences
  }) async {
    // Loaded unconditionally, not just when sinhala==true: individual
    // phoneme values are Sinhala script (e.g. 'ර') regardless of which
    // report language is selected, since they come straight from the
    // child's practice data — an English-language report can still need
    // to render Sinhala glyphs in its tables. Registered as a document-
    // wide fallback so Base14 Helvetica handles Latin text crisply while
    // this catches any Sinhala codepoints Helvetica can't draw.
    final sinhalaFontData = await rootBundle.load('assets/fonts/NotoSansSinhala-Regular.ttf');
    final sinhalaFallback = pw.Font.ttf(sinhalaFontData);

    // Second fallback: phoneme data also includes IPA symbols (ə, ɪ, ʌ,
    // ɛ, ʃ, θ, ð, ŋ, etc. — see phoneme_image_widget.dart,
    // cross_language_phoneme_map.dart) which Helvetica's Base14 metrics
    // don't cover either. Noto Sans has broad IPA Extensions coverage.
    // Tried in order: Sinhala first, then IPA/Latin-extended, so a
    // codepoint missing from one still has a second chance.
    final ipaFontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final ipaFallback = pw.Font.ttf(ipaFontData);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(fontFallback: [sinhalaFallback, ipaFallback]),
    );

    // Sinhala-mode body text uses the Sinhala font directly as primary
    // (better shaping/metrics for continuous Sinhala text than relying on
    // fallback); English-mode leaves `font` null so styles fall back to
    // the document theme's Base14 Helvetica, with sinhalaFallback still
    // catching any embedded Sinhala-script data cells.
    final siFont = sinhala ? sinhalaFallback : null;

    final title = pw.TextStyle(font: siFont, fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800);
    final sectionTitle =
        pw.TextStyle(font: siFont, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800);
    final label = pw.TextStyle(font: siFont, fontSize: 10.5, color: PdfColors.grey700);
    final value = pw.TextStyle(font: siFont, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900);
    final statLabel = pw.TextStyle(font: siFont, fontSize: 9.5, color: PdfColors.grey700);
    final statValue = pw.TextStyle(font: siFont, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700);
    final tableHeader =
        pw.TextStyle(font: siFont, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final tableCell = pw.TextStyle(font: siFont, fontSize: 10, color: PdfColors.grey900);
    final footerStyle = pw.TextStyle(font: siFont, fontSize: 8.5, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600);

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    String t(String en, String si) => sinhala ? si : en;

    // Same "enough data to matter" filter the on-screen card uses
    // (_needsAttentionPhonemes: total >= 2), ranked worst-first, capped to
    // a report-appropriate top 10 (the on-screen card caps at 5; a
    // clinical report can reasonably show a few more).
    final rankedPhonemes = phonemeStats.where((r) => (r['total'] as int) >= 2).toList()
      ..sort((a, b) {
        final rateA = (a['incorrect'] as int) / (a['total'] as int);
        final rateB = (b['incorrect'] as int) / (b['total'] as int);
        return rateB.compareTo(rateA);
      });
    final topPhonemes = rankedPhonemes.take(10).toList();

    String langLabel(String code) => sinhala
        ? (code == 'si' ? 'සිංහල' : 'ඉංග්‍රීසි')
        : (code == 'si' ? 'Sinhala' : 'English');

    pw.Widget sectionHeading(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
          child: pw.Text(text, style: sectionTitle),
        );

    pw.Widget statTile(String labelText, String valueText) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.symmetric(horizontal: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.teal100),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(valueText, style: statValue),
                pw.SizedBox(height: 2),
                pw.Text(labelText, style: statLabel),
              ],
            ),
          ),
        );

    pw.TableRow tableHeaderRow(List<String> cols) => pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.teal700),
          children: cols
              .map((c) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(c, style: tableHeader),
                  ))
              .toList(),
        );

    pw.TableRow tableDataRow(List<String> cols, {bool striped = false}) => pw.TableRow(
          decoration: pw.BoxDecoration(color: striped ? PdfColors.grey100 : PdfColors.white),
          children: cols
              .map((c) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: pw.Text(c, style: tableCell),
                  ))
              .toList(),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            t(
              'This report is generated from a child\'s app usage data and is intended to support, not replace, '
                  'professional speech-language assessment.',
              PdfSiText.footer,
            ),
            style: footerStyle,
          ),
        ),
        build: (context) => [
          pw.Text(t('Speech Progress Summary', PdfSiText.title), style: title),
          pw.SizedBox(height: 4),
          pw.Container(height: 2, width: 80, color: PdfColors.teal700),
          pw.SizedBox(height: 16),

          // Header info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(t('Child', PdfSiText.child), style: label),
                    pw.Text(childName, style: value),
                  ],
                ),
              ),
              if (grade != null)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(t('Grade', PdfSiText.grade), style: label),
                      pw.Text(grade, style: value),
                    ],
                  ),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(t('Report generated on', PdfSiText.reportGeneratedOn), style: label),
                    pw.Text(dateStr, style: value),
                  ],
                ),
              ),
            ],
          ),

          // Summary stats
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              statTile(t('Overall Accuracy', PdfSiText.overallAccuracy), '${(accuracy * 100).round()}%'),
              statTile(t('Total Sessions', PdfSiText.totalSessions), '$sessionCount'),
              statTile(t('Words Practiced', PdfSiText.wordsPracticed), '$wordsPracticed'),
            ],
          ),

          // Top Struggling Phonemes
          if (topPhonemes.isNotEmpty) ...[
            sectionHeading(t('Top Struggling Phonemes', PdfSiText.topStrugglingPhonemes)),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2)},
              children: [
                tableHeaderRow([
                  t('Phoneme / Sound', PdfSiText.colPhoneme),
                  t('Language', PdfSiText.colLanguage),
                  t('Error Rate', PdfSiText.colErrorRate),
                ]),
                for (var i = 0; i < topPhonemes.length; i++)
                  tableDataRow(
                    [
                      topPhonemes[i]['phoneme'].toString(),
                      langLabel(topPhonemes[i]['language'] as String),
                      '${(((topPhonemes[i]['incorrect'] as int) / (topPhonemes[i]['total'] as int)) * 100).round()}%',
                    ],
                    striped: i.isOdd,
                  ),
              ],
            ),
          ],

          // Cross-Language Pattern Findings
          if (crossPatterns.isNotEmpty) ...[
            sectionHeading(t('Cross-Language Pattern Findings', PdfSiText.crossLanguageFindings)),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                tableHeaderRow([
                  t('Phoneme / Sound', PdfSiText.colPhoneme),
                  t('Sinhala Script', 'සිංහල'),
                  '${t('Sinhala', 'සිංහල')} ${t('Error Rate', PdfSiText.colErrorRate)}',
                  '${t('English', 'ඉංග්‍රීසි')} ${t('Error Rate', PdfSiText.colErrorRate)}',
                ]),
                for (var i = 0; i < crossPatterns.length; i++)
                  tableDataRow(
                    [
                      crossPatterns[i].mapping.englishPhoneme,
                      crossPatterns[i].mapping.sinhalaScript,
                      '${(crossPatterns[i].sinhalaErrorRate * 100).round()}%',
                      '${(crossPatterns[i].englishErrorRate * 100).round()}%',
                    ],
                    striped: i.isOdd,
                  ),
              ],
            ),
          ],

          // Sound Patterns (substitutions)
          if (substitutionPatterns.isNotEmpty) ...[
            sectionHeading(t('Sound Patterns (Substitution Findings)', PdfSiText.soundPatterns)),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(1.5),
              },
              children: [
                tableHeaderRow([
                  t('Expected', PdfSiText.colExpected),
                  t('Produced', PdfSiText.colProduced),
                  t('Language', PdfSiText.colLanguage),
                  t('Occurrences', PdfSiText.colOccurrences),
                ]),
                for (var i = 0; i < substitutionPatterns.length; i++)
                  tableDataRow(
                    [
                      substitutionPatterns[i]['expected_phoneme'].toString(),
                      substitutionPatterns[i]['produced_phoneme'].toString(),
                      langLabel(substitutionPatterns[i]['language'] as String),
                      substitutionPatterns[i]['occurrences'].toString(),
                    ],
                    striped: i.isOdd,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }
}
