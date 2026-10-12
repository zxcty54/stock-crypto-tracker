import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers on this device whether the first-run Aangan tour was finished.
class OnboardingStore extends ChangeNotifier {
  OnboardingStore();

  static final OnboardingStore instance = OnboardingStore();
  static const _storageKey = 'aangan.onboarding_completed_v1';

  bool _completed = false;

  bool get isCompleted => _completed;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _completed = preferences.getBool(_storageKey) ?? false;
    } catch (_) {
      // Local storage is a convenience: show the tour, never block the app.
      _completed = false;
    }
    notifyListeners();
  }

  Future<void> complete() async {
    if (!_completed) {
      _completed = true;
      notifyListeners();
    }
    await _persist(completed: true);
  }

  Future<void> restart() async {
    if (_completed) {
      _completed = false;
      notifyListeners();
    }
    await _persist(completed: false);
  }

  Future<void> _persist({required bool completed}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_storageKey, completed);
    } catch (_) {
      // Keep the in-memory state usable if local storage is unavailable.
    }
  }
}
