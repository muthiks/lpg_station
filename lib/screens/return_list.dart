import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/services/auth_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/return_card.dart';

class ReturnsList extends StatefulWidget {
  final void Function()? onNavigateToAdd;
  final void Function(CylinderReturn)? onNavigateToEdit;

  const ReturnsList({super.key, this.onNavigateToAdd, this.onNavigateToEdit});

  @override
  State<ReturnsList> createState() => _ReturnsListState();
}

class _ReturnsListState extends State<ReturnsList>
    with SingleTickerProviderStateMixin {
  // ── Role helpers ─────────────────────────────────────────────────────────
  String get _role => AuthService.instance.userRole?.toLowerCase() ?? 'driver';
  bool get _isDriver => _role == 'driver';
  bool get _isManager => _role == 'manager';
  bool get _isAdmin => _role == 'admin';

  // Driver  → 1 tab : My Returns (New only)
  // Manager → 2 tabs: New | Received
  // Admin   → 2 tabs: New | Received  (+ can approve from Received)
  int get _tabCount => _isDriver ? 1 : 2;

  late TabController _tabController;

  bool _isLoadingReturns = false;
  String? _errorMessage;
  List<CylinderReturn> _returns = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadReturns();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════ DATA LOADING ════════════════════════════

  Future<void> _loadReturns() async {
    setState(() {
      _isLoadingReturns = true;
      _errorMessage = null;
    });
    try {
      final all = await ApiService.fetchAllReturns();
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

  // ═══════════════════════════ FILTERED LISTS ══════════════════════════

  /// Driver sees only their own New returns
  List<CylinderReturn> get _myNewReturns => _returns
      .where(
        (r) => r.status == 'New' && r.addedBy == AuthService.instance.userId,
      )
      .toList();

  /// Manager/Admin see all New returns
  List<CylinderReturn> get _allNewReturns =>
      _returns.where((r) => r.status == 'New').toList();

  /// Manager/Admin see all Received returns
  List<CylinderReturn> get _receivedReturns =>
      _returns.where((r) => r.status == 'Received').toList();

  // ═══════════════════════════ ACTIONS ════════════════════════════════

  Future<void> _advanceStatus(CylinderReturn r) async {
    final next = r.nextStatus;
    if (next == null) return;
    try {
      await ApiService.advanceReturnStatus(
        returnId: r.returnId,
        newStatus: next,
      );
      // Update in-place for instant badge refresh
      setState(() {
        final idx = _returns.indexWhere((x) => x.returnId == r.returnId);
        if (idx >= 0) {
          _returns[idx] = CylinderReturn(
            returnId: r.returnId,
            returnDate: r.returnDate,
            customerId: r.customerId,
            customerName: r.customerName,
            stationId: r.stationId,
            stationName: r.stationName,
            status: next,
            returnType: r.returnType,
            addedBy: r.addedBy,
            cylinders: r.cylinders,
          );
        }
      });
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
        // Re-add to list since Dismissible already removed it visually
        setState(() => _returns.add(r));
      }
    }
  }

  // ═══════════════════════════ BUILD ══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isDriver) return _buildDriverView();
    return _buildManagerAdminView();
  }

  // ─────────────────────────────────────────────────────────────────────
  // DRIVER VIEW  — plain list of own New returns, no tabs, no dropdowns
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildDriverView() {
    return Column(
      children: [
        // Header
        _sectionHeader(
          title: 'Cylinder Returns',
          onAdd: widget.onNavigateToAdd,
        ),
        Expanded(
          child: _isLoadingReturns
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _errorView()
              : _buildList(
                  returns: _myNewReturns,
                  emptyMessage: 'No pending returns',
                  // Driver: swipe left = delete, tap = edit, no swipe right
                  cardBuilder: (r) => ReturnCard(
                    cylinderReturn: r,
                    onTap: () => widget.onNavigateToEdit?.call(r),
                    onDelete: () => _deleteReturn(r),
                    canDelete: true,
                    canAdvance: false,
                  ),
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // MANAGER / ADMIN VIEW  — 2 tabs: New | Received
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildManagerAdminView() {
    final newList = _allNewReturns;
    final receivedList = _receivedReturns;

    return Column(
      children: [
        // Tab bar
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryOrange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            _tabWithCount('New', newList.length),
            _tabWithCount('Received', receivedList.length),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ── New tab ───────────────────────────────────────────────
              Column(
                children: [
                  _sectionHeader(
                    title: 'New Returns',
                    onAdd: widget.onNavigateToAdd,
                  ),
                  Expanded(
                    child: _isLoadingReturns
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                        ? _errorView()
                        : _buildList(
                            returns: newList,
                            emptyMessage: 'No new returns',
                            cardBuilder: (r) => ReturnCard(
                              cylinderReturn: r,
                              // Admin can tap to edit New returns
                              onTap: _isAdmin
                                  ? () => widget.onNavigateToEdit?.call(r)
                                  : null,
                              onDelete: () => _deleteReturn(r),
                              onAdvanceStatus: () => _advanceStatus(r),
                              canDelete: true,
                              // Manager/Admin can swipe right → Received
                              canAdvance: r.nextStatus != null,
                            ),
                          ),
                  ),
                ],
              ),

              // ── Received tab ──────────────────────────────────────────
              Column(
                children: [
                  _sectionHeader(title: 'Received Returns'),
                  Expanded(
                    child: _isLoadingReturns
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                        ? _errorView()
                        : _buildList(
                            returns: receivedList,
                            emptyMessage: 'No received returns',
                            cardBuilder: (r) => ReturnCard(
                              cylinderReturn: r,
                              onTap: null, // no edit once received
                              onDelete: _isAdmin
                                  ? () => _deleteReturn(r)
                                  : null,
                              onAdvanceStatus: _isAdmin
                                  ? () => _advanceStatus(r)
                                  : null,
                              canDelete: _isAdmin,
                              // Only admin can approve (Received → Approved)
                              canAdvance: _isAdmin && r.nextStatus != null,
                            ),
                          ),
                  ),
                ],
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
    required Widget Function(CylinderReturn) cardBuilder,
  }) {
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
      onRefresh: _loadReturns,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        separatorBuilder: (_, __) =>
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
        itemCount: returns.length,
        itemBuilder: (_, i) => cardBuilder(returns[i]),
      ),
    );
  }

  // ═══════════════════════════ WIDGETS ═════════════════════════════════

  Widget _sectionHeader({required String title, VoidCallback? onAdd}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle, color: Colors.white, size: 20),
              label: const Text(
                'Add',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange.withOpacity(0.25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

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
          onPressed: _loadReturns,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
