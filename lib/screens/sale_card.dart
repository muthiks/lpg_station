import 'package:flutter/material.dart';
import 'package:lpg_station/theme/theme.dart';

class SaleCard extends StatefulWidget {
  final Map<String, dynamic> sale;

  const SaleCard({super.key, required this.sale});

  @override
  State<SaleCard> createState() => _SaleCardState();
}

class _SaleCardState extends State<SaleCard> {
  bool _isExpanded = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return AppTheme.primaryBlue;
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.amber;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCurrency(num amount) {
    return 'KSh ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final saleDetails = widget.sale['SaleDetails'] as List<dynamic>;
    final status = widget.sale['Status'] as String;
    final customerName = widget.sale['CustomerName'] as String;
    final invoiceNo = widget.sale['InvoiceNo'] as String;
    final saleDate = widget.sale['SaleDate'] as String;
    final total = widget.sale['Total'] as num;
    final balance = widget.sale['Balance'] as num;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Column(
          children: [
            // Header Section - Customer Name & Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
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

            // Body Section - Invoice, Date, Total
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Invoice Number
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          invoiceNo,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Date and Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(saleDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatCurrency(total),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Toggle Items Button
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  border: const Border(top: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 18,
                          color: AppTheme.primaryOrange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Items (${saleDetails.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),

            // Expandable Items Table
            if (_isExpanded)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 48,
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  'Item',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  'Qty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Price',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'Amount',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Rows
                        ...saleDetails.asMap().entries.map((entry) {
                          final index = entry.key;
                          final detail = entry.value;
                          final lubName = detail['LubName'] as String;
                          final quantity = detail['Quantity'] as num;
                          final price = detail['Price'] as num;
                          final amount = detail['Amount'] as num;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: index % 2 == 0
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.03),
                              border: Border(
                                bottom: index == saleDetails.length - 1
                                    ? BorderSide.none
                                    : const BorderSide(color: Colors.white12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryOrange.withOpacity(
                                        0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lubName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    _formatCurrency(price),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    _formatCurrency(amount),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),

            // Balance Section
            if (balance > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  border: _isExpanded
                      ? null
                      : const Border(top: BorderSide(color: Colors.white24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Balance',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatCurrency(balance),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
