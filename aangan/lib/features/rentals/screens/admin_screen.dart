import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../models/rental_listing.dart';
import '../services/app_backend.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import 'auth_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<RentalListing> _pending = <RentalListing>[];
  bool _loading = true;
  bool _isAdmin = false;
  String? _error;
  String? _workingId;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final user = AppBackend.currentUser;
    if (!AppBackend.isReady || user == null) {
      setState(() {
        _loading = false;
        _isAdmin = false;
        _pending = <RentalListing>[];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await AppBackend.client
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .eq('role', 'admin')
          .maybeSingle();
      if (role == null) {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _isAdmin = true);
      final pending = await RentalRepository.instance.getPendingListings();
      if (!mounted) return;
      setState(() {
        _isAdmin = true;
        _pending = pending;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin review', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh review queue',
            onPressed: _loadQueue,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 7),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !AppBackend.isReady
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: BackendNotice(),
              )
            : AppBackend.currentUser == null
                ? EmptyState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin sign-in required',
                    message:
                        'Sign in with your admin email. Only accounts granted the admin role in Supabase can review homes.',
                    action: PrimaryButton(
                      label: 'Sign in with email',
                      icon: Icons.lock_open_rounded,
                      expand: false,
                      onPressed: _signIn,
                    ),
                  )
                : _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AanganColors.forest),
                      )
                    : !_isAdmin
                        ? _notAllowed()
                        : _queue(),
      ),
    );
  }

  Widget _notAllowed() {
    return const EmptyState(
      icon: Icons.gpp_bad_outlined,
      title: 'No admin access',
      message:
          'This account cannot review homes. Add its auth user ID to public.user_roles from the Supabase SQL editor.',
    );
  }

  Widget _queue() {
    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Review queue unavailable',
        message: 'Check the admin database policies and try again. $_error',
        action: TextButton.icon(
          onPressed: _loadQueue,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadQueue,
      color: AanganColors.forest,
      child: _pending.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[
                SizedBox(height: 100),
                EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'All caught up',
                  message: 'New owner and broker listings will appear here before they go live.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 20),
              itemCount: _pending.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _queueHeader();
                }
                final listing = _pending[index - 1];
                return _PendingListingCard(
                  listing: listing,
                  busy: _workingId == listing.id,
                  onApprove: () => _review(listing, 'published'),
                  onDecline: () => _decline(listing),
                );
              },
            ),
    );
  }

  Widget _queueHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AanganColors.forest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.fact_check_outlined, color: AanganColors.gold, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Before it goes live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_pending.length} listing${_pending.length == 1 ? '' : 's'} waiting for your review',
                  style: const TextStyle(
                    color: Color(0xFFD8E5DA),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _decline(RentalListing listing) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Give the owner a short reason so they can fix and resubmit.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 11),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Please add a clear living-room photo.',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AanganColors.danger),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return;
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a reason for the owner.')),
      );
      return;
    }
    await _review(listing, 'rejected', note: note);
  }

  Future<void> _review(
    RentalListing listing,
    String decision, {
    String? note,
  }) async {
    setState(() => _workingId = listing.id);
    try {
      await RentalRepository.instance.reviewListing(
        listingId: listing.id,
        decision: decision,
        note: note,
      );
      if (!mounted) return;
      setState(() => _pending.removeWhere((item) => item.id == listing.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'published'
                ? 'Listing approved and is now live.'
                : 'Listing declined. The owner can edit and resubmit.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  Future<void> _signIn() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );
    if (result == true && mounted) await _loadQueue();
  }
}

class _PendingListingCard extends StatelessWidget {
  const _PendingListingCard({
    required this.listing,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  final RentalListing listing;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AanganColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 82,
                  child: listing.firstPhoto.isEmpty
                      ? Container(
                          color: AanganColors.paleGreen,
                          child: const Icon(Icons.home_outlined,
                              color: AanganColors.forest),
                        )
                      : CachedNetworkImage(
                          imageUrl: listing.firstPhoto,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: AanganColors.paleGreen,
                            child: const Icon(Icons.home_outlined,
                                color: AanganColors.forest),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const StatusPill(status: 'pending'),
                    const SizedBox(height: 6),
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AanganColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.locality}, ${listing.block}, ${listing.town} · ${listing.district}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AanganColors.muted,
                        fontSize: 9,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _AdminFact(label: 'Rent', value: '₹${formatRupees(listing.monthlyRent)}/mo'),
              _AdminFact(label: 'Host', value: listing.hostName),
              _AdminFact(
                label: 'Listed as',
                value: listing.listerType == 'broker' ? 'Broker' : 'Owner',
              ),
              if (listing.listerType == 'broker')
                _AdminFact(label: 'Broker fee', value: listing.brokerFee),
              _AdminFact(label: 'Photos', value: '${listing.photoPaths.length}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            listing.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AanganColors.muted,
              fontSize: 10,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final key in <String>[
                'pets',
                'bachelors',
                'couples',
                'night_visitors',
                'unknown_visitors',
              ])
                RulePill(
                  compact: true,
                  label: houseRuleLabels[key] ?? key,
                  value: listing.tenantRules[key] ?? 'discuss',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onDecline,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AanganColors.danger,
                    minimumSize: const Size(0, 45),
                    side: const BorderSide(color: Color(0xFFE9C7C1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 17),
                  label: const Text('Approve & publish'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AanganColors.forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 45),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminFact extends StatelessWidget {
  const _AdminFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 9),
        children: <InlineSpan>[
          TextSpan(
            text: '$label · ',
            style: const TextStyle(color: AanganColors.muted),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AanganColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
