class PortfolioAnnualReport {
  final String id;
  final String portfolioId;
  final int year;
  final double inflowUsd;
  final String note;
  final DateTime createdAt;

  PortfolioAnnualReport({
    required this.id,
    required this.portfolioId,
    required this.year,
    required this.inflowUsd,
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'portfolio_id': portfolioId,
    'year': year,
    'inflow_usd': inflowUsd,
    'note': note,
    'created_at': createdAt.toIso8601String(),
  };

  static PortfolioAnnualReport fromMap(Map<String, dynamic> m) {
    return PortfolioAnnualReport(
      id: m['id'] as String,
      portfolioId: m['portfolio_id'] as String,
      year: (m['year'] as num).toInt(),
      inflowUsd: (m['inflow_usd'] as num).toDouble(),
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
    String? note,
    DateTime? createdAt,
  }) {
    return PortfolioAnnualReport(
      id: id ?? this.id,
      portfolioId: portfolioId ?? this.portfolioId,
      year: year ?? this.year,
      inflowUsd: inflowUsd ?? this.inflowUsd,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
