import 'package:lpg_station/models/receive_cylinder_badge.dart';

class Receive {
  final int saleID;
  final DateTime saleDate;
  final int stationID;
  final String invoiceNo;
  final String truckNo;
  final String customer;
  final String user;
  final List<CylinderBadge> cylinders;

  Receive({
    required this.saleID,
    required this.saleDate,
    required this.stationID,
    required this.invoiceNo,
    required this.truckNo,
    required this.customer,
    required this.user,
    required this.cylinders,
  });

  factory Receive.fromJson(Map<String, dynamic> json) {
    return Receive(
      saleID: json['SaleID'] ?? 0,
      saleDate: DateTime.parse(json['SaleDate']),
      truckNo: json['TruckNo'],
      customer: json['DealerName'],
      stationID: json['StationID'],
      invoiceNo: json['InvoiceNo'],
      user: json['User'] ?? '',
      cylinders: (json['Cylinders'] as List)
          .map((e) => CylinderBadge.fromJson(e))
          .toList(),
    );
  }
}
