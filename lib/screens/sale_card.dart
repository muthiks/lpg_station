// lib/screens/sale_card.dart

import 'package:flutter/material.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:intl/intl.dart';

class SaleCard extends StatelessWidget {
  final SaleDto sale;

  const SaleCard({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'KSh ',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to sale details
          Navigator.pushNamed(context, '/sale-details', arguments: sale.saleID);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              sale.invoiceNo,
                              style: TextStyle(
                                color: AppTheme.primaryBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (sale.orderNo != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${sale.orderNo}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(sale.saleDate),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(sale),
                ],
              ),

              const SizedBox(height: 12),

              // Customer Info
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.customerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        if (sale.customerPhone != null)
                          Text(
                            sale.customerPhone!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Delivery Status (if applicable)
              if (sale.isDispatched || sale.isDelivered) ...[
                const SizedBox(height: 12),
                _buildDeliveryStatus(sale, timeFormat),
              ],

              const SizedBox(height: 12),

              // Amount Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          currencyFormat.format(sale.total),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (!sale.isPaid) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Balance:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            currencyFormat.format(sale.balance),
                            style: TextStyle(
                              color: AppTheme.primaryOrange,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SaleDto sale) {
    Color badgeColor;
    String badgeText;

    if (sale.isPaid) {
      badgeColor = Colors.green;
      badgeText = 'PAID';
    } else if (sale.isApproved) {
      badgeColor = AppTheme.primaryOrange;
      badgeText = 'PENDING';
    } else {
      badgeColor = Colors.red;
      badgeText = 'UNAPPROVED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDeliveryStatus(SaleDto sale, DateFormat timeFormat) {
    IconData icon;
    Color color;
    String text;

    if (sale.isDelivered && sale.dateDelivered != null) {
      icon = Icons.check_circle;
      color = Colors.green;
      text = 'Delivered ${timeFormat.format(sale.dateDelivered!)}';
    } else if (sale.isDispatched && sale.dateDispatched != null) {
      icon = Icons.local_shipping;
      color = AppTheme.primaryBlue;
      text = 'Dispatched ${timeFormat.format(sale.dateDispatched!)}';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
