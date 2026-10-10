import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/aangan_app.dart';
import '../data/bihar_locations.dart';
import '../models/rental_listing.dart';
import '../services/app_backend.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import 'auth_screen.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _townController = TextEditingController();
  final _blockController = TextEditingController();
  final _localityController = TextEditingController();
  final _roadController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _areaController = TextEditingController();
  final _hostNameController = TextEditingController();

  final Map<String, String> _tenantRules = <String, String>{
    for (final key in houseRuleLabels.keys) key: 'discuss',
  };
  final Set<String> _selectedAmenities = <String>{};
  final List<XFile> _photos = <XFile>[];

  String? _district;
  String _propertyType = 'Apartment';
  String _furnishing = 'Unfurnished';
  String _listerType = 'owner';
  String _brokerFee = 'Discuss before visit';
  int _bedrooms = 1;
  int _bathrooms = 1;
  DateTime? _availableFrom;
  bool _rentNegotiable = false;
  bool _maintenanceIncluded = false;
  bool _showExactAddress = false;
  bool _submitting = false;

  static const _propertyTypes = <String>[
    'Apartment',
    'Independent floor',
    'Independent house',
    'Studio',
    'PG / shared home',
  ];
  static const _furnishingTypes = <String>[
    'Unfurnished',
    'Semi-furnished',
    'Furnished',
  ];
  static const _brokerFeeOptions = <String>[
    'No brokerage',
    'Half month rent',
    'One month rent',
    'Discuss before visit',
  ];
  static const _amenityOptions = <String>[
    'Balcony',
    'Lift',
    'Parking',
    'Power backup',
    'Geyser',
    'Water supply',
    'Wi-Fi ready',
    'CCTV',
    'Private terrace',
    'Modular kitchen',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _townController.dispose();
    _blockController.dispose();
    _localityController.dispose();
    _roadController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _areaController.dispose();
    _hostNameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final user = AppBackend.currentUser;
    if (user == null) return;
    try {
      final profile = await AppBackend.client
          .from('profiles')
          .select('full_name, account_type')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || profile == null) return;
      setState(() {
        if (_hostNameController.text.isEmpty) {
          _hostNameController.text = profile['full_name']?.toString() ?? '';
        }
        final accountType = profile['account_type']?.toString();
        if (accountType == 'broker' || accountType == 'owner') {
          _listerType = accountType!;
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'List your property',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 5, 18, 28),
            children: <Widget>[
              if (!AppBackend.isReady) ...<Widget>[
                const BackendNotice(),
                const SizedBox(height: 14),
              ],
              _introCard(),
              const SizedBox(height: 15),
              _FormSection(
                title: 'The home',
                subtitle: 'A few accurate details help the right renter find you.',
                child: Column(
                  children: <Widget>[
                    _textField(
                      controller: _titleController,
                      label: 'Listing title',
                      hint: 'e.g. Bright 2 BHK near Boring Road',
                      validator: _minLength(8),
                      maxLength: 70,
                    ),
                    const SizedBox(height: 11),
                    _textField(
                      controller: _descriptionController,
                      label: 'Describe your home',
                      hint: 'Tell renters about light, water, nearby shops, access…',
                      validator: _minLength(20),
                      maxLines: 4,
                      maxLength: 900,
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _propertyType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Home type',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                            items: _propertyTypes
                                .map((type) => DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(
                                        type,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(
                              () => _propertyType = value ?? 'Apartment',
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _furnishing,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Furnishing',
                              prefixIcon: Icon(Icons.chair_alt_outlined),
                            ),
                            items: _furnishingTypes
                                .map((type) => DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(
                              () => _furnishing = value ?? 'Unfurnished',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _numberField(
                            controller: _rentController,
                            label: 'Monthly rent',
                            prefix: '₹ ',
                            validator: _positiveNumber,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _numberField(
                            controller: _depositController,
                            label: 'Security deposit',
                            prefix: '₹ ',
                            validator: _nonNegativeNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      title: const Text(
                        'Rent is negotiable',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      value: _rentNegotiable,
                      activeColor: AanganColors.forest,
                      onChanged: (value) => setState(() => _rentNegotiable = value),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      title: const Text(
                        'Maintenance included in rent',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      value: _maintenanceIncluded,
                      activeColor: AanganColors.forest,
                      onChanged: (value) =>
                          setState(() => _maintenanceIncluded = value),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _bedrooms,
                            decoration: const InputDecoration(
                              labelText: 'Bedrooms',
                              prefixIcon: Icon(Icons.bed_outlined),
                            ),
                            items: <int>[0, 1, 2, 3, 4, 5]
                                .map((value) => DropdownMenuItem<int>(
                                      value: value,
                                      child: Text(value == 0 ? 'Studio' : '$value BHK'),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(
                              () => _bedrooms = value ?? 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _bathrooms,
                            decoration: const InputDecoration(
                              labelText: 'Bathrooms',
                              prefixIcon: Icon(Icons.shower_outlined),
                            ),
                            items: <int>[1, 2, 3, 4, 5]
                                .map((value) => DropdownMenuItem<int>(
                                      value: value,
                                      child: Text('$value'),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(
                              () => _bathrooms = value ?? 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _numberField(
                            controller: _areaController,
                            label: 'Area sq ft',
                            validator: _positiveNumber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    _availabilityField(),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FormSection(
                title: 'Where in Bihar?',
                subtitle: 'District → town → block → locality. Pin the road if useful.',
                child: Column(
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      value: _district,
                      isExpanded: true,
                      validator: (value) => value == null ? 'Choose a district' : null,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: BiharLocations.districts
                          .map((district) => DropdownMenuItem<String>(
                                value: district,
                                child: Text(district),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() {
                        if (_district != value) {
                          _townController.clear();
                          _blockController.clear();
                        }
                        _district = value;
                      }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _suggestedField(
                            controller: _townController,
                            label: 'City / town',
                            hint: 'Patna, Danapur…',
                            suggestions: BiharLocations.townsFor(_district),
                            validator: _minLength(2),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _suggestedField(
                            controller: _blockController,
                            label: 'Block',
                            hint: 'Block / anchal',
                            suggestions: BiharLocations.blocksFor(_district),
                            validator: _minLength(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _textField(
                      controller: _localityController,
                      label: 'Locality / mohalla',
                      hint: 'e.g. Kankarbagh, AP Colony',
                      validator: _minLength(2),
                    ),
                    const SizedBox(height: 10),
                    _textField(
                      controller: _roadController,
                      label: 'Road / street / road number (optional)',
                      hint: 'e.g. Road No. 4',
                      prefixIcon: Icons.signpost_outlined,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _textField(
                            controller: _landmarkController,
                            label: 'Nearby landmark',
                            hint: 'Optional',
                          ),
                        ),
                        const SizedBox(width: 9),
                        SizedBox(
                          width: 118,
                          child: _textField(
                            controller: _pincodeController,
                            label: 'PIN code',
                            hint: '800001',
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) return null;
                              if (value.length != 6) return '6 digits';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                      value: _showExactAddress,
                      activeColor: AanganColors.forest,
                      onChanged: (value) =>
                          setState(() => _showExactAddress = value),
                      title: const Text(
                        'Show road, landmark & PIN publicly',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'Off by default. You can share exact directions in chat.',
                        style: TextStyle(fontSize: 10, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FormSection(
                title: 'Your house rules',
                subtitle:
                    'Choose Yes, No or Discuss for each. Renters can filter before messaging.',
                child: Column(
                  children: houseRuleLabels.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _RuleSetting(
                        title: entry.value,
                        value: _tenantRules[entry.key] ?? 'discuss',
                        onChanged: (value) => setState(
                          () => _tenantRules[entry.key] = value,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              _FormSection(
                title: 'Amenities & photos',
                subtitle: 'Real, recent photos build trust. Add up to 8.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 7,
                      runSpacing: 1,
                      children: _amenityOptions.map((amenity) {
                        final selected = _selectedAmenities.contains(amenity);
                        return FilterChip(
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (value) => setState(() {
                            if (value) {
                              _selectedAmenities.add(amenity);
                            } else {
                              _selectedAmenities.remove(amenity);
                            }
                          }),
                          label: Text(amenity),
                          labelStyle: TextStyle(
                            color: selected ? AanganColors.forest : AanganColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          backgroundColor: AanganColors.canvas,
                          selectedColor: AanganColors.paleGreen,
                          side: BorderSide(
                            color: selected ? AanganColors.leaf : AanganColors.line,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ..._photos.asMap().entries.map((entry) {
                          return Stack(
                            children: <Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.file(
                                  File(entry.value.path),
                                  width: 83,
                                  height: 83,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 83,
                                    height: 83,
                                    color: AanganColors.paleGreen,
                                    child: const Icon(Icons.image_outlined),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _photos.removeAt(entry.key)),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 15),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        if (_photos.length < 8)
                          InkWell(
                            onTap: _pickPhotos,
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                              width: 83,
                              height: 83,
                              decoration: BoxDecoration(
                                color: AanganColors.paleGreen,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: const Color(0xFFD4E1D5)),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(Icons.add_a_photo_outlined,
                                      color: AanganColors.forest, size: 21),
                                  SizedBox(height: 5),
                                  Text(
                                    'Add photos',
                                    style: TextStyle(
                                      color: AanganColors.forest,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_photos.isEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      const Text(
                        'At least one photo is required to submit.',
                        style: TextStyle(color: AanganColors.muted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FormSection(
                title: 'Who is listing?',
                subtitle: 'Keep broker fees and terms clear with every renter.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SegmentedButton<String>(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'owner',
                          label: Text('Property owner'),
                          icon: Icon(Icons.home_outlined),
                        ),
                        ButtonSegment<String>(
                          value: 'broker',
                          label: Text('Local broker'),
                          icon: Icon(Icons.badge_outlined),
                        ),
                      ],
                      selected: <String>{_listerType},
                      showSelectedIcon: false,
                      onSelectionChanged: (values) =>
                          setState(() => _listerType = values.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_listerType == 'broker')
                      DropdownButtonFormField<String>(
                        value: _brokerFee,
                        decoration: const InputDecoration(
                          labelText: 'Brokerage / fee disclosure',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                        ),
                        items: _brokerFeeOptions
                            .map((fee) => DropdownMenuItem<String>(
                                  value: fee,
                                  child: Text(fee),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _brokerFee = value ?? _brokerFee),
                      )
                    else
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Direct owner listing · no brokerage fee',
                          style: TextStyle(
                            color: AanganColors.forest,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _hostNameController,
                      label: 'Your display name',
                      hint: 'Name shown to renters',
                      validator: _required,
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Your mobile number stays private by default. Set its visibility in Profile; renters can always message you in Aangan.',
                      style: TextStyle(
                        color: AanganColors.muted,
                        fontSize: 10,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: _submitting ? 'Submitting…' : 'Submit for approval',
                icon: Icons.verified_user_outlined,
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
              const SizedBox(height: 9),
              const Text(
                'Your home will not appear in search until an admin approves it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AanganColors.muted,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AanganColors.forest,
        borderRadius: BorderRadius.circular(19),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.handshake_outlined, color: AanganColors.gold, size: 23),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Aap apne rules set karein — pet, bachelor, visitors, late entry. Renters ko pehle se clear dikhega; listing admin review ke baad hi live hogi.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityField() {
    final label = _availableFrom == null
        ? 'Set move-in date (optional)'
        : 'Available from ${_availableFrom!.day}/${_availableFrom!.month}/${_availableFrom!.year}';
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: _availableFrom ?? DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 730)),
        );
        if (selected != null) setState(() => _availableFrom = selected);
      },
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AanganColors.forest,
        minimumSize: const Size(double.infinity, 48),
        alignment: Alignment.centerLeft,
        side: const BorderSide(color: AanganColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    IconData? prefixIcon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        alignLabelWithHint: maxLines > 1,
        counterStyle: const TextStyle(fontSize: 9),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: InputDecoration(labelText: label, prefixText: prefix),
    );
  }

  Widget _suggestedField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> suggestions,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _textField(
          controller: controller,
          label: label,
          hint: hint,
          validator: validator,
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length > 4 ? 4 : suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) => InkWell(
                onTap: () => setState(() {
                  controller.text = suggestions[index];
                }),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AanganColors.canvas,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    suggestions[index],
                    style: const TextStyle(
                      color: AanganColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(picked.take(8));
      });
    } catch (error) {
      if (mounted) _showMessage('Photos select nahi ho paayi: $error');
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? Function(String?) _minLength(int minimum) {
    return (value) {
      if (value == null || value.trim().length < minimum) {
        return 'Enter at least $minimum characters';
      }
      return null;
    };
  }

  String? _positiveNumber(String? value) {
    final number = int.tryParse(value ?? '');
    if (number == null || number <= 0) return 'Enter a valid amount';
    return null;
  }

  String? _nonNegativeNumber(String? value) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < 0) return 'Enter a valid amount';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      _showMessage('Please add at least one property photo.');
      return;
    }
    if (!AppBackend.isReady) {
      _showMessage('Supabase connect hone ke baad hi listing submit hogi.');
      return;
    }
    if (AppBackend.currentUser == null) {
      final signedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
      );
      if (signedIn != true || AppBackend.currentUser == null) return;
    }

    setState(() => _submitting = true);
    try {
      await RentalRepository.instance.submitListing(
        photos: _photos,
        fields: <String, dynamic>{
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'district': _district,
          'town': _townController.text.trim(),
          'block': _blockController.text.trim(),
          'locality': _localityController.text.trim(),
          'road': _roadController.text.trim(),
          'landmark': _landmarkController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'property_type': _propertyType,
          'furnishing': _furnishing,
          'lister_type': _listerType,
          'broker_fee': _listerType == 'broker' ? _brokerFee : 'No brokerage',
          'host_name': _hostNameController.text.trim(),
          'monthly_rent': int.parse(_rentController.text),
          'deposit': int.parse(_depositController.text),
          'bedrooms': _bedrooms,
          'bathrooms': _bathrooms,
          'area_sqft': int.parse(_areaController.text),
          'rent_negotiable': _rentNegotiable,
          'maintenance_included': _maintenanceIncluded,
          'show_exact_address': _showExactAddress,
          'available_from': _availableFrom?.toIso8601String().split('T').first,
          'amenities': _selectedAmenities.toList(),
          'tenant_rules': _tenantRules,
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.hourglass_top_rounded,
            color: AanganColors.forest,
            size: 35,
          ),
          title: const Text('Home sent for review'),
          content: const Text(
            'Shukriya! Your listing is saved as pending. It will appear in Bihar search only after an admin approves it.',
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage('Listing submit nahi hui: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AanganColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AanganColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AanganColors.muted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RuleSetting extends StatelessWidget {
  const _RuleSetting({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: AanganColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'allowed', label: Text('Yes')),
            ButtonSegment<String>(value: 'discuss', label: Text('Discuss')),
            ButtonSegment<String>(value: 'not_allowed', label: Text('No')),
          ],
          selected: <String>{value},
          showSelectedIcon: false,
          onSelectionChanged: (values) => onChanged(values.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
