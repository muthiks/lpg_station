import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lpg_station/models/receive_model.dart';
import 'package:lpg_station/theme/theme.dart';

class ReceiveCard extends StatelessWidget {
  final Receive delivery;
  final VoidCallback? onTap; // ✅ Add this parameter
  const ReceiveCard({super.key, required this.delivery, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: CircleAvatar(child: Icon(Icons.shopping_cart_outlined)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Header row
                      Text(
                        delivery.customer,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            delivery.invoiceNo,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(delivery.saleDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      /// Driver
                      const SizedBox(height: 4),

                      Text(
                        delivery.truckNo,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      /// Cylinder badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: delivery.cylinders.map<Widget>((c) {
                          return Chip(
                            label: Text(
                              c.badgeText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            backgroundColor: c.totalCount == c.undeliveredCount
                                ? AppTheme.primaryBlue
                                : c.undeliveredCount == 0
                                ? const Color.fromARGB(255, 2, 104, 6)
                                : AppTheme.primaryOrange,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
