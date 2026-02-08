import 'package:flutter/material.dart';
import 'package:lpg_station/screens/add_sale.dart';
import 'package:lpg_station/screens/sale_list.dart';

class SaleContainer extends StatefulWidget {
  const SaleContainer({super.key});

  @override
  State<SaleContainer> createState() => _SaleContainerState();
}

class _SaleContainerState extends State<SaleContainer> {
  bool _showAddScreen = false;

  void _navigateToAdd() {
    setState(() {
      _showAddScreen = true;
    });
  }

  void _navigateToList() {
    setState(() {
      _showAddScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showAddScreen
        ? AddSale(onBack: _navigateToList)
        : SaleList(onNavigateToAdd: _navigateToAdd);
  }
}
