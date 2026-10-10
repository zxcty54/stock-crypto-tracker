class MarketSettings {
  const MarketSettings({
    this.verificationPhone = '',
    this.supportEmail = '',
    this.privacyUrl = '',
    this.termsUrl = '',
    this.mandiName = 'Danapur Mandi',
  });
  final String verificationPhone, supportEmail, privacyUrl, termsUrl, mandiName;
  factory MarketSettings.fromJson(Map<String, dynamic> json) => MarketSettings(
    verificationPhone: json['verification_phone'] as String? ?? '',
    supportEmail: json['support_email'] as String? ?? '',
    privacyUrl: json['privacy_url'] as String? ?? '',
    termsUrl: json['terms_url'] as String? ?? '',
    mandiName: json['mandi_name'] as String? ?? 'Danapur Mandi',
  );
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.target,
    required this.createdAt,
  });
  final String id, action, target;
  final DateTime createdAt;
  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as String,
    action: json['action'] as String,
    target: json['target'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
