import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppBackend {
  static bool isReady = false;
  static String? initializationError;

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => isReady ? client.auth.currentUser : null;
}
