import 'package:flutter/material.dart';

class SummaryTabsContainer extends StatefulWidget {
  const SummaryTabsContainer({super.key});

  @override
  State<SummaryTabsContainer> createState() => _SummaryTabsContainerState();
}

class _SummaryTabsContainerState extends State<SummaryTabsContainer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        if (_tabController.index == 1) {
          //_loadReceiveStock = true;
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
                    'SUMMARY REPORT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                Expanded(
                  child: TabBarView(controller: _tabController, children: [
                        
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
