class CylinderReturn {
  final int returnId;
  final DateTime returnDate;
  final int customerId;
  final String customerName;
  final int stationId;
  final String stationName;
  final String status;
  final String returnType;
  final List<ReturnCylinderInfo> cylinders;

  CylinderReturn({
    required this.returnId,
    required this.returnDate,
    required this.customerId,
    required this.customerName,
    required this.stationId,
    required this.stationName,
    required this.status,
    required this.returnType,
    required this.cylinders,
  });

  factory CylinderReturn.fromJson(Map<String, dynamic> json) {
    return CylinderReturn(
      returnId: json['ReturnID'] as int,
      returnDate: DateTime.parse(json['ReturnDate'] as String),
      customerId: json['CustomerID'] as int,
      customerName: json['CustomerName'] as String,
      stationId: json['StationID'] as int,
      stationName: json['StationName'] as String? ?? '',
      status: json['Status'] as String? ?? '',
      returnType: json['ReturnType'] as String? ?? '',
      cylinders: (json['Cylinders'] as List<dynamic>? ?? [])
          .map((c) => ReturnCylinderInfo.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ReturnID': returnId,
      'ReturnDate': returnDate.toIso8601String(),
      'CustomerID': customerId,
      'CustomerName': customerName,
      'StationID': stationId,
      'StationName': stationName,
      'Status': status,
      'ReturnType': returnType,
      'Cylinders': cylinders.map((c) => c.toJson()).toList(),
    };
  }
}

class ReturnCylinderInfo {
  final int lubId;
  final String lubName;
  final int taggedCount;
  final int untaggedCount;
  final int totalCount;
  final String badgeText;

  ReturnCylinderInfo({
    required this.lubId,
    required this.lubName,
    required this.taggedCount,
    required this.untaggedCount,
    required this.totalCount,
    required this.badgeText,
  });

  factory ReturnCylinderInfo.fromJson(Map<String, dynamic> json) {
    return ReturnCylinderInfo(
      lubId: (json['lubId'] ?? json['LubId']) as int,
      lubName: (json['lubName'] ?? json['LubName']) as String? ?? '',
      taggedCount: (json['taggedCount'] ?? json['TaggedCount']) as int? ?? 0,
      untaggedCount:
          (json['untaggedCount'] ?? json['UntaggedCount']) as int? ?? 0,
      totalCount: (json['totalCount'] ?? json['TotalCount']) as int? ?? 0,
      badgeText: (json['badgeText'] ?? json['BadgeText']) as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'LubId': lubId,
      'LubName': lubName,
      'TaggedCount': taggedCount,
      'UntaggedCount': untaggedCount,
      'TotalCount': totalCount,
      'BadgeText': badgeText,
    };
  }
}
