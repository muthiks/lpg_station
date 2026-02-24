import 'package:flutter/material.dart';
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/screens/add_return.dart';
import 'package:lpg_station/screens/return_list.dart';

class ReturnContainer extends StatefulWidget {
  const ReturnContainer({super.key});

  @override
  State<ReturnContainer> createState() => _ReturnContainerState();
}

class _ReturnContainerState extends State<ReturnContainer> {
  bool _showAddScreen = false;
  CylinderReturn? _editingReturn; // null = add mode, non-null = edit mode

  void _navigateToAdd() {
    setState(() {
      _showAddScreen = true;
      _editingReturn = null; // ensure fresh add
    });
  }

  void _navigateToEdit(CylinderReturn r) {
    setState(() {
      _showAddScreen = true;
      _editingReturn = r;
    });
  }

  void _navigateToList() {
    setState(() {
      _showAddScreen = false;
      _editingReturn = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showAddScreen) {
      return ReturnAddScreen(
        onBack: _navigateToList,
        existingReturn: _editingReturn, // null = add, non-null = edit
      );
    }
    return ReturnsList(
      onNavigateToAdd: _navigateToAdd,
      onNavigateToEdit: _navigateToEdit,
    );
  }
}
