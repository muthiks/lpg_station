// lib/models/stock_models.dart

class StationStockDto {
  final int stationID;
  final String? stationName;
  final List<CylinderStockDto> cylinders;
  final List<AccessoryStockDto> accessories;

  StationStockDto({
    required this.stationID,
    this.stationName,
    required this.cylinders,
    required this.accessories,
  });

  factory StationStockDto.fromJson(Map<String, dynamic> json) {
    return StationStockDto(
      stationID: json['stationID'] ?? 0,
      stationName: json['stationName'],
      cylinders:
          (json['cylinders'] as List<dynamic>?)
              ?.map((c) => CylinderStockDto.fromJson(c))
              .toList() ??
          [],
      accessories:
          (json['accessories'] as List<dynamic>?)
              ?.map((a) => AccessoryStockDto.fromJson(a))
              .toList() ??
          [],
    );
  }
}

class CylinderStockDto {
  final int cylinderID;
  final String cylinderName;
  final List<CylinderItemDto> items;

  CylinderStockDto({
    required this.cylinderID,
    required this.cylinderName,
    required this.items,
  });

  factory CylinderStockDto.fromJson(Map<String, dynamic> json) {
    return CylinderStockDto(
      cylinderID: json['cylinderID'] ?? 0,
      cylinderName: json['cylinderName'] ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => CylinderItemDto.fromJson(i))
              .toList() ??
          [],
    );
  }
}

class CylinderItemDto {
  final int lubId;
  final String lubName;
  final double? cylinderCost;
  final double? retailPrice;
  final int? filled;
  final int? empty;
  final int? reserved;

  CylinderItemDto({
    required this.lubId,
    required this.lubName,
    this.cylinderCost,
    this.retailPrice,
    this.filled,
    this.reserved,
    this.empty,
  });

  factory CylinderItemDto.fromJson(Map<String, dynamic> json) {
    return CylinderItemDto(
      lubId: json['lubId'] ?? 0,
      lubName: json['lubName'] ?? '',
      cylinderCost: json['cylinderCost']?.toDouble(),
      retailPrice: json['retailPrice']?.toDouble(),
      filled: json['filled'],
      empty: json['empty'],
      reserved: json['reserved'],
    );
  }
}

class AccessoryStockDto {
  final int lubId;
  final String lubName;
  final double? cylinderCost;
  final double? retailPrice;
  final int? availableQty;
  final int? reserved;

  AccessoryStockDto({
    required this.lubId,
    required this.lubName,
    this.cylinderCost,
    this.retailPrice,
    this.availableQty,
    this.reserved,
  });

  factory AccessoryStockDto.fromJson(Map<String, dynamic> json) {
    return AccessoryStockDto(
      lubId: json['lubId'] ?? 0,
      lubName: json['lubName'] ?? '',
      cylinderCost: json['cylinderCost']?.toDouble(),
      retailPrice: json['retailPrice']?.toDouble(),
      availableQty: json['availableQty'],
      reserved: json['reserved'],
    );
  }
}

class StationDto {
  final int stationID;
  final String stationName;

  StationDto({required this.stationID, required this.stationName});

  factory StationDto.fromJson(Map<String, dynamic> json) {
    return StationDto(
      stationID: json['StationID'] ?? 0,
      stationName: json['StationName'] ?? '',
    );
  }
}
