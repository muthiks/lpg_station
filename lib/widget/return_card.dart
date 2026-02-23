import 'package:flutter/material.dart';
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/services/auth_service.dart';
import 'package:lpg_station/theme/theme.dart';

class ReturnCard extends StatelessWidget {
  final CylinderReturn cylinderReturn;
  final VoidCallback onTap;
  final VoidCallback? onAdvanceStatus; // null = not allowed for this user
  final VoidCallback onDelete;

  const ReturnCard({
    super.key,
    required this.cylinderReturn,
    required this.onTap,
    required this.onDelete,
    this.onAdvanceStatus,
  });

  // ── Permission helpers ────────────────────────────────────────────────────
  static bool get _isDriver =>
      AuthService.instance.role?.toLowerCase() == 'driver';

  bool get _canDelete {
    if (!cylinderReturn.isEditable) return false;
    if (_isDriver && cylinderReturn.addedBy != AuthService.instance.userId) {
      return false;
    }
    return true;
  }

  bool get _canAdvance {
    if (_isDriver) return false; // drivers never advance status
    return cylinderReturn.nextStatus != null; // Approved has no next
  }

  // ── Status styling ────────────────────────────────────────────────────────
  Color get _statusColor {
    switch (cylinderReturn.status) {
      case 'New':
        return Colors.blue;
      case 'Received':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (cylinderReturn.status) {
      case 'New':
        return Icons.fiber_new;
      case 'Received':
        return Icons.move_to_inbox;
      case 'Approved':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('return_${cylinderReturn.returnId}'),
      // ── Swipe right → advance status ─────────────────────────────────────
      direction: _canAdvance || _canDelete
          ? DismissDirection.horizontal
          : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right = advance status
          if (!_canAdvance) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You do not have permission to advance this return',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
          return await _confirmAdvance(context);
        } else {
          // Swipe left = delete
          if (!_canDelete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  cylinderReturn.isEditable
                      ? 'You can only delete your own returns'
                      : 'Only New returns can be deleted',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
          return await _confirmDelete(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onAdvanceStatus?.call();
        } else {
          onDelete();
        }
      },
      // ── Swipe right background (advance) ─────────────────────────────────
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      // ── Swipe left background (delete) ───────────────────────────────────
      background: _canAdvance
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: _nextStatusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_nextStatusIcon, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    cylinderReturn.nextStatus ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Container(color: Colors.transparent),
      // ── Card ─────────────────────────────────────────────────────────────
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cylinderReturn.customerName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.warehouse,
                                  size: 13,
                                  color: Colors.white.withOpacity(0.65),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cylinderReturn.stationName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(cylinderReturn.returnDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _statusColor.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon, size: 13, color: _statusColor),
                            const SizedBox(width: 5),
                            Text(
                              cylinderReturn.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Colors.white.withOpacity(0.15), height: 1),
                  const SizedBox(height: 10),

                  // ── Cylinder badges ─────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: cylinderReturn.cylinders
                        .map((c) => _buildCylinderBadge(c))
                        .toList(),
                  ),

                  const SizedBox(height: 10),

                  // ── Summary totals ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryItem(
                          'Tagged',
                          _totalTagged,
                          Icons.qr_code_scanner,
                          Colors.green,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        _summaryItem(
                          'Untagged',
                          _totalUntagged,
                          Icons.propane_tank,
                          Colors.orange,
                        ),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        _summaryItem(
                          'Total',
                          _totalCount,
                          Icons.inventory_2,
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  // ── Swipe hint ──────────────────────────────────────────
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_canAdvance)
                        _swipeHint(
                          Icons.swipe_right,
                          '→ ${cylinderReturn.nextStatus}',
                          _nextStatusColor,
                        ),
                      if (_canDelete)
                        _swipeHint(Icons.swipe_left, '← Delete', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color get _nextStatusColor {
    switch (cylinderReturn.nextStatus) {
      case 'Received':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData get _nextStatusIcon {
    switch (cylinderReturn.nextStatus) {
      case 'Received':
        return Icons.move_to_inbox;
      case 'Approved':
        return Icons.check_circle;
      default:
        return Icons.arrow_forward;
    }
  }

  int get _totalTagged =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.taggedCount);
  int get _totalUntagged =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.untaggedCount);
  int get _totalCount =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.totalCount);

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _buildCylinderBadge(ReturnCylinderInfo c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.lubName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.taggedCount > 0) ...[
                Icon(
                  Icons.qr_code_scanner,
                  size: 11,
                  color: Colors.green.shade300,
                ),
                const SizedBox(width: 3),
                Text(
                  '${c.taggedCount}',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade300),
                ),
              ],
              if (c.taggedCount > 0 && c.untaggedCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    '|',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              if (c.untaggedCount > 0) ...[
                Icon(
                  Icons.propane_tank,
                  size: 11,
                  color: Colors.orange.shade300,
                ),
                const SizedBox(width: 3),
                Text(
                  '${c.untaggedCount}',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade300),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 3),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _swipeHint(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmAdvance(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Mark as ${cylinderReturn.nextStatus}?'),
            content: Text(
              'Move "${cylinderReturn.customerName}" return to '
              '${cylinderReturn.nextStatus} status?',
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(cylinderReturn.nextStatus ?? ''),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Return?'),
            content: Text(
              'Delete the return for "${cylinderReturn.customerName}"? '
              'This cannot be undone.',
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
