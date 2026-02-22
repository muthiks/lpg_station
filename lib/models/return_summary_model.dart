class ReturnSummaryItem {
  final int lubId;
  final String lubName;
  final String returnType;
  final int quantity;

  const ReturnSummaryItem({
    required this.lubId,
    required this.lubName,
    required this.returnType,
    required this.quantity,
  });

  factory ReturnSummaryItem.fromJson(Map<String, dynamic> json) =>
      ReturnSummaryItem(
        lubId: json['LubId'] as int,
        lubName: json['LubName'] as String,
        returnType: json['ReturnType'] as String,
        quantity: json['Quantity'] as int,
      );
}

class ReturnSummaryResponse {
  final List<ReturnSummaryItem> cylinders;

  const ReturnSummaryResponse({required this.cylinders});

  factory ReturnSummaryResponse.fromJson(Map<String, dynamic> json) =>
      ReturnSummaryResponse(
        cylinders: ((json['cylinders'] ?? json['Cylinders']) as List? ?? [])
            .map((e) => ReturnSummaryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isEmpty => cylinders.isEmpty;
}
