import 'package:flutter/material.dart';
import 'package:lpg_station/models/sale_item.dart';
import 'package:lpg_station/theme/theme.dart';

class SaleItemCard extends StatelessWidget {
  final SaleItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String) onBarcodeDeleted;
  final String Function(num) formatCurrency;
  final bool hideActions;

  const SaleItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onBarcodeDeleted,
    required this.formatCurrency,
    this.hideActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAccessoryOnly = item.cylinderTypeName == 'Accessory Only';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withOpacity(0.1),
      child: Column(
        children: [
          // Cylinder item display
          if (!isAccessoryOnly)
            ListTile(
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
                item.isTagged
                    ? 'Tagged (${item.taggedBarcodes.length} scanned)'
                    : 'Qty: ${item.quantity} × ${formatCurrency(item.price)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              subtitle: Row(
                children: [
                  Text(
                    item.cylinderStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (item.isTagged) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'TAGGED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: hideActions
                  ? Text(
                      formatCurrency(item.totalAmount),
                      style: TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatCurrency(item.totalAmount),
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
            ),

          // Accessory-only item display
          if (isAccessoryOnly && item.hasAccessories)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.build_circle, color: Colors.white, size: 18),
              ),
              title: Text(
                item.accessoryName ?? 'Accessory',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Qty: ${item.accessoryQuantity} × ${formatCurrency(item.accessoryPrice ?? 0)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              trailing: hideActions
                  ? Text(
                      formatCurrency(item.totalAmount),
                      style: TextStyle(
                        color: AppTheme.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatCurrency(item.totalAmount),
                          style: TextStyle(
                            color: AppTheme.primaryOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
            ),

          // Show scanned barcodes for tagged items
          if (item.isTagged && item.taggedBarcodes.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: item.taggedBarcodes.map((barcode) {
                  return Chip(
                    label: Text(
                      barcode,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor: AppTheme.primaryBlue,
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onDeleted: () => onBarcodeDeleted(barcode),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
