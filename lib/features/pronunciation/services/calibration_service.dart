import 'package:smart_reading_buddy/core/models/local_storage.dart';
import 'package:smart_reading_buddy/core/services/session_logger.dart';

class CalibrationService {
  // Default multipliers used when a profile has never been calibrated.
  // These match the previous hard-coded scales in PronunciationScorer.
  static const _defaultEn = 0.50;
  static const _defaultSi = 0.55;

  // Safety factor applied on top of the raw ratio so the child's correct
  // pronunciations land comfortably inside the OK gate (not just on the edge).
  static const _safetyFactor = 1.15;

  // Clamp bounds — never go below 0.30 (too strict) or above 2.0 (too lenient)
  static const _minMultiplier = 0.30;
  static const _maxMultiplier = 2.00;

  /// Returns the personal threshold multiplier for [profileName].
  /// Falls back to the lang-specific default if the profile has not been
  /// calibrated yet (thresholdMultiplier == -1.0).
  static Future<double> getMultiplier(String profileName, String lang) async {
    try {
      final profiles = await LocalStorage.getAllProfiles();
      final profile = profiles.firstWhere(
        (p) => p.name == profileName,
        orElse: () => throw StateError('not found'),
      );
      if (profile.thresholdMultiplier < 0) {
        return lang == 'si' ? _defaultSi : _defaultEn;
      }
      return profile.thresholdMultiplier;
    } catch (_) {
      return lang == 'si' ? _defaultSi : _defaultEn;
    }
  }

  /// Whether [profileName] has been calibrated at least once.
  static Future<bool> isCalibrated(String profileName) async {
    try {
      final profiles = await LocalStorage.getAllProfiles();
      final profile =
          profiles.firstWhere((p) => p.name == profileName);
      return profile.thresholdMultiplier >= 0;
    } catch (_) {
      return false;
    }
  }

  /// Records one calibration data point (correct pronunciation of [word]).
  static Future<void> recordScore({
    required String profileName,
    required String word,
    required double dtwScore,
    required double rawThreshold,
  }) =>
      SessionLogger.saveCalibrationScore(
        profileName:  profileName,
        word:         word,
        dtwScore:     dtwScore,
        rawThreshold: rawThreshold,
      );

  /// Calculates and persists the personal multiplier from [data].
  ///
  /// [data] is a list of `{dtw, rawThreshold}` maps — one per calibration word
  /// that was successfully scored.  At least one entry is required.
  ///
  /// Algorithm:
  ///   ratio_i   = dtw_i / rawThreshold_i   (how much of the threshold the
  ///                                          child's voice actually uses)
  ///   multiplier = mean(ratio_i) × safetyFactor
  ///
  /// Result is clamped to [_minMultiplier, _maxMultiplier] and saved to the
  /// profile in SharedPreferences.
  static Future<double> calculateAndSave({
    required String profileName,
    required List<({double dtw, double rawThreshold})> data,
  }) async {
    if (data.isEmpty) {
      // No successful calibration words — keep default
      final lang = (await LocalStorage.getAllProfiles())
              .firstWhere((p) => p.name == profileName,
                  orElse: () => throw StateError('missing'))
              .language;
      return lang == 'sinhala' ? _defaultSi : _defaultEn;
    }

    final ratios = data
        .where((d) => d.rawThreshold > 0)
        .map((d) => d.dtw / d.rawThreshold)
        .toList();

    if (ratios.isEmpty) return _defaultEn;

    final avg = ratios.reduce((a, b) => a + b) / ratios.length;
    final multiplier =
        (avg * _safetyFactor).clamp(_minMultiplier, _maxMultiplier);

    // ignore: avoid_print
    print('🎯 Calibration complete: avg_ratio=${avg.toStringAsFixed(3)}'
        '  ×safetyFactor=$_safetyFactor'
        '  → multiplier=${multiplier.toStringAsFixed(3)}');

    await LocalStorage.updateMultiplier(profileName, multiplier);
    return multiplier;
  }

  /// Adaptive refinement — call after any pronunciation session.
  ///
  /// Reads the last [sampleSize] calibration_data rows for this profile and
  /// blends a new multiplier from them (90 % old weight, 10 % new evidence).
  /// Only runs when at least [sampleSize] data points exist.
  static Future<void> adaptiveRefine(
    String profileName, {
    int sampleSize = 10,
  }) async {
    final rows = await SessionLogger.getCalibrationScores(
      profileName,
      limit: sampleSize,
    );
    if (rows.length < sampleSize) return; // not enough data yet

    final ratios = rows
        .where((r) => (r['raw_threshold'] as double) > 0)
        .map((r) => (r['dtw_score'] as double) / (r['raw_threshold'] as double))
        .toList();
    if (ratios.isEmpty) return;

    final newAvgRatio = ratios.reduce((a, b) => a + b) / ratios.length;

    final profiles = await LocalStorage.getAllProfiles();
    final profile =
        profiles.firstWhere((p) => p.name == profileName, orElse: () => throw StateError('missing'));
    final oldM = profile.thresholdMultiplier < 0
        ? (profile.language == 'sinhala' ? _defaultSi : _defaultEn)
        : profile.thresholdMultiplier;

    final newM = (oldM * 0.90 + newAvgRatio * _safetyFactor * 0.10)
        .clamp(_minMultiplier, _maxMultiplier);

    if ((newM - oldM).abs() < 0.005) return; // change too small to bother

    // ignore: avoid_print
    print('🔄 Adaptive refine: ${oldM.toStringAsFixed(3)} → ${newM.toStringAsFixed(3)}');
    await LocalStorage.updateMultiplier(profileName, newM);
  }
}
