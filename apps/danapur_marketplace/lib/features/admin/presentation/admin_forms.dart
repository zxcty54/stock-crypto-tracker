import 'package:flutter/material.dart';
import '../../../core/data/controller.dart';
import '../../../core/data/repository.dart';
import '../../../core/domain/market.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../mandi/domain/mandi.dart';
import '../../seller/presentation/forms.dart';
import '../domain/administration.dart';

class ReviewShopForm extends StatefulWidget {
  const ReviewShopForm({
    super.key,
    required this.controller,
    required this.shop,
  });
  final MarketController controller;
  final Shop shop;
  @override
  State<ReviewShopForm> createState() => _ReviewShopFormState();
}

class _ReviewShopFormState extends State<ReviewShopForm> {
  final _note = TextEditingController();
  String _decision = 'approved';
  bool _photo = false, _whatsapp = false, _busy = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final noteError = validateLength(_note.text, 'Review note', 3, 400);
    if (noteError != null ||
        (_decision == 'approved' &&
            (!_photo ||
                !_whatsapp ||
                widget.shop.verificationPhotoPath == null))) {
      setState(
        () => _error =
            noteError ??
            'Review the private storefront photo and match WhatsApp proof before approval.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.repository.reviewShop(
        widget.shop.id,
        _decision,
        _note.text,
        _whatsapp,
      );
      await widget.controller.reload();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: 'Review ${widget.shop.name}',
    subtitle:
        'Server-enforced administrator action. A photo review is not government or identity certification.',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          'Request: ${widget.shop.id}',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _decision,
          decoration: const InputDecoration(labelText: 'Decision'),
          items: const [
            DropdownMenuItem(value: 'approved', child: Text('Approve')),
            DropdownMenuItem(value: 'rejected', child: Text('Reject')),
            DropdownMenuItem(value: 'suspended', child: Text('Suspend / hide')),
          ],
          onChanged: _busy
              ? null
              : (value) => setState(() => _decision = value!),
        ),
        const SizedBox(height: 18),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _photo,
          onChanged: _busy
              ? null
              : (value) => setState(() => _photo = value ?? false),
          title: const Text(
            'I reviewed the uploaded storefront photo',
            style: TextStyle(fontSize: 12),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _whatsapp,
          onChanged: _busy
              ? null
              : (value) => setState(() => _whatsapp = value ?? false),
          title: const Text(
            'WhatsApp sender/photo match this shop and registered mobile',
            style: TextStyle(fontSize: 12),
          ),
        ),
        TextField(
          controller: _note,
          maxLength: 400,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review note / rejection reason *',
            helperText:
                'Visible to the shop owner; avoid private IDs or documents.',
          ),
        ),
      ],
    ),
    onSave: _save,
    busy: _busy,
    error: _error,
    saveLabel: 'Confirm decision',
  );
}

class MandiRateForm extends StatefulWidget {
  const MandiRateForm({
    super.key,
    required this.controller,
    required this.item,
    required this.priceType,
    this.rate,
  });
  final MarketController controller;
  final MandiItem item;
  final String priceType;
  final MandiRate? rate;
  @override
  State<MandiRateForm> createState() => _MandiRateFormState();
}

class _MandiRateFormState extends State<MandiRateForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _min, _max, _note;
  late String _unit;
  late DateTime _date;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final rate = widget.rate;
    _min = TextEditingController(
      text: rate == null ? '' : priceInput(rate.minPaise),
    );
    _max = TextEditingController(
      text: rate == null ? '' : priceInput(rate.maxPaise),
    );
    _note = TextEditingController(text: rate?.note);
    _unit = rate?.unit ?? widget.item.defaultUnit;
    final today = indiaNow();
    _date = DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final minimum = parsePrice(_min.text)!;
      await widget.controller.repository.setMandiRate(
        widget.item,
        widget.priceType,
        _unit,
        minimum,
        _max.text.trim().isEmpty ? minimum : parsePrice(_max.text)!,
        _date,
        _note.text,
      );
      await widget.controller.reload();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: '${widget.item.name} / ${widget.item.hindiName}',
    subtitle:
        '${widget.priceType.toUpperCase()} • enter an actual rate; no automatic or demo prices.',
    onSave: _save,
    busy: _busy,
    error: _error,
    saveLabel: 'Publish rate',
    body: Form(
      key: _form,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Rate is per *'),
            items: mandiUnits
                .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                .toList(),
            onChanged: (value) => setState(() => _unit = value!),
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('mandi-min-price'),
            controller: _min,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price / minimum price *',
              prefixText: '₹ ',
            ),
            validator: (value) => parsePrice(value ?? '') == null
                ? 'Enter ₹0.01–₹10,00,000.'
                : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const ValueKey('mandi-max-price'),
            controller: _max,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Maximum price',
              prefixText: '₹ ',
              helperText: 'Optional: leave blank for one fixed price.',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return null;
              final max = parsePrice(value!), min = parsePrice(_min.text);
              return max == null || min == null || max < min
                  ? 'Maximum must be valid and at least the minimum.'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined, color: green),
            title: Text('Market date: ${mandiDateKey(_date)}'),
            subtitle: const Text(
              'IST date; future dates are not allowed.',
              style: TextStyle(fontSize: 11),
            ),
            trailing: TextButton(
              onPressed: () async {
                final now = indiaNow();
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year, now.month, now.day),
                );
                if (selected != null && mounted)
                  setState(() => _date = selected);
              },
              child: const Text('Change'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Variety / quality note',
              hintText: 'Optional: local variety, grade or quantity condition',
            ),
          ),
        ],
      ),
    ),
  );
}

