import '../../../core/location/location_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';

Future<void> editShop(
  BuildContext context,
  MarketController controller, [
  Shop? shop,
]) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ShopForm(controller: controller, shop: shop),
);
Future<void> editProduct(
  BuildContext context,
  MarketController controller, [
  Product? product,
]) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ProductForm(controller: controller, product: product),
);

class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.onSave,
    required this.busy,
    this.error,
    this.saveLabel = 'Save changes',
  });
  final String title, subtitle, saveLabel;
  final String? error;
  final Widget body;
  final VoidCallback onSave;
  final bool busy;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight:
              (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      48)
                  .clamp(120, 900)
                  .toDouble(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = (MediaQuery.textScalerOf(context).scale(14) / 14)
                  .clamp(1, 3);
              final compact = constraints.maxHeight < 320 * scale;
              final fields = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  body,
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFB44337)),
                        textAlign: TextAlign.left,
                      ),
                    ),
                ],
              );
              final content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close form',
                        onPressed: busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (compact)
                    fields
                  else
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: fields,
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: busy ? null : onSave,
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(busy ? 'Saving…' : saveLabel),
                      ),
                    ],
                  ),
                ],
              );
              // On short screens/with the keyboard open, scroll the entire form
              // rather than overflowing its pinned heading and action buttons.
              return compact
                  ? SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: content,
                    )
                  : content;
            },
          ),
        ),
      ),
    ),
  );
}

class ShopForm extends StatefulWidget {
  const ShopForm({super.key, required this.controller, this.shop});
  final MarketController controller;
  final Shop? shop;
  @override
  State<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _address,
      _phone,
      _description,
      _hours,
      _deliveryFee;
  late String _category, _area, _businessType;
  PickedPhoto? _proof;
  bool _offersDelivery = false, _open = true, _locating = false;
  double? _latitude, _longitude;
  bool _consent = false, _published = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final shop = widget.shop;
    _name = TextEditingController(text: shop?.name);
    _address = TextEditingController(text: shop?.address);
    _phone = TextEditingController(text: shop?.phone);
    _description = TextEditingController(text: shop?.description);
    _hours = TextEditingController(text: shop?.hours);
    _deliveryFee = TextEditingController(
      text: priceInput(shop?.deliveryBasePaise ?? 0),
    );
    _offersDelivery = shop?.offersDelivery ?? false;
    _open = shop?.isOpen ?? true;
    _latitude = shop?.latitude;
    _longitude = shop?.longitude;
    _businessType = shop?.businessType ?? businessTypes.first;
    _category = shop?.category ?? categories.first;
    _area = shop?.area ?? areas.first;
    _published = shop?.isPublished ?? true;
    _consent = shop != null;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _phone,
      _description,
      _hours,
      _deliveryFee,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (!_consent) {
      setState(
        () => _error =
            'Confirm that you manage this shop and agree to publish its business contact after approval.',
      );
      return;
    }
    if (_proof == null && widget.shop?.verificationPhotoPath == null) {
      setState(
        () => _error =
            'Choose a current storefront photo showing your shop signboard.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.saveShop(
        ShopDraft(
          name: _name.text,
          businessType: _businessType,
          isOpen: _open,
          offersDelivery: _offersDelivery,
          latitude: _latitude,
          longitude: _longitude,
          deliveryBasePaise: parseCharge(_deliveryFee.text) ?? -1,
          verificationPhotoPath: widget.shop?.verificationPhotoPath,
          category: _category,
          area: _area,
          address: _address.text,
          phone: _phone.text,
          description: _description.text,
          hours: _hours.text,
          isPublished: _published,
        ),
        id: widget.shop?.id,
        photo: _proof,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: widget.shop == null ? 'Create your shop' : 'Edit shop details',
    subtitle:
        'Private application. Your shop appears to buyers only after storefront-photo review and administrator approval.',
    busy: _busy,
    error: _error,
    onSave: _save,
    saveLabel: widget.shop == null ? 'Submit for review' : 'Save shop',
    body: Form(
      key: _form,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _businessType,
            decoration: const InputDecoration(labelText: 'Business type *'),
            items: businessTypes
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) => setState(() => _businessType = value!),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('shop-name'),
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Shop name *',
              hintText: 'Your business name',
            ),
            validator: (v) => validateLength(v, 'Shop name', 3, 80),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Shop category *'),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _area,
            decoration: const InputDecoration(
              labelText: 'Danapur neighbourhood *',
            ),
            items: areas
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _area = v!),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('shop-address'),
            controller: _address,
            maxLength: 180,
            decoration: const InputDecoration(
              labelText: 'Shop address *',
              hintText: 'Street, building and a nearby landmark',
            ),
            validator: (v) => validateLength(v, 'Address', 6, 180),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('shop-phone'),
            controller: _phone,
            maxLength: 10,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Business mobile number *',
              prefixText: '+91 ',
              helperText:
                  'Use the same mobile when sending WhatsApp verification. Public after approval.',
            ),
            validator: validatePhone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _hours,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Opening hours',
              hintText: 'e.g. Mon–Sat, 9 AM – 8 PM',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'About your shop',
              hintText: 'Tell neighbours what you sell.',
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: canvas,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private storefront photo *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Show the real shop entrance and signboard. No Aadhaar, PAN or private identity documents. JPEG, PNG or WebP under 512 KB. Only you and administrators can access it.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                if (_proof != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _proof!.bytes,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_outlined),
                    ),
                  ),
                if (_proof == null &&
                    widget.shop?.verificationPhotoPath != null)
                  const Text(
                    'Existing private storefront photo saved.',
                    style: TextStyle(color: green, fontSize: 12),
                  ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            final file = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1200,
                              imageQuality: 70,
                            );
                            if (file == null) {
                              return;
                            }
                            final photo = PickedPhoto.fromBytes(
                              await file.readAsBytes(),
                            );
                            if (mounted) {
                              setState(() {
                                _proof = photo;
                                _error = null;
                              });
                            }
                          } catch (error) {
                            if (mounted) {
                              setState(() => _error = friendlyError(error));
                            }
                          }
                        },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _proof == null && widget.shop?.verificationPhotoPath == null
                        ? 'Choose storefront photo'
                        : 'Replace storefront photo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _open,
            onChanged: (v) => setState(() => _open = v),
            title: const Text('Shop open for orders today'),
            subtitle: const Text(
              'Closed shops remain discoverable but cannot accept new orders.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _offersDelivery,
            onChanged: (v) => setState(() => _offersDelivery = v),
            title: const Text('Offer home delivery within 500 m'),
            subtitle: const Text(
              'Products also need delivery enabled individually. COD eligibility uses straight-line distance.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          if (_offersDelivery) ...[
            TextFormField(
              controller: _deliveryFee,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Base delivery charge per order',
                prefixText: '₹ ',
                helperText:
                    '0 for free delivery. Product handling charges can be additional.',
              ),
              validator: (v) {
                final n = parseCharge(v ?? '');
                return n == null || n > 10000000 ? 'Use ₹0–₹1,00,000.' : null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _locating
                  ? null
                  : () async {
                      setState(() => _locating = true);
                      try {
                        final fix = await currentLocation();
                        if (mounted) {
                          setState(() {
                            _latitude = fix.latitude;
                            _longitude = fix.longitude;
                          });
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
                    },
              icon: const Icon(Icons.my_location),
              label: Text(_locating ? 'Locating…' : 'Capture shop location'),
            ),
            Text(
              _latitude == null
                  ? 'Stand at your actual storefront and allow precise foreground location.'
                  : 'Shop coordinates: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publish after approval'),
            subtitle: const Text(
              'Approval is always required. Turning this off hides an approved shop.',
              style: TextStyle(fontSize: 11),
            ),
            value: _published,
            onChanged: (v) => setState(() => _published = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I manage this real shop and agree to display its business address and contact number after approval.',
              style: TextStyle(fontSize: 12),
            ),
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
          ),
        ],
      ),
    ),
  );
}

