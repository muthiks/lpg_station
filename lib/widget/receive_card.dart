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
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            delivery.customer,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.file_present_sharp,
                                size: 16,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                delivery.invoiceNo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_sharp,
                                size: 16,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(delivery.saleDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      /// Driver
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.fire_truck_sharp,
                            size: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            delivery.truckNo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      /// Cylinder badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 0,
                        children: delivery.cylinders.map<Widget>((c) {
                          return Chip(
                            label: Text(
                              c.badgeText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: c.isFullyReceived
                                ? const Color.fromARGB(
                                    255,
                                    2,
                                    104,
                                    6,
                                  ) // ✅ green = all received
                                : c.receivedCount == 0
                                ? AppTheme
                                      .primaryBlue // ✅ blue = none received yet
                                : AppTheme.primaryOrange,
                          );
                        }).toList(),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.delivery_dining_sharp,
                            size: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            delivery.user,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
