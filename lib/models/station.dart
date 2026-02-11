class Station {
  final int stationID;
  final String stationName;

  Station({required this.stationID, required this.stationName});

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationID: json['StationID'] as int,
      stationName: json['StationName'] as String,
    );
  }
}
