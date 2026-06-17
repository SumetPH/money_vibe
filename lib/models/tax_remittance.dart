enum TaxRemittanceBucketType {
  principal,
  realizedGain,
  dividend,
  interest,
  manual,
}

String taxRemittanceBucketLabel(TaxRemittanceBucketType type) {
  switch (type) {
    case TaxRemittanceBucketType.principal:
      return 'เงินต้น';
    case TaxRemittanceBucketType.realizedGain:
      return 'กำไรขายหุ้น';
    case TaxRemittanceBucketType.dividend:
      return 'ปันผล';
    case TaxRemittanceBucketType.interest:
      return 'ดอกเบี้ย';
    case TaxRemittanceBucketType.manual:
      return 'อื่น ๆ';
  }
}

class TaxRemittanceAllocation {
  final String id;
  final String remittanceId;
  final TaxRemittanceBucketType bucketType;
  final int? taxYear;
  final double amountUsd;
  final String note;

  const TaxRemittanceAllocation({
    required this.id,
    required this.remittanceId,
    required this.bucketType,
    this.taxYear,
    required this.amountUsd,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'remittance_id': remittanceId,
    'bucket_type': bucketType.name,
    'tax_year': taxYear,
    'amount_usd': amountUsd,
    'note': note,
  };

  static TaxRemittanceAllocation fromMap(Map<String, dynamic> m) =>
      TaxRemittanceAllocation(
        id: m['id'] as String,
        remittanceId: m['remittance_id'] as String,
        bucketType:
            TaxRemittanceBucketType.values.asNameMap()[m['bucket_type']
                as String?] ??
            TaxRemittanceBucketType.manual,
        taxYear: (m['tax_year'] as num?)?.toInt(),
        amountUsd: (m['amount_usd'] as num).toDouble(),
        note: m['note'] as String? ?? '',
      );

  TaxRemittanceAllocation copyWith({
    String? remittanceId,
    TaxRemittanceBucketType? bucketType,
    int? taxYear,
    double? amountUsd,
    String? note,
  }) => TaxRemittanceAllocation(
    id: id,
    remittanceId: remittanceId ?? this.remittanceId,
    bucketType: bucketType ?? this.bucketType,
    taxYear: taxYear ?? this.taxYear,
    amountUsd: amountUsd ?? this.amountUsd,
    note: note ?? this.note,
  );
}

class TaxRemittance {
  final String id;
  final String portfolioId;
  final DateTime remittedAt;
  final double amountUsd;
  final double fxRate;
  final double thbAmount;
  final String note;
  final DateTime createdAt;
  final List<TaxRemittanceAllocation> allocations;

  TaxRemittance({
    required this.id,
    required this.portfolioId,
    required this.remittedAt,
    required this.amountUsd,
    required this.fxRate,
    double? thbAmount,
    this.note = '',
    DateTime? createdAt,
    List<TaxRemittanceAllocation>? allocations,
  }) : thbAmount = thbAmount ?? amountUsd * fxRate,
       createdAt = createdAt ?? DateTime.now(),
       allocations = List.unmodifiable(allocations ?? const []);

  double get allocatedUsd =>
      allocations.fold(0.0, (sum, allocation) => sum + allocation.amountUsd);

  double get taxableUsd => allocations
      .where(
        (allocation) =>
            allocation.bucketType != TaxRemittanceBucketType.principal,
      )
      .fold(0.0, (sum, allocation) => sum + allocation.amountUsd);

  double get taxableThb => taxableUsd * fxRate;

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'remitted_at': remittedAt.toIso8601String(),
    'amount_usd': amountUsd,
    'fx_rate': fxRate,
    'thb_amount': thbAmount,
    'note': note,
    'created_at': createdAt.toIso8601String(),
  };

  static TaxRemittance fromMap(
    Map<String, dynamic> m, {
    List<TaxRemittanceAllocation> allocations = const [],
  }) => TaxRemittance(
    id: m['id'] as String,
    portfolioId: m['portfolio_id'] as String,
    remittedAt: DateTime.parse(m['remitted_at'] as String),
    amountUsd: (m['amount_usd'] as num).toDouble(),
    fxRate: (m['fx_rate'] as num).toDouble(),
    thbAmount: (m['thb_amount'] as num).toDouble(),
    note: m['note'] as String? ?? '',
    createdAt: DateTime.parse(m['created_at'] as String),
    allocations: allocations,
  );

  TaxRemittance copyWith({
    String? portfolioId,
    DateTime? remittedAt,
    double? amountUsd,
    double? fxRate,
    double? thbAmount,
    String? note,
    DateTime? createdAt,
    List<TaxRemittanceAllocation>? allocations,
  }) => TaxRemittance(
    id: id,
    portfolioId: portfolioId ?? this.portfolioId,
    remittedAt: remittedAt ?? this.remittedAt,
    amountUsd: amountUsd ?? this.amountUsd,
    fxRate: fxRate ?? this.fxRate,
    thbAmount: thbAmount ?? this.thbAmount,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    allocations: allocations ?? this.allocations,
  );
}
