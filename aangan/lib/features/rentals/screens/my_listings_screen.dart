import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/aangan_app.dart';
import '../models/rental_listing.dart';
import '../services/app_backend.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import 'auth_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  Future<List<RentalListing>>? _future;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    if (AppBackend.currentUser != null) {
      _future = RentalRepository.instance.getMyListings();
    } else {
      _future = Future<List<RentalListing>>.value(const <RentalListing>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My listings', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh listings',
            onPressed: () => setState(_refresh),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 7),
        ],
      ),
      body: !AppBackend.isReady
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: BackendNotice(),
            )
          : AppBackend.currentUser == null
              ? EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Sign in to manage your homes',
                  message: 'Only you can view and update your own listings.',
                  action: PrimaryButton(
                    label: 'Sign in',
                    icon: Icons.mail_outline_rounded,
                    expand: false,
                    onPressed: _signIn,
                  ),
                )
              : FutureBuilder<List<RentalListing>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Could not load listings',
                        message: 'Check your connection and try again.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AanganColors.forest,
                        ),
                      );
                    }
                    final listings = snapshot.data!;
                    if (listings.isEmpty) {
                      return const EmptyState(
                        icon: Icons.home_work_outlined,
                        title: 'No property listed yet',
                        message:
                            'Start with clear photos, a complete Bihar address and the house rules renters need to know.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => setState(_refresh),
                      color: AanganColors.forest,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(17, 9, 17, 20),
                        itemCount: listings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 11),
                        itemBuilder: (context, index) => _OwnerListingCard(
                          listing: listings[index],
                          busy: _working,
                          onAction: (status) => _update(listings[index], status),
                          onEdit: () => _editRejectedListing(listings[index]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _update(RentalListing listing, String status) async {
    setState(() => _working = true);
    try {
      if (status == 'pending') {
        await RentalRepository.instance.resubmitListing(listing.id);
      } else {
        await RentalRepository.instance.setOwnerListingStatus(listing.id, status);
      }
      if (mounted) {
        setState(_refresh);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'pending'
                  ? 'Updated home sent back for review.'
                  : 'Listing status updated.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update nahi hua: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _editRejectedListing(RentalListing listing) async {
    final titleController = TextEditingController(text: listing.title);
    final descriptionController = TextEditingController(text: listing.description);
    final rentController = TextEditingController(text: listing.monthlyRent.toString());
    final depositController = TextEditingController(text: listing.deposit.toString());
    final formKey = GlobalKey<FormState>();
    final rules = Map<String, String>.from(listing.tenantRules);
    for (final key in houseRuleLabels.keys) {
      if (!<String>['allowed', 'discuss', 'not_allowed'].contains(rules[key])) {
        rules[key] = 'discuss';
      }
    }

    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update your listing'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: titleController,
                      maxLength: 70,
                      validator: (value) => value == null || value.trim().length < 8
                          ? 'Use at least 8 characters'
                          : null,
                      decoration: const InputDecoration(labelText: 'Listing title'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 900,
                      validator: (value) => value == null || value.trim().length < 20
                          ? 'Add at least 20 characters'
                          : null,
                      decoration: const InputDecoration(labelText: 'Home description'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: rentController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final amount = int.tryParse(value ?? '');
                              return amount == null || amount <= 0
                                  ? 'Enter rent'
                                  : null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Monthly rent',
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: depositController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final amount = int.tryParse(value ?? '');
                              return amount == null || amount < 0
                                  ? 'Enter deposit'
                                  : null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Deposit',
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    const Text(
                      'House rules',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    for (final entry in houseRuleLabels.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              entry.value,
                              style: const TextStyle(
                                color: AanganColors.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SegmentedButton<String>(
                              segments: const <ButtonSegment<String>>[
                                ButtonSegment(value: 'allowed', label: Text('Yes')),
                                ButtonSegment(value: 'discuss', label: Text('Ask')),
                                ButtonSegment(value: 'not_allowed', label: Text('No')),
                              ],
                              selected: <String>{rules[entry.key] ?? 'discuss'},
                              showSelectedIcon: false,
                              onSelectionChanged: (values) => setDialogState(
                                () => rules[entry.key] = values.first,
                              ),
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                textStyle: WidgetStateProperty.all(
                                  const TextStyle(fontSize: 9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, <String, dynamic>{
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'monthly_rent': int.parse(rentController.text),
                  'deposit': int.parse(depositController.text),
                  'tenant_rules': rules,
                });
              },
              child: const Text('Save details'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    rentController.dispose();
    depositController.dispose();
    if (changes == null || !mounted) return;

    setState(() => _working = true);
    try {
      await AppBackend.client
          .from('listings')
          .update(changes)
          .eq('id', listing.id)
          .eq('owner_id', AppBackend.currentUser!.id)
          .eq('status', 'rejected');
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved. Review them, then resubmit.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Changes not saved: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _signIn() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );
    if (result == true && mounted) setState(_refresh);
  }
}

class _OwnerListingCard extends StatelessWidget {
  const _OwnerListingCard({
    required this.listing,
    required this.busy,
    required this.onAction,
    required this.onEdit,
  });

  final RentalListing listing;
  final bool busy;
  final ValueChanged<String> onAction;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AanganColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 78,
              height: 78,
              child: listing.firstPhoto.isEmpty
                  ? Container(
                      color: AanganColors.paleGreen,
                      child: const Icon(Icons.home_outlined, color: AanganColors.forest),
                    )
                  : CachedNetworkImage(
                      imageUrl: listing.firstPhoto,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AanganColors.paleGreen,
                        child: const Icon(Icons.home_outlined, color: AanganColors.forest),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        listing.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AanganColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    StatusPill(status: listing.status),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${listing.locality}, ${listing.town} · ₹${formatRupees(listing.monthlyRent)}/mo',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AanganColors.muted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
                if (listing.status == 'rejected' && listing.rejectionNote.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Admin note: ${listing.rejectionNote}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AanganColors.danger,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      TextButton(
                        onPressed: busy ? null : onEdit,
                        style: TextButton.styleFrom(
                          foregroundColor: AanganColors.muted,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Edit details'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => onAction('pending'),
                        style: TextButton.styleFrom(
                          foregroundColor: AanganColors.forest,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Resubmit for approval'),
                      ),
                    ],
                  ),
                ] else if (listing.status == 'published') ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    children: <Widget>[
                      _MiniAction(
                        label: 'Pause',
                        onPressed: busy ? null : () => onAction('paused'),
                      ),
                      _MiniAction(
                        label: 'Mark rented',
                        onPressed: busy ? null : () => onAction('rented'),
                      ),
                    ],
                  ),
                ] else if (listing.status == 'paused') ...<Widget>[
                  TextButton(
                    onPressed: busy ? null : () => onAction('published'),
                    style: TextButton.styleFrom(
                      foregroundColor: AanganColors.forest,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Make live again'),
                  ),
                ] else if (listing.status == 'pending') ...<Widget>[
                  const SizedBox(height: 5),
                  const Text(
                    'Our team is reviewing your photos and listing details.',
                    style: TextStyle(
                      color: AanganColors.muted,
                      fontSize: 9,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AanganColors.forest,
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        side: const BorderSide(color: AanganColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }
}
