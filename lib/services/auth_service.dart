import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check karein ki user logged in hai ya nahi
  static bool isLoggedIn() {
    return _supabase.auth.currentSession != null;
  }

  /// Current User ID
  static String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Anonymous Auth session create karein aur user handle save karein
  static Future<bool> startAnonymousSession(String name) async {
    try {
      // 1. Supabase Anonymous Login
      final authResponse = await _supabase.auth.signInAnonymously();
      final user = authResponse.user;

      if (user != null) {
        final cleanName = name.trim();
        // 2. Profiles table me unique handle save
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'username': '${cleanName.toLowerCase().replaceAll(' ', '_')}_${user.id.substring(0, 4)}',
          'full_name': cleanName,
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Anonymous Auth Error: $e');
      return false;
    }
  }
}
