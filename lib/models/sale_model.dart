// lib/models/sale_models.dart
// Handles BOTH PascalCase (API) and camelCase (local) JSON keys

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────
int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? 0;
}

double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

// Reads key trying PascalCase first, then camelCase
dynamic _get(Map<String, dynamic> json, String pascalKey, String camelKey) =>
    json[pascalKey] ?? json[camelKey];

// ─────────────────────────────────────────────
//  Sale Detail DTO
// ─────────────────────────────────────────────
class SaleDetailDto {
  final int saleDetailID;
  final int lpgSaleID;
  final int cylinderID;
  final int lubId;
  final String priceType;
  final double price;
  final double cylinderPrice;
  final double cylinderAmount;
  final int quantity;
  final double amount;
  final String cylStatus;
  final String lubName;
  final double? capacity;

  SaleDetailDto({
    required this.saleDetailID,
    required this.lpgSaleID,
    required this.cylinderID,
    required this.lubId,
    required this.priceType,
    required this.price,
    required this.cylinderPrice,
    required this.cylinderAmount,
    required this.quantity,
    required this.amount,
    required this.cylStatus,
    required this.lubName,
    this.capacity,
  });

  factory SaleDetailDto.fromJson(Map<String, dynamic> json) {
    return SaleDetailDto(
      saleDetailID: _parseInt(_get(json, 'SaleDetailID', 'saleDetailID')),
      lpgSaleID: _parseInt(_get(json, 'LpgSaleID', 'lpgSaleID')),
      cylinderID: _parseInt(_get(json, 'CylinderID', 'cylinderID')),
      lubId: _parseInt(_get(json, 'LubId', 'lubId')),
      priceType: _get(json, 'PriceType', 'priceType')?.toString() ?? 'Custom',
      price: _parseDouble(_get(json, 'Price', 'price')),
      cylinderPrice: _parseDouble(_get(json, 'CylinderPrice', 'cylinderPrice')),
      cylinderAmount: _parseDouble(
        _get(json, 'CylinderAmount', 'cylinderAmount'),
      ),
      quantity: _parseInt(_get(json, 'Quantity', 'quantity')),
      amount: _parseDouble(_get(json, 'Amount', 'amount')),
      cylStatus:
          _get(json, 'CylStatus', 'cylStatus')?.toString() ??
          _get(json, 'Status', 'status')?.toString() ??
          'Lease',
      lubName: _get(json, 'LubName', 'lubName')?.toString() ?? '',
      capacity: _get(json, 'Capacity', 'capacity') != null
          ? _parseDouble(_get(json, 'Capacity', 'capacity'))
          : null,
    );
  }
}

// ─────────────────────────────────────────────
//  Sale DTO
// ─────────────────────────────────────────────
class SaleDto {
  final int lpgSaleID;
  final DateTime saleDate;
  final double balance;
  final int customerID;
  final int stationID;
  final String customerName;
  final String? customerPhone;
  final String? stationName;
  final String invoiceNo;
  final String? deliveryGuy;
  final String? dispatcher;
  final double total;
  final String status;
  final bool isApproved;
  final String? comments;
  final String? customerType;
  final String? orderNo;
  final DateTime? dateDispatched;
  final DateTime? dateDelivered;
  final List<SaleDetailDto> saleDetails;

  SaleDto({
    required this.lpgSaleID,
    required this.saleDate,
    required this.balance,
    required this.customerID,
    required this.stationID,
    required this.customerName,
    this.customerPhone,
    this.stationName,
    required this.invoiceNo,
    this.deliveryGuy,
    this.dispatcher,
    required this.total,
    required this.status,
    required this.isApproved,
    this.comments,
    this.customerType,
    this.orderNo,
    this.dateDelivered,
    this.dateDispatched,
    required this.saleDetails,
  });

