import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../domain/mandi.dart';

class MandiScreen extends StatefulWidget {
  const MandiScreen({super.key, required this.controller});
  final MarketController controller;
  @override
  State<MandiScreen> createState() => _MandiScreenState();
}

class _MandiScreenState extends State<MandiScreen> {
  final _search = TextEditingController();
  String _category = 'All', _priceType = 'wholesale';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (ctx, _) {
      final market = widget.controller;
      final query = _search.text.trim().toLowerCase();
      final items =
          market.snapshot.mandiItems
              .where(
                (item) =>
                    item.active &&
                    (_category == 'All' || item.category == _category) &&
                    '${item.name} ${item.hindiName}'.toLowerCase().contains(
                      query,
                    ),
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
          const Tag('LOCAL MARKET INTELLIGENCE', icon: Icons.eco_outlined),
          const SizedBox(height: 16),
          Text(
            market.snapshot.settings.mandiName,
            style: Theme.of(ctx).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sabzi aur phal ke rates, ek jagah.',
            style: TextStyle(color: muted, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3EB),
              border: Border.all(color: const Color(0xFFD8E8DC)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Rates are entered by the marketplace administrator, not scraped or simulated. Check the rate type, unit and market date. Old rates are labelled; unpublished prices stay blank. Final transaction prices can vary by quality and quantity.',
              style: TextStyle(color: green, fontSize: 12, height: 1.6),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'wholesale', label: Text('Wholesale')),
                  ButtonSegment(value: 'retail', label: Text('Retail')),
                ],
                selected: {_priceType},
                onSelectionChanged: (values) =>
                    setState(() => _priceType = values.first),
              ),
              ...['All', 'Vegetables', 'Fruits'].map(
                (c) => ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('mandi-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search vegetables or fruits / सब्जी या फल',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${items.length} commodities • ${_priceType == 'wholesale' ? 'Wholesale' : 'Retail'} rates',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const EmptyState(
              title: 'No commodities found',
              message:
                  'Try another search. If the catalogue has not been installed, the administrator should run the mandi seed SQL.',
              icon: Icons.eco_outlined,
            ),
          ...items.map(
            (item) => MandiRateCard(item: item, rate: rates[item.id]),
          ),
        ],
      );
    },
  );
}

class MandiRateCard extends StatelessWidget {
  const MandiRateCard({
    super.key,
    required this.item,
    this.rate,
    this.trailing,
  });
  final MandiItem item;
  final MandiRate? rate;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final identity = Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.category == 'Fruits'
                        ? const Color(0xFFFFF0DC)
                        : const Color(0xFFEAF3E7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.category == 'Fruits'
                        ? Icons.local_florist_outlined
                        : Icons.eco_outlined,
                    color: green,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        item.hindiName,
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                      Text(
                        item.category,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final price = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate == null
                      ? 'Not published'
                      : '${money(rate!.minPaise)}${rate!.maxPaise == rate!.minPaise ? '' : '–${money(rate!.maxPaise)}'} / ${rate!.unit}',
                  style: TextStyle(
                    color: rate == null ? muted : green,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                if (rate == null)
                  Text(
                    'No ${item.defaultUnit} rate entered yet',
                    style: const TextStyle(color: muted, fontSize: 11),
                  )
                else
                  Tag(
                    rate!.isToday
                        ? 'Today • ${mandiDateKey(rate!.effectiveDate)}'
                        : 'Previous rate • ${mandiDateKey(rate!.effectiveDate)}',
                    color: rate!.isToday ? green : const Color(0xFF98621E),
                    background: rate!.isToday
                        ? const Color(0xFFEAF4EC)
                        : const Color(0xFFFFF0DC),
                    icon: rate!.isToday ? Icons.update : Icons.history,
                  ),
                if (rate?.note.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      rate!.note,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ),
              ],
            );
            return constraints.maxWidth > 680
                ? Row(
                    children: [
                      Expanded(child: identity),
                      Expanded(child: price),
                      if (trailing != null) trailing!,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 14),
                      price,
                      if (trailing != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing!,
                        ),
                    ],
                  );
          },
        ),
      ),
    ),
  );
}
