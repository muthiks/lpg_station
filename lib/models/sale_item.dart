class SaleItem {
  final int cylinderTypeId;
  final String cylinderTypeName;
  int quantity;
  final double price;
  double amount;
  final double cylinderPrice;
  double cylinderAmount;
  final String cylinderStatus; // Refill, Complete, or Lease
  final String priceType; // Retail, Custom, or KG
  final bool isTagged;
  final List<String> taggedBarcodes;

  // Accessory fields
  final String? accessoryId;
  final String? accessoryName;
  final int? accessoryQuantity;
  final double? accessoryPrice;
  final double? accessoryAmount;
  final String? accessoryPriceType;

  double get totalAmount {
    final accessories = accessoryAmount ?? 0.0;
    return amount + cylinderAmount + accessories;
  }

  bool get hasAccessories =>
      accessoryId != null && accessoryAmount != null && accessoryAmount! > 0;

  SaleItem({
    required this.cylinderTypeId,
    required this.cylinderTypeName,
    required this.quantity,
    required this.price,
    required this.amount,
    required this.cylinderPrice,
    required this.cylinderAmount,
    required this.cylinderStatus,
    required this.priceType,
    this.isTagged = false,
    List<String>? taggedBarcodes,
    this.accessoryId,
    this.accessoryName,
    this.accessoryQuantity,
    this.accessoryPrice,
    this.accessoryAmount,
    this.accessoryPriceType,
  }) : taggedBarcodes = taggedBarcodes ?? [];
}
