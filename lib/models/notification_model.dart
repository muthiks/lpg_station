// lib/models/notification_model.dart

class NotificationModel {
  final int notificationID;
  final int lpgSaleID;
  final String invoiceNo;
  final String description;
  final bool read;
  final DateTime dateAdded;
  final String? saleStatus;

  NotificationModel({
    required this.notificationID,
    required this.lpgSaleID,
    required this.invoiceNo,
    required this.description,
    required this.read,
    required this.dateAdded,
    this.saleStatus,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationID: json['notificationID'] ?? json['NotificationID'] ?? 0,
      lpgSaleID: json['lpgSaleID'] ?? json['LpgSaleID'] ?? 0,
      invoiceNo: json['invoiceNo'] ?? json['InvoiceNo'] ?? '',
      description: json['description'] ?? json['Description'] ?? '',
      read: json['read'] ?? json['Read'] ?? false,
      dateAdded: DateTime.parse(
        json['dateAdded'] ??
            json['DateAdded'] ??
            DateTime.now().toIso8601String(),
      ),
      saleStatus: json['title'] ?? json['Title'],
    );
  }
}
