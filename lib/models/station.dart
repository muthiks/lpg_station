class Station {
  final int id;
  final String name;

  Station({required this.id, required this.name});

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['StationID'] as int,
      name: json['StationName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'StationID': id, 'StationName': name};
  }
}
