class CylinderBadge {
  final int cylinderId;
  final int saleDetailId; // ✅ added
  final String cylinderType;
  final int totalCount;
  final int undeliveredCount;
  final double price; // ✅ added

  CylinderBadge({
    required this.cylinderId,
    required this.saleDetailId,
    required this.cylinderType,
    required this.totalCount,
    required this.undeliveredCount,
    required this.price,
  });

  factory CylinderBadge.fromJson(Map<String, dynamic> json) {
    return CylinderBadge(
      cylinderId: json['CylinderID'],
      saleDetailId: json['SaleDetailID'], // ✅ added
      cylinderType: json['CylinderType'],
      totalCount: json['TotalCount'],
      undeliveredCount: json['UndeliveredCount'],
      price: (json['Price'] as num).toDouble(), // ✅ added
    );
  }

  int get receivedCount => undeliveredCount;
  bool get isFullyReceived => undeliveredCount == 0;
  String get badgeText => '$cylinderType - ($receivedCount-$totalCount)';
}
