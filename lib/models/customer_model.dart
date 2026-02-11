class CustomerDto {
  final int customerID;
  final String customerName;
  final String? customerPhone;
  //final String? customerStation;
  final String? customerLocation;
  // final String? category;
  // final String? customerType;
  final double balance;
  // final double cylinderBalance;
  // final double prepaidBalance;

  CustomerDto({
    required this.customerID,
    required this.customerName,
    this.customerPhone,
    //  this.customerStation,
    this.customerLocation,
    // this.category,
    // this.customerType,
    required this.balance,
    // required this.cylinderBalance,
    // required this.prepaidBalance,
  });

  factory CustomerDto.fromJson(Map<String, dynamic> json) {
    return CustomerDto(
      customerID: json['CustomerID'] ?? 0,
      customerName: json['CustomerName'] ?? '',
      customerPhone: json['CustomerPhone'],
      // customerStation: json['customerStation'],
      customerLocation: json['CustomerLocation'],
      // category: json['category'],
      // customerType: json['customerType'],
      balance: (json['Balance'] ?? 0).toDouble(),
      // cylinderBalance: (json['cylinderBalance'] ?? 0).toDouble(),
      // prepaidBalance: (json['prepaidBalance'] ?? 0).toDouble(),
    );
  }

  bool get hasBalance => balance > 0;
  // bool get hasCylinderBalance => cylinderBalance > 0;
}
