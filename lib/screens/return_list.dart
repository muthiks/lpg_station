import 'package:flutter/material.dart';
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/return_card.dart';

class ReturnsList extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;
  const ReturnsList({super.key, this.onNavigateToAdd});

  @override
  State<ReturnsList> createState() => _ReturnsListState();
}

class _ReturnsListState extends State<ReturnsList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<CylinderReturn>> pendingReturnsFuture;
  late Future<List<CylinderReturn>> completedReturnsFuture;

  @override
  void initState() {
    super.initState();
    // log('TOKEN: ${AuthService.instance.token}');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes to show/hide button
    });
    _loadReturns();
  }

  void _loadReturns() {
    pendingReturnsFuture = ApiService.fetchPendingReturns();
    completedReturnsFuture = ApiService.fetchCompletedReturns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Title
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 15, 0, 20),
              child: Text(
                'CYLINDER RETURNS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Tab Bar
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
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'PENDING'),
                  Tab(text: 'COMPLETED'),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Pending Returns Tab
                  _buildReturnsList(
                    future: pendingReturnsFuture,
                    emptyMessage: 'No pending returns',
                  ),
                  // Completed Returns Tab
                  _buildReturnsList(
                    future: completedReturnsFuture,
                    emptyMessage: 'No completed returns',
                  ),
                ],
              ),
            ),

            // Bottom button - Only show on Pending tab (index 0)
            if (_tabController.index == 0)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      widget.onNavigateToAdd?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 22,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, AppTheme.primaryOrange],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Add Return',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnsList({
    required Future<List<CylinderReturn>> future,
    required String emptyMessage,
  }) {
    return FutureBuilder<List<CylinderReturn>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final returns = snapshot.data!;

        if (returns.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _loadReturns();
            });
          },
          child: ListView.separated(
            separatorBuilder: (_, __) => const Divider(color: Colors.white),
            itemCount: returns.length,
            itemBuilder: (_, index) {
              return ReturnCard(cylinderReturn: returns[index]);
            },
          ),
        );
      },
    );
  }
}
