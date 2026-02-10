import 'package:lpg_station/models/receive_cylinder_badge.dart';

class Receive {
  final int saleID;
  final DateTime saleDate;
  final String invoiceNo;
  final String truckNo;
  final String customer;
  final List<CylinderBadge> cylinders;

  Receive({
    required this.saleID,
    required this.saleDate,
    required this.invoiceNo,
    required this.truckNo,
    required this.customer,
    required this.cylinders,
  });

  factory Receive.fromJson(Map<String, dynamic> json) {
    return Receive(
      saleID: json['SaleID'] ?? 0,
      saleDate: DateTime.parse(json['SaleDate']),
      truckNo: json['TruckNo'],
      customer: json['DealerName'],
      invoiceNo: json['InvoiceNo'],
      cylinders: (json['Cylinders'] as List)
          .map((e) => CylinderBadge.fromJson(e))
          .toList(),
    );
  }
}
