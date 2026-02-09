class SaleItem {
  final int cylinderTypeId;
  final String cylinderTypeName;
  int quantity;
  final double price;
  double amount;
  final double cylinderPrice;
  double cylinderAmount;
  final String cylinderStatus; // Lease or Sale
  final String priceType; // Standard or Custom
  final bool isTagged;
  final List<String> taggedBarcodes;

  double get totalAmount => amount + cylinderAmount;

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
  }) : taggedBarcodes = taggedBarcodes ?? [];
}
