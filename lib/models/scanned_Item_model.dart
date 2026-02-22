class ScannedItem {
  final String barcode; // 0=Register, 1=Refill, 2=Sale
  final String cylinderType;
  final int cylinderId;

  ScannedItem({
    required this.barcode,
    required this.cylinderType,
    required this.cylinderId,
  });
}
