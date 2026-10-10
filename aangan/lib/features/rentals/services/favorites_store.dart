import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();

  static final FavoritesStore instance = FavoritesStore._();
  static const _storageKey = 'aangan.saved_listing_ids';

  final Set<String> _ids = <String>{};

  Set<String> get ids => Set<String>.unmodifiable(_ids);
  bool contains(String id) => _ids.contains(id);

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _ids
        ..clear()
        ..addAll(preferences.getStringList(_storageKey) ?? const <String>[]);
    } catch (_) {
      // Saving favourites is a convenience; browsing should not depend on it.
    }
  }

  void toggle(String id) {
    if (!_ids.add(id)) _ids.remove(id);
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_storageKey, _ids.toList());
    } catch (_) {
      // Keep the in-memory state usable if local storage is unavailable.
    }
  }
}
