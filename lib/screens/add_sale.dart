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
  // ── Loading flags ────────────────────────────────────────────────────
  bool _isLoadingStations = true;
  bool _isLoadingCustomers = false;
  bool _isLoadingDeliveryGuys = false;
  bool _isLoadingStock = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // ── Data lists ──────────────────────────────────────────────────────
  List<StationDto> _stations = [];
  List<CustomerDto> _customers = [];
  List<DeliveryGuyDto> _deliveryGuys = [];
  List<Map<String, dynamic>> _allStockItems = [];

  // ── Selected values ─────────────────────────────────────────────────
  StationDto? _selectedStation;
  CustomerDto? _selectedCustomer;
  String _deliveryType = 'Own Picking';
  DeliveryGuyDto? _selectedDeliveryGuy;

  // ── Sale items ──────────────────────────────────────────────────────
  List<SaleItem> saleItems = [];
  double totalAmount = 0.0;

  // ── Scanner ─────────────────────────────────────────────────────────
  final FocusNode _scannerFocusNode = FocusNode();
  final TextEditingController _scannerController = TextEditingController();
  String _scanBuffer = '';
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadStations();
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
      });

      if (widget.isEditMode) {
        final sale = widget.editSale!;

        // StationID is now always returned by the API.
        // Match by StationID directly — name and single-station as fallbacks.
        // stationID is always present from the API — match directly.
        // Name and single-station are kept as safety fallbacks.
        final match =
            _stations.where((s) => s.stationID == sale.stationID).firstOrNull ??
            (sale.stationName != null
                ? _stations
                      .where((s) => s.stationName == sale.stationName)
                      .firstOrNull
                : null) ??
            (_stations.length == 1 ? _stations.first : null);

        if (match != null) {
          setState(() => _selectedStation = match);
          // Load customers, delivery guys, and stock in parallel,
          // then populate all fields once data is ready.
          await Future.wait([
            _loadCustomersForEdit(match.stationID),
            _loadDeliveryGuysForEdit(match.stationID),
            _loadStationStock(match.stationID),
          ]);
          _populateEditFields(sale);
        }
      } else {
        if (_stations.length == 1) {
          setState(() => _selectedStation = _stations.first);
          _loadAllForStation(_selectedStation!.stationID);
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingStations = false;
        _errorMessage = 'Failed to load stations: $e';
      });
    }
  }

  Future<void> _loadCustomersForEdit(int stationId) async {
    setState(() => _isLoadingCustomers = true);
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

  Future<void> _loadDeliveryGuysForEdit(int stationId) async {
    setState(() => _isLoadingDeliveryGuys = true);
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

  void _populateEditFields(SaleDto sale) {
    setState(() {
      final hasDelivery =
          sale.deliveryGuy != null &&
          sale.deliveryGuy!.isNotEmpty &&
          sale.deliveryGuy != 'N/A';
      _deliveryType = hasDelivery ? 'Delivery' : 'Own Picking';
      _selectedCustomer = _customers
          .where((c) => c.customerID == sale.customerID)
          .firstOrNull;
      if (hasDelivery) {
        _selectedDeliveryGuy = _deliveryGuys
            .where(
              (g) => g.fullName == sale.deliveryGuy || g.id == sale.deliveryGuy,
            )
            .firstOrNull;
      }
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
              capacity: d.capacity ?? 0, // carry capacity from API for submit
              isTagged: false,
              taggedBarcodes: [],
            ),
          )
          .toList();
    });
    _calculateTotals();
  }

  void _loadAllForStation(int stationId) {
    _loadCustomers(stationId);
    _loadDeliveryGuys(stationId);
    _loadStationStock(stationId);
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
      _showSnack('Failed to load customers', isError: true);
    }
  }

  Future<void> _loadDeliveryGuys(int stationId) async {
    setState(() {
      _isLoadingDeliveryGuys = true;
      _selectedDeliveryGuy = null;
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
      final items = stock.allItemsForSheet;
      log(
        'Stock: ${stock.cylinders.length} cylinders, ${stock.accessories.length} accessories → ${items.length} total',
      );
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
          return _sheet(
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
          return _sheet(
            height: 0.75,
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
                            ? 'KSh ${c.balance.toStringAsFixed(0)}'
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
      return;
    }
    final cylinders = _allStockItems
        .where((i) => i['isAccessory'] == false)
        .toList();
    final accessories = _allStockItems
        .where((i) => i['isAccessory'] == true)
        .toList();
    // Accumulate items from the sheet then apply in one setState
    // Avoids the race where two rapid onItemAdded calls both capture
    // the same pre-flush saleItems list and the first item gets lost
    final pending = <SaleItem>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemSheet(
        cylinderTypes: cylinders,
        accessories: accessories,
        onItemAdded: (item) => pending.add(item),
      ),
    ).then((_) {
      if (pending.isNotEmpty && mounted) {
        setState(() {
          saleItems = [...saleItems, ...pending];
          _calculateTotals();
        });
      }
    });
  }

  void _editSaleItem(int index) {
    final cylinders = _allStockItems
        .where((i) => i['isAccessory'] == false)
        .toList();
    final accessories = _allStockItems
        .where((i) => i['isAccessory'] == true)
        .toList();
    final pending = <SaleItem>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemSheet(
        cylinderTypes: cylinders,
        accessories: accessories,
        existingItem: saleItems[index],
        onItemAdded: (item) => pending.add(item),
      ),
    ).then((_) {
      if (pending.isNotEmpty && mounted) {
        setState(() {
          // Replace the tapped item with the first result,
          // append any additional items (e.g. accessory added alongside)
          final updated = List<SaleItem>.from(saleItems);
          updated[index] = pending.first;
          if (pending.length > 1) updated.addAll(pending.skip(1));
          saleItems = updated;
          _calculateTotals();
        });
      }
    });
  }

  // ── CHANGE 2: Swipe-to-delete with confirmation dialog ───────────────
  Future<bool> _confirmItemDelete(int index) async {
    final item = saleItems[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Remove Item', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Remove "${item.cylinderTypeName}" (x${item.quantity}) from this sale?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        saleItems = List<SaleItem>.from(saleItems)..removeAt(index);
        _calculateTotals();
      });
      return true;
    }
    return false;
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
              (t) => ListTile(
                title: Text(t['name']),
                onTap: () {
                  Navigator.pop(context);
                  _addScannedCylinder(barcode, t);
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
        saleItems = [
          ...saleItems,
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
        ];
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

  // ════════════════════════════ SAVE — CHANGE 3: API JSON ══════════════

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
      _showSnack('Tagged items must have barcodes', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now();
      final deliveryGuy =
          _deliveryType == 'Delivery' && _selectedDeliveryGuy != null
          ? _selectedDeliveryGuy!.id
          : '';

      // ── Payload — wrapped in 'data' as the model binder expects ────
      final saleData = {
        // LpgSaleID only needed for update — server uses it to find the record
        if (widget.isEditMode) 'LpgSaleID': widget.editSale!.lpgSaleID,
        'SaleDate': now.toIso8601String(),
        'CustomerID': _selectedCustomer!.customerID,
        'CustomerName': _selectedCustomer!.customerName,
        'StationID': _selectedStation!.stationID,
        'DeliveryGuy': _selectedDeliveryGuy!.id,
        'AddedBy': 'user',
        'DateAdded': now.toIso8601String(),

        // Totals calculated in Flutter — server stores them as-is
        'Total': totalAmount,
        'Balance': totalAmount,

        // Detail lines — cylinders AND accessories
        // Accessories are sent with IsAccessory:true so the API handles them separately
        'SaleDetails': saleItems.map((item) {
          if (item.cylinderTypeName == 'Accessory Only') {
            // Accessory line — LubId comes from accessoryId (stored as String)
            return {
              'CylinderID': int.tryParse(item.accessoryId ?? '0') ?? 0,
              'Quantity': item.accessoryQuantity ?? 1,
              'Status': 'Accessory',
              'PriceType': item.accessoryPriceType ?? 'Custom',
              'Price': item.accessoryPrice ?? 0.0,
              'Amount': item.accessoryAmount ?? 0.0,
              'CylinderPrice': 0.0,
              'CylinderAmount': 0.0,
              'Capacity': 0,
              'IsAccessory': true,
            };
          }
          return {
            'CylinderID': item.cylinderTypeId,
            'Quantity': item.quantity,
            'Status': item.cylinderStatus,
            'PriceType': item.priceType,
            'Price': item.price,
            'Amount': item.amount,
            'CylinderPrice': item.cylinderPrice,
            'CylinderAmount': item.cylinderAmount,
            'Capacity': _getCapacity(
              item.cylinderTypeId,
              knownCapacity: item.capacity,
            ).toInt(),
            'IsAccessory': false,
          };
        }).toList(),
      };

      // [FromBody] reads the body directly — no wrapper key needed
      final payload = saleData;

      log('Submitting sale payload: $payload');

      if (widget.isEditMode) {
        await ApiService.updateSale(payload);
      } else {
        await ApiService.createSale(payload);
      }

      _showSnack(widget.isEditMode ? 'Sale updated!' : 'Sale saved!');
      widget.onBack();
    } catch (e) {
      _showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Returns capacity for a sale item.
  // Prefers the value already on the SaleDetailDto (populated from the API),
  // with a fallback to the stock items list loaded for this session.
  double _getCapacity(int cylinderTypeId, {double? knownCapacity}) {
    if (knownCapacity != null && knownCapacity > 0) return knownCapacity;
    final match = _allStockItems
        .where((i) => i['id'] == cylinderTypeId || i['lubId'] == cylinderTypeId)
        .firstOrNull;
    if (match != null) {
      final cap = match['capacity'];
      if (cap != null) return (cap as num).toDouble();
    }
    return 0;
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
    if (_isLoadingStations) {
      return _scaffold(
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryOrange),
        ),
      );
    }
    if (_errorMessage != null) {
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
                onPressed: _loadStations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return _scaffold(child: _buildForm());
  }

  // ─────────────────── Scaffold wrapper ────────────────────────────────

  Widget _scaffold({required Widget child}) {
    return Stack(
      children: [
        Column(
          children: [
            // ── CHANGE 1: back icon wired to widget.onBack ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 6),
              child: Row(
                children: [
                  // Back arrow — calls onBack which pops to sales list
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_circle_left,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: widget.onBack, // ← FIXED: was null
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditMode ? 'Edit Sale' : 'Add New Sale',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.isEditMode && widget.editSale != null)
                        Text(
                          widget.editSale!.invoiceNo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (_isLoadingStock)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
        // Hidden scanner field
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

  // ─────────────────── Form body ───────────────────────────────────────

  Widget _buildForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Station ───────────────────────────────────────────────
                _sectionLabel('Station'),
                const SizedBox(height: 4),
                _stations.length == 1
                    ? _autoField(
                        Icons.warehouse,
                        _selectedStation?.stationName ?? '',
                      )
                    : _tapField(
                        icon: Icons.warehouse,
                        value: _selectedStation?.stationName,
                        placeholder: 'Select Station',
                        onTap: _showStationSelector,
                      ),

                const SizedBox(height: 12),

                // ── Customer ──────────────────────────────────────────────
                _sectionLabel('Customer'),
                const SizedBox(height: 4),
                _isLoadingCustomers
                    ? _loadingField('Loading customers...')
                    : _tapField(
                        icon: Icons.person,
                        value: _selectedCustomer?.customerName,
                        placeholder: _selectedStation == null
                            ? 'Select station first'
                            : 'Select Customer',
                        isDisabled: _selectedStation == null,
                        onTap: _selectedStation == null
                            ? null
                            : _showCustomerSelector,
                      ),

                const SizedBox(height: 12),

                // ── Delivery Type ─────────────────────────────────────────
                _sectionLabel('Delivery Type'),
                const SizedBox(height: 4),
                _styledDropdown<String>(
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

                // ── Delivery Guy ──────────────────────────────────────────
                if (_deliveryType == 'Delivery') ...[
                  const SizedBox(height: 12),
                  _sectionLabel('Delivery Guy'),
                  const SizedBox(height: 4),
                  _isLoadingDeliveryGuys
                      ? _loadingField('Loading delivery guys...')
                      : _styledDropdown<DeliveryGuyDto>(
                          icon: Icons.person_pin,
                          value: _selectedDeliveryGuy,
                          hint: _deliveryGuys.isEmpty
                              ? 'No delivery guys available'
                              : 'Select Delivery Guy',
                          items: _deliveryGuys,
                          labelOf: (v) => v.fullName,
                          isDisabled: _deliveryGuys.isEmpty,
                          onChanged: (v) =>
                              setState(() => _selectedDeliveryGuy = v),
                        ),
                ],

                const SizedBox(height: 16),

                // ── Items header ──────────────────────────────────────────
                Row(
                  children: [
                    _sectionLabel('Items'),
                    const Spacer(),
                    GestureDetector(
                      onTap: _addSaleItem,
                      child: Row(
                        children: [
                          Icon(
                            _isLoadingStock
                                ? Icons.hourglass_empty
                                : Icons.add_circle_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isLoadingStock ? 'Loading...' : 'Add Item',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (saleItems.any((i) => i.isTagged)) ...[
                  const SizedBox(height: 10),
                  ScannerToggle(
                    isScanning: _isScanning,
                    onToggle: _toggleScanning,
                  ),
                ],

                const SizedBox(height: 10),

                // ── Items list ────────────────────────────────────────────
                if (saleItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryOrange.withOpacity(0.3),
                      ),
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
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // ── CHANGE 2: confirmDismiss shows dialog before removing ─
                  ...saleItems.asMap().entries.map((e) {
                    final idx = e.key;
                    final item = e.value;
                    return Dismissible(
                      key: Key(
                        'item_${idx}_${item.cylinderTypeId}_${item.cylinderStatus}_${item.price}_${item.accessoryId ?? 'none'}',
                      ),
                      direction: DismissDirection.endToStart,
                      // confirmDismiss handles removal itself — always return false
                      // so Dismissible never auto-removes the widget
                      confirmDismiss: (_) =>
                          _confirmItemDelete(idx).then((_) => false),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 8),
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
                              'Remove',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () => _editSaleItem(idx),
                        child: SaleItemCard(
                          item: item,
                          onEdit: () => _editSaleItem(idx),
                          onDelete: () => _confirmItemDelete(idx),
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      // color: Colors.black.withOpacity(0.25),
                      // borderRadius: BorderRadius.circular(12),
                      // border: Border.all(
                      //   color: AppTheme.primaryOrange,
                      //   width: 1.5,
                      // ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'KSh ${NumberFormat('#,##0').format(totalAmount)}',
                          style: TextStyle(
                            color: Colors.purple,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // ── Submit Button ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _saveSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                disabledBackgroundColor: AppTheme.primaryOrange.withOpacity(
                  0.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _tapField({
    required IconData icon,
    required String? value,
    required String placeholder,
    VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
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
            Icon(icon, color: AppTheme.primaryOrange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null
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
    );
  }

  Widget _styledDropdown<T>({
    required IconData icon,
    required T? value,
    String? hint,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T?) onChanged,
    bool isDisabled = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
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
          Icon(icon, color: AppTheme.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: false,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF757575),
                  size: 22,
                ),
                hint: hint != null
                    ? Text(
                        hint,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                        ),
                      )
                    : null,
                items: isDisabled
                    ? null
                    : items
                          .map(
                            (t) => DropdownMenuItem<T>(
                              value: t,
                              child: Text(
                                labelOf(t),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                onChanged: isDisabled ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoField(IconData icon, String value) {
    return Container(
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
          Icon(icon, color: AppTheme.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'AUTO',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
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
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF757575), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════ SHEET HELPERS ══════════════════════════

  Widget _sheet({required double height, required Widget child}) {
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