  factory SaleDto.fromJson(Map<String, dynamic> json) {
    // Robust saleDetails parsing — handles PascalCase and camelCase
    List<SaleDetailDto> parsedDetails = [];
    final rawDetails = _get(json, 'SaleDetails', 'saleDetails');
    if (rawDetails is List) {
      for (final item in rawDetails) {
        try {
          if (item is Map<String, dynamic>) {
            parsedDetails.add(SaleDetailDto.fromJson(item));
          }
        } catch (_) {}
      }
    }

    return SaleDto(
      lpgSaleID: _parseInt(_get(json, 'LpgSaleID', 'lpgSaleID')),
      saleDate:
          DateTime.tryParse(
            _get(json, 'SaleDate', 'saleDate')?.toString() ?? '',
          ) ??
          DateTime.now(),
      balance: _parseDouble(_get(json, 'Balance', 'balance')),
      customerID: _parseInt(_get(json, 'CustomerID', 'customerID')),
      stationID: _parseInt(_get(json, 'StationID', 'stationID')),
      customerName:
          _get(json, 'CustomerName', 'customerName')?.toString() ?? '',
      customerPhone: _get(json, 'CustomerPhone', 'customerPhone')?.toString(),
      stationName: _get(json, 'StationName', 'stationName')?.toString(),
      invoiceNo: _get(json, 'InvoiceNo', 'invoiceNo')?.toString() ?? '',
      deliveryGuy: _get(json, 'DeliveryGuy', 'deliveryGuy')?.toString(),
      dispatcher: _get(json, 'Dispatcher', 'dispatcher')?.toString(),
      total: _parseDouble(_get(json, 'Total', 'total')),
      status: _get(json, 'Status', 'status')?.toString() ?? 'Draft',
      isApproved: _get(json, 'IsApproved', 'isApproved') == true,
      comments: _get(json, 'Comments', 'comments')?.toString(),
      customerType: _get(json, 'CustomerType', 'customerType')?.toString(),
      orderNo: _get(json, 'OrderNo', 'orderNo')?.toString(),
      dateDelivered:
          DateTime.tryParse(
            _get(json, 'DateDelivered', 'dateDelivered')?.toString() ?? '',
          ) ??
          DateTime.now(),
      dateDispatched:
          DateTime.tryParse(
            _get(json, 'DateDispatched', 'dateDispatched')?.toString() ?? '',
          ) ??
          DateTime.now(),
      saleDetails: parsedDetails,
    );
  }

  bool get isPaid => balance <= 0;

  String get nextStatus {
    switch (status) {
      case 'Draft':
        return 'Confirmed';
      case 'Confirmed':
        return 'Dispatched';
      case 'Dispatched':
        return 'Delivered';
      default:
        return status;
    }
  }

  bool get isDelivered => status == 'Delivered';
  bool get canAdvanceStage => status != 'Delivered';
}

// ─────────────────────────────────────────────
//  Station DTO
// ─────────────────────────────────────────────
class StationDto {
  final int stationID;
  final String stationName;

  StationDto({required this.stationID, required this.stationName});

  factory StationDto.fromJson(Map<String, dynamic> json) {
    return StationDto(
      stationID: _parseInt(_get(json, 'StationID', 'stationID')),
      stationName: _get(json, 'StationName', 'stationName')?.toString() ?? '',
    );
  }
}

// ─────────────────────────────────────────────
//  Customer DTO
// ─────────────────────────────────────────────
class CustomerDto {
  final int customerID;
  final String customerName;
  final String? customerPhone;
  final String? customerStation;
  final String? customerLocation;
  final String? category;
  final String? customerType;
  final double balance;
  final double cylinderBalance;
  final double prepaidBalance;

  CustomerDto({
    required this.customerID,
    required this.customerName,
    this.customerPhone,
    this.customerStation,
    this.customerLocation,
    this.category,
    this.customerType,
    required this.balance,
    required this.cylinderBalance,
    required this.prepaidBalance,
  });

  factory CustomerDto.fromJson(Map<String, dynamic> json) {
    return CustomerDto(
      customerID: _parseInt(_get(json, 'CustomerID', 'customerID')),
      customerName:
          _get(json, 'CustomerName', 'customerName')?.toString() ?? '',
      customerPhone: _get(json, 'CustomerPhone', 'customerPhone')?.toString(),
      customerStation: _get(
        json,
        'CustomerStation',
        'customerStation',
      )?.toString(),
      customerLocation: _get(
        json,
        'CustomerLocation',
        'customerLocation',
      )?.toString(),
      category: _get(json, 'Category', 'category')?.toString(),
      customerType: _get(json, 'CustomerType', 'customerType')?.toString(),
      balance: _parseDouble(_get(json, 'Balance', 'balance')),
      cylinderBalance: _parseDouble(
        _get(json, 'CylinderBalance', 'cylinderBalance'),
      ),
      prepaidBalance: _parseDouble(
        _get(json, 'PrepaidBalance', 'prepaidBalance'),
      ),
    );
  }

  bool get hasBalance => balance > 0;
}

// ─────────────────────────────────────────────
//  Delivery Guy DTO
// ─────────────────────────────────────────────
class DeliveryGuyDto {
  final String id;
  final String fullName;

  DeliveryGuyDto({required this.id, required this.fullName});

  factory DeliveryGuyDto.fromJson(Map<String, dynamic> json) {
    return DeliveryGuyDto(
      id: _get(json, 'Id', 'id')?.toString() ?? '',
      fullName: _get(json, 'FullName', 'fullName')?.toString() ?? '',
    );
  }
}

// ─────────────────────────────────────────────
//  Cylinder Item DTO  (from GetStationStock)
// ─────────────────────────────────────────────
class CylinderItemDto {
  final int lubId;
  final String lubName;
  final double capacity;
  final double cylinderCost;
  final double retailPrice;
  final int filled;
  final int empty;
  final int reserved;

  CylinderItemDto({
    required this.lubId,
    required this.lubName,
    required this.capacity,
    required this.cylinderCost,
    required this.retailPrice,
    required this.filled,
    required this.empty,
    required this.reserved,
  });

