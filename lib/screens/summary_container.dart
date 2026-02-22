import 'package:flutter/material.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/screens/sale_summary.dart';
import 'package:lpg_station/screens/return_summary.dart';

class SummaryTabsContainer extends StatefulWidget {
  const SummaryTabsContainer({super.key});

  @override
  State<SummaryTabsContainer> createState() => _SummaryTabsContainerState();
}

class _SummaryTabsContainerState extends State<SummaryTabsContainer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loadSaleSummary = true;
  bool _loadReturnSummary = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        if (_tabController.index == 1) {
          _loadReturnSummary = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 15, 0, 20),
                  child: Text(
                    'SALES & RETURNS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'SALE SUMMARY'),
                      Tab(text: 'RETURN SUMMARY'),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _loadSaleSummary ? const SaleSummary() : const SizedBox(),

                      _loadReturnSummary
                          ? const ReturnSummary()
                          : const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
