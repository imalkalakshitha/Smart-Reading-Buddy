import 'package:flutter/material.dart';

class AppState {
  static String name = '';
  static String grade = '';
  static String language = '';
  static String avatar = '';
  static String pin = '';

  static final List<VoidCallback> _languageChangeListeners = [];

  static void addLanguageChangeListener(VoidCallback listener) {
    _languageChangeListeners.add(listener);
  }

  static void removeLanguageChangeListener(VoidCallback listener) {
    _languageChangeListeners.remove(listener);
  }

  static void _notifyLanguageChangeListeners() {
    for (final listener in _languageChangeListeners) {
      listener();
    }
  }

  static void setLanguage(String newLanguage) {
    language = newLanguage;
    _notifyLanguageChangeListeners();
  }

  static void clear() {
    name = '';
    grade = '';
    language = '';
    avatar = '';
    pin = '';
  }
}
