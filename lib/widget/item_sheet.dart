import 'package:flutter/material.dart';
import 'package:lpg_station/models/sale_item.dart';
import 'package:lpg_station/theme/theme.dart';

class AddItemSheet extends StatefulWidget {
  final List<Map<String, dynamic>> cylinderTypes;
  final SaleItem? existingItem;
  final Function(SaleItem) onItemAdded;

  const AddItemSheet({
    super.key,
    required this.cylinderTypes,
    required this.onItemAdded,
    this.existingItem,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  int? selectedCylinderTypeId;
  int quantity = 1;
  double price = 0.0;
  double cylinderPrice = 0.0;
  double cylinderAmount = 0.0;
  String cylinderStatus = 'Refill';
  String priceType = 'Retail';

  // Accessories
  bool includeAccessories = false;
  String? selectedAccessoryId;
  int accessoryQuantity = 1;
  double accessoryPrice = 0.0;
  String accessoryPriceType = 'Retail';

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _accessoryPriceController =
      TextEditingController();

  // Sample accessories data - Replace with API
  final List<Map<String, dynamic>> accessories = [
    {'id': 'acc_1', 'name': 'Gas Hose', 'price': 500.0},
    {'id': 'acc_2', 'name': 'Regulator', 'price': 1200.0},
    {'id': 'acc_3', 'name': 'Gas Lighter', 'price': 150.0},
    {'id': 'acc_4', 'name': 'Pipe Clips', 'price': 50.0},
    {'id': 'acc_5', 'name': 'Burner Head', 'price': 800.0},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;

      // Only load cylinder data if it's not an accessory-only item
      if (item.cylinderTypeName != 'Accessory Only') {
        selectedCylinderTypeId = item.cylinderTypeId;
        quantity = item.quantity;
        price = item.price;
        cylinderPrice = item.cylinderPrice;
        cylinderAmount = item.cylinderAmount;
        cylinderStatus = item.cylinderStatus;
        priceType = item.priceType;
      }

      // Load accessory data if present
      if (item.hasAccessories) {
        includeAccessories = true;
        selectedAccessoryId = item.accessoryId;
        accessoryQuantity = item.accessoryQuantity ?? 1;
        accessoryPrice = item.accessoryPrice ?? 0.0;
        accessoryPriceType = item.accessoryPriceType ?? 'Retail';
      }
    }
    _priceController.text = price > 0 ? price.toString() : '';
    _accessoryPriceController.text = accessoryPrice > 0
        ? accessoryPrice.toString()
        : '';
  }

  @override
  void dispose() {
    _priceController.dispose();
    _accessoryPriceController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get selectedType {
    return widget.cylinderTypes.firstWhere(
      (type) => type['id'] == selectedCylinderTypeId,
      orElse: () => {},
    );
  }

  Map<String, dynamic> get selectedAccessory {
    return accessories.firstWhere(
      (acc) => acc['id'] == selectedAccessoryId,
      orElse: () => {},
    );
  }

  String _formatCurrency(num amount) {
    return 'KSh ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  void _onPriceTypeChanged(String newPriceType) {
    setState(() {
      priceType = newPriceType;

      if (priceType == 'Retail') {
        // Set to retail price and make readonly
        if (selectedType.isNotEmpty) {
          price = (selectedType['price'] as num).toDouble();
          _priceController.text = price.toString();
        }
      } else {
        // Clear the textbox for Custom/KG
        price = 0.0;
        _priceController.text = '';
      }
    });
  }

  void _onAccessoryPriceTypeChanged(String newPriceType) {
    setState(() {
      accessoryPriceType = newPriceType;

      if (accessoryPriceType == 'Retail') {
        if (selectedAccessory.isNotEmpty) {
          accessoryPrice = (selectedAccessory['price'] as num).toDouble();
          _accessoryPriceController.text = accessoryPrice.toString();
        }
      } else {
        accessoryPrice = 0.0;
        _accessoryPriceController.text = '';
      }
    });
  }

  void _showAccessorySelector() {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredAccessories = accessories;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterAccessories(String query) {
              setModalState(() {
                if (query.isEmpty) {
                  filteredAccessories = accessories;
                } else {
                  filteredAccessories = accessories
                      .where(
                        (acc) => acc['name'].toLowerCase().contains(
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
                        Icon(Icons.build_circle, color: AppTheme.primaryOrange),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Select Accessory',
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
                        hintText: 'Search accessories...',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  filterAccessories('');
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
                      onChanged: filterAccessories,
                    ),
                  ),

                  // Accessory List
                  Expanded(
                    child: filteredAccessories.isEmpty
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
                                  'No accessories found',
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
                            itemCount: filteredAccessories.length,
                            itemBuilder: (context, index) {
                              final accessory = filteredAccessories[index];
                              final isSelected =
                                  selectedAccessoryId == accessory['id'];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: isSelected
                                    ? AppTheme.primaryOrange.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.1),
                                child: ListTile(
                                  leading: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.build_circle_outlined,
                                    color: isSelected
                                        ? AppTheme.primaryOrange
                                        : Colors.white,
                                  ),
                                  title: Text(
                                    accessory['name'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: Text(
                                    _formatCurrency(accessory['price']),
                                    style: TextStyle(
                                      color: AppTheme.primaryOrange,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      selectedAccessoryId = accessory['id'];
                                      if (accessoryPriceType == 'Retail') {
                                        accessoryPrice =
                                            (accessory['price'] as num)
                                                .toDouble();
                                        _accessoryPriceController.text =
                                            accessoryPrice.toString();
                                      }
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

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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

  @override
  Widget build(BuildContext context) {
    if (selectedCylinderTypeId != null && price == 0.0) {
      price = (selectedType['price'] as num?)?.toDouble() ?? 0.0;
      cylinderPrice =
          (selectedType['cylinderPrice'] as num?)?.toDouble() ?? 0.0;
    }

    // Calculate item amount based on price type
    final double itemAmount;
    if (priceType == 'KG' && selectedType.isNotEmpty) {
      // For KG: price per unit * quantity * cylinder capacity
      final int capacity = (selectedType['capacity'] as num?)?.toInt() ?? 0;
      itemAmount = price * quantity * capacity;
    } else {
      // For Retail and Custom: price per unit * quantity
      itemAmount = price * quantity;
    }

    // Calculate accessories amount
    final double accessoriesAmount = includeAccessories
        ? (accessoryPrice * accessoryQuantity)
        : 0.0;

    final double totalItemCost =
        itemAmount + cylinderAmount + accessoriesAmount;

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
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
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.add_shopping_cart, color: AppTheme.primaryOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.existingItem != null ? 'Edit Item' : 'Add Item',
                    style: const TextStyle(
                      fontSize: 15,
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cylinder Selection
                  Row(
                    children: [
                      const Text(
                        'Select Cylinder',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Optional',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.cylinderTypes.map((type) {
                      final isSelected = selectedCylinderTypeId == type['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCylinderTypeId = type['id'];
                            price = (type['price'] as num).toDouble();
                            cylinderPrice = (type['cylinderPrice'] as num)
                                .toDouble();
                            if (priceType == 'Retail') {
                              _priceController.text = price.toString();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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

                  const SizedBox(height: 16),

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
                            setState(() => quantity--);
                          }
                        },
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
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
                          setState(() => quantity++);
                        },
                        icon: const Icon(Icons.add_circle, color: Colors.white),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

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
                        child: _buildChip(
                          'Retail',
                          priceType == 'Retail',
                          () => _onPriceTypeChanged('Retail'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          'Custom',
                          priceType == 'Custom',
                          () => _onPriceTypeChanged('Custom'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          'KG',
                          priceType == 'KG',
                          () => _onPriceTypeChanged('KG'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

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
                    controller: _priceController,
                    readOnly: priceType == 'Retail',
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: priceType == 'Retail'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: priceType == 'Retail'
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixText: 'KSh ',
                      prefixStyle: const TextStyle(color: Colors.white70),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        price = double.tryParse(value) ?? 0.0;
                      });
                    },
                  ),

                  // KG calculation helper text
                  if (priceType == 'KG' && selectedType.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppTheme.primaryOrange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Amount = Price/KG × Qty × ${selectedType['capacity']}KG',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

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
                        child: _buildChip(
                          'Refill',
                          cylinderStatus == 'Refill',
                          () => setState(() {
                            cylinderStatus = 'Refill';
                            cylinderAmount = 0.0;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          'Complete',
                          cylinderStatus == 'Complete',
                          () => setState(() {
                            cylinderStatus = 'Complete';
                            cylinderAmount = cylinderPrice * quantity;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          'Lease',
                          cylinderStatus == 'Lease',
                          () => setState(() {
                            cylinderStatus = 'Lease';
                            cylinderAmount = 0.0;
                          }),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Accessories Toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: includeAccessories
                            ? AppTheme.primaryOrange
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.build_circle,
                              color: includeAccessories
                                  ? AppTheme.primaryOrange
                                  : Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Add Accessories',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: includeAccessories,
                          onChanged: (value) {
                            setState(() {
                              includeAccessories = value;
                              if (!value) {
                                // Reset accessories when toggle is off
                                selectedAccessoryId = null;
                                accessoryQuantity = 1;
                                accessoryPrice = 0.0;
                                accessoryPriceType = 'Retail';
                                _accessoryPriceController.clear();
                              }
                            });
                          },
                          activeColor: AppTheme.primaryOrange,
                        ),
                      ],
                    ),
                  ),

                  // Accessories Section
                  if (includeAccessories) ...[
                    const SizedBox(height: 16),

                    // Accessory Selection
                    const Text(
                      'Select Accessory',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showAccessorySelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
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
                              Icons.build_circle,
                              color: AppTheme.primaryOrange,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedAccessoryId != null &&
                                        selectedAccessory.isNotEmpty
                                    ? selectedAccessory['name']
                                    : 'Select Accessory',
                                style: TextStyle(
                                  color: selectedAccessoryId != null
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.primaryBlue,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Accessory Quantity
                    const Text(
                      'Accessory Quantity',
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
                            if (accessoryQuantity > 1) {
                              setState(() => accessoryQuantity--);
                            }
                          },
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              accessoryQuantity.toString(),
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
                            setState(() => accessoryQuantity++);
                          },
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Accessory Price Type (Retail/Custom only, no KG)
                    const Text(
                      'Accessory Price Type',
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
                          child: _buildChip(
                            'Retail',
                            accessoryPriceType == 'Retail',
                            () => _onAccessoryPriceTypeChanged('Retail'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildChip(
                            'Custom',
                            accessoryPriceType == 'Custom',
                            () => _onAccessoryPriceTypeChanged('Custom'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Accessory Price
                    const Text(
                      'Accessory Price per Unit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accessoryPriceController,
                      readOnly: accessoryPriceType == 'Retail',
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: accessoryPriceType == 'Retail'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: accessoryPriceType == 'Retail'
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixText: 'KSh ',
                        prefixStyle: const TextStyle(color: Colors.white70),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          accessoryPrice = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Gas Amount:',
                              style: TextStyle(color: Colors.white),
                            ),
                            Text(
                              _formatCurrency(itemAmount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (cylinderStatus == 'Complete') ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cylinder Amount:',
                                style: TextStyle(color: Colors.white),
                              ),
                              Text(
                                _formatCurrency(cylinderAmount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (includeAccessories && accessoriesAmount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Accessories:',
                                style: TextStyle(color: Colors.white),
                              ),
                              Text(
                                _formatCurrency(accessoriesAmount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(color: Colors.white24, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatCurrency(totalItemCost),
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontSize: 18,
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

          // Add Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Enable button if either cylinder OR accessory is selected
                  final hasCylinder = selectedCylinderTypeId != null;
                  final hasAccessory =
                      includeAccessories && selectedAccessoryId != null;

                  if (!hasCylinder && !hasAccessory) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select at least a cylinder or an accessory',
                        ),
                      ),
                    );
                    return;
                  }

                  // Add cylinder item if selected
                  if (hasCylinder) {
                    final cylinderItem = SaleItem(
                      cylinderTypeId: selectedCylinderTypeId!,
                      cylinderTypeName: selectedType['name'],
                      quantity: quantity,
                      price: price,
                      amount: itemAmount,
                      cylinderPrice: cylinderPrice,
                      cylinderAmount: cylinderAmount,
                      cylinderStatus: cylinderStatus,
                      priceType: priceType,
                      isTagged: false,
                      taggedBarcodes: [],
                      accessoryId: null,
                      accessoryName: null,
                      accessoryQuantity: null,
                      accessoryPrice: null,
                      accessoryAmount: null,
                      accessoryPriceType: null,
                    );
                    widget.onItemAdded(cylinderItem);
                  }

                  // Add accessory as separate item if selected
                  if (hasAccessory) {
                    final accessoryItem = SaleItem(
                      cylinderTypeId: 0,
                      cylinderTypeName: 'Accessory Only',
                      quantity: 0,
                      price: 0.0,
                      amount: 0.0,
                      cylinderPrice: 0.0,
                      cylinderAmount: 0.0,
                      cylinderStatus: 'N/A',
                      priceType: 'N/A',
                      isTagged: false,
                      taggedBarcodes: [],
                      accessoryId: selectedAccessoryId,
                      accessoryName: selectedAccessory['name'],
                      accessoryQuantity: accessoryQuantity,
                      accessoryPrice: accessoryPrice,
                      accessoryAmount: accessoriesAmount,
                      accessoryPriceType: accessoryPriceType,
                    );
                    widget.onItemAdded(accessoryItem);
                  }

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.existingItem != null ? 'Update Item' : 'Add Item',
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
  }
}
