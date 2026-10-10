import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/aangan_app.dart';
import '../services/app_backend.dart';
import '../widgets/common_widgets.dart';
import 'admin_screen.dart';
import 'auth_screen.dart';
import 'my_listings_screen.dart';

String _profileUsername(User user) {
  final emailName = user.email?.split('@').first.toLowerCase() ?? 'aangan';
  final safeName = emailName.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  final prefix = safeName.length > 20 ? safeName.substring(0, 20) : safeName;
  final suffix = user.id.length > 6 ? user.id.substring(0, 6) : user.id;
  return '${prefix}_$suffix';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onCreateListing,
  });

  final VoidCallback onCreateListing;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isAdmin = false;
  bool _loading = false;
  String? _loadError;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (AppBackend.isReady) {
      _authSubscription = AppBackend.client.auth.onAuthStateChange.listen((_) {
        if (mounted) _loadProfile();
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AppBackend.currentUser;
    if (user == null || !AppBackend.isReady) {
      setState(() {
        _profile = null;
        _isAdmin = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final values = await Future.wait<dynamic>(<Future<dynamic>>[
        AppBackend.client
            .from('profiles')
            .select('full_name, phone_number, phone_visible, account_type')
            .eq('id', user.id)
            .maybeSingle(),
        AppBackend.client
            .from('user_roles')
            .select('role')
            .eq('user_id', user.id)
            .eq('role', 'admin')
            .maybeSingle(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = values[0] == null
            ? <String, dynamic>{
                'full_name': user.email?.split('@').first ?? 'Aangan member',
                'phone_number': '',
                'phone_visible': false,
                'account_type': 'seeker',
              }
            : Map<String, dynamic>.from(values[0] as Map);
        _isAdmin = values[1] != null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppBackend.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Aangan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 7),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 7, 18, 24),
          children: <Widget>[
            if (!AppBackend.isReady) ...<Widget>[
              const BackendNotice(),
              const SizedBox(height: 14),
              _previewProfile(),
            ] else if (user == null) ...<Widget>[
              _signedOutCard(),
            ] else ...<Widget>[
              if (_loading)
                const LinearProgressIndicator(color: AanganColors.forest),
              if (_loadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4DD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Profile load nahi hua. Supabase schema setup check karein. $_loadError',
                    style: const TextStyle(fontSize: 11, height: 1.4),
                  ),
                ),
              _profileCard(user),
              const SizedBox(height: 15),
              _profileMenu(),
            ],
            const SizedBox(height: 16),
            _ownerCard(),
            const SizedBox(height: 16),
            _privacyNote(),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'AANGAN · BIHAR RENTALS',
                style: TextStyle(
                  color: AanganColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewProfile() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AanganColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ProfileAvatar(),
          const SizedBox(height: 12),
          const Text(
            'Welcome to Aangan',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Preview the app, save homes on this device and explore the owner listing form.',
            style: TextStyle(
              color: AanganColors.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedOutCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AanganColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _ProfileAvatar(),
          const SizedBox(height: 12),
          const Text(
            'A better way to rent in Bihar.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Sign in to list a home, message a host or manage your privacy.',
            style: TextStyle(
              color: AanganColors.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Sign in with email',
            icon: Icons.mail_outline_rounded,
            onPressed: _signIn,
          ),
        ],
      ),
    );
  }

  Widget _profileCard(User user) {
    final name = _profile?['full_name']?.toString() ?? 'Aangan member';
    final phone = _profile?['phone_number']?.toString() ?? '';
    final phoneVisible = _profile?['phone_visible'] == true;
    final type = _profile?['account_type']?.toString() ?? 'seeker';
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AanganColors.forest,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF406B59),
                child: Icon(Icons.person_rounded, color: Colors.white, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? '',
                      style: const TextStyle(
                        color: Color(0xFFD2E2D7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _darkBadge(
                type == 'owner'
                    ? 'PROPERTY OWNER'
                    : type == 'broker'
                        ? 'LOCAL BROKER'
                        : 'RENTER',
              ),
              _darkBadge(
                phoneVisible && phone.isNotEmpty
                    ? 'PHONE VISIBLE ON REQUEST'
                    : 'PHONE PRIVATE',
              ),
              if (_isAdmin) _darkBadge('ADMIN'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileMenu() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AanganColors.line),
      ),
      child: Column(
        children: <Widget>[
          _MenuRow(
            icon: Icons.home_work_outlined,
            title: 'My listings',
            subtitle: 'Track review, availability and status',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const MyListingsScreen()),
            ),
          ),
          const Divider(height: 1, indent: 55),
          if (_isAdmin) ...<Widget>[
            _MenuRow(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Admin review panel',
              subtitle: 'Approve or decline homes before they go live',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
              ),
            ),
            const Divider(height: 1, indent: 55),
          ],
          _MenuRow(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'Sign out on this device',
            onTap: _signOut,
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _ownerCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3D8C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.vpn_key_outlined, color: AanganColors.terracotta),
              SizedBox(width: 8),
              Text(
                'Aap owner ya broker hain?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Rent, deposit, photos aur har house rule par aapka control. Listing pehle admin review mein jaati hai.',
            style: TextStyle(
              color: AanganColors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 13),
          PrimaryButton(
            label: 'List a property',
            icon: Icons.add_home_work_outlined,
            onPressed: widget.onCreateListing,
          ),
        ],
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AanganColors.paleGreen,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.privacy_tip_outlined, size: 18, color: AanganColors.forest),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Aangan phone numbers ko public listing mein kabhi nahi dikhata. Agar aap allow karein, signed-in renter call button se number dekh sakta hai; warna in-app chat use hoga.',
              style: TextStyle(
                color: AanganColors.forest,
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFEAF1E9),
          fontSize: 8,
          letterSpacing: 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );
    if (result == true && mounted) await _loadProfile();
  }

  Future<void> _editProfile() async {
    final current = _profile ?? <String, dynamic>{};
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(profile: current),
    );
    if (updated == null || !mounted) return;
    final currentUser = AppBackend.currentUser;
    if (currentUser == null) return;
    try {
      await AppBackend.client.from('profiles').upsert(<String, dynamic>{
        'id': currentUser.id,
        'username': _profileUsername(currentUser),
        ...updated,
      });
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile save nahi hua: $error')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AppBackend.client.auth.signOut();
      if (mounted) {
        setState(() {
          _profile = null;
          _isAdmin = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out nahi hua: $error')),
        );
      }
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 25,
      backgroundColor: AanganColors.paleGreen,
      child: Icon(Icons.person_rounded, color: AanganColors.forest, size: 26),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AanganColors.paleGreen,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: AanganColors.forest, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AanganColors.muted, fontSize: 10),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 19),
      onTap: onTap,
      contentPadding: EdgeInsets.fromLTRB(13, 2, 13, last ? 2 : 1),
      minVerticalPadding: 8,
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late bool _phoneVisible;
  late String _accountType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.profile['full_name']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.profile['phone_number']?.toString() ?? '',
    );
    _phoneVisible = widget.profile['phone_visible'] == true;
    final type = widget.profile['account_type']?.toString() ?? 'seeker';
    _accountType = <String>['seeker', 'owner', 'broker'].contains(type)
        ? type
        : 'seeker';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: const BoxDecoration(
          color: AanganColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const Text(
              'Profile & privacy',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _accountType,
              decoration: const InputDecoration(labelText: 'I am here as a'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'seeker', child: Text('Home seeker')),
                DropdownMenuItem(value: 'owner', child: Text('Property owner')),
                DropdownMenuItem(value: 'broker', child: Text('Local broker')),
              ],
              onChanged: (value) => setState(() => _accountType = value ?? 'seeker'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number (with +91)',
                hintText: '+91 98765 43210',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Allow signed-in renters to call',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Off means your number stays hidden; Aangan chat still works.',
                style: TextStyle(fontSize: 10),
              ),
              value: _phoneVisible,
              activeColor: AanganColors.forest,
              onChanged: (value) => setState(() => _phoneVisible = value),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Save profile',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a display name.')),
      );
      return;
    }
    if (_phoneVisible && phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a valid phone number or keep it private.')),
      );
      return;
    }
    Navigator.of(context).pop(<String, dynamic>{
      'full_name': name,
      'account_type': _accountType,
      'phone_number': phone.isEmpty ? null : phone,
      'phone_visible': _phoneVisible,
    });
  }
}
