import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_reading_buddy/core/models/app_state.dart';

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

/// A single "assigned practice" flag set by a parent for one child, from
/// the Parent Dashboard's "Assign Practice" button. Purely local, no sync —
/// at most one active assignment per profile (assigning again just
/// overwrites; completing the resulting session clears it).
class AssignedPractice {
  final String profileName;
  final String phoneme;
  final String language; // 'en' | 'si'
  final int assignedAt; // epoch millis

  const AssignedPractice({
    required this.profileName,
    required this.phoneme,
    required this.language,
    required this.assignedAt,
  });

  Map<String, dynamic> toJson() => {
        'profileName': profileName,
        'phoneme': phoneme,
        'language': language,
        'assignedAt': assignedAt,
      };

  factory AssignedPractice.fromJson(Map<String, dynamic> json) => AssignedPractice(
        profileName: json['profileName'] as String,
        phoneme: json['phoneme'] as String,
        language: json['language'] as String,
        assignedAt: json['assignedAt'] as int,
      );
}

class LocalStorage {
  static const _profilesKey = 'profiles';
  static const _languageKey = 'language';
  static const _assignedPracticeKey = 'assigned_practice'; // Map<profileName, AssignedPractice.toJson()>

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

  // ── Assigned practice ───────────────────────────────────

  static Future<Map<String, dynamic>> _readAssignedPracticeMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_assignedPracticeKey);
      if (raw == null) return {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeAssignedPracticeMap(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_assignedPracticeKey, jsonEncode(map));
  }

  /// Sets (or overwrites) the active assigned-practice flag for [profileName].
  static Future<void> setAssignedPractice({
    required String profileName,
    required String phoneme,
    required String language,
  }) async {
    final map = await _readAssignedPracticeMap();
    map[profileName] = AssignedPractice(
      profileName: profileName,
      phoneme: phoneme,
      language: language,
      assignedAt: DateTime.now().millisecondsSinceEpoch,
    ).toJson();
    await _writeAssignedPracticeMap(map);
  }

  /// Returns the active assignment for [profileName], or null if none.
  static Future<AssignedPractice?> getAssignedPractice(String profileName) async {
    final map = await _readAssignedPracticeMap();
    final raw = map[profileName];
    if (raw == null) return null;
    try {
      return AssignedPractice.fromJson(raw as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Clears the active assignment for [profileName] — called once the
  /// resulting practice session is completed, so the banner doesn't keep
  /// reappearing until the parent assigns something new.
  static Future<void> clearAssignedPractice(String profileName) async {
    final map = await _readAssignedPracticeMap();
    if (map.remove(profileName) != null) {
      await _writeAssignedPracticeMap(map);
    }
  }
}
