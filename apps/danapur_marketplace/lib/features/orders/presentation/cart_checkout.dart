import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../seller/presentation/seller.dart';
import '../domain/commerce.dart';

class CartCheckoutScreen extends StatefulWidget {
  const CartCheckoutScreen({super.key, required this.controller});
  final MarketController controller;
  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _address = TextEditingController();
  String _mode = 'pickup', _requestId = const Uuid().v4();
  GeoFix? _fix;
  bool _busy = false, _locating = false, _consent = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final fix = await currentLocation();
      if (mounted) {
        setState(() => _fix = fix);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (!_consent) {
      setState(
        () =>
            _error = 'Confirm cash payment terms and delivery/pickup details.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final market = widget.controller;
      final quote = quoteCart(market.snapshot, market.cart, _mode, _fix);
      final address = _mode == 'pickup'
          ? 'Pickup at ${quote.shop.address}'
          : _address.text;
      final id = await market.repository.placeCashOrder(
        quote.shop.id,
        List.of(market.cart),
        _mode,
        _name.text,
        _phone.text,
        address,
        _fix,
        _requestId,
      );
      market.clearCart();
      _requestId = const Uuid().v4();
      await market.reload();
      if (mounted) {
        toast(
          context,
          'Order placed. No online payment was collected. Reference: $id',
        );
        Navigator.pushReplacementNamed(context, '/orders');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (ctx, _) {
      final market = widget.controller;
      if (market.ownerId == null) {
        return SellerAuth(controller: market);
      }
      CartQuote? quote;
      String? eligibility;
      try {
        quote = quoteCart(market.snapshot, market.cart, _mode, _fix);
      } catch (error) {
        eligibility = friendlyError(error);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('CASH-ONLY CHECKOUT', icon: Icons.shopping_cart_outlined),
          const SizedBox(height: 16),
          Text('Your cart', style: Theme.of(ctx).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text(
            'One shop per order. No cards, UPI gateway or online payment in this app.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          if (market.cart.isEmpty)
            const EmptyState(
              title: 'Your cart is empty',
              message: 'Choose a product from an open approved shop.',
            )
          else ...[
            ...market.cart.map((line) {
              final p = market.snapshot.products
                  .where((p) => p.id == line.productId)
                  .firstOrNull;
              if (p == null) {
                return const Text(
                  'An item is no longer listed. Clear the cart and choose again.',
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${money(p.sellingPaise)} / ${p.unit} • ${p.deliveryAllowed ? 'Delivery eligible' : 'Pickup only'}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Reduce ${p.name}',
                            onPressed: _busy
                                ? null
                                : () => market.setCartQuantity(
                                    p.id,
                                    line.quantity - 1,
                                  ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${line.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            tooltip: 'Increase ${p.name}',
                            onPressed: _busy
                                ? null
                                : () => market.setCartQuantity(
                                    p.id,
                                    line.quantity + 1,
                                  ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              money(p.sellingPaise * line.quantity),
                              style: const TextStyle(
                                color: green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            TextButton(
              onPressed: _busy ? null : market.clearCart,
              child: const Text('Clear cart'),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Fulfilment method'),
              items: const [
                DropdownMenuItem(
                  value: 'pickup',
                  child: Text('Shop pickup + cash'),
                ),
                DropdownMenuItem(
                  value: 'delivery',
                  child: Text('Home delivery COD — within 500 m'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _mode = value!;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 16),
            if (_mode == 'delivery') ...[
              const Text(
                '500 m straight-line radius, not road distance. Both shop and product must allow delivery. Accurate foreground location is used only when you request it; address/location are shared privately with this seller.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _locating || _busy ? null : _locate,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      _locating ? 'Locating…' : 'Use current location',
                    ),
                  ),
                  if (market.repository.sampleProfilesEnabled)
                    TextButton(
                      onPressed: () => setState(() {
                        final first = market.snapshot.products
                            .where((p) => p.id == market.cart.first.productId)
                            .firstOrNull;
                        final shop = market.snapshot.shops
                            .where((s) => s.id == first?.shopId)
                            .firstOrNull;
                        if (shop?.latitude != null) {
                          _fix = GeoFix(
                            shop!.latitude! + 0.0005,
                            shop.longitude!,
                            measuredAt: DateTime.now(),
                          );
                        }
                      }),
                      child: const Text('Use fictional test address'),
                    ),
                ],
              ),
              if (_fix != null)
                Text(
                  'Location accuracy: ${_fix!.accuracy.toStringAsFixed(0)} m${quote?.distance == null ? '' : ' • distance: ${quote!.distance!.toStringAsFixed(0)} m'}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              const SizedBox(height: 16),
            ],
            if (eligibility != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(eligibility, style: const TextStyle(fontSize: 12)),
              ),
            if (quote != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _money('Base product total', quote.subtotal),
                      _money('Product discounts', -quote.discount),
                      _money(
                        _mode == 'pickup'
                            ? 'Pickup — no delivery charge'
                            : 'Delivery: shop base + per-unit handling',
                        quote.delivery,
                      ),
                      const Divider(),
                      _money('Cash payable', quote.total, strong: true),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('checkout-name'),
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Customer name *',
                    ),
                    validator: (v) => validateLength(v, 'Name', 2, 80),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('checkout-phone'),
                    controller: _phone,
                    maxLength: 10,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact mobile *',
                      prefixText: '+91 ',
                    ),
                    validator: validatePhone,
                  ),
                  if (_mode == 'delivery') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('checkout-address'),
                      controller: _address,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Delivery address + landmark *',
                      ),
                      validator: (v) => validateLength(v, 'Address', 6, 300),
                    ),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consent,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _consent = v ?? false),
                    title: const Text(
                      'I will pay cash on delivery / at pickup. I confirm the details and will coordinate fulfilment with the seller.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('place-order'),
              onPressed: _busy || quote == null ? null : _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(_busy ? 'Placing order…' : 'Place cash order'),
            ),
            const SizedBox(height: 14),
            const Text(
              'The server rechecks shop status, current prices and 500 m eligibility at placement. Seller acceptance and delivery are not guaranteed. Either party can close/cancel an open order; completion is self-reported, not a digital cash-payment receipt.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
        ],
      );
    },
  );
  Widget _money(String label, int value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value < 0 ? '−${money(-value)}' : money(value),
          style: TextStyle(
            color: green,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
