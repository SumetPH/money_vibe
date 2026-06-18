class PortfolioAnnualReport {
  final String id;
  final String portfolioId;
  final int year;
  final double inflowUsd;
  final double inflowThb;
  final double dividendGrossUsd;
  final double dividendTaxWithheldUsd;
  final double dividendNetUsd;
  final double remittedUsd;
  final double remittedThb;
  final String note;
  final DateTime createdAt;

  PortfolioAnnualReport({
    required this.id,
    required this.portfolioId,
    required this.year,
    required this.inflowUsd,
    this.inflowThb = 0,
    this.dividendGrossUsd = 0,
    this.dividendTaxWithheldUsd = 0,
    this.dividendNetUsd = 0,
    this.remittedUsd = 0,
    this.remittedThb = 0,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'year': year,
    'inflow_usd': inflowUsd,
    'inflow_thb': inflowThb,
    'dividend_gross_usd': dividendGrossUsd,
    'dividend_tax_withheld_usd': dividendTaxWithheldUsd,
    'dividend_net_usd': dividendNetUsd,
    'remitted_usd': remittedUsd,
    'remitted_thb': remittedThb,
    'note': note,
    'created_at': createdAt.toIso8601String(),
  };

  static PortfolioAnnualReport fromMap(Map<String, dynamic> m) {
    return PortfolioAnnualReport(
      id: m['id'] as String,
      portfolioId: m['portfolio_id'] as String,
      year: (m['year'] as num).toInt(),
      inflowUsd: (m['inflow_usd'] as num).toDouble(),
      inflowThb: (m['inflow_thb'] as num?)?.toDouble() ?? 0,
      dividendGrossUsd: (m['dividend_gross_usd'] as num?)?.toDouble() ?? 0,
      dividendTaxWithheldUsd:
          (m['dividend_tax_withheld_usd'] as num?)?.toDouble() ?? 0,
      dividendNetUsd: (m['dividend_net_usd'] as num?)?.toDouble() ?? 0,
      remittedUsd: (m['remitted_usd'] as num?)?.toDouble() ?? 0,
      remittedThb: (m['remitted_thb'] as num?)?.toDouble() ?? 0,
      note: m['note'] as String? ?? '',
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
    );
  }

  PortfolioAnnualReport copyWith({
    String? id,
    String? portfolioId,
    int? year,
    double? inflowUsd,
    double? inflowThb,
    double? dividendGrossUsd,
    double? dividendTaxWithheldUsd,
    double? dividendNetUsd,
    double? remittedUsd,
    double? remittedThb,
    String? note,
    DateTime? createdAt,
  }) {
    return PortfolioAnnualReport(
      id: id ?? this.id,
      portfolioId: portfolioId ?? this.portfolioId,
      year: year ?? this.year,
      inflowUsd: inflowUsd ?? this.inflowUsd,
      inflowThb: inflowThb ?? this.inflowThb,
      dividendGrossUsd: dividendGrossUsd ?? this.dividendGrossUsd,
      dividendTaxWithheldUsd:
          dividendTaxWithheldUsd ?? this.dividendTaxWithheldUsd,
      dividendNetUsd: dividendNetUsd ?? this.dividendNetUsd,
      remittedUsd: remittedUsd ?? this.remittedUsd,
      remittedThb: remittedThb ?? this.remittedThb,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
