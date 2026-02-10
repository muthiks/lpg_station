import 'package:flutter/material.dart';

class StockBalanceScreen extends StatelessWidget {
  const StockBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Stock Balance Screen',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
