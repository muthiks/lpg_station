class SaleDto {
  final int saleID;
  final int stationID;
  final String stationName;
  final DateTime saleDate;
  final String invoiceNo;
  final String? orderNo;
  final int customerID;
  final String customerName;
  final String? customerPhone;
  final double total;
  final double balance;
  final String? status;
  final bool isApproved;
  final String? approvedBy;
  final DateTime? dateApproved;
  final String? deliveryGuy;
  final String? pickupPoint;
  final String? dispatcher;
  final DateTime? dateDispatched;
  final DateTime? dateConfirmed;
  final DateTime? dateDelivered;
  final String? comments;

  SaleDto({
    required this.saleID,
    required this.stationID,
    required this.stationName,
    required this.saleDate,
    required this.invoiceNo,
    this.orderNo,
    required this.customerID,
    required this.customerName,
    this.customerPhone,
    required this.total,
    required this.balance,
    this.status,
    required this.isApproved,
    this.approvedBy,
    this.dateApproved,
    this.deliveryGuy,
    this.pickupPoint,
    this.dispatcher,
    this.dateDispatched,
    this.dateConfirmed,
    this.dateDelivered,
    this.comments,
  });

  factory SaleDto.fromJson(Map<String, dynamic> json) {
    return SaleDto(
      saleID: json['SaleID'] ?? 0,
      stationID: json['StationID'] ?? 0,
      stationName: json['StationName'] ?? '',
      saleDate: DateTime.parse(json['SaleDate']),
      invoiceNo: json['InvoiceNo'] ?? '',
      customerID: json['CustomerID'] ?? 0,
      customerName: json['CustomerName'] ?? '',
      total: (json['Total'] ?? 0).toDouble(),
      balance: (json['Balance'] ?? 0).toDouble(),
      status: json['status'],
      isApproved: json['IsApproved'] ?? false,
      approvedBy: json['ApprovedBy'],
      dateApproved: json['DateApproved'] != null
          ? DateTime.parse(json['DateApproved'])
          : null,
      // deliveryGuy: json['deliveryGuy'],
      // pickupPoint: json['pickupPoint'],
      // dispatcher: json['dispatcher'],
      // dateDispatched: json['dateDispatched'] != null
      //     ? DateTime.parse(json['dateDispatched'])
      //     : null,
      // dateConfirmed: json['dateConfirmed'] != null
      //     ? DateTime.parse(json['dateConfirmed'])
      //     : null,
      // dateDelivered: json['dateDelivered'] != null
      //     ? DateTime.parse(json['dateDelivered'])
      //     : null,
      comments: json['comments'],
    );
  }

  bool get isPaid => balance <= 0;
  bool get isPending => status?.toLowerCase() == 'pending';
  bool get isDelivered => dateDelivered != null;
  bool get isDispatched => dateDispatched != null;
}
