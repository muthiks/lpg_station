import 'package:flutter/material.dart';

class AppInputDecorations {
  static InputDecoration dropdown({
    String? hint,
    Widget? prefixIcon,
    Color textColor = Colors.black87,
    double fontSize = 14,
    double height = 48,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: fontSize),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,

      //controls height
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: (height - fontSize) / 2,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide.none,
      ),
    );
  }
}
