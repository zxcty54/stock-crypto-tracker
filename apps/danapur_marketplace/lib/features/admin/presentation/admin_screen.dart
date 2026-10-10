import '../../reviews/presentation/review_moderation.dart';
import 'dart:convert';
import 'cash_operations.dart';
import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../mandi/presentation/mandi_screen.dart';
import '../../seller/presentation/seller.dart';
import 'admin_forms.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.controller});
  final MarketController controller;
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;
  String _status = 'pending', _priceType = 'wholesale', _query = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (ctx, _) {
      final market = widget.controller;
      if (market.ownerId == null) {
        return SellerAuth(controller: market);
      }
      if (market.loading && !market.snapshot.isAdmin) {
        return const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (!market.snapshot.isAdmin) {
        return EmptyState(
          title: 'Administrator access required',
          message:
              'This account cannot manage shop approvals or mandi rates. The project owner must enable your account through the secure Supabase admin bootstrap SQL; there is no self-admin signup.',
          icon: Icons.admin_panel_settings_outlined,
          action: TextButton(
            onPressed: () => runAction(ctx, market.repository.signOut),
            child: const Text('Use another account'),
          ),
        );
      }
      final shops =
          market.snapshot.shops
              .where(
                (s) =>
                    s.reviewStatus == _status &&
                    '${s.name} ${s.area} ${s.phone}'.toLowerCase().contains(
                      _query,
                    ),
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final items =
          market.snapshot.mandiItems
              .where(
                (i) =>
                    '${i.name} ${i.hindiName}'.toLowerCase().contains(_query),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      final rates = {
        for (final rate in market.snapshot.mandiRates.where(
          (r) => r.priceType == _priceType,
        ))
          rate.itemId: rate,
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('RESTRICTED ADMIN WORKSPACE', icon: Icons.shield_outlined),
          const SizedBox(height: 16),
          Text(
            'Marketplace control',
            style: Theme.of(ctx).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Review real businesses. Keep local prices useful.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _metric(
                '${market.snapshot.shops.where((s) => s.reviewStatus == 'pending').length}',
                'Awaiting review',
                Icons.pending_actions,
              ),
              _metric(
                '${market.snapshot.shops.where((s) => s.reviewStatus == 'approved').length}',
                'Approved shops',
                Icons.storefront_outlined,
              ),
              _metric(
                '${market.snapshot.mandiRates.where((r) => r.isToday).length}',
                'Rates dated today',
                Icons.eco_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final entry in [
                'Shop requests',
                'Mandi rates',
                'Settings',
                'Activity',
                'Membership & samples',
                'Order feedback',
              ].asMap().entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _tab == entry.key,
                  onSelected: (_) => setState(() {
                    _tab = entry.key;
                    _query = '';
                  }),
                ),
              TextButton.icon(
                onPressed: market.reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              TextButton.icon(
                onPressed: () => runAction(ctx, market.repository.signOut),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_tab < 2) ...[
            TextField(
              key: ValueKey('admin-search-$_tab'),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: _tab == 0
                    ? 'Search shop, mobile or area'
                    : 'Search vegetables / fruits',
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (_tab == 0) ...[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: reviewStatuses
                  .map(
                    (status) => ChoiceChip(
                      label: Text(
                        '${status[0].toUpperCase()}${status.substring(1)}',
                      ),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            if (shops.isEmpty)
              const EmptyState(
                title: 'No requests in this view',
                message:
                    'New onboarding requests appear here only after a real owner submits their details and private shop photo.',
                icon: Icons.fact_check_outlined,
              ),
            ...shops.map(
              (shop) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                              shop.name,
                              style: Theme.of(ctx).textTheme.titleLarge,
                            ),
                            Tag(shop.businessType),
                            Tag(shop.reviewStatus.toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${shop.category} • ${shop.area}',
                          style: const TextStyle(color: muted),
                        ),
                        Text(shop.address),
                        const SizedBox(height: 8),
                        SelectableText(
                          'Request: ${shop.id}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                        Text(
                          'Registered contact: +91${shop.phone}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (shop.reviewNote.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Last review: ${shop.reviewNote}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: shop.verificationPhotoPath == null
                                  ? null
                                  : () => showDialog<void>(
                                      context: ctx,
                                      builder: (_) => VerificationPhotoDialog(
                                        shop: shop,
                                        repository: market.repository,
                                      ),
                                    ),
                              icon: const Icon(Icons.photo_outlined),
                              label: const Text('Private storefront photo'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => openLink(ctx, whatsappUri(shop)),
                              icon: const Icon(Icons.chat_outlined),
                              label: const Text('Contact owner'),
                            ),
                            FilledButton.icon(
                              onPressed: () => showDialog<void>(
                                context: ctx,
                                barrierDismissible: false,
                                builder: (_) => ReviewShopForm(
                                  controller: market,
                                  shop: shop,
                                ),
                              ),
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Review request'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else if (_tab == 1) ...[
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'wholesale', label: Text('Wholesale')),
                    ButtonSegment(value: 'retail', label: Text('Retail')),
                  ],
                  selected: {_priceType},
                  onSelectionChanged: (value) =>
                      setState(() => _priceType = value.first),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => AddCommodityForm(controller: market),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add commodity'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'No invented rates. Enter an actual market date, quantity unit and price (or price range). Previous rates remain in history and show as stale.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => MandiRateCard(
                item: item,
                rate: rates[item.id],
                trailing: TextButton.icon(
                  key: ValueKey('edit-rate-${item.id}'),
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    barrierDismissible: false,
                    builder: (_) => MandiRateForm(
                      controller: market,
                      item: item,
                      priceType: _priceType,
                      rate: rates[item.id],
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Update rate'),
                ),
              ),
            ),
          ] else if (_tab == 2)
            MarketSettingsForm(controller: market)
          else if (_tab == 5)
            ReviewModerationPanel(controller: market)
          else if (_tab == 4)
            CashOperationsPanel(controller: market)
          else ...[
            Text(
              'Recent administrative activity',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (market.snapshot.audit.isEmpty)
              const Text(
                'No administrative changes yet.',
                style: TextStyle(color: muted),
              ),
            ...market.snapshot.audit.map(
              (entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history, color: green),
                  title: Text(entry.action.replaceAll('_', ' ')),
                  subtitle: Text(
                    '${entry.target}\n${updatedLabel(entry.createdAt)}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
  Widget _metric(String value, String label, IconData icon) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: green),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class VerificationPhotoDialog extends StatefulWidget {
  const VerificationPhotoDialog({
    super.key,
    required this.shop,
    required this.repository,
  });
  final Shop shop;
  final MarketRepository repository;
  @override
  State<VerificationPhotoDialog> createState() =>
      _VerificationPhotoDialogState();
}

class _VerificationPhotoDialogState extends State<VerificationPhotoDialog> {
  late final Future<String> _url = widget.repository.verificationPhotoUrl(
    widget.shop.verificationPhotoPath!,
  );
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Private shop proof • ${widget.shop.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<String>(
                future: _url,
                builder: (_, state) {
                  if (state.hasError) {
                    return Text(friendlyError(state.error!));
                  }
                  if (!state.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (state.data!.startsWith('data:image/')) {
                    return Image.memory(
                      base64Decode(state.data!.split(',').last),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'Could not display this local sample proof.',
                      ),
                    );
                  }
                  return Image.network(
                    state.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text(
                      'Could not load the verification image. Refresh and try again.',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Owner/admin only. Signed image link expires after 5 minutes.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}
