// ── Result model for cylinder validation ─────────────────────────────────────
class CylinderValidationResult {
  final bool isValid;
  final String message;
  final int? cylinderID;
  final String? lubName;
  CylinderValidationResult({
    required this.isValid,
    required this.message,
    this.cylinderID,
    this.lubName,
  });
}
