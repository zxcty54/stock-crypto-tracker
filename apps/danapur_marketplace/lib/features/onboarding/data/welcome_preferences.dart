import '../../../core/data/local_store.dart';

// Separate from Auth, favourites and sample records; deleting samples does not
// make the first-launch introduction repeat. No backend or SQL change required.
abstract final class WelcomePreferences {
  static const storageKey = 'danapur.welcome.v1';
  static const completedValue = 'completed';
  static bool hasCompleted(LocalStore store) {
    try {
      return store.read(storageKey) == completedValue;
    } catch (_) {
      return false;
    }
  }

  static Future<void> complete(LocalStore store) =>
      store.write(storageKey, completedValue);
}
