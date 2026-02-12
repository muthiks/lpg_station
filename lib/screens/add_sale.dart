// lib/screens/add_sale.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lpg_station/models/sale_item.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/item_sheet.dart';
import 'package:lpg_station/widget/sale_item_card.dart';
import 'package:lpg_station/widget/scanner_toggle.dart';

class AddSale extends StatefulWidget {
  final VoidCallback onBack;
  final SaleDto? editSale;

  const AddSale({super.key, required this.onBack, this.editSale});

  bool get isEditMode => editSale != null;

  @override
  State<AddSale> createState() => _AddSaleState();
}

class _AddSaleState extends State<AddSale> {
  bool _isLoadingStations = true;
  bool _isLoadingCustomers = false;
  bool _isLoadingDeliveryGuys = false;
  bool _isLoadingStock = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<StationDto> _stations = [];
  List<CustomerDto> _customers = [];
  List<DeliveryGuyDto> _deliveryGuys = [];

  // ── All items ready for AddItemSheet ─────────────────────────────────
  // This is populated from stock API and passed directly to AddItemSheet
  List<Map<String, dynamic>> _allStockItems = [];

  StationDto? _selectedStation;
  CustomerDto? _selectedCustomer;
  String _deliveryType = 'Own Picking';
  DeliveryGuyDto? _selectedDeliveryGuy;

  List<SaleItem> saleItems = [];
  double totalAmount = 0.0;

