import 'package:flutter/material.dart';
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/theme/theme.dart';

class ReturnCard extends StatelessWidget {
  final CylinderReturn cylinderReturn;

  const ReturnCard({super.key, required this.cylinderReturn});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              AppTheme.primaryOrange.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer name
                        Text(
                          cylinderReturn.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Station name — subtitle, slightly bigger than date
                        Row(
                          children: [
                            Icon(
                              Icons.warehouse,
                              size: 13,
                              color: Colors.white.withOpacity(0.75),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cylinderReturn.stationName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Date
                        Text(
                          _formatDate(cylinderReturn.returnDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),

              // ── Cylinder badges ───────────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cylinderReturn.cylinders
                    .map((c) => _buildCylinderBadge(c))
                    .toList(),
              ),

              const SizedBox(height: 12),

              // ── Summary totals ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      'Tagged',
                      _getTotalTagged(),
                      Icons.qr_code_scanner,
                      Colors.green,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildSummaryItem(
                      'Untagged',
                      _getTotalUntagged(),
                      Icons.propane_tank,
                      Colors.orange,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildSummaryItem(
                      'Total',
                      _getTotalCount(),
                      Icons.inventory_2,
                      Colors.blue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCylinderBadge(ReturnCylinderInfo cylinder) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cylinder.lubName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cylinder.taggedCount > 0) ...[
                Icon(
                  Icons.qr_code_scanner,
                  size: 12,
                  color: Colors.green.shade300,
                ),
                const SizedBox(width: 4),
                Text(
                  '${cylinder.taggedCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (cylinder.taggedCount > 0 && cylinder.untaggedCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '|',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              if (cylinder.untaggedCount > 0) ...[
                Icon(
                  Icons.propane_tank,
                  size: 12,
                  color: Colors.orange.shade300,
                ),
                const SizedBox(width: 4),
                Text(
                  '${cylinder.untaggedCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  int _getTotalTagged() =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.taggedCount);

  int _getTotalUntagged() =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.untaggedCount);

  int _getTotalCount() =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.totalCount);

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
