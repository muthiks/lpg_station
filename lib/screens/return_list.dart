import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/services/auth_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/return_card.dart';

class ReturnsList extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;
  // Called with a CylinderReturn when user taps to edit
  final void Function(CylinderReturn)? onNavigateToEdit;

  const ReturnsList({super.key, this.onNavigateToAdd, this.onNavigateToEdit});

  @override
  State<ReturnsList> createState() => _ReturnsListState();
}

class _ReturnsListState extends State<ReturnsList>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingStations = true;
  bool _isLoadingCustomers = false;
  bool _isLoadingReturns = false;
  String? _errorMessage;

  List<StationDto> _stations = [];
  List<CustomerDto> _customers = [];
  List<CylinderReturn> _returns = [];

  StationDto? _selectedStation;
  CustomerDto? _selectedCustomer;

  final _dateFormat = DateFormat('d/M/yyyy');

  bool get _isDriver =>
      AuthService.instance.userRole?.toLowerCase() == 'driver';

  @override
  void initState() {
    super.initState();
    // 3 tabs: New / Received / Approved
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadStations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════ DATA LOADING ════════════════════════════

  Future<void> _loadStations() async {
    setState(() {
      _isLoadingStations = true;
      _errorMessage = null;
    });
    try {
      final stations = await ApiService.getUserStations();
      setState(() {
        _stations = stations;
        _isLoadingStations = false;
        if (_stations.length == 1) {
          _selectedStation = _stations.first;
          _loadCustomers(_selectedStation!.stationID);
        }
      });
      _loadReturns(_selectedStation?.stationID);
    } catch (e) {
      setState(() {
        _isLoadingStations = false;
        _errorMessage = 'Failed to load stations: $e';
      });
    }
  }

  Future<void> _loadCustomers(int stationId) async {
    setState(() {
      _isLoadingCustomers = true;
      _selectedCustomer = null;
    });
    try {
      final customers = await ApiService.getCustomersByStation(stationId);
      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() => _isLoadingCustomers = false);
      log('Error loading customers: $e');
    }
  }

  Future<void> _loadReturns(int? stationId) async {
    setState(() {
      _isLoadingReturns = true;
      _errorMessage = null;
    });
    try {
      final all = await ApiService.fetchAllReturns(stationId: stationId);
      setState(() {
        _returns = all;
        _isLoadingReturns = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingReturns = false;
        _errorMessage = 'Failed to load returns: $e';
      });
      log('Error loading returns: $e');
    }
  }

  // ── Status advance ──────────────────────────────────────────────────
  Future<void> _advanceStatus(CylinderReturn r) async {
    final next = r.nextStatus;
    if (next == null) return;
    try {
      await ApiService.advanceReturnStatus(
        returnId: r.returnId,
        newStatus: next,
      );
      _loadReturns(_selectedStation?.stationID);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return marked as $next'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────
  Future<void> _deleteReturn(CylinderReturn r) async {
    try {
      await ApiService.deleteReturn(returnId: r.returnId);
      setState(() => _returns.removeWhere((x) => x.returnId == r.returnId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
        // Re-add to list if API failed (Dismissible already removed it)
        setState(() => _returns.add(r));
      }
    }
  }

  // ═══════════════════════════ FILTERING ═══════════════════════════════

  List<CylinderReturn> get _filtered => _returns.where((r) {
    if (_selectedStation != null && r.stationId != _selectedStation!.stationID)
      return false;
    if (_selectedCustomer != null &&
        r.customerId != _selectedCustomer!.customerID)
      return false;
    // Drivers see only their own returns
    if (_isDriver && r.addedBy != AuthService.instance.userId) return false;
    return true;
  }).toList();

  List<CylinderReturn> _byStatus(String status) =>
      _filtered.where((r) => r.status == status).toList();

  // ═══════════════════════════ BUILD ═══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStations) {
      return const Center(child: CircularProgressIndicator());
    }

    final newReturns = _byStatus('New');
    final receivedReturns = _byStatus('Received');
    final approvedReturns = _byStatus('Approved');

    return Column(
      children: [
        // ── Filter row ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Station
              Expanded(
                child: _stations.length == 1
                    ? _autoField(Icons.warehouse, _selectedStation!.stationName)
                    : _filterField(
                        icon: Icons.warehouse,
                        value: _selectedStation?.stationName,
                        placeholder: 'All Stations',
                        onTap: _showStationSelector,
                      ),
              ),
              const SizedBox(width: 8),
              // Customer
              Expanded(
                child: _isLoadingCustomers
                    ? _loadingField('Loading...')
                    : _filterField(
                        icon: Icons.person,
                        value: _selectedCustomer?.customerName,
                        placeholder: 'All Customers',
                        isDisabled: _selectedStation == null,
                        onTap: _selectedStation == null
                            ? null
                            : _showCustomerSelector,
                      ),
              ),
            ],
          ),
        ),

        // ── Tabs ────────────────────────────────────────────────────────
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryOrange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            _tabWithCount('New', newReturns.length),
            _tabWithCount('Received', receivedReturns.length),
            _tabWithCount('Approved', approvedReturns.length),
          ],
        ),

        // ── Tab views ───────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(returns: newReturns, emptyMessage: 'No new returns'),
              _buildList(
                returns: receivedReturns,
                emptyMessage: 'No received returns',
              ),
              _buildList(
                returns: approvedReturns,
                emptyMessage: 'No approved returns',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════ LIST BUILDER ════════════════════════════

  Widget _buildList({
    required List<CylinderReturn> returns,
    required String emptyMessage,
  }) {
    if (_isLoadingReturns) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) return _errorView();
    if (returns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_return,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReturns(_selectedStation?.stationID),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        separatorBuilder: (_, __) =>
            Divider(color: Colors.white.withOpacity(0.1)),
        itemCount: returns.length,
        itemBuilder: (_, i) {
          final r = returns[i];
          return ReturnCard(
            cylinderReturn: r,
            onTap: () => widget.onNavigateToEdit?.call(r),
            onDelete: () => _deleteReturn(r),
            onAdvanceStatus: _isDriver ? null : () => _advanceStatus(r),
          );
        },
      ),
    );
  }

  // ═══════════════════════════ STATION SELECTOR ════════════════════════

  void _showStationSelector() {
    final ctrl = TextEditingController();
    List<StationDto> filtered = _stations;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => _bottomSheet(
          height: 0.65,
          child: Column(
            children: [
              _sheetHeader('Select Station', Icons.warehouse, ctx),
              _searchField(ctrl, 'Search stations...', (q) {
                setModal(() {
                  filtered = q.isEmpty
                      ? _stations
                      : _stations
                            .where(
                              (s) => s.stationName.toLowerCase().contains(
                                q.toLowerCase(),
                              ),
                            )
                            .toList();
                });
              }),
              _sheetOptionTile(
                label: 'All Stations',
                icon: Icons.all_inclusive,
                isSelected: _selectedStation == null,
                onTap: () {
                  setState(() {
                    _selectedStation = null;
                    _selectedCustomer = null;
                    _customers = [];
                  });
                  _loadReturns(null);
                  Navigator.pop(ctx);
                },
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    return _sheetItemTile(
                      label: s.stationName,
                      icon: Icons.warehouse,
                      isSelected: _selectedStation?.stationID == s.stationID,
                      onTap: () {
                        setState(() {
                          _selectedStation = s;
                          _selectedCustomer = null;
                        });
                        _loadCustomers(s.stationID);
                        _loadReturns(s.stationID);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════ CUSTOMER SELECTOR ═══════════════════════

  void _showCustomerSelector() {
    if (_selectedStation == null) return;
    if (_customers.isEmpty) {
      _showSnack('No customers for this station', isError: true);
      return;
    }
    final ctrl = TextEditingController();
    List<CustomerDto> filtered = _customers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => _bottomSheet(
          height: 0.70,
          child: Column(
            children: [
              _sheetHeader('Filter by Customer', Icons.person, ctx),
              _searchField(ctrl, 'Search customers...', (q) {
                setModal(() {
                  filtered = q.isEmpty
                      ? _customers
                      : _customers
                            .where(
                              (c) => c.customerName.toLowerCase().contains(
                                q.toLowerCase(),
                              ),
                            )
                            .toList();
                });
              }),
              _sheetOptionTile(
                label: 'All Customers',
                icon: Icons.people_outline,
                isSelected: _selectedCustomer == null,
                onTap: () {
                  setState(() => _selectedCustomer = null);
                  Navigator.pop(ctx);
                },
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return _sheetItemTile(
                      label: c.customerName,
                      icon: Icons.person_outline,
                      isSelected: _selectedCustomer?.customerID == c.customerID,
                      onTap: () {
                        setState(() => _selectedCustomer = c);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════ ERROR VIEW ══════════════════════════════

  Widget _errorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: AppTheme.primaryOrange, size: 48),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => _loadReturns(_selectedStation?.stationID),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ═══════════════════════════ FIELD HELPERS ════════════════════════════

  Widget _filterField({
    required IconData icon,
    required String? value,
    required String placeholder,
    VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? Colors.black87 : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade500, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _autoField(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'AUTO',
              style: TextStyle(
                color: Colors.green,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingField(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════ TAB HELPER ══════════════════════════════

  Widget _tabWithCount(String label, int count) => Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
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

  // ═══════════════════════════ SHEET HELPERS ═══════════════════════════

  Widget _bottomSheet({required double height, required Widget child}) =>
      Container(
        height: MediaQuery.of(context).size.height * height,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: child,
      );

  Widget _sheetHeader(String title, IconData icon, BuildContext ctx) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );

  Widget _searchField(
    TextEditingController ctrl,
    String hint,
    void Function(String) onChanged,
  ) => Padding(
    padding: const EdgeInsets.all(16),
    child: TextField(
      controller: ctrl,
      autofocus: true,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      onChanged: onChanged,
    ),
  );

  Widget _sheetOptionTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Card(
      color: isSelected
          ? AppTheme.primaryOrange.withOpacity(0.2)
          : Colors.white.withOpacity(0.1),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryOrange : Colors.white,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    ),
  );

  Widget _sheetItemTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? subtitle,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: isSelected
        ? AppTheme.primaryOrange.withOpacity(0.2)
        : Colors.white.withOpacity(0.1),
    child: ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : icon,
        color: isSelected ? AppTheme.primaryOrange : Colors.white,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            )
          : null,
      onTap: onTap,
    ),
  );
}
