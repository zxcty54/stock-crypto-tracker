import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/aangan_app.dart';
import '../services/app_backend.dart';
import '../widgets/common_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in securely')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AanganColors.paleGreen,
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: AanganColors.forest,
                size: 29,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your home search,\nkept private.',
              style: TextStyle(
                color: AanganColors.ink,
                fontSize: 29,
                height: 1.13,
                letterSpacing: -1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Sign in with a one-time email code to message hosts, save homes across devices or submit a property.',
              style: TextStyle(
                color: AanganColors.muted,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 22),
            if (!AppBackend.isReady) ...<Widget>[
              const BackendNotice(),
              const SizedBox(height: 12),
              const Text(
                'Supabase URL / anon key abhi configured nahi hain. Browse mode phir bhi available hai; live sign-in ke liye README ka setup follow karein.',
                style: TextStyle(
                  color: AanganColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ] else ...<Widget>[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: _codeSent
                    ? TextInputAction.next
                    : TextInputAction.done,
                enabled: !_codeSent && !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                onSubmitted: (_) => _sendCode(),
              ),
              if (_codeSent) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'One-time code',
                    hintText: 'Enter the code from your email',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                  onSubmitted: (_) => _verifyCode(),
                ),
                const SizedBox(height: 7),
                TextButton.icon(
                  onPressed: _busy ? null : _sendCode,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Send a new code'),
                  style: TextButton.styleFrom(
                    foregroundColor: AanganColors.forest,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 9),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AanganColors.danger,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_notice != null) ...<Widget>[
                const SizedBox(height: 9),
                Text(
                  _notice!,
                  style: const TextStyle(
                    color: AanganColors.forest,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: _busy
                    ? 'Please wait…'
                    : _codeSent
                        ? 'Verify and continue'
                        : 'Email me a sign-in code',
                icon: _codeSent
                    ? Icons.verified_user_outlined
                    : Icons.mark_email_read_outlined,
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : _codeSent
                        ? _verifyCode
                        : _sendCode,
              ),
              const SizedBox(height: 13),
              const Text(
                'No password to remember. Your phone number is never shown unless you enable it in Profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AanganColors.muted,
                  fontSize: 10,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await AppBackend.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _notice = 'Code sent to $email. Check your inbox and spam folder.';
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Code send nahi hua. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the full one-time code from your email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final response = await AppBackend.client.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: code,
      );
      final user = response.user;
      if (user != null) {
        final profile = await AppBackend.client
            .from('profiles')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        if (profile == null) {
          final emailName = email.split('@').first;
          final suggestedName = emailName.replaceAll('.', ' ');
          final safeHandle = emailName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
          final handlePrefix = safeHandle.length > 20
              ? safeHandle.substring(0, 20)
              : safeHandle;
          final username = '${handlePrefix}_${user.id.substring(0, 6)}';
          await AppBackend.client.from('profiles').insert(<String, dynamic>{
            'id': user.id,
            'username': username,
            'full_name': suggestedName.length > 80
                ? suggestedName.substring(0, 80)
                : suggestedName,
            'account_type': 'seeker',
          });
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Sign-in complete nahi hua. Supabase profile table setup check karein. $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
