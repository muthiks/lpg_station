import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/screens/stock_balance.dart';
import 'package:lpg_station/screens/receive_stock.dart';

class StockTabsContainer extends StatefulWidget {
  const StockTabsContainer({super.key});

  @override
  State<StockTabsContainer> createState() => _StockTabsContainerState();
}

class _StockTabsContainerState extends State<StockTabsContainer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Lazy-load flags
  bool _loadStockBalance = true; // load first tab immediately
  bool _loadReceiveStock = false;

  /// Badge counts (replace with API values)
  int stockBalanceCount = 12;
  int receiveStockCount = 3;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      setState(() {
        if (_tabController.index == 1) {
          _loadReceiveStock = true; // lazy load tab 2
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
                // 🔹 Title
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 15, 0, 20),
                  child: Text(
                    'STOCK MANAGEMENT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                // 🔹 Tabs with badges
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
                    tabs: [
                      _tabWithBadge(
                        label: 'STOCK BALANCE',
                        count: stockBalanceCount,
                      ),
                      _tabWithBadge(
                        label: 'RECEIVE STOCK',
                        count: receiveStockCount,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // 🔹 Lazy-loaded Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _loadStockBalance
                          ? const StockBalanceScreen()
                          : const SizedBox(),

                      _loadReceiveStock
                          ? const ReceiveStockScreen()
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

  /// 🔹 Tab with badge widget
  Widget _tabWithBadge({required String label, required int count}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
