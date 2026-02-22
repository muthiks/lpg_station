// ─────────────────────────────────────────────────────────────────
// DTOs
// ─────────────────────────────────────────────────────────────────

class SaleSummaryItem {
  final int lubId;
  final String lubName;
  final int quantity;

  const SaleSummaryItem({
    required this.lubId,
    required this.lubName,
    required this.quantity,
  });

  factory SaleSummaryItem.fromJson(Map<String, dynamic> json) =>
      SaleSummaryItem(
        lubId: json['LubId'] as int,
        lubName: json['LubName'] as String,
        quantity: json['Quantity'] as int,
      );
}

class SaleSummaryResponse {
  final List<SaleSummaryItem> cylinders;
  final List<SaleSummaryItem> accessories;

  const SaleSummaryResponse({
    required this.cylinders,
    required this.accessories,
  });

  factory SaleSummaryResponse.fromJson(Map<String, dynamic> json) =>
      SaleSummaryResponse(
        cylinders: ((json['cylinders'] ?? json['Cylinders']) as List? ?? [])
            .map((e) => SaleSummaryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        accessories:
            ((json['accessories'] ?? json['Accessories']) as List? ?? [])
                .map((e) => SaleSummaryItem.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  bool get isEmpty => cylinders.isEmpty && accessories.isEmpty;
}
