import 'package:flutter/material.dart';
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/theme/theme.dart';

class ReturnCard extends StatelessWidget {
  final CylinderReturn cylinderReturn;

  /// Tap to open in edit mode. null = tapping does nothing.
  final VoidCallback? onTap;

  /// Called after swipe-left confirmed. null = swipe left disabled.
  final VoidCallback? onDelete;

  /// Called after swipe-right confirmed. null = swipe right disabled.
  final VoidCallback? onAdvanceStatus;

  /// Whether the swipe-left (delete) action is shown.
  final bool canDelete;

  /// Whether the swipe-right (advance status) action is shown.
  final bool canAdvance;

  const ReturnCard({
    super.key,
    required this.cylinderReturn,
    required this.canDelete,
    required this.canAdvance,
    this.onTap,
    this.onDelete,
    this.onAdvanceStatus,
  });

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

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final DismissDirection direction;
    if (canAdvance && canDelete) {
      direction = DismissDirection.horizontal;
    } else if (canAdvance) {
      direction = DismissDirection.startToEnd;
    } else if (canDelete) {
      direction = DismissDirection.endToStart;
    } else {
      direction = DismissDirection.none;
    }

    return Dismissible(
      key: ValueKey('return_${cylinderReturn.returnId}'),
      direction: direction,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          return await _confirmAdvance(context);
        } else {
          return await _confirmDelete(context);
        }
      },
      onDismissed: (dir) {
        if (dir == DismissDirection.startToEnd) {
          onAdvanceStatus?.call();
        } else {
          onDelete?.call();
        }
      },
      // ── Swipe RIGHT background (advance) ─────────────────────────────────
      background: canAdvance
          ? Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
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
          : const SizedBox.shrink(),
      // ── Swipe LEFT background (delete) ───────────────────────────────────
      secondaryBackground: canDelete
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
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
            )
          : const SizedBox.shrink(),

      // ── Card ─────────────────────────────────────────────────────────────
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          elevation: 3,
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
                  // ── Header ──────────────────────────────────────────────
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
                                  size: 12,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cylinderReturn.stationName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(cylinderReturn.returnDate),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.55),
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
                            Icon(_statusIcon, size: 12, color: _statusColor),
                            const SizedBox(width: 4),
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

                  const SizedBox(height: 10),
                  Divider(color: Colors.white.withOpacity(0.12), height: 1),
                  const SizedBox(height: 10),

                  // ── Cylinder badges ──────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: cylinderReturn.cylinders
                        .map(_buildCylinderBadge)
                        .toList(),
                  ),

                  const SizedBox(height: 10),

                  // ── Summary totals ───────────────────────────────────────
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
                          height: 26,
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
                          height: 26,
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

                  // ── Swipe hints ──────────────────────────────────────────
                  if (canAdvance || canDelete || onTap != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (canAdvance)
                          _swipeHint(
                            Icons.swipe_right,
                            '→ ${cylinderReturn.nextStatus}',
                            _nextStatusColor,
                          ),
                        if (onTap != null)
                          _swipeHint(
                            Icons.touch_app,
                            'Tap to edit',
                            Colors.white54,
                          ),
                        if (canDelete)
                          _swipeHint(Icons.swipe_left, '← Delete', Colors.red),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  int get _totalTagged =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.taggedCount);
  int get _totalUntagged =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.untaggedCount);
  int get _totalCount =>
      cylinderReturn.cylinders.fold(0, (s, c) => s + c.totalCount);

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _buildCylinderBadge(ReturnCylinderInfo c) => Container(
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
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
              ),
            if (c.untaggedCount > 0) ...[
              Icon(Icons.propane_tank, size: 11, color: Colors.orange.shade300),
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

  Widget _summaryItem(String label, int count, IconData icon, Color color) =>
      Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      );

  Widget _swipeHint(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color.withOpacity(0.65)),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color.withOpacity(0.65),
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );

  Future<bool> _confirmAdvance(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Mark as ${cylinderReturn.nextStatus}?'),
          content: Text(
            'Move "${cylinderReturn.customerName}" return to '
            '${cylinderReturn.nextStatus}?',
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

  Future<bool> _confirmDelete(BuildContext context) async =>
      await showDialog<bool>(
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
