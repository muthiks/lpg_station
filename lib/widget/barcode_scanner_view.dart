// lib/widget/barcode_scanner_view.dart
//
// Add to pubspec.yaml:
//   dependencies:
//     mobile_scanner: ^5.2.3
//
// Android — android/app/src/main/AndroidManifest.xml:
//   <uses-permission android:name="android.permission.CAMERA" />
//
// iOS — ios/Runner/Info.plist:
//   <key>NSCameraUsageDescription</key>
//   <string>Camera is used to scan cylinder barcodes</string>

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:lpg_station/theme/theme.dart';

class BarcodeScannerView extends StatefulWidget {
  /// Called once per unique detected barcode. Debounced — won't fire again
  /// for the same code until [rescanDelay] has passed.
  final void Function(String barcode) onDetected;

  /// Visual overlay color (defaults to primaryOrange)
  final Color? accentColor;

  /// Height of the camera preview area
  final double height;

  /// Milliseconds to wait before the same barcode can fire again
  final int rescanDelayMs;

  const BarcodeScannerView({
    super.key,
    required this.onDetected,
    this.accentColor,
    this.height = 220,
    this.rescanDelayMs = 2000,
  });

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _torchOn = false;
  String? _lastBarcode;
  DateTime? _lastScanTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    final now = DateTime.now();

    // Debounce — ignore same code within rescanDelayMs
    if (barcode == _lastBarcode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < widget.rescanDelayMs) {
      return;
    }

    _lastBarcode = barcode;
    _lastScanTime = now;
    widget.onDetected(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppTheme.primaryOrange;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            // ── Camera feed ─────────────────────────────────────────────
            MobileScanner(controller: _controller, onDetect: _onDetect),

            // ── Scanning overlay ─────────────────────────────────────────
            _ScanOverlay(accentColor: accent),

            // ── Top controls bar ─────────────────────────────────────────
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  // Torch toggle
                  _ControlButton(
                    icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                    color: _torchOn ? Colors.yellow : Colors.white70,
                    onTap: () {
                      _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                  ),
                  const SizedBox(width: 6),
                  // Flip camera
                  _ControlButton(
                    icon: Icons.flip_camera_ios,
                    color: Colors.white70,
                    onTap: () => _controller.switchCamera(),
                  ),
                ],
              ),
            ),

            // ── "Scanning…" label ─────────────────────────────────────────
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'Scanning…',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scanning frame overlay ────────────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  final Color accentColor;
  const _ScanOverlay({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OverlayPainter(accentColor));
  }
}

class _OverlayPainter extends CustomPainter {
  final Color accent;
  _OverlayPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.45);
    final cornerPaint = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Scanning window
    const cornerLen = 22.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final boxW = size.width * 0.72;
    final boxH = size.height * 0.55;
    final left = cx - boxW / 2;
    final top = cy - boxH / 2;
    final right = cx + boxW / 2;
    final bottom = cy + boxH / 2;

    // Dim regions
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), dimPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, bottom, size.width, size.height - bottom),
      dimPaint,
    );
    canvas.drawRect(Rect.fromLTWH(0, top, left, boxH), dimPaint);
    canvas.drawRect(
      Rect.fromLTWH(right, top, size.width - right, boxH),
      dimPaint,
    );

    // Corner marks
    // Top-left
    canvas.drawLine(
      Offset(left, top + cornerLen),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLen, top),
      cornerPaint,
    );
    // Top-right
    canvas.drawLine(
      Offset(right - cornerLen, top),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLen),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(left, bottom - cornerLen),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLen, bottom),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(right - cornerLen, bottom),
      Offset(right, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLen),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Small icon button ─────────────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ── Pulsing dot indicator ─────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.3,
    end: 1.0,
  ).animate(_anim);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
