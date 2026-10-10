import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check karein ki user logged in hai ya nahi
  static bool isLoggedIn() {
    return _supabase.auth.currentUser != null;
  }

  /// Current User ID
  static String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Anonymous Auth session create karein aur user handle save karein
  static Future<bool> startAnonymousSession(String name) async {
    try {
      // 1. Agar pehle se logged in hai toh dubara login na karein
      User? user = _supabase.auth.currentUser;
      if (user == null) {
        final authResponse = await _supabase.auth.signInAnonymously();
        user = authResponse.user;
      }

      if (user != null) {
        final cleanName = name.trim();
        final randomSuffix = user.id.length >= 4 ? user.id.substring(0, 4) : 'trader';
        final username = '${cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}_$randomSuffix';

        // 2. Profiles table me unique handle upsert karein
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'username': username,
          'full_name': cleanName,
        });

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AuthService Error: $e');
      return false;
    }
  }
}
