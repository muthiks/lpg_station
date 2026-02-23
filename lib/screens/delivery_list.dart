// lib/screens/delivery_list.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/dispatch_sheet.dart';

class DeliveryList extends StatefulWidget {
  const DeliveryList({super.key});

  @override
  State<DeliveryList> createState() => _DeliveryListState();
}

class _DeliveryListState extends State<DeliveryList> {
  bool _isLoadingSales = false;
  String? _errorMessage;
  List<SaleDto> _sales = [];

  final _currencyFormat = NumberFormat('#,##0', 'en_US');
  final _dateFormat = DateFormat('d/M/yyyy');

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoadingSales = true;
      _errorMessage = null;
    });
    try {
      // Dedicated driver endpoint — returns only Confirmed/Dispatched sales
      // assigned to the authenticated driver. Delivered sales are excluded server-side.
      final sales = await ApiService.getDriverDeliveries();
      setState(() {
        // Belt-and-suspenders: also drop anything already Delivered client-side
        _sales = sales.where((s) => s.status != 'Delivered').toList();
        _isLoadingSales = false;
      });
      for (final s in _sales) {
        log('Delivery ${s.invoiceNo} → ${s.saleDetails.length} items');
      }
    } catch (e) {
      setState(() {
        _isLoadingSales = false;
        _errorMessage = 'Failed to load deliveries: $e';
      });
    }
  }

  // ════════════════════════════ ACTIONS ════════════════════════════════

  Future<void> _confirmAdvanceStage(SaleDto sale) async {
    if (!sale.canAdvanceStage) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Move to ${sale.nextStatus}?',
          style: const TextStyle(color: Colors.black, fontSize: 17),
        ),
        content: Text(
          'Update ${sale.invoiceNo} from "${sale.status}" to "${sale.nextStatus}"?',
          style: const TextStyle(color: Colors.black),
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

    if (ok != true) return;

    // Confirmed → Dispatched: open dispatch sheet
    if (sale.nextStatus == 'Dispatched') {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DispatchSheet(
          sale: sale,
          onDispatched: () {
            _loadSales();
            _showSnack('Sale dispatched');
          },
        ),
      );
      return;
    }

    // Dispatched → Delivered
    try {
      await ApiService.updateSaleStatus(sale.lpgSaleID, sale.nextStatus);
      // Remove immediately from list — delivered sales don't belong here
      setState(() => _sales.removeWhere((s) => s.lpgSaleID == sale.lpgSaleID));
      _showSnack('Marked as Delivered ✓');
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
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

  // ════════════════════════════ BUILD ══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeading(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildHeading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryOrange.withOpacity(0.4),
            width: 1.2,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_shipping,
              color: AppTheme.primaryOrange,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery List',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                _isLoadingSales
                    ? 'Loading...'
                    : '${_sales.length} pending ${_sales.length == 1 ? 'delivery' : 'deliveries'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Refresh button
          IconButton(
            onPressed: _isLoadingSales ? null : _loadSales,
            icon: Icon(
              Icons.refresh_rounded,
              color: _isLoadingSales
                  ? Colors.white24
                  : Colors.white.withOpacity(0.7),
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingSales) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

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
              onPressed: _loadSales,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No deliveries assigned',
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
      onRefresh: _loadSales,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: _sales.length,
        itemBuilder: (_, i) => _buildSwipeableCard(_sales[i]),
      ),
    );
  }

  Widget _buildSwipeableCard(SaleDto sale) {
    return Dismissible(
      key: Key('delivery_${sale.lpgSaleID}'),
      // Swipe right → advance stage (Confirmed → Dispatched, Dispatched → Delivered)
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
      // No delete action — secondary background is intentionally hidden
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      direction: DismissDirection.startToEnd, // only right-swipe allowed
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (!sale.canAdvanceStage) {
            _showSnack('Cannot advance this sale', isError: true);
            return false;
          }
          await _confirmAdvanceStage(sale);
        }
        return false; // never auto-dismiss; we handle list refresh manually
      },
      child: _DeliveryCardBody(
        sale: sale,
        stageColor: _stageColor(sale.status),
        currencyFormat: _currencyFormat,
        dateFormat: _dateFormat,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  Delivery Card Body  (read-only, no edit tap)
// ══════════════════════════════════════════════════════════════════════════

class _DeliveryCardBody extends StatefulWidget {
  final SaleDto sale;
  final Color stageColor;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  const _DeliveryCardBody({
    required this.sale,
    required this.stageColor,
    required this.currencyFormat,
    required this.dateFormat,
  });

  @override
  State<_DeliveryCardBody> createState() => _DeliveryCardBodyState();
}

class _DeliveryCardBodyState extends State<_DeliveryCardBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final details = sale.saleDetails;

    return Container(
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
          // ── HEADER ────────────────────────────────────────────────────
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
                if (sale.stationName != null) ...[
                  const SizedBox(height: 5),
                  _iconRow(Icons.warehouse, sale.stationName!),
                ],
              ],
            ),
          ),

          // ── ITEMS TOGGLE ──────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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

          // ── FOOTER ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(
                top: BorderSide(color: AppTheme.primaryOrange.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
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
                // Swipe hint
                Row(
                  children: [
                    Icon(
                      Icons.swipe_right_outlined,
                      size: 14,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Swipe to dispatch',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
