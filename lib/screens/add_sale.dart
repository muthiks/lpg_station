import 'package:flutter/material.dart';
import 'package:lpg_station/models/sale_item.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/customer_selector.dart';
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
  // Selection States
  String? selectedStation;
  String? selectedCustomer;
  String deliveryType = 'Own Picking';
  String? selectedDeliveryGuy;

  // Sale Items
  List<SaleItem> saleItems = [];

  // Totals
  double totalAmount = 0.0;

  // Scanner
  final FocusNode _scannerFocusNode = FocusNode();
  final TextEditingController _scannerController = TextEditingController();
  String _scanBuffer = '';
  bool _isScanning = false;

  // Sample Data - Replace with API calls
  final List<String> stations = ['Station 1', 'Station 2', 'Station 3'];

  final List<String> customers = [
    'JAMWAS BEAUTY SHOP- CBD',
    'CAFE CASSIA',
    'HABESHA KILIMANI',
  ];

  // Delivery guys per station
  final Map<String, List<String>> deliveryGuysByStation = {
    'Station 1': ['John Doe', 'Jane Smith', 'Mike Johnson'],
    'Station 2': ['Alice Brown', 'Bob Wilson', 'Charlie Davis'],
    'Station 3': ['David Lee', 'Emma White', 'Frank Miller'],
  };

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
    _calculateTotals();
  }

  @override
  void dispose() {
    _scannerFocusNode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _calculateTotals() {
    totalAmount = saleItems.fold(0.0, (sum, item) => sum + item.totalAmount);
    setState(() {});
  }

  List<String> get availableDeliveryGuys {
    if (selectedStation == null) return [];
    return deliveryGuysByStation[selectedStation] ?? [];
  }

  void _onStationChanged(String? value) {
    setState(() {
      selectedStation = value;
      if (deliveryType == 'Delivery') {
        selectedDeliveryGuy = null;
      }
    });
  }

  void _onDeliveryTypeChanged(String? value) {
    setState(() {
      deliveryType = value ?? 'Own Picking';
      if (deliveryType == 'Own Picking') {
        selectedDeliveryGuy = null;
      }
    });
  }

  // Scanner Methods
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

  // Item Management
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerSelectorSheet(
        customers: customers,
        selectedCustomer: selectedCustomer,
        onCustomerSelected: (customer) {
          setState(() {
            selectedCustomer = customer;
          });
        },
      ),
    );
  }

  void _saveSale() async {
    if (selectedStation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a station')));
      return;
    }

    if (selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    if (deliveryType == 'Delivery' && selectedDeliveryGuy == null) {
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

    // TODO: Implement API call

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sale saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              //  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
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
                    // Station Dropdown
                    const Text(
                      'Station',
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
                        initialValue: selectedStation,
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
                        items: stations.map((station) {
                          return DropdownMenuItem(
                            value: station,
                            child: Text(
                              station,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: _onStationChanged,
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
                      onTap: _showCustomerSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
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
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: AppTheme.primaryOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedCustomer ?? 'Select Customer',
                                style: TextStyle(
                                  color: selectedCustomer != null
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                        initialValue: deliveryType,
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

                    // Conditional Delivery Guy Dropdown
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
                          initialValue: selectedDeliveryGuy,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.person_pin,
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
                          hint: Text(
                            availableDeliveryGuys.isEmpty
                                ? 'Select a station first'
                                : 'Select Delivery Guy',
                            style: const TextStyle(fontSize: 13),
                          ),
                          isExpanded: true,
                          items: availableDeliveryGuys.map((guy) {
                            return DropdownMenuItem(
                              value: guy,
                              child: Text(
                                guy,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: availableDeliveryGuys.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    selectedDeliveryGuy = value;
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
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSale,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
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
