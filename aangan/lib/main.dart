import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/aangan_app.dart';
import 'features/rentals/services/app_backend.dart';
import 'features/rentals/services/favorites_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      AppBackend.isReady = true;
    } catch (error) {
      // Keep the app browsable when the backend is temporarily unavailable.
      AppBackend.initializationError = error.toString();
    }
  }

  await FavoritesStore.instance.load();
  runApp(const AanganApp());
}
