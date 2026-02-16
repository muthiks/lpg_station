import 'package:flutter/material.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/screens/add_sale.dart';
import 'package:lpg_station/screens/sale_list.dart';

class SaleContainer extends StatefulWidget {
  const SaleContainer({super.key});

  @override
  State<SaleContainer> createState() => _SaleContainerState();
}

class _SaleContainerState extends State<SaleContainer> {
  bool _showAddScreen = false;
  SaleDto? _editSale; // null = Add New Sale, non-null = Edit Sale

  void _navigateToAdd() {
    setState(() {
      _showAddScreen = true;
      _editSale = null; // always clear when adding new
    });
  }

  void _navigateToEdit(SaleDto sale) {
    setState(() {
      _showAddScreen = true;
      _editSale = sale; // pre-fill with existing sale data
    });
  }

  void _navigateToList() {
    setState(() {
      _showAddScreen = false;
      _editSale = null; // clear on return
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showAddScreen) {
      return AddSale(
        onBack: _navigateToList,
        editSale: _editSale, // null → "Add New Sale", SaleDto → "Edit Sale"
      );
    }

    return SaleList(
      onNavigateToAdd: _navigateToAdd,
      onEditSale: _navigateToEdit, // card tap → edit mode (no Navigator.push)
    );
  }
}
