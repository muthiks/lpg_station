class CylinderType {
  final int id;
  final String type;
  final int capacity;

  CylinderType({required this.id, required this.type, required this.capacity});

  factory CylinderType.fromJson(Map<String, dynamic> json) {
    return CylinderType(
      id: json['LubId'],
      type: json['CylinderType'],
      capacity: json['Capacity'],
    );
  }
}
