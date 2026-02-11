// lib/screens/add_sale.dart (updated version)

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:lpg_station/models/customer_model.dart';
import 'package:lpg_station/models/driver.dart';
import 'package:lpg_station/models/sale_item.dart';
import 'package:lpg_station/models/stock.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/item_sheet.dart';
import 'package:lpg_station/widget/sale_item_card.dart';
import 'package:lpg_station/widget/scanner_toggle.dart';

class AddSale extends StatefulWidget {
  final VoidCallback onBack;
  const AddSale({super.key, required this.onBack});

  @override
  State<AddSale> createState() => _AddSaleState();
}

class _AddSaleState extends State<AddSale> {
  // Loading states
  bool _isLoadingStations = true;
  bool _isLoadingCustomers = false;
  bool _isLoadingDeliveryGuys = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // API Data
  List<StationDto> _stations = [];
  List<CustomerDto> _customers = [];
  List<Driver> _deliveryGuys = [];

  // Selection States
  int? _selectedStationId;
  int? _selectedCustomerId;
  String deliveryType = 'Own Picking';
  String? _selectedDeliveryGuyId;

  // Sale Items
  List<SaleItem> saleItems = [];

  // Totals
  double totalAmount = 0.0;

  // Scanner
  final FocusNode _scannerFocusNode = FocusNode();
  final TextEditingController _scannerController = TextEditingController();
  String _scanBuffer = '';
  bool _isScanning = false;

  // Cylinder types - Replace with API call if needed
  final List<Map<String, dynamic>> cylinderTypes = [
    {
      'id': 1,
      'name': '6KG',
      'capacity': 6,
      'price': 1000,
      'cylinderPrice': 2500,
    },
    {
      'id': 2,
      'name': '13KG',
      'capacity': 13,
      'price': 2000,
      'cylinderPrice': 3650,
    },
    {
      'id': 3,
      'name': '13KG(SAFE)',
      'capacity': 13,
      'price': 4000,
      'cylinderPrice': 6500,
    },
    {
      'id': 4,
      'name': '50KG',
      'capacity': 50,
      'price': 7000,
      'cylinderPrice': 12000,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStations();
    _calculateTotals();
  }

  @override
  void dispose() {
    _scannerFocusNode.dispose();
    _scannerController.dispose();
    super.dispose();
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

        // If only one station, auto-select it
        if (_stations.length == 1) {
          _selectedStationId = _stations.first.stationID;
          _loadCustomers(_selectedStationId!);
          _loadDeliveryGuys(_selectedStationId!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingStations = false;
        _errorMessage = 'Failed to load stations: ${e.toString()}';
      });
      log('Error loading stations: $e');
    }
  }

