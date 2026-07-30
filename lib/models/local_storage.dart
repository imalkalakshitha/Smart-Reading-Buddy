import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';

class UserProfile {
  final String name;
  final String grade;
  final String language;
  final String avatar;
  final String pin;
  final int createdAt;
  // -1.0 = not yet calibrated; CalibrationService uses lang-specific default
  final double thresholdMultiplier;

  UserProfile({
    required this.name,
    required this.grade,
    required this.language,
    required this.avatar,
    required this.pin,
    int? createdAt,
    this.thresholdMultiplier = -1.0,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'name': name,
        'grade': grade,
        'language': language,
        'avatar': avatar,
        'pin': pin,
        'createdAt': createdAt,
        'thresholdMultiplier': thresholdMultiplier,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String,
        grade: json['grade'] as String,
        language: json['language'] as String,
        avatar: json['avatar'] as String,
        pin: json['pin'] as String? ?? '0000',
        createdAt: json['createdAt'] as int?,
        thresholdMultiplier:
            (json['thresholdMultiplier'] as num?)?.toDouble() ?? -1.0,
      );
}

class LocalStorage {
  static const _profilesKey = 'profiles';
  static const _languageKey = 'language';

  // ── Language ──────────────────────────────────────────
  static Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  // ── Profiles ──────────────────────────────────────────
  static Future<List<UserProfile>> getAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profilesKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveProfile() async {
    final profiles = await getAllProfiles();
    final newProfile = UserProfile(
      name: AppState.name,
      grade: AppState.grade,
      language: AppState.language,
      avatar: AppState.avatar,
      pin: AppState.pin,
    );
    final idx = profiles.indexWhere((p) => p.name == AppState.name);
    if (idx >= 0) {
      profiles[idx] = newProfile;
    } else {
      profiles.add(newProfile);
    }
    await _persist(profiles);
  }

  /// Updates only the threshold multiplier for an existing profile.
  static Future<void> updateMultiplier(String name, double multiplier) async {
    final profiles = await getAllProfiles();
    final idx = profiles.indexWhere((p) => p.name == name);
    if (idx < 0) return;
    final old = profiles[idx];
    profiles[idx] = UserProfile(
      name: old.name,
      grade: old.grade,
      language: old.language,
      avatar: old.avatar,
      pin: old.pin,
      createdAt: old.createdAt,
      thresholdMultiplier: multiplier,
    );
    await _persist(profiles);
  }

  static Future<bool> loadProfile(String name) async {
    try {
      final profiles = await getAllProfiles();
      final profile = profiles.firstWhere((p) => p.name == name);
      AppState.name = profile.name;
      AppState.grade = profile.grade;
      AppState.language = profile.language;
      AppState.avatar = profile.avatar;
      AppState.pin = profile.pin;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteProfile(String name) async {
    final profiles = await getAllProfiles();
    profiles.removeWhere((p) => p.name == name);
    await _persist(profiles);
  }

  static Future<void> _persist(List<UserProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _profilesKey, jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }
}
