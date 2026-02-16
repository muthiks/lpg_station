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

  bool _loadStockBalance = true;
  bool _loadReceiveStock = false;

  // Only receive stock has a badge now
  int receiveStockCount = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        if (_tabController.index == 1) {
          _loadReceiveStock = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Called by ReceiveStockScreen once it loads its data
  void _onReceiveStockCountLoaded(int count) {
    setState(() {
      receiveStockCount = count;
    });
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
                    'STOCK MANAGEMENT',
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
                    tabs: [
                      // ✅ No badge for Stock Balance
                      _tabWithBadge(label: 'STOCK BALANCE', count: 0),
                      // ✅ Badge driven by actual record count
                      _tabWithBadge(
                        label: 'RECEIVE STOCK',
                        count: receiveStockCount,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _loadStockBalance
                          ? const StockBalanceScreen()
                          : const SizedBox(),

                      _loadReceiveStock
                          ? ReceiveStockScreen(
                              // ✅ Pass callback so child can report its count
                              onCountLoaded: _onReceiveStockCountLoaded,
                            )
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