  Future<void> _loadCustomers(int stationId) async {
    setState(() {
      _isLoadingCustomers = true;
      _selectedCustomerId = null;
    });

    try {
      final customers = await ApiService.getCustomersByStation(stationId);

      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCustomers = false;
      });
      log('Error loading customers: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customers: ${e.toString()}'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
    }
  }

  Future<void> _loadDeliveryGuys(int stationId) async {
    setState(() {
      _isLoadingDeliveryGuys = true;
      _selectedDeliveryGuyId = null;
    });

    try {
      final deliveryGuys = await ApiService.getStationDeliveryGuys(stationId);

      setState(() {
        _deliveryGuys = deliveryGuys;
        _isLoadingDeliveryGuys = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDeliveryGuys = false;
      });
      log('Error loading delivery guys: $e');

      if (deliveryType == 'Delivery') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load delivery guys: ${e.toString()}'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
      }
    }
  }

  void _calculateTotals() {
    totalAmount = saleItems.fold(0.0, (sum, item) => sum + item.totalAmount);
    setState(() {});
  }

  String? get selectedStationName {
    if (_selectedStationId == null) return null;
    final station = _stations.firstWhere(
      (s) => s.stationID == _selectedStationId,
      orElse: () => StationDto(stationID: 0, stationName: 'Unknown'),
    );
    return station.stationName;
  }

  String? get selectedCustomerName {
    if (_selectedCustomerId == null) return null;
    final customer = _customers.firstWhere(
      (c) => c.customerID == _selectedCustomerId,
      orElse: () => CustomerDto(
        customerID: 0,
        customerName: 'Unknown',
        balance: 0,
        // cylinderBalance: 0,
        // prepaidBalance: 0,
      ),
    );
    return customer.customerName;
  }

  String? get selectedDeliveryGuyName {
    if (_selectedDeliveryGuyId == null) return null;
    final deliveryGuy = _deliveryGuys.firstWhere(
      (d) => d.id == _selectedDeliveryGuyId,
      orElse: () => Driver(id: '', fullName: 'Unknown'),
    );
    return deliveryGuy.fullName;
  }

  void _onStationChanged(int? value) {
    if (value != null) {
      setState(() {
        _selectedStationId = value;
        _selectedDeliveryGuyId = null;
      });
      _loadCustomers(value);
      _loadDeliveryGuys(value);
    }
  }

  void _onDeliveryTypeChanged(String? value) {
    setState(() {
      deliveryType = value ?? 'Own Picking';
      if (deliveryType == 'Own Picking') {
        _selectedDeliveryGuyId = null;
      } else if (deliveryType == 'Delivery' &&
          _selectedStationId != null &&
          _deliveryGuys.isEmpty &&
          !_isLoadingDeliveryGuys) {
        // Load delivery guys if switching to delivery and not loaded yet
        _loadDeliveryGuys(_selectedStationId!);
      }
    });
  }

  // ... Keep all your existing scanner methods unchanged ...
  void _onScannerTextChanged(String value) {
    _scanBuffer = value;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scanBuffer == value && value.isNotEmpty) {
        _processScan(value.trim());
      }
    });
  }

  void _processScan(String barcode) {
    if (barcode.isEmpty || !_isScanning) return;

    final alreadyScanned = saleItems.any(
      (item) => item.isTagged && item.taggedBarcodes.contains(barcode),
    );

    if (alreadyScanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode $barcode already scanned'),
          backgroundColor: Colors.orange,
        ),
      );
      _resetScanner();
      return;
    }

    _showCylinderTypeForScan(barcode);
  }

  void _showCylinderTypeForScan(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Cylinder Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Barcode: $barcode',
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ...cylinderTypes.map(
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

  void _addScannedCylinder(String barcode, Map<String, dynamic> cylinderType) {
    setState(() {
      final existingIndex = saleItems.indexWhere(
        (item) => item.cylinderTypeId == cylinderType['id'] && item.isTagged,
      );

      if (existingIndex != -1) {
        saleItems[existingIndex].taggedBarcodes.add(barcode);
        saleItems[existingIndex].quantity =
            saleItems[existingIndex].taggedBarcodes.length;
        saleItems[existingIndex].amount =
            saleItems[existingIndex].price * saleItems[existingIndex].quantity;
      } else {
        final item = SaleItem(
          cylinderTypeId: cylinderType['id'],
          cylinderTypeName: cylinderType['name'],
          quantity: 1,
          price: (cylinderType['price'] as num).toDouble(),
          amount: (cylinderType['price'] as num).toDouble(),
          cylinderPrice: (cylinderType['cylinderPrice'] as num).toDouble(),
          cylinderAmount: 0.0,
          cylinderStatus: 'Refill',
          priceType: 'Retail',
          isTagged: true,
          taggedBarcodes: [barcode],
        );
        saleItems.add(item);
      }
      _calculateTotals();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${cylinderType['name']} - $barcode'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    _resetScanner();
  }

  void _resetScanner() {
    _scannerController.clear();
    _scanBuffer = '';
    if (_isScanning) {
      Future.delayed(const Duration(milliseconds: 50), () {
        FocusScope.of(context).requestFocus(_scannerFocusNode);
      });
    }
  }

  void _toggleScanning(bool enable) {
    setState(() {
      _isScanning = enable;
    });
    if (enable) {
      Future.delayed(const Duration(milliseconds: 100), () {
        FocusScope.of(context).requestFocus(_scannerFocusNode);
      });
    } else {
      _scannerFocusNode.unfocus();
    }
  }

  // ... Keep all your existing item management methods unchanged ...
  void _addSaleItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemSheet(
        cylinderTypes: cylinderTypes,
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
    final item = saleItems[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemSheet(
        cylinderTypes: cylinderTypes,
        existingItem: item,
        onItemAdded: (updatedItem) {
          setState(() {
            saleItems[index] = updatedItem;
            _calculateTotals();
          });
        },
      ),
    );
  }

  void _deleteSaleItem(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        saleItems.removeAt(index);
        _calculateTotals();
      });
    }
  }

  String _formatCurrency(num amount) {
    return 'KSh ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  void _showCustomerSelector() {
    if (_selectedStationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a station first'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
      return;
    }

    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No customers available for this station'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCustomerSelectorSheet(),
    );
  }

  Widget _buildCustomerSelectorSheet() {
    final TextEditingController searchController = TextEditingController();
    List<CustomerDto> filteredCustomers = _customers;

    return StatefulBuilder(
      builder: (context, setModalState) {
        void filterCustomers(String query) {
          setModalState(() {
            if (query.isEmpty) {
              filteredCustomers = _customers;
            } else {
              filteredCustomers = _customers
                  .where(
                    (customer) => customer.customerName.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
                  )
                  .toList();
            }
          });
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppTheme.primaryOrange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search Box
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              filterCustomers('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: filterCustomers,
                ),
              ),

              // Customer List
              Expanded(
                child: filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No customers found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          final isSelected =
                              _selectedCustomerId == customer.customerID;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected
                                ? AppTheme.primaryOrange.withOpacity(0.2)
                                : Colors.white.withOpacity(0.1),
                            child: ListTile(
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.person_outline,
                                color: isSelected
                                    ? AppTheme.primaryOrange
                                    : Colors.white,
                              ),
                              title: Text(
                                customer.customerName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: customer.customerPhone != null
                                  ? Text(
                                      customer.customerPhone!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              trailing: customer.hasBalance
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryOrange
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Bal: ${customer.balance.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: AppTheme.primaryOrange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedCustomerId = customer.customerID;
                                });
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveSale() async {
    if (_selectedStationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a station')));
      return;
    }

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    if (deliveryType == 'Delivery' && _selectedDeliveryGuyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery guy')),
      );
      return;
    }

    if (saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final taggedItemsWithoutScans = saleItems
        .where((item) => item.isTagged && item.taggedBarcodes.isEmpty)
        .toList();

    if (taggedItemsWithoutScans.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tagged items must have at least one scanned cylinder'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // TODO: Implement API call to save sale
      // final saleData = {
      //   'stationId': _selectedStationId,
      //   'customerId': _selectedCustomerId,
      //   'deliveryType': deliveryType,
      //   'deliveryGuyId': _selectedDeliveryGuyId,
      //   'items': saleItems.map((item) => item.toJson()).toList(),
      //   'totalAmount': totalAmount,
      // };
      // await ApiService.createSale(saleData);

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save sale: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      log('Error saving sale: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoadingStations) {
      return Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_circle_left,
                        color: Colors.white,
                      ),
                      onPressed: widget.onBack,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Add New Sale',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Error state
    if (_errorMessage != null && _stations.isEmpty) {
      return Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_circle_left,
                        color: Colors.white,
                      ),
                      onPressed: widget.onBack,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Add New Sale',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
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
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_circle_left,
                      color: Colors.white,
                    ),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Add New Sale',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Station Dropdown or Display
                    const Text(
                      'Station',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // If multiple stations, show dropdown
                    if (_stations.length > 1)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<int>(
                          value: _selectedStationId,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.warehouse,
                              color: AppTheme.primaryOrange,
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          hint: const Text(
                            'Select Station',
                            style: TextStyle(fontSize: 13),
                          ),
                          isExpanded: true,
                          items: _stations.map((station) {
                            return DropdownMenuItem<int>(
                              value: station.stationID,
                              child: Text(
                                station.stationName,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: _onStationChanged,
                        ),
                      )
                    // If single station, show display
                    else if (_stations.length == 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                          ),
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
                              Icons.warehouse,
                              color: AppTheme.primaryBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedStationName ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                      ),

                    const SizedBox(height: 10),

                    // Customer Selection
                    const Text(
                      'Customer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _selectedStationId == null || _isLoadingCustomers
                          ? null
                          : _showCustomerSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedStationId == null
                              ? Colors.grey.shade300
                              : Colors.white,
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
                              Icons.person,
                              color: _selectedStationId == null
                                  ? Colors.grey.shade600
                                  : AppTheme.primaryOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _isLoadingCustomers
                                  ? const Text(
                                      'Loading customers...',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    )
                                  : Text(
                                      _selectedStationId == null
                                          ? 'Select station first'
                                          : (selectedCustomerName ??
                                                'Select Customer'),
                                      style: TextStyle(
                                        color: _selectedStationId == null
                                            ? Colors.grey.shade600
                                            : (_selectedCustomerId != null
                                                  ? Colors.black87
                                                  : Colors.grey[600]),
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                            if (!_isLoadingCustomers &&
                                _selectedStationId != null)
                              Icon(
                                Icons.arrow_drop_down,
                                color: AppTheme.primaryBlue,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Delivery Type
                    const Text(
                      'Delivery Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: deliveryType,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.local_shipping,
                            color: AppTheme.primaryOrange,
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        isExpanded: true,
                        items: ['Own Picking', 'Delivery'].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: _onDeliveryTypeChanged,
                      ),
                    ),

                    // Delivery Guy Dropdown
                    if (deliveryType == 'Delivery') ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Delivery Guy',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color:
                              _selectedStationId == null ||
                                  _isLoadingDeliveryGuys
                              ? Colors.grey.shade300
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isLoadingDeliveryGuys
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
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
                                      'Loading delivery guys...',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedDeliveryGuyId,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.person_pin,
                                    color: _selectedStationId == null
                                        ? Colors.grey.shade600
                                        : AppTheme.primaryOrange,
                                    size: 18,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: _selectedStationId == null
                                      ? Colors.grey.shade300
                                      : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                hint: Text(
                                  _selectedStationId == null
                                      ? 'Select a station first'
                                      : (_deliveryGuys.isEmpty
                                            ? 'No delivery guys available'
                                            : 'Select Delivery Guy'),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                isExpanded: true,
                                items: _deliveryGuys.isEmpty
                                    ? null
                                    : _deliveryGuys.map((guy) {
                                        return DropdownMenuItem<String>(
                                          value: guy.id,
                                          child: Text(
                                            guy.fullName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                onChanged:
                                    _deliveryGuys.isEmpty ||
                                        _selectedStationId == null
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedDeliveryGuyId = value;
                                        });
                                      },
                              ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Sale Items Section
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
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Add Item',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Scanner Toggle
                    if (saleItems.any((item) => item.isTagged)) ...[
                      ScannerToggle(
                        isScanning: _isScanning,
                        onToggle: _toggleScanning,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Sale Items List
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
                      ...saleItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Dismissible(
                          key: Key('sale_item_$index'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Item'),
                                content: const Text(
                                  'Are you sure you want to delete this item?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            setState(() {
                              saleItems.removeAt(index);
                              _calculateTotals();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Item deleted'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
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
                            onTap: () => _editSaleItem(index),
                            child: SaleItemCard(
                              item: item,
                              onEdit: () => _editSaleItem(index),
                              onDelete: () => _deleteSaleItem(index),
                              onBarcodeDeleted: (barcode) {
                                setState(() {
                                  item.taggedBarcodes.remove(barcode);
                                  item.quantity = item.taggedBarcodes.length;
                                  item.amount = item.price * item.quantity;
                                  _calculateTotals();
                                });
                              },
                              formatCurrency: _formatCurrency,
                              hideActions: true,
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 20),

                    // Total Summary
                    if (saleItems.isNotEmpty)
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
                            const Text(
                              'Total Amount:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatCurrency(totalAmount),
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
                ),
              ),
            ),

            // Submit Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
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
                      : const Text(
                          'Submit Sale',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),

        // Hidden Scanner Input
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
}
