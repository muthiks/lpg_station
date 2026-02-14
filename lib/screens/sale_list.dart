// lib/screens/sale_list.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/screens/add_sale.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';

class SaleList extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;
  final String userRole;

  const SaleList({super.key, this.onNavigateToAdd, this.userRole = 'Manager'});

  @override
  State<SaleList> createState() => _SaleListState();
}

class _SaleListState extends State<SaleList> {
  bool _isLoadingStations = true;
  bool _isLoadingCustomers = false;
  bool _isLoadingSales = false;
  String? _errorMessage;

  List<StationDto> _stations = [];
  List<CustomerDto> _customers = [];
  List<SaleDto> _sales = [];

  StationDto? _selectedStation;
  CustomerDto? _selectedCustomer;

  final _currencyFormat = NumberFormat('#,##0', 'en_US');
  final _dateFormat = DateFormat('d/M/yyyy');

  bool get _isDriver => widget.userRole == 'Driver';
  bool get _isSuperOrAdmin =>
      widget.userRole == 'Super' || widget.userRole == 'Admin';
  bool get _canManageSales =>
      ['Super', 'Admin', 'Manager'].contains(widget.userRole);

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

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
      _loadSales(_selectedStation?.stationID);
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

  Future<void> _loadSales(int? stationId) async {
    setState(() {
      _isLoadingSales = true;
      _errorMessage = null;
    });
    try {
      final sales = await ApiService.getStationLpgSales(stationId: stationId);
      setState(() {
        _sales = sales;
        _isLoadingSales = false;
      });
      for (final s in sales) {
        log('Sale ${s.invoiceNo} → ${s.saleDetails.length} items');
      }
    } catch (e) {
      setState(() {
        _isLoadingSales = false;
        _errorMessage = 'Failed to load sales: $e';
      });
    }
  }

  List<SaleDto> get _filteredSales => _sales.where((s) {
    if (_selectedCustomer != null &&
        s.customerID != _selectedCustomer!.customerID)
      return false;
    return true;
  }).toList();

  // ════════════════════════════ NAVIGATION — FIX ═══════════════════════
  // Push directly to AddSale widget instead of using named route
  // This avoids the "Could not find a generator for route" error