class MarketSettingsForm extends StatefulWidget {
  const MarketSettingsForm({super.key, required this.controller});
  final MarketController controller;
  @override
  State<MarketSettingsForm> createState() => _MarketSettingsFormState();
}

class _MarketSettingsFormState extends State<MarketSettingsForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _phone, _email, _privacy, _terms, _mandi;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final settings = widget.controller.snapshot.settings;
    _phone = TextEditingController(text: settings.verificationPhone);
    _email = TextEditingController(text: settings.supportEmail);
    _privacy = TextEditingController(text: settings.privacyUrl);
    _terms = TextEditingController(text: settings.termsUrl);
    _mandi = TextEditingController(text: settings.mandiName);
  }

  @override
  void dispose() {
    for (final field in [_phone, _email, _privacy, _terms, _mandi]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.repository.setSettings(
        MarketSettings(
          verificationPhone: _phone.text.trim(),
          supportEmail: _email.text.trim(),
          privacyUrl: _privacy.text.trim(),
          termsUrl: _terms.text.trim(),
          mandiName: _mandi.text.trim(),
        ),
      );
      await widget.controller.reload();
      if (mounted) toast(context, 'Marketplace settings saved.');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _url(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final uri = Uri.tryParse(value!.trim());
    return uri?.scheme == 'https' &&
            uri!.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? null
        : 'Use a valid public HTTPS URL.';
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 640),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operator configuration',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Public business contact and policy links, not Supabase keys. Set these before inviting real shops.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _phone,
                maxLength: 10,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Verification WhatsApp mobile *',
                  prefixText: '+91 ',
                ),
                validator: validatePhone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Support email'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ||
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v!.trim())
                    ? null
                    : 'Enter a valid email.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _mandi,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Mandi display name *',
                ),
                validator: (v) => validateLength(v, 'Mandi name', 3, 80),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _privacy,
                decoration: const InputDecoration(
                  labelText: 'Reviewed privacy policy HTTPS URL',
                ),
                validator: _url,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _terms,
                decoration: const InputDecoration(
                  labelText: 'Reviewed terms HTTPS URL',
                ),
                validator: _url,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_busy ? 'Saving…' : 'Save settings'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AddCommodityForm extends StatefulWidget {
  const AddCommodityForm({super.key, required this.controller});
  final MarketController controller;
  @override
  State<AddCommodityForm> createState() => _AddCommodityFormState();
}

class _AddCommodityFormState extends State<AddCommodityForm> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController(),
      _name = TextEditingController(),
      _hindi = TextEditingController();
  String _category = 'Vegetables', _unit = 'kg';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _hindi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.repository.addMandiItem(
        _id.text.trim(),
        _name.text,
        _hindi.text,
        _category,
        _unit,
      );
      await widget.controller.reload();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormSheet(
    title: 'Add a mandi commodity',
    subtitle:
        'Extend the common/seasonal catalogue without adding sellers or invented prices.',
    onSave: _save,
    busy: _busy,
    error: _error,
    saveLabel: 'Add commodity',
    body: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _id,
            decoration: const InputDecoration(
              labelText: 'Unique ID *',
              hintText: 'e.g. local-mango-variety',
            ),
            validator: (v) =>
                RegExp(r'^[a-z][a-z0-9_-]{1,49}$').hasMatch((v ?? '').trim())
                ? null
                : 'Use 2–50 lowercase letters, digits or hyphens.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'English name *'),
            validator: (v) => validateLength(v, 'Name', 2, 80),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _hindi,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Hindi name *'),
            validator: (v) => validateLength(v, 'Hindi name', 1, 80),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: const [
              DropdownMenuItem(value: 'Vegetables', child: Text('Vegetables')),
              DropdownMenuItem(value: 'Fruits', child: Text('Fruits')),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Default unit'),
            items: mandiUnits
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _unit = v!),
          ),
        ],
      ),
    ),
  );
}
