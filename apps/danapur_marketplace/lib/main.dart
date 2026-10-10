import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/controller.dart';
import 'data/local_store.dart';
import 'data/repository.dart';
import 'ui/app.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in const {
      'Manrope': 'assets/fonts/OFL.txt',
      'Noto Sans Devanagari': 'assets/fonts/NOTO-OFL.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([font.key], await rootBundle.loadString(font.value));
    }
  });
  const url = String.fromEnvironment('DANAPUR_SUPABASE_URL');
  const key = String.fromEnvironment('DANAPUR_SUPABASE_ANON_KEY');
  final configError = validateBackendConfig(url, key);
  if (configError != null) {
    runApp(StartupError(message: configError));
    return;
  }
  try {
    final store = PreferencesStore(await SharedPreferences.getInstance());
    final MarketRepository repository;
    if (url.isEmpty) {
      repository = DemoRepository(store);
    } else {
      await Supabase.initialize(url: url, publishableKey: key);
      repository = SupabaseMarketRepository(Supabase.instance.client);
    }
    runApp(DanapurApp(controller: MarketController(repository, store)));
  } catch (_) {
    runApp(
      const StartupError(
        message:
            'Could not start the app. Check browser storage permissions and the Supabase configuration, then reload.',
      ),
    );
  }
}

class StartupError extends StatelessWidget {
  const StartupError({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: marketTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_outlined, color: green, size: 44),
                const SizedBox(height: 20),
                const Text(
                  'Setup needs attention',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
