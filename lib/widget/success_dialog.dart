import 'package:flutter/material.dart';

class SuccessDialog extends StatelessWidget {
  const SuccessDialog();

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context);
    });

    return const Dialog(
      backgroundColor: Colors.transparent,
      child: Icon(Icons.check_circle, size: 80, color: Colors.green),
    );
  }
}
