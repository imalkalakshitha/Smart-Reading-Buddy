import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

/// Pure-Dart Random Forest inference over assets/eduplay/rf_model.json —
/// mirrors eduplay_prep.py's predict()/build_vector() exactly (same
/// feature-layout convention, same float32 coercion), so this reproduces
/// scikit-learn's output bit-for-bit (see that script's PARITY OK check).
/// No ML packages — just JSON parsing + tree traversal.
class TopFeature {
  final String name;
  final dynamic value;
  final double impact;

  const TopFeature({required this.name, required this.value, required this.impact});
}

class EduPlayPrediction {
  final String activity;
  final double confidence;
  final Map<String, double> classProbs;
  final String ruleTag;
  final List<TopFeature> topFeatures;

  const EduPlayPrediction({
    required this.activity,
    required this.confidence,
    required this.classProbs,
    required this.ruleTag,
    required this.topFeatures,
  });
}

class _Tree {
  final List<int> left;
  final List<int> right;
  final List<int> feature;
  final List<double> threshold;
  final List<List<double>> value; // normalised leaf probabilities

  const _Tree({
    required this.left,
    required this.right,
    required this.feature,
    required this.threshold,
    required this.value,
  });

  factory _Tree.fromJson(Map<String, dynamic> json) {
    return _Tree(
      left: (json['l'] as List).cast<int>(),
      right: (json['r'] as List).cast<int>(),
      feature: (json['f'] as List).cast<int>(),
      threshold: (json['t'] as List).map((x) => (x as num).toDouble()).toList(),
      value: (json['v'] as List)
          .map((row) => (row as List).map((x) => (x as num).toDouble()).toList())
          .toList(),
    );
  }
}

class RFModel {
  final List<String> _classes;
  final List<String> _numericColumns;
  final List<String> _categoricalColumns;
  final Map<String, double> _numericMedians;
  final Map<String, String> _categoricalDefaults;
  final Map<String, List<String>> _categories;
  final List<_Tree> _trees;

  RFModel._({
    required List<String> classes,
    required List<String> numericColumns,
    required List<String> categoricalColumns,
    required Map<String, double> numericMedians,
    required Map<String, String> categoricalDefaults,
    required Map<String, List<String>> categories,
    required List<_Tree> trees,
  })  : _classes = classes,
        _numericColumns = numericColumns,
        _categoricalColumns = categoricalColumns,
        _numericMedians = numericMedians,
        _categoricalDefaults = categoricalDefaults,
        _categories = categories,
        _trees = trees;

