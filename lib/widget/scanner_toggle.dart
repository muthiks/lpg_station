import 'package:flutter/material.dart';
import 'package:lpg_station/theme/theme.dart';

class ScannerToggle extends StatelessWidget {
  final bool isScanning;
  final Function(bool) onToggle;

  const ScannerToggle({
    super.key,
    required this.isScanning,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isScanning
            ? AppTheme.primaryOrange.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isScanning ? AppTheme.primaryOrange : Colors.white24,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isScanning ? Icons.qr_code_scanner : Icons.qr_code,
            color: isScanning ? AppTheme.primaryOrange : Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isScanning
                  ? 'Scanner Active - Scan cylinders'
                  : 'Tap to activate scanner',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isScanning ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Switch(
            value: isScanning,
            onChanged: onToggle,
            activeThumbColor: AppTheme.primaryOrange,
          ),
        ],
      ),
    );
  }
}