class ProductForm extends StatefulWidget {
  const ProductForm({super.key, required this.controller, this.product});
  final MarketController controller;
  final Product? product;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _price,
      _mrp,
      _unit,
      _description,
      _discount,
      _handling;
  String _discountMode = 'amount';
  bool _deliveryAllowed = false;
  late String _category;
  String? _imageUrl, _error;
  PickedPhoto? _photo;
  bool _available = true, _busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name);
    _price = TextEditingController(
      text: p == null ? '' : priceInput(p.pricePaise),
    );
    _mrp = TextEditingController(
      text: p?.mrpPaise == null ? '' : priceInput(p!.mrpPaise!),
    );
    _unit = TextEditingController(text: p?.unit ?? 'each');
    _description = TextEditingController(text: p?.description);
    _category =
        p?.category ?? widget.controller.myShop?.category ?? categories.first;
    _imageUrl = p?.imageUrl;
    _available = p?.isAvailable ?? true;
    _discount = TextEditingController(text: priceInput(p?.discountPaise ?? 0));
    _handling = TextEditingController(
      text: priceInput(p?.deliveryExtraPaise ?? 0),
    );
    _deliveryAllowed = p?.deliveryAllowed ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _mrp,
      _unit,
      _description,
      _discount,
      _handling,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 75,
      );
      if (file == null) {
        return;
      }
      final photo = PickedPhoto.fromBytes(await file.readAsBytes());
      if (mounted) {
        setState(() {
          _photo = photo;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is MarketException
              ? e.message
              : 'Could not open the photo picker. Try a JPEG, PNG or WebP file.',
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.saveProduct(
        ProductDraft(
          name: _name.text,
          category: _category,
          pricePaise: parsePrice(_price.text)!,
          discountPaise:
              discountFromInput(
                _discount.text,
                parsePrice(_price.text)!,
                percent: _discountMode == 'percent',
              ) ??
              -1,
          deliveryAllowed: _deliveryAllowed,
          deliveryExtraPaise: parseCharge(_handling.text) ?? -1,
          mrpPaise: _mrp.text.trim().isEmpty ? null : parsePrice(_mrp.text),
          description: _description.text,
          unit: _unit.text,
          imageUrl: _imageUrl,
          illustration: widget.product?.illustration ?? 'bag',
          isAvailable: _available,
        ),
        id: widget.product?.id,
        photo: _photo,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: widget.product == null ? 'Add a product' : 'Edit product',
    subtitle: 'Clear prices help neighbours decide. Confirm your unit.',
    busy: _busy,
    error: _error,
    onSave: _save,
    saveLabel: widget.product == null ? 'List product' : 'Save product',
    body: Form(
      key: _form,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: _photo != null
                        ? Image.memory(
                            _photo!.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_not_supported_outlined),
                          )
                        : _imageUrl != null
                        ? const Icon(
                            Icons.photo_outlined,
                            color: green,
                            size: 34,
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: green,
                            size: 34,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product photo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Optional • JPEG, PNG, WebP • under 512 KB',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : _pick,
                            child: Text(
                              _photo != null || _imageUrl != null
                                  ? 'Change photo'
                                  : 'Choose photo',
                            ),
                          ),
                          if (_photo != null || _imageUrl != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _photo = null;
                                      _imageUrl = null;
                                    }),
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('product-name'),
            controller: _name,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Product name *'),
            validator: (v) => validateLength(v, 'Product name', 3, 100),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('product-price'),
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Base unit price *',
              prefixText: '₹ ',
              hintText: 'e.g. 120.50',
            ),
            validator: (v) => parsePrice(v ?? '') == null
                ? 'Enter ₹0.01–₹10,00,000, with up to 2 decimals.'
                : null,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _discountMode,
            decoration: const InputDecoration(labelText: 'Discount style'),
            items: const [
              DropdownMenuItem(
                value: 'amount',
                child: Text('₹ off each listed unit'),
              ),
              DropdownMenuItem(
                value: 'percent',
                child: Text('% off base unit price'),
              ),
            ],
            onChanged: (v) => setState(() {
              _discountMode = v!;
              _discount.text = '0';
            }),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _discount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _discountMode == 'percent'
                  ? 'Discount percentage'
                  : 'Discount per unit',
              helperText:
                  'Optional; 0 means no discount. Percent discounts round down to a paise.',
            ),
            validator: (v) {
              final base = parsePrice(_price.text);
              return base == null ||
                      discountFromInput(
                            v ?? '',
                            base,
                            percent: _discountMode == 'percent',
                          ) ==
                          null
                  ? 'Discount must leave a positive selling price.'
                  : null;
            },
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _deliveryAllowed,
            onChanged: (v) => setState(() => _deliveryAllowed = v),
            title: const Text('Allow home delivery for this product'),
            subtitle: const Text(
              'Disable for heavy / bulky goods. Shop delivery must also be enabled; 500 m limit applies.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          if (_deliveryAllowed)
            TextFormField(
              controller: _handling,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Additional delivery handling per unit',
                prefixText: '₹ ',
                helperText:
                    'Added to the shop delivery fee. 0 for no extra charge.',
              ),
              validator: (v) {
                final fee = parseCharge(v ?? '');
                return fee == null || fee > 10000000
                    ? 'Use ₹0–₹1,00,000.'
                    : null;
              },
            ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _mrp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'MRP / original price',
              prefixText: '₹ ',
              hintText: 'Optional',
            ),
            validator: (v) {
              if ((v ?? '').trim().isEmpty) {
                return null;
              }
              final mrp = parsePrice(v!), price = parsePrice(_price.text);
              return mrp == null || price == null || mrp < price
                  ? 'MRP must be valid and not below the selling price.'
                  : null;
            },
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('product-unit'),
            controller: _unit,
            maxLength: 32,
            decoration: const InputDecoration(
              labelText: 'Price is for *',
              hintText: 'e.g. 1 kg, 1 litre, pair, piece',
            ),
            validator: (v) => validateLength(v, 'Unit', 1, 32),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            maxLength: 800,
            decoration: const InputDecoration(
              labelText: 'Product details',
              hintText: 'Size, colour, brand or other useful details.',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available / in stock'),
            subtitle: const Text(
              'Turn off when this product is out of stock.',
              style: TextStyle(fontSize: 11),
            ),
            value: _available,
            onChanged: (v) => setState(() => _available = v),
          ),
        ],
      ),
    ),
  );
}
