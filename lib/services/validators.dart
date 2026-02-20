class Validators {
  static final RegExp _cylinderRegex = RegExp(r'^LG\d{8}$');

  /// Strips spaces, control characters, and invisible unicode
  static String sanitize(String code) {
    return code
        .replaceAll(RegExp(r'[\x00-\x1F\x7F\u00A0\uFEFF]'), '') // control chars
        .replaceAll(' ', '') // regular spaces
        .trim()
        .toUpperCase();
  }

  static bool isValidCylinderCode(String code) {
    return _cylinderRegex.hasMatch(sanitize(code));
  }

  static String? cylinderCodeError(String code) {
    final sanitized = sanitize(code);

    if (sanitized.isEmpty) {
      return 'Code cannot be empty';
    }
    if (!sanitized.startsWith('LG')) {
      return 'Code must start with LG (got: "$sanitized")'; // helpful for debugging
    }
    if (sanitized.length != 10) {
      return 'Code must be exactly 10 characters (got ${sanitized.length}: "$sanitized")';
    }
    if (!_cylinderRegex.hasMatch(sanitized)) {
      return 'Last 8 characters must be numbers';
    }
    return null;
  }
}
