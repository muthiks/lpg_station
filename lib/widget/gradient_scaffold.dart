import 'package:flutter/material.dart';
import 'package:lpg_station/theme/theme.dart';

class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget navigationBar;
  const GradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    required this.navigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: navigationBar,
      ),
    );
  }
}
