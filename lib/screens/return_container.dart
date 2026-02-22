import 'package:flutter/material.dart';
import 'package:lpg_station/screens/add_return.dart';
import 'package:lpg_station/screens/return_list.dart';

class ReturnContainer extends StatefulWidget {
  const ReturnContainer({super.key});

  @override
  State<ReturnContainer> createState() => _ReturnContainerState();
}

class _ReturnContainerState extends State<ReturnContainer> {
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
        ? ReturnAddScreen(onBack: _navigateToList)
        : ReturnsList(onNavigateToAdd: _navigateToAdd);
  }
}