  static Future<RFModel> load() async {
    final raw = await rootBundle.loadString('assets/eduplay/rf_model.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final classes = (json['classes'] as List).cast<String>();
    final numericColumns = (json['numeric_columns'] as List).cast<String>();
    final categoricalColumns = (json['categorical_columns'] as List).cast<String>();
    final numericMedians = (json['numeric_medians'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    final categoricalDefaults = (json['categorical_defaults'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
    final categories = (json['categories'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List).cast<String>()),
    );
    final trees = (json['trees'] as List)
        .map((t) => _Tree.fromJson(t as Map<String, dynamic>))
        .toList();

    return RFModel._(
      classes: classes,
      numericColumns: numericColumns,
      categoricalColumns: categoricalColumns,
      numericMedians: numericMedians,
      categoricalDefaults: categoricalDefaults,
      categories: categories,
      trees: trees,
    );
  }

  // scikit-learn casts every feature value to float32 before walking a
  // tree; Dart's double is float64, so without this coercion a handful of
  // samples sitting exactly on a split boundary take the opposite branch
  // (see eduplay_prep.py's f32() for the Python-side equivalent).
  double _f32(double x) {
    final bytes = ByteData(4);
    bytes.setFloat32(0, x, Endian.little);
    return bytes.getFloat32(0, Endian.little);
  }

  /// Builds the flat feature vector in the exact column order the model
  /// was trained with — all numeric columns (float32-coerced) followed by
  /// every one-hot column in categorical-column order. Missing/null
  /// numeric values fall back to the training-data median; missing
  /// categorical values fall back to the training-data default; unknown
  /// categorical values leave every one-hot slot at 0 (matches
  /// OneHotEncoder(handle_unknown="ignore")).
  List<double> _buildVector(Map<String, dynamic> features) {
    final vec = <double>[];

    for (final col in _numericColumns) {
      final raw = features[col];
      final numValue = raw == null ? _numericMedians[col]! : (raw as num).toDouble();
      vec.add(_f32(numValue));
    }

    for (final col in _categoricalColumns) {
      var raw = features[col]?.toString();
      raw ??= _categoricalDefaults[col];
      for (final value in _categories[col]!) {
        vec.add(raw == value ? 1.0 : 0.0);
      }
    }

    return vec;
  }

  /// Pre-baked feature importances from the training output — see the
  /// spec's topFeatures table. 'activity_type' and 'skill_area' represent
  /// the SUM of their one-hot slots' individual importances, so they're
  /// looked up by base feature name below rather than per-OHE-column.
  static const Map<String, double> _importance = {
    'recent_mistake_rate': 0.0845,
    'last_5_accuracy': 0.0823,
    'accuracy_percentage': 0.0749,
    'activity_type': 0.0551,
    'skill_area': 0.0472,
    'previous_accuracy': 0.0342,
  };

  static const Map<String, String> _displayNames = {
    'recent_mistake_rate': 'Recent error rate',
    'last_5_accuracy': 'Last 5 sessions accuracy',
    'accuracy_percentage': 'This session accuracy',
    'activity_type': 'Current activity',
    'skill_area': 'Target skill area',
    'previous_accuracy': 'Previous session accuracy',
  };

  EduPlayPrediction predict(Map<String, dynamic> features) {
    final vec = _buildVector(features);
    final totals = List<double>.filled(_classes.length, 0.0);

    for (final tree in _trees) {
      var node = 0;
      while (tree.left[node] != -1) {
        node = vec[tree.feature[node]] <= tree.threshold[node]
            ? tree.left[node]
            : tree.right[node];
      }
      final leafProbs = tree.value[node];
      for (var i = 0; i < leafProbs.length; i++) {
        totals[i] += leafProbs[i];
      }
    }

    final nTrees = _trees.length;
    final classProbs = <String, double>{
      for (var i = 0; i < _classes.length; i++) _classes[i]: totals[i] / nTrees,
    };

    var bestClass = _classes.first;
    var bestProb = classProbs[bestClass]!;
    for (final entry in classProbs.entries) {
      if (entry.value > bestProb) {
        bestClass = entry.key;
        bestProb = entry.value;
      }
    }

    final ruleTag = bestProb >= 0.80
        ? 'MOVE_TO_NEXT_SKILL'
        : bestProb >= 0.70
            ? 'PRACTICE_SAME_SKILL'
            : 'REINFORCE_FOUNDATION';

    final topFeatures = _pickTopFeatures(features);

    return EduPlayPrediction(
      activity: bestClass,
      confidence: bestProb,
      classProbs: classProbs,
      ruleTag: ruleTag,
      topFeatures: topFeatures,
    );
  }

  /// Top 3 importance-ranked features that have a non-default value in
  /// this specific input — a feature sitting at its cold-start default
  /// isn't informative about *this* prediction, so it's excluded even if
  /// its importance rank is high.
  List<TopFeature> _pickTopFeatures(Map<String, dynamic> features) {
    final ranked = _importance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final picked = <TopFeature>[];
    for (final entry in ranked) {
      if (picked.length >= 3) break;
      final name = entry.key;
      if (!features.containsKey(name)) continue;
      final value = features[name];
      if (_isDefaultValue(name, value)) continue;
      picked.add(TopFeature(
        name: _displayNames[name] ?? name,
        value: value,
        impact: entry.value,
      ));
    }
    return picked;
  }

  bool _isDefaultValue(String name, dynamic value) {
    if (value == null) return true;
    if (_numericMedians.containsKey(name)) {
      return value is num && value.toDouble() == _numericMedians[name];
    }
    if (_categoricalDefaults.containsKey(name)) {
      return value.toString() == _categoricalDefaults[name];
    }
    return false;
  }
}