  factory CylinderItemDto.fromJson(Map<String, dynamic> json) {
    return CylinderItemDto(
      lubId: _parseInt(_get(json, 'LubId', 'lubId')),
      lubName: _get(json, 'LubName', 'lubName')?.toString() ?? '',
      capacity: _parseDouble(_get(json, 'Capacity', 'capacity')),
      cylinderCost: _parseDouble(_get(json, 'CylinderCost', 'cylinderCost')),
      retailPrice: _parseDouble(_get(json, 'RetailPrice', 'retailPrice')),
      filled: _parseInt(_get(json, 'Filled', 'filled')),
      empty: _parseInt(_get(json, 'Empty', 'empty')),
      reserved: _parseInt(_get(json, 'Reserved', 'reserved')),
    );
  }
}

// ─────────────────────────────────────────────
//  Cylinder Type DTO
// ─────────────────────────────────────────────
class CylinderTypeDto {
  final int cylinderID;
  final String cylinderName;
  final List<CylinderItemDto> items;

  CylinderTypeDto({
    required this.cylinderID,
    required this.cylinderName,
    required this.items,
  });

  factory CylinderTypeDto.fromJson(Map<String, dynamic> json) {
    final rawItems = _get(json, 'Items', 'items');
    return CylinderTypeDto(
      cylinderID: _parseInt(_get(json, 'CylinderID', 'cylinderID')),
      cylinderName:
          _get(json, 'CylinderName', 'cylinderName')?.toString() ?? '',
      items: (rawItems is List)
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map((i) => CylinderItemDto.fromJson(i))
                .toList()
          : [],
    );
  }

  // Use first item's prices for AddItemSheet
  double get retailPrice => items.isNotEmpty ? items.first.retailPrice : 0;
  double get cylinderCost => items.isNotEmpty ? items.first.cylinderCost : 0;
  int get lubId => items.isNotEmpty ? items.first.lubId : cylinderID;

  Map<String, dynamic> toItemSheetFormat() => {
    'id': cylinderID,
    'lubId': lubId,
    'name': cylinderName,
    'price': retailPrice,
    'cylinderPrice': cylinderCost,
    'isAccessory': false,
  };
}

// ─────────────────────────────────────────────
//  Accessory DTO
// ─────────────────────────────────────────────
class AccessoryDto {
  final int lubId;
  final String lubName;
  final double cylinderCost;
  final double retailPrice;
  final int availableQty;
  final int reserved;

  AccessoryDto({
    required this.lubId,
    required this.lubName,
    required this.cylinderCost,
    required this.retailPrice,
    required this.availableQty,
    required this.reserved,
  });

  factory AccessoryDto.fromJson(Map<String, dynamic> json) {
    return AccessoryDto(
      lubId: _parseInt(_get(json, 'LubId', 'lubId')),
      lubName: _get(json, 'LubName', 'lubName')?.toString() ?? '',
      cylinderCost: _parseDouble(_get(json, 'CylinderCost', 'cylinderCost')),
      retailPrice: _parseDouble(_get(json, 'RetailPrice', 'retailPrice')),
      availableQty: _parseInt(_get(json, 'AvailableQty', 'availableQty')),
      reserved: _parseInt(_get(json, 'Reserved', 'reserved')),
    );
  }

  Map<String, dynamic> toItemSheetFormat() => {
    'id': lubId,
    'lubId': lubId,
    'name': lubName,
    'price': retailPrice,
    'cylinderPrice': cylinderCost,
    'isAccessory': true,
  };
}

// ─────────────────────────────────────────────
//  Station Stock DTO
// ─────────────────────────────────────────────
class StationStockDto {
  final int stationID;
  final String? stationName;
  final List<CylinderTypeDto> cylinders;
  final List<AccessoryDto> accessories;

  StationStockDto({
    required this.stationID,
    this.stationName,
    required this.cylinders,
    required this.accessories,
  });

  factory StationStockDto.fromJson(Map<String, dynamic> json) {
    final rawCylinders = _get(json, 'Cylinders', 'cylinders');
    final rawAccessories = _get(json, 'Accessories', 'accessories');
    return StationStockDto(
      stationID: _parseInt(_get(json, 'StationID', 'stationID')),
      stationName: _get(json, 'StationName', 'stationName')?.toString(),
      cylinders: (rawCylinders is List)
          ? rawCylinders
                .whereType<Map<String, dynamic>>()
                .map((c) => CylinderTypeDto.fromJson(c))
                .toList()
          : [],
      accessories: (rawAccessories is List)
          ? rawAccessories
                .whereType<Map<String, dynamic>>()
                .map((a) => AccessoryDto.fromJson(a))
                .toList()
          : [],
    );
  }

  List<Map<String, dynamic>> get allItemsForSheet => [
    ...cylinders.map((c) => c.toItemSheetFormat()),
    ...accessories.map((a) => a.toItemSheetFormat()),
  ];
}