  final FocusNode _scannerFocusNode = FocusNode();
  final TextEditingController _scannerController = TextEditingController();
  String _scanBuffer = '';
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
    if (widget.isEditMode) _prefillFromSale(widget.editSale!);
  }

  @override
  void dispose() {
    _scannerFocusNode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // ════════════════════════════ DATA LOADING ════════════════════════════

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
          _loadAllForStation(_selectedStation!.stationID);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingStations = false;
        _errorMessage = 'Failed to load stations: $e';
      });
    }
  }

  void _loadAllForStation(int stationId) {
    _loadCustomers(stationId);
    _loadDeliveryGuys(stationId);
    _loadStationStock(stationId);
  }

  Future<void> _loadCustomers(int stationId) async {
    setState(() {
      _isLoadingCustomers = true;
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
      _showSnack('Failed to load customers', isError: true);
    }
  }

  Future<void> _loadDeliveryGuys(int stationId) async {
    setState(() {
      _isLoadingDeliveryGuys = true;
      if (!widget.isEditMode) _selectedDeliveryGuy = null;
    });
    try {
      final guys = await ApiService.getStationDeliveryGuys(stationId);
      setState(() {
        _deliveryGuys = guys;
        _isLoadingDeliveryGuys = false;
      });
    } catch (e) {
      setState(() => _isLoadingDeliveryGuys = false);
      log('Error loading delivery guys: $e');
    }
  }

  Future<void> _loadStationStock(int stationId) async {
    setState(() {
      _isLoadingStock = true;
      _allStockItems = [];
    });
    try {
      final stock = await ApiService.getStationStock(stationId);

      // ── FIX: use allItemsForSheet which handles PascalCase correctly ──
      final items = stock.allItemsForSheet;

      log(
        'Stock loaded: ${stock.cylinders.length} cylinders, ${stock.accessories.length} accessories',
      );
      log('Total items for sheet: ${items.length}');
      for (final item in items) {
        log(
          '  Item: ${item['name']} (lubId=${item['lubId']}, price=${item['price']}, isAccessory=${item['isAccessory']})',
        );
      }

      setState(() {
        _allStockItems = items;
        _isLoadingStock = false;
      });
    } catch (e) {
      setState(() => _isLoadingStock = false);
      log('Error loading stock: $e');
      _showSnack('Failed to load stock items', isError: true);
    }
  }

  void _prefillFromSale(SaleDto sale) {
    _deliveryType =
        (sale.deliveryGuy != null &&
            sale.deliveryGuy!.isNotEmpty &&
            sale.deliveryGuy != 'N/A')
        ? 'Delivery'
        : 'Own Picking';
    saleItems = sale.saleDetails
        .map(
          (d) => SaleItem(
            cylinderTypeId: d.cylinderID,
            cylinderTypeName: d.lubName,
            quantity: d.quantity,
            price: d.price,
            amount: d.amount,
            cylinderPrice: d.cylinderPrice,
            cylinderAmount: d.cylinderAmount,
            cylinderStatus: d.cylStatus,
            priceType: d.priceType,
            isTagged: false,
            taggedBarcodes: [],
          ),
        )
        .toList();
    _calculateTotals();
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
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
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
                            _selectedDeliveryGuy = null;
                            if (!widget.isEditMode) {
                              saleItems.clear();
                              _calculateTotals();
                            }
                          });
                          _loadAllForStation(s.stationID);
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
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _sheetHeader('Select Customer', Icons.person, ctx),
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
                            ? 'Bal: KSh ${c.balance.toStringAsFixed(0)}'
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

  // ════════════════════════════ ITEMS ══════════════════════════════════

  void _addSaleItem() {
    if (_selectedStation == null) {
      _showSnack('Select a station first', isError: true);
      return;
    }
    if (_isLoadingStock) {
      _showSnack('Loading items, please wait...', isError: true);
      return;
    }
    if (_allStockItems.isEmpty) {
      _showSnack('No stock items found. Try refreshing.', isError: true);
      log('⚠️ _allStockItems is empty — stock may not have loaded');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemSheet(
        cylinderTypes: _allStockItems,
        onItemAdded: (item) {
          setState(() {
            saleItems.add(item);
            _calculateTotals();
          });
        },
      ),
    );
  }

  void _editSaleItem(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemSheet(
        cylinderTypes: _allStockItems,
        existingItem: saleItems[index],
        onItemAdded: (updated) {
          setState(() {
            saleItems[index] = updated;
            _calculateTotals();
          });
        },
      ),
    );
  }

  void _calculateTotals() {
    totalAmount = saleItems.fold(0.0, (s, i) => s + i.totalAmount);
    setState(() {});
  }

  // ════════════════════════════ SCANNER ════════════════════════════════

  void _onScannerTextChanged(String value) {
    _scanBuffer = value;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scanBuffer == value && value.isNotEmpty) _processScan(value.trim());
    });
  }

  void _processScan(String barcode) {
    if (barcode.isEmpty || !_isScanning) return;
    final already = saleItems.any(
      (i) => i.isTagged && i.taggedBarcodes.contains(barcode),
    );
    if (already) {
      _showSnack('Barcode already scanned', isError: true);
      _resetScanner();
      return;
    }
    _showCylinderTypeForScan(barcode);
  }

  void _showCylinderTypeForScan(String barcode) {
    final cylinders = _allStockItems
        .where((i) => i['isAccessory'] == false)
        .toList();
    if (cylinders.isEmpty) {
      _showSnack('No cylinder types available', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Cylinder Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Barcode: $barcode'),
            const SizedBox(height: 16),
            ...cylinders.map(
              (type) => ListTile(
                title: Text(type['name']),
                onTap: () {
                  Navigator.pop(context);
                  _addScannedCylinder(barcode, type);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addScannedCylinder(String barcode, Map<String, dynamic> type) {
    setState(() {
      final idx = saleItems.indexWhere(
        (i) => i.cylinderTypeId == type['id'] && i.isTagged,
      );
      if (idx != -1) {
        saleItems[idx].taggedBarcodes.add(barcode);
        saleItems[idx].quantity = saleItems[idx].taggedBarcodes.length;
        saleItems[idx].amount = saleItems[idx].price * saleItems[idx].quantity;
      } else {
        saleItems.add(
          SaleItem(
            cylinderTypeId: type['id'],
            cylinderTypeName: type['name'],
            quantity: 1,
            price: (type['price'] as num).toDouble(),
            amount: (type['price'] as num).toDouble(),
            cylinderPrice: (type['cylinderPrice'] as num).toDouble(),
            cylinderAmount: 0.0,
            cylinderStatus: 'Lease',
            priceType: 'Custom',
            isTagged: true,
            taggedBarcodes: [barcode],
          ),
        );
      }
      _calculateTotals();
    });
    _showSnack('Added ${type['name']} - $barcode');
    _resetScanner();
  }

  void _resetScanner() {
    _scannerController.clear();
    _scanBuffer = '';
    if (_isScanning)
      Future.delayed(
        const Duration(milliseconds: 50),
        () => FocusScope.of(context).requestFocus(_scannerFocusNode),
      );
  }

  void _toggleScanning(bool enable) {
    setState(() => _isScanning = enable);
    if (enable)
      Future.delayed(
        const Duration(milliseconds: 100),
        () => FocusScope.of(context).requestFocus(_scannerFocusNode),
      );
    else
      _scannerFocusNode.unfocus();
  }

  // ════════════════════════════ SAVE ═══════════════════════════════════

  void _saveSale() async {
    if (_selectedStation == null) {
      _showSnack('Select a station', isError: true);
      return;
    }
    if (_selectedCustomer == null) {
      _showSnack('Select a customer', isError: true);
      return;
    }
    if (_deliveryType == 'Delivery' && _selectedDeliveryGuy == null) {
      _showSnack('Select a delivery guy', isError: true);
      return;
    }
    if (saleItems.isEmpty) {
      _showSnack('Add at least one item', isError: true);
      return;
    }
    if (saleItems.any((i) => i.isTagged && i.taggedBarcodes.isEmpty)) {
      _showSnack('Tagged items must have scanned cylinders', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Future.delayed(
        const Duration(seconds: 1),
      ); // TODO: ApiService.createSale / updateSale
      _showSnack(widget.isEditMode ? 'Sale updated!' : 'Sale saved!');
      widget.onBack();
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

  // ════════════════════════════ BUILD ══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStations)
      return _scaffold(
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    if (_errorMessage != null)
      return _scaffold(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.primaryOrange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    return _scaffold(child: _buildForm());
  }

  Widget _scaffold({required Widget child}) {
    return Stack(
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 2, 16, 2),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_circle_left,
                      color: Colors.white,
                    ),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isEditMode ? 'Edit Sale' : 'Add New Sale',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoadingStock)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
        SizedBox(
          height: 0,
          width: 0,
          child: TextField(
            focusNode: _scannerFocusNode,
            controller: _scannerController,
            autofocus: false,
            showCursor: false,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(border: InputBorder.none),
            onChanged: _onScannerTextChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Station
                _label('Station'),
                const SizedBox(height: 4),
                _stations.length == 1
                    ? _singleStationDisplay()
                    : _tapField(
                        icon: Icons.warehouse,
                        value: _selectedStation?.stationName,
                        placeholder: 'Select Station',
                        onTap: _showStationSelector,
                      ),
                const SizedBox(height: 10),

                // Customer
                _label('Customer'),
                const SizedBox(height: 4),
                _tapField(
                  icon: Icons.person,
                  value: _selectedCustomer?.customerName,
                  placeholder: _selectedStation == null
                      ? 'Select station first'
                      : 'Select Customer',
                  isLoading: _isLoadingCustomers,
                  isDisabled: _selectedStation == null,
                  onTap: _selectedStation == null
                      ? null
                      : _showCustomerSelector,
                ),
                const SizedBox(height: 10),

                // Delivery Type
                _label('Delivery Type'),
                const SizedBox(height: 4),
                _whiteDropdown<String>(
                  icon: Icons.local_shipping,
                  value: _deliveryType,
                  items: const ['Own Picking', 'Delivery'],
                  labelOf: (v) => v,
                  onChanged: (v) => setState(() {
                    _deliveryType = v ?? 'Own Picking';
                    if (_deliveryType == 'Own Picking')
                      _selectedDeliveryGuy = null;
                  }),
                ),

                // Delivery Guy
                if (_deliveryType == 'Delivery') ...[
                  const SizedBox(height: 10),
                  _label('Delivery Guy'),
                  const SizedBox(height: 4),
                  _isLoadingDeliveryGuys
                      ? _loadingField('Loading delivery guys...')
                      : _whiteDropdown<DeliveryGuyDto>(
                          icon: Icons.person_pin,
                          value: _selectedDeliveryGuy,
                          hint: _deliveryGuys.isEmpty
                              ? 'No delivery guys'
                              : 'Select Delivery Guy',
                          items: _deliveryGuys,
                          labelOf: (v) => v.fullName,
                          isDisabled: _deliveryGuys.isEmpty,
                          onChanged: (v) =>
                              setState(() => _selectedDeliveryGuy = v),
                        ),
                ],

                const SizedBox(height: 16),

                // Items header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addSaleItem,
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      label: Text(
                        _isLoadingStock ? 'Loading...' : 'Add Item',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                if (saleItems.any((i) => i.isTagged)) ...[
                  ScannerToggle(
                    isScanning: _isScanning,
                    onToggle: _toggleScanning,
                  ),
                  const SizedBox(height: 12),
                ],

                // Items list
                if (saleItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No items added yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...saleItems.asMap().entries.map((e) {
                    final idx = e.key;
                    final item = e.value;
                    return Dismissible(
                      key: Key('item_$idx'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => setState(() {
                        saleItems.removeAt(idx);
                        _calculateTotals();
                      }),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () => _editSaleItem(idx),
                        child: SaleItemCard(
                          item: item,
                          onEdit: () => _editSaleItem(idx),
                          onDelete: () => setState(() {
                            saleItems.removeAt(idx);
                            _calculateTotals();
                          }),
                          onBarcodeDeleted: (bc) => setState(() {
                            item.taggedBarcodes.remove(bc);
                            item.quantity = item.taggedBarcodes.length;
                            item.amount = item.price * item.quantity;
                            _calculateTotals();
                          }),
                          formatCurrency: (v) =>
                              'KSh ${NumberFormat('#,##0').format(v)}',
                          hideActions: true,
                        ),
                      ),
                    );
                  }),

                if (saleItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryOrange,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'KSh ${NumberFormat('#,##0').format(totalAmount)}',
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Submit button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.isEditMode ? 'Update Sale' : 'Submit Sale',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════ UI HELPERS ═════════════════════════════

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    ),
  );

  Widget _tapField({
    required IconData icon,
    required String? value,
    required String placeholder,
    VoidCallback? onTap,
    bool isLoading = false,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: isDisabled || isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey.shade300 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDisabled ? Colors.grey.shade600 : AppTheme.primaryOrange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isLoading
                  ? const Text(
                      'Loading...',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    )
                  : Text(
                      value ?? placeholder,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDisabled
                            ? Colors.grey.shade600
                            : (value != null
                                  ? Colors.black87
                                  : Colors.grey[600]),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (!isLoading && !isDisabled)
              Icon(
                Icons.arrow_drop_down,
                color: AppTheme.primaryBlue,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _whiteDropdown<T>({
    required IconData icon,
    required T? value,
    String? hint,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?) onChanged,
    bool isDisabled = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade300 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppTheme.primaryOrange, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: isDisabled ? Colors.grey.shade300 : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        hint: hint != null
            ? Text(hint, style: const TextStyle(fontSize: 13))
            : null,
        isExpanded: true,
        items: items
            .map(
              (t) => DropdownMenuItem<T>(
                value: t,
                child: Text(labelOf(t), style: const TextStyle(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: isDisabled ? null : onChanged,
      ),
    );
  }

  Widget _singleStationDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warehouse, color: AppTheme.primaryBlue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedStation?.stationName ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════ SHEET HELPERS ══════════════════════════

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
