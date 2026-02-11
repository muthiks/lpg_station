class Driver {
  final String id;
  final String fullName;

  Driver({required this.id, required this.fullName});

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(id: json['Id'], fullName: json['FullName']);
  }
}
