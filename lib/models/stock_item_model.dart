// lib/models/stock_item_model.dart

class CylinderTypeDto {
  final int cylinderID;
  final String cylinderName;
  final int capacity;
  final List<CylinderStockItemDto> items;

  CylinderTypeDto({
    required this.cylinderID,
    required this.cylinderName,
    required this.capacity,
    required this.items,
  });

  factory CylinderTypeDto.fromJson(Map<String, dynamic> json) {
    return CylinderTypeDto(
      cylinderID: json['CylinderID'] ?? 0,
      cylinderName: json['CylinderName'] ?? '',
      capacity: json['Capacity'] ?? 0,
      items:
          (json['Items'] as List<dynamic>?)
              ?.map((i) => CylinderStockItemDto.fromJson(i))
              .toList() ??
          [],
    );
  }

  // Convert to the format needed by AddItemSheet
  Map<String, dynamic> toItemSheetFormat() {
    // Use the first item's prices, or default if no items
    final firstItem = items.isNotEmpty ? items.first : null;

    return {
      'id': cylinderID,
      'name': cylinderName,
      'capacity': capacity, // You might want to add this to your API response
      'price': firstItem?.retailPrice ?? 0,
      'cylinderPrice': firstItem?.cylinderCost ?? 0,
    };
  }
}

class CylinderStockItemDto {
  final int lubId;
  final String lubName;
  final double? cylinderCost;
  final double? retailPrice;
  final int capacity;
  final int? filled;
  final int? empty;
  final int? reserved;

  CylinderStockItemDto({
    required this.lubId,
    required this.lubName,
    this.cylinderCost,
    this.retailPrice,
    required this.capacity,
    this.filled,
    this.empty,
    this.reserved,
  });

  factory CylinderStockItemDto.fromJson(Map<String, dynamic> json) {
    return CylinderStockItemDto(
      lubId: json['LubId'] ?? 0,
      lubName: json['LubName'] ?? '',
      cylinderCost: json['CylinderCost']?.toDouble(),
      retailPrice: json['RetailPrice']?.toDouble(),
      capacity: json['Capacity'] ?? 0,
      filled: json['Filled'],
      empty: json['Empty'],
      reserved: json['Reserved'],
    );
  }
}

class AccessoryDto {
  final int lubId;
  final String lubName;
  final double? cylinderCost;
  final double? retailPrice;
  final int? availableQty;
  final int? reserved;

  AccessoryDto({
    required this.lubId,
    required this.lubName,
    this.cylinderCost,
    this.retailPrice,
    this.availableQty,
    this.reserved,
  });

  factory AccessoryDto.fromJson(Map<String, dynamic> json) {
    return AccessoryDto(
      lubId: json['LubId'] ?? 0,
      lubName: json['LubName'] ?? '',
      cylinderCost: json['CylinderCost']?.toDouble(),
      retailPrice: json['RetailPrice']?.toDouble(),
      availableQty: json['AvailableQty'],
      reserved: json['Reserved'],
    );
  }

  // Convert to the format needed by AddItemSheet
  Map<String, dynamic> toItemSheetFormat() {
    return {
      'id': lubId,
      'name': lubName,
      'capacity': 0,
      'price': retailPrice ?? 0,
      'cylinderPrice': cylinderCost ?? 0,
      'isAccessory': true,
    };
  }
}
