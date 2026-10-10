const mandiUnits = ['kg', 'dozen', 'piece', 'bunch', '100 kg'];
const mandiPriceTypes = ['wholesale', 'retail'];

class MandiItem {
  const MandiItem({
    required this.id,
    required this.name,
    required this.hindiName,
    required this.category,
    this.defaultUnit = 'kg',
    this.active = true,
  });
  final String id, name, hindiName, category, defaultUnit;
  final bool active;
  factory MandiItem.fromJson(Map<String, dynamic> json) => MandiItem(
    id: json['id'] as String,
    name: json['name'] as String,
    hindiName: json['hindi_name'] as String,
    category: json['category'] as String,
    defaultUnit: json['default_unit'] as String? ?? 'kg',
    active: json['is_active'] as bool? ?? true,
  );
}

class MandiRate {
  const MandiRate({
    required this.id,
    required this.itemId,
    required this.priceType,
    required this.unit,
    required this.minPaise,
    required this.maxPaise,
    required this.effectiveDate,
    required this.updatedAt,
    this.note = '',
  });
  final String id, itemId, priceType, unit, note;
  final int minPaise, maxPaise;
  final DateTime effectiveDate, updatedAt;
  bool get isToday => mandiDateKey(effectiveDate) == mandiDateKey(indiaNow());
  factory MandiRate.fromJson(Map<String, dynamic> json) => MandiRate(
    id: json['id'] as String,
    itemId: json['item_id'] as String,
    priceType: json['price_type'] as String,
    unit: json['unit'] as String,
    minPaise: (json['min_paise'] as num).toInt(),
    maxPaise: (json['max_paise'] as num).toInt(),
    effectiveDate: DateTime.parse(json['effective_date'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    note: json['note'] as String? ?? '',
  );
}

DateTime indiaNow() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
String mandiDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
