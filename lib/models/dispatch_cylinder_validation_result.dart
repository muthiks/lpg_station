// ── Result model for cylinder validation ─────────────────────────────────────
class CylinderValidationResult {
  final bool isValid;
  final String message;
  final int? lubId;
  final String? lubName;
  CylinderValidationResult({
    required this.isValid,
    required this.message,
    this.lubId,
    this.lubName,
  });
}
