class SaleItem {
  final int cylinderTypeId;
  final String cylinderTypeName;
  final int quantity;
  final double price;
  final double amount;
  final double cylinderPrice;
  final double cylinderAmount;
  final String cylinderStatus; // Lease or Sale
  final String priceType; // Standard or Custom

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
  });
}
