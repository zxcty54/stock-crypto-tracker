class ContentReport {
  const ContentReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
    this.reporterId,
    this.statusNote = '',
    this.isSample = false,
  });
  final String id,
      targetType,
      targetId,
      targetTitle,
      reason,
      details,
      status,
      statusNote;
  final String? reporterId;
  final DateTime createdAt;
  final bool isSample;

  factory ContentReport.fromJson(Map<String, dynamic> json) => ContentReport(
    id: json['id'] as String,
    reporterId: json['reporter_id'] as String?,
    targetType: json['target_type'] as String,
    targetId: json['target_id'] as String,
    targetTitle: json['target_title'] as String? ?? '',
    reason: json['reason'] as String,
    details: json['details'] as String? ?? '',
    status: json['status'] as String? ?? 'pending',
    statusNote: json['status_note'] as String? ?? '',
    isSample: json['is_sample'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reporter_id': reporterId,
    'target_type': targetType,
    'target_id': targetId,
    'target_title': targetTitle,
    'reason': reason,
    'details': details,
    'status': status,
    'status_note': statusNote,
    'is_sample': isSample,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

const reportReasons = [
  'Inappropriate or offensive content',
  'Misleading, scam or fake listing',
  'Incorrect business contact or address',
  'Harassment or abusive behavior',
  'Unlawful or prohibited commodity',
  'Other issue',
];
