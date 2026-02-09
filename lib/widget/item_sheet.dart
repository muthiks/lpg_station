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
  bool isTagged = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      selectedCylinderTypeId = item.cylinderTypeId;
      quantity = item.quantity;
      price = item.price;
      cylinderPrice = item.cylinderPrice;
      cylinderAmount = item.cylinderAmount;
      cylinderStatus = item.cylinderStatus;
      priceType = item.priceType;
      isTagged = item.isTagged;
    }
  }

  Map<String, dynamic> get selectedType {
    return widget.cylinderTypes.firstWhere(
      (type) => type['id'] == selectedCylinderTypeId,
      orElse: () => {},
    );
  }

  String _formatCurrency(num amount) {
    return 'KSh ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tagged/Non-Tagged
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
                        child: _buildChip(
                          'Non-Tagged',
                          !isTagged,
                          () => setState(() => isTagged = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          'Tagged',
                          isTagged,
                          () => setState(() => isTagged = true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Cylinder Selection
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
                    children: widget.cylinderTypes.map((type) {
                      final isSelected = selectedCylinderTypeId == type['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCylinderTypeId = type['id'];
                            price = (type['price'] as num).toDouble();
                            cylinderPrice = (type['cylinderPrice'] as num)
                                .toDouble();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
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
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Tagged info
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
                        child: _buildChip(
                          'Retail',
                          priceType == 'Retail',
                          () => setState(() {
                            priceType = 'Retail';
                            if (selectedType.isNotEmpty) {
                              price = (selectedType['price'] as num).toDouble();
                            }
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          'Custom',
                          priceType == 'Custom',
                          () => setState(() => priceType = 'Custom'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildChip(
                          'KG',
                          priceType == 'KG',
                          () => setState(() => priceType = 'KG'),
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
                    enabled: priceType == 'Custom' || priceType == 'KG',
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixText: 'KSh ',
                      prefixStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
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
                          const Divider(color: Colors.white24, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatCurrency(totalItemCost),
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontSize: 15,
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
                              widget.existingItem?.taggedBarcodes ?? [],
                        );

                        widget.onItemAdded(item);
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
                  widget.existingItem != null ? 'Update Item' : 'Add Item',
                  style: const TextStyle(
                    fontSize: 14,
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
