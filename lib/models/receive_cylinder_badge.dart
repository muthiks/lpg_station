class CylinderBadge {
  final int cylinderId;
  final String cylinderType;
  final int totalCount;
  final int undeliveredCount;

  CylinderBadge({
    required this.cylinderId,
    required this.cylinderType,
    required this.totalCount,
    required this.undeliveredCount,
  });

  factory CylinderBadge.fromJson(Map<String, dynamic> json) {
    return CylinderBadge(
      cylinderId: json['CylinderID'],
      cylinderType: json['CylinderType'],
      totalCount: json['TotalCount'],
      undeliveredCount: json['UndeliveredCount'],
    );
  }

  /// How many have already been received
  int get receivedCount => totalCount - undeliveredCount;

  /// true when nothing left to receive
  bool get isFullyReceived => undeliveredCount == 0;

  /// e.g. "50KG - (4-0)" means 4 received out of 4
  ///      "50KG - (0-4)" means 0 received out of 4  ✅ corrected order
  String get badgeText => '$cylinderType - ($receivedCount-$totalCount)';
}