  void _openEditSale(SaleDto sale) {
    if (!_canManageSales) {
      _showSnack('No permission to edit', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.93,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryBlue, Color(0xFFc0440a)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: AddSale(
            onBack: () {
              Navigator.pop(context);
              _loadSales(_selectedStation?.stationID);
            },
            editSale: sale,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════ ACTIONS ════════════════════════════════

  Future<void> _confirmDelete(SaleDto sale) async {
    if (sale.isDelivered && !_isSuperOrAdmin) {
      _showSnack('Only Admin/Super can delete delivered sales', isError: true);
      return;
    }
    if (!_canManageSales) {
      _showSnack('No permission to delete', isError: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Sale'),
        content: Text(
          'Delete invoice ${sale.invoiceNo}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.deleteSale(sale.lpgSaleID);
        setState(
          () => _sales.removeWhere((s) => s.lpgSaleID == sale.lpgSaleID),
        );
        _showSnack('Sale deleted');
      } catch (e) {
        _showSnack('Failed: $e', isError: true);
      }
    }
  }

  Future<void> _confirmAdvanceStage(SaleDto sale) async {
    if (_isDriver && sale.status != 'Dispatched') {
      _showSnack(
        'You can only mark Dispatched sales as Delivered',
        isError: true,
      );
      return;
    }
    if (!_canManageSales && !_isDriver) {
      _showSnack('No permission to update status', isError: true);
      return;
    }
    if (!sale.canAdvanceStage) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Move to ${sale.nextStatus}?'),
        content: Text(
          'Update ${sale.invoiceNo} from "${sale.status}" to "${sale.nextStatus}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _stageColor(sale.nextStatus),
            ),
            child: Text(
              'Move to ${sale.nextStatus}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.updateSaleStatus(sale.lpgSaleID, sale.nextStatus);
        await _loadSales(_selectedStation?.stationID);
        _showSnack('Moved to ${sale.nextStatus}');
      } catch (e) {
        _showSnack('Failed: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Color _stageColor(String status) {
    switch (status) {
      case 'Draft':
        return const Color(0xFF2196F3);
      case 'Confirmed':
        return const Color(0xFF4CAF50);
      case 'Dispatched':
        return const Color(0xFF9C27B0);
      case 'Delivered':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  IconData _stageIcon(String status) {
    switch (status) {
      case 'Draft':
        return Icons.edit_note;
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Dispatched':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.verified;
      default:
        return Icons.circle;
    }
  }

  // ════════════════════════════ STATION SELECTOR ═══════════════════════

  void _showStationSelector() {
    final ctrl = TextEditingController();
    List<StationDto> filtered = _stations;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          return _bottomSheet(
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
                    _loadSales(null);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      final sel = _selectedStation?.stationID == s.stationID;
                      return _sheetItemTile(
                        label: s.stationName,
                        icon: Icons.warehouse,
                        isSelected: sel,
                        onTap: () {
                          setState(() {
                            _selectedStation = s;
                            _selectedCustomer = null;
                          });
                          _loadCustomers(s.stationID);
                          _loadSales(s.stationID);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ════════════════════════════ CUSTOMER SELECTOR ══════════════════════

  void _showCustomerSelector() {
    if (_selectedStation == null) {
      _showSnack('Select a station first', isError: true);
      return;
    }
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
        builder: (ctx, setModal) {
          return _bottomSheet(
            height: 0.7,
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
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final sel = _selectedCustomer?.customerID == c.customerID;
                      return _sheetItemTile(
                        label: c.customerName,
                        icon: Icons.person_outline,
                        isSelected: sel,
                        subtitle: c.customerPhone,
                        trailing: c.hasBalance
                            ? 'Bal: ${_currencyFormat.format(c.balance)}'
                            : null,
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
          );
        },
      ),
    );
  }

  // ════════════════════════════ BUILD ══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStations)
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(child: _buildSalesContent()),
        if (!_isDriver) _buildAddButton(),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _stations.length > 1 ? _showStationSelector : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warehouse,
                    color: AppTheme.primaryOrange,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedStation?.stationName ?? '--Select Station--',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedStation != null
                            ? Colors.black87
                            : const Color(0xFF757575),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_stations.length > 1)
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF757575),
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _selectedStation == null || _isLoadingCustomers
                ? null
                : _showCustomerSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: AppTheme.primaryOrange, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isLoadingCustomers
                          ? 'Loading...'
                          : (_selectedCustomer?.customerName ??
                                'Select Customer'),
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedCustomer != null
                            ? Colors.black87
                            : const Color(0xFF757575),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF757575),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesContent() {
    if (_isLoadingSales)
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    if (_errorMessage != null) {
      return Center(
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
              onPressed: () => _loadSales(_selectedStation?.stationID),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_filteredSales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sales found',
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
      onRefresh: () => _loadSales(_selectedStation?.stationID),
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: _filteredSales.length,
        itemBuilder: (_, i) => _buildSwipeableCard(_filteredSales[i]),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ElevatedButton(
        onPressed: widget.onNavigateToAdd,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 22),
            SizedBox(width: 8),
            Text(
              'Add Sale',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeableCard(SaleDto sale) {
    final canRight = _isDriver
        ? sale.status == 'Dispatched'
        : (_canManageSales && sale.canAdvanceStage);
    final canLeft = sale.isDelivered ? _isSuperOrAdmin : _canManageSales;

    return Dismissible(
      key: Key('sale_${sale.lpgSaleID}'),
      background: Container(
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: _stageColor(sale.nextStatus),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_stageIcon(sale.nextStatus), color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              sale.nextStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (!canRight) {
            _showSnack(
              _isDriver
                  ? 'Can only mark Dispatched as Delivered'
                  : 'Cannot advance',
              isError: true,
            );
            return false;
          }
          await _confirmAdvanceStage(sale);
          return false;
        } else {
          if (!canLeft) {
            _showSnack(
              sale.isDelivered
                  ? 'Only Admin/Super can delete delivered'
                  : 'No permission',
              isError: true,
            );
            return false;
          }
          await _confirmDelete(sale);
          return false;
        }
      },
      direction: DismissDirection.horizontal,
      child: _SaleCardBody(
        sale: sale,
        stageColor: _stageColor(sale.status),
        stationName:
            _selectedStation?.stationName ??
            _stations
                .where((st) => st.stationID == sale.stationID)
                .map((st) => st.stationName)
                .firstOrNull,
        currencyFormat: _currencyFormat,
        dateFormat: _dateFormat,
        onTap: _canManageSales ? () => _openEditSale(sale) : null,
      ),
    );
  }

  // ════════════════════════════ SHEET HELPERS ══════════════════════════

  Widget _bottomSheet({required double height, required Widget child}) {
    return Container(
      height: MediaQuery.of(context).size.height * height,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    );
  }

  Widget _sheetHeader(String title, IconData icon, BuildContext ctx) {
    return Container(
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
  }

  Widget _searchField(
    TextEditingController ctrl,
    String hint,
    void Function(String) onChanged,
  ) {
    return Padding(
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
  }

  Widget _sheetOptionTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
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
  }

  Widget _sheetItemTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? subtitle,
    String? trailing,
  }) {
    return Card(
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
        trailing: trailing != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailing,
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Sale Card Body
// ══════════════════════════════════════════════════════════════════════════

class _SaleCardBody extends StatefulWidget {
  final SaleDto sale;
  final Color stageColor;
  final String? stationName;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final VoidCallback? onTap;

  const _SaleCardBody({
    required this.sale,
    required this.stageColor,
    this.stationName,
    required this.currencyFormat,
    required this.dateFormat,
    this.onTap,
  });

  @override
  State<_SaleCardBody> createState() => _SaleCardBodyState();
}

class _SaleCardBodyState extends State<_SaleCardBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final details = sale.saleDetails;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryOrange.withOpacity(0.6),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER: Customer name + Stage badge ───────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sale.customerName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: widget.stageColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sale.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── BODY ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invoice + Customer Type on same row
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        size: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sale.invoiceNo,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (sale.customerType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sale.customerType!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Date + Total
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.dateFormat.format(sale.saleDate),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'KSh ${widget.currencyFormat.format(sale.total)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  // Station
                  if ((sale.stationName ?? widget.stationName) != null) ...[
                    const SizedBox(height: 5),
                    _iconRow(
                      Icons.warehouse,
                      sale.stationName ?? widget.stationName!,
                    ),
                  ],
                ],
              ),
            ),

            // ── ITEMS TOGGLE ──────────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.primaryOrange.withOpacity(0.3),
                    ),
                    bottom: _expanded
                        ? BorderSide(
                            color: AppTheme.primaryOrange.withOpacity(0.3),
                          )
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.propane_tank_outlined,
                      size: 15,
                      color: AppTheme.primaryOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Items (${details.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // ── ITEMS TABLE ───────────────────────────────────────────────
            if (_expanded) ...[
              if (details.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No items',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                )
              else ...[
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  color: Colors.white.withOpacity(0.05),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Item',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Status',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Price',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Amount',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                ...details.map(_buildDetailRow),
              ],
            ],

            // ── FOOTER: Phone (left) + Delivery Guy (right) ──────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Phone — left side
                  if (sale.customerPhone != null &&
                      sale.customerPhone!.isNotEmpty) ...[
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        sale.customerPhone!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ] else
                    const Expanded(child: SizedBox()),
                  // Delivery guy — right side
                  if (sale.deliveryGuy != null &&
                      sale.deliveryGuy!.isNotEmpty &&
                      sale.deliveryGuy != 'N/A') ...[
                    Icon(
                      Icons.delivery_dining,
                      size: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        sale.deliveryGuy!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(SaleDetailDto d) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                d.lubName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              d.cylStatus,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              d.quantity.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'KSh ${_fmt(d.price)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'KSh ${_fmt(d.amount)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => NumberFormat('#,##0', 'en_US').format(v);
}
