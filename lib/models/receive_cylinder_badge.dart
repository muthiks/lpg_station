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

  /// Computed badge text (BEST PRACTICE)
  String get badgeText => '$cylinderType - ($totalCount-$undeliveredCount)';
}
