import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpg_station/theme/theme.dart';

class AddSale extends StatefulWidget {
  final VoidCallback onBack;
  const AddSale({super.key, required this.onBack});

  @override
  State<AddSale> createState() => _AddSaleState();
}

class _AddSaleState extends State<AddSale> {
  // Form Controllers
  final _formKey = GlobalKey<FormState>();

  // Selection States
  String? selectedStation;
  String? selectedCustomer;
  String deliveryType = 'Own Picking'; // Own Picking or Delivery
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
      'name': '26KG',
      'capacity': 26,
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
      // Reset delivery guy if station changes
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

  void _addSaleItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddItemSheet(),
    );
  }

  void _editSaleItem(int index) {
    final item = saleItems[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _buildAddItemSheet(existingItem: item, itemIndex: index),
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

  // Handle barcode scan
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

    // Check if already scanned
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

    // TODO: Validate barcode with backend and get cylinder type
    // For now, show dialog to select cylinder type
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
      // Find existing item of same type
      final existingIndex = saleItems.indexWhere(
        (item) => item.cylinderTypeId == cylinderType['id'] && item.isTagged,
      );

      if (existingIndex != -1) {
        // Add to existing tagged item
        saleItems[existingIndex].taggedBarcodes.add(barcode);
        saleItems[existingIndex].quantity =
            saleItems[existingIndex].taggedBarcodes.length;
        saleItems[existingIndex].amount =
            saleItems[existingIndex].price * saleItems[existingIndex].quantity;
      } else {
        // Create new tagged item
        final item = SaleItem(
          cylinderTypeId: cylinderType['id'],
          cylinderTypeName: cylinderType['name'],
          quantity: 1,
          price: (cylinderType['price'] as num).toDouble(),
          amount: (cylinderType['price'] as num).toDouble(),
          cylinderPrice: (cylinderType['cylinderPrice'] as num).toDouble(),
          cylinderAmount: 0.0,
          cylinderStatus: 'Lease',
          priceType: 'Standard',
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

  Widget _buildAddItemSheet({SaleItem? existingItem, int? itemIndex}) {
    int? selectedCylinderTypeId = existingItem?.cylinderTypeId;
    int quantity = existingItem?.quantity ?? 1;
    double price = existingItem?.price ?? 0.0;
    double cylinderPrice = existingItem?.cylinderPrice ?? 0.0;
    double cylinderAmount = existingItem?.cylinderAmount ?? 0.0;
    String cylinderStatus = existingItem?.cylinderStatus ?? 'Lease';
    String priceType = existingItem?.priceType ?? 'Standard';
    bool isTagged = existingItem?.isTagged ?? false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        final selectedType = cylinderTypes.firstWhere(
          (type) => type['id'] == selectedCylinderTypeId,
          orElse: () => {},
        );

        if (selectedCylinderTypeId != null && price == 0.0) {
          price = (selectedType['price'] as num).toDouble();
          cylinderPrice = (selectedType['cylinderPrice'] as num).toDouble();
        }

        final double itemAmount = price * quantity;
        final double totalItemCost = itemAmount + cylinderAmount;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: const BorderRadius.only(
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
                    Icon(
                      Icons.add_shopping_cart,
                      color: AppTheme.primaryOrange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        existingItem != null ? 'Edit Item' : 'Add Item',
                        style: const TextStyle(
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

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tagged/Non-Tagged Selection
                      const Text(
                        'Cylinder Type',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTagTypeChip(
                              'Non-Tagged',
                              !isTagged,
                              () => setModalState(() => isTagged = false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTagTypeChip('Tagged', isTagged, () {
                              if (existingItem != null &&
                                  existingItem.isTagged) {
                                // Cannot change tagged items to non-tagged if they have scanned barcodes
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Cannot change tagged items with scanned cylinders',
                                    ),
                                  ),
                                );
                              } else {
                                setModalState(() => isTagged = true);
                              }
                            }),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Cylinder Type Selection
                      const Text(
                        'Select Cylinder',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cylinderTypes.map((type) {
                          final isSelected =
                              selectedCylinderTypeId == type['id'];
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedCylinderTypeId = type['id'];
                                price = (type['price'] as num).toDouble();
                                cylinderPrice = (type['cylinderPrice'] as num)
                                    .toDouble();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryOrange
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryOrange
                                      : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                type['name'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Quantity (only for non-tagged)
                      if (!isTagged) ...[
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (quantity > 1) {
                                  setModalState(() => quantity--);
                                }
                              },
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.white,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  quantity.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setModalState(() => quantity++);
                              },
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Tagged cylinders info
                      if (isTagged) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primaryOrange),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.primaryOrange,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Tagged cylinders will be scanned individually',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Price Type
                      const Text(
                        'Price Type',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriceTypeChip(
                              'Standard',
                              priceType == 'Standard',
                              () => setModalState(() {
                                priceType = 'Standard';
                                if (selectedType.isNotEmpty) {
                                  price = (selectedType['price'] as num)
                                      .toDouble();
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPriceTypeChip(
                              'Custom',
                              priceType == 'Custom',
                              () => setModalState(() => priceType = 'Custom'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Price
                      const Text(
                        'Price per Unit',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: price.toString(),
                        enabled: priceType == 'Custom',
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          prefixText: 'KSh ',
                          prefixStyle: const TextStyle(color: Colors.white70),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            price = double.tryParse(value) ?? 0.0;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // Cylinder Status
                      const Text(
                        'Cylinder Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusChip(
                              'Lease',
                              cylinderStatus == 'Lease',
                              () => setModalState(() {
                                cylinderStatus = 'Lease';
                                cylinderAmount = 0.0;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusChip(
                              'Sale',
                              cylinderStatus == 'Sale',
                              () => setModalState(() {
                                cylinderStatus = 'Sale';
                                cylinderAmount = cylinderPrice * quantity;
                              }),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Summary
                      if (!isTagged)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow('Gas Amount:', itemAmount),
                              if (cylinderStatus == 'Sale')
                                _buildSummaryRow(
                                  'Cylinder Amount:',
                                  cylinderAmount,
                                ),
                              const Divider(color: Colors.white24, height: 20),
                              _buildSummaryRow(
                                'Total:',
                                totalItemCost,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Add/Update Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCylinderTypeId == null
                        ? null
                        : () {
                            final item = SaleItem(
                              cylinderTypeId: selectedCylinderTypeId!,
                              cylinderTypeName: selectedType['name'],
                              quantity: isTagged ? 0 : quantity,
                              price: price,
                              amount: isTagged ? 0.0 : itemAmount,
                              cylinderPrice: cylinderPrice,
                              cylinderAmount: isTagged ? 0.0 : cylinderAmount,
                              cylinderStatus: cylinderStatus,
                              priceType: priceType,
                              isTagged: isTagged,
                              taggedBarcodes:
                                  existingItem?.taggedBarcodes ?? [],
                            );

                            setState(() {
                              if (existingItem != null && itemIndex != null) {
                                saleItems[itemIndex] = item;
                              } else {
                                saleItems.add(item);
                              }
                              _calculateTotals();
                            });

                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      existingItem != null ? 'Update Item' : 'Add Item',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagTypeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceTypeChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              color: isTotal ? AppTheme.primaryOrange : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(num amount) {
    return 'KSh ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  void _showCustomerSelector() {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredCustomers = customers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterCustomers(String query) {
              setModalState(() {
                if (query.isEmpty) {
                  filteredCustomers = customers;
                } else {
                  filteredCustomers = customers
                      .where(
                        (customer) => customer.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList();
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: const BorderRadius.only(
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
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final isSelected = selectedCustomer == customer;

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
                              customer,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                selectedCustomer = customer;
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
      },
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

    // Check if tagged items have scanned cylinders
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

    // TODO: Implement API call to save sale
    // Payload should include:
    // - selectedStation
    // - selectedCustomer
    // - deliveryType
    // - selectedDeliveryGuy (if delivery)
    // - saleItems with tagged barcodes

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sale saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Go back to list
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    int? selectedCylinderTypeId = existingItem?.cylinderTypeId;
    int quantity = existingItem?.quantity ?? 1;
    double price = existingItem?.price ?? 0.0;
    double cylinderPrice = existingItem?.cylinderPrice ?? 0.0;
    double cylinderAmount = existingItem?.cylinderAmount ?? 0.0;
    String cylinderStatus = existingItem?.cylinderStatus ?? 'Lease';
    String priceType = existingItem?.priceType ?? 'Standard';

    return StatefulBuilder(
      builder: (context, setModalState) {
        final selectedType = cylinderTypes.firstWhere(
          (type) => type['id'] == selectedCylinderTypeId,
          orElse: () => {},
        );

        if (selectedCylinderTypeId != null && price == 0.0) {
          price = (selectedType['price'] as num).toDouble();
          cylinderPrice = (selectedType['cylinderPrice'] as num).toDouble();
        }

        final double itemAmount = price * quantity;
        final double totalItemCost = itemAmount + cylinderAmount;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: const BorderRadius.only(
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
                    Icon(
                      Icons.add_shopping_cart,
                      color: AppTheme.primaryOrange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        existingItem != null ? 'Edit Item' : 'Add Item',
                        style: const TextStyle(
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

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cylinder Type Selection
                      const Text(
                        'Cylinder Type',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: cylinderTypes.map((type) {
                          final isSelected =
                              selectedCylinderTypeId == type['id'];
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedCylinderTypeId = type['id'];
                                price = (type['price'] as num).toDouble();
                                cylinderPrice = (type['cylinderPrice'] as num)
                                    .toDouble();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryOrange
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryOrange
                                      : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                type['name'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Quantity
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (quantity > 1) {
                                setModalState(() => quantity--);
                              }
                            },
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                quantity.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(() => quantity++);
                            },
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Price Type
                      const Text(
                        'Price Type',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriceTypeChip(
                              'Standard',
                              priceType == 'Standard',
                              () => setModalState(() {
                                priceType = 'Standard';
                                if (selectedType.isNotEmpty) {
                                  price = (selectedType['price'] as num)
                                      .toDouble();
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildPriceTypeChip(
                              'Custom',
                              priceType == 'Custom',
                              () => setModalState(() => priceType = 'Custom'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Price
                      const Text(
                        'Price per Unit',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: price.toString(),
                        enabled: priceType == 'Custom',
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          prefixText: 'KSh ',
                          prefixStyle: const TextStyle(color: Colors.white70),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            price = double.tryParse(value) ?? 0.0;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // Cylinder Status
                      const Text(
                        'Cylinder Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusChip(
                              'Lease',
                              cylinderStatus == 'Lease',
                              () => setModalState(() {
                                cylinderStatus = 'Lease';
                                cylinderAmount = 0.0;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusChip(
                              'Sale',
                              cylinderStatus == 'Sale',
                              () => setModalState(() {
                                cylinderStatus = 'Sale';
                                cylinderAmount = cylinderPrice * quantity;
                              }),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Gas Amount:', itemAmount),
                            if (cylinderStatus == 'Sale')
                              _buildSummaryRow(
                                'Cylinder Amount:',
                                cylinderAmount,
                              ),
                            const Divider(color: Colors.white24, height: 20),
                            _buildSummaryRow(
                              'Total:',
                              totalItemCost,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add/Update Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCylinderTypeId == null
                        ? null
                        : () {
                            final item = SaleItem(
                              cylinderTypeId: selectedCylinderTypeId!,
                              cylinderTypeName: selectedType['name'],
                              quantity: quantity,
                              price: price,
                              amount: itemAmount,
                              cylinderPrice: cylinderPrice,
                              cylinderAmount: cylinderAmount,
                              cylinderStatus: cylinderStatus,
                              priceType: priceType,
                            );

                            setState(() {
                              if (existingItem != null && itemIndex != null) {
                                saleItems[itemIndex] = item;
                              } else {
                                saleItems.add(item);
                              }
                              _calculateTotals();
                            });

                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      existingItem != null ? 'Update Item' : 'Add Item',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceTypeChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.white24,
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              color: isTotal ? AppTheme.primaryOrange : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(num amount) {
    return 'KSh ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  void _showCustomerSelector() {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredCustomers = customers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterCustomers(String query) {
              setModalState(() {
                if (query.isEmpty) {
                  filteredCustomers = customers;
                } else {
                  filteredCustomers = customers
                      .where(
                        (customer) => customer.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList();
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: const BorderRadius.only(
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
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final isSelected = selectedCustomer == customer;

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
                              customer,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                selectedCustomer = customer;
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
      },
    );
  }

  void _saveSale() async {
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }

    if (saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    // TODO: Implement API call to save sale
    // For now, just show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sale saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Go back to list
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              const Text(
                'Add New Sale',
                style: TextStyle(
                  fontSize: 18,
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
                // Customer Selection
                const Text(
                  'Customer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _showCustomerSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                        Icon(Icons.person, color: AppTheme.primaryOrange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedCustomer ?? 'Select Customer',
                            style: TextStyle(
                              color: selectedCustomer != null
                                  ? Colors.black87
                                  : Colors.grey[600],
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Sale Items Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addSaleItem,
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      label: const Text(
                        'Add Item',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white.withOpacity(0.1),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.cylinderTypeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          'Qty: ${item.quantity} × ${_formatCurrency(item.price)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          item.cylinderStatus,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatCurrency(
                                item.amount + item.cylinderAmount,
                              ),
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: () => _editSaleItem(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSaleItem(index),
                            ),
                          ],
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
                    child: Column(
                      children: [
                        Row(
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
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Save Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Sale',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
