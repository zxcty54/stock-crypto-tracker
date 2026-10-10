import 'dart:convert';

String? validateBackendConfig(String url, String key) {
  if (url.isEmpty && key.isEmpty)
    return 'Connect your Supabase project to activate Danapur Bazaar. Fill config/app_config.json or the two DANAPUR_SUPABASE GitHub secrets, then rebuild. No demo data is included.';
  if (url.isEmpty || key.isEmpty) {
    return 'Set both DANAPUR_SUPABASE_URL and DANAPUR_SUPABASE_ANON_KEY, then rebuild the app.';
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      ['localhost', '127.0.0.1', '::1', '[::1]'].contains(uri.host)) {
    return 'Use a valid HTTPS Supabase project URL.';
  }
  if (key.startsWith('sb_secret_')) {
    return 'Never embed a Supabase secret/service-role key in this app. Use a publishable or anon key.';
  }
  if (key.split('.').length == 3) {
    try {
      final body = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))),
      );
      if (body is! Map || body['role'] != 'anon') {
        return 'Only the public anon-role key can be embedded. Do not use service-role or user-session tokens.';
      }
    } catch (_) {
      return 'The Supabase key is not a valid JWT. Use the public anon or publishable key.';
    }
  }
  if (key.split('.').length != 3 &&
      !RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key)) {
    return 'Use a Supabase publishable key or a legacy public anon JWT.';
  }
  return null;
}
