import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DispatchSheet
//  Opens after user confirms "Move to Dispatched".
//  Step 1: choose mode  → Tagged | Non Tagged | Both
//  Step 2: scan / enter untagged counts
//  Step 3: confirm dispatch
// ─────────────────────────────────────────────────────────────────────────────
class DispatchSheet extends StatefulWidget {
  final SaleDto sale;
  final VoidCallback onDispatched;

  const DispatchSheet({
    super.key,
    required this.sale,
    required this.onDispatched,
  });

  @override
  State<DispatchSheet> createState() => _DispatchSheetState();
}

class _DispatchSheetState extends State<DispatchSheet> {
  // ── Step 1: mode selection ─────────────────────────────────────────────
  String? _mode; // 'Tagged' | 'NonTagged' | 'Both'

  // ── Scanner ────────────────────────────────────────────────────────────
  bool _useCameraScanner = true; // false = physical scanner (keyboard wedge)
  bool _scannerActive = false;
  final FocusNode _scanFocus = FocusNode();
  final TextEditingController _scanController = TextEditingController();
  String _scanBuffer = '';

  // ── Scanned barcodes grouped by cylinderID ─────────────────────────────
  // { cylinderID: { lubName, barcodes: [..] } }
  final Map<int, _CylGroup> _scanned = {};

  // ── Untagged counts (for Both mode) ───────────────────────────────────
  // { cylinderID: TextEditingController }
  final Map<int, TextEditingController> _untaggedControllers = {};

  // ── Validation / submission state ─────────────────────────────────────
  bool _isSubmitting = false;
  String? _scanError;

  // Cylinder-only sale details (no accessories)
  List<SaleDetailDto> get _cylDetails =>
      widget.sale.saleDetails.where((d) => d.cylStatus != 'Accessory').toList();

  // Max tagged per cylinder type = sale qty  (Both mode: sale qty minus untagged)
  int _maxTagged(int cylID) {
    final detail = _cylDetails.firstWhere(
      (d) => d.cylinderID == cylID,
      orElse: () => _cylDetails.first,
    );
    final untagged =
        int.tryParse(_untaggedControllers[cylID]?.text ?? '0') ?? 0;
    return detail.quantity - untagged;
  }

  int _scannedCount(int cylID) => _scanned[cylID]?.barcodes.length ?? 0;

  int get _totalScanned =>
      _scanned.values.fold(0, (s, g) => s + g.barcodes.length);

  int get _totalSaleQty => _cylDetails.fold(0, (s, d) => s + d.quantity);

  bool get _allTaggedComplete {
    for (final d in _cylDetails) {
      if (_scannedCount(d.cylinderID) < _maxTagged(d.cylinderID)) return false;
    }
    return true;
  }

  bool get _canDispatch {
    switch (_mode) {
      case 'NonTagged':
        return true;
      case 'Tagged':
        return _allTaggedComplete;
      case 'Both':
        for (final d in _cylDetails) {
          final untagged =
              int.tryParse(_untaggedControllers[d.cylinderID]?.text ?? '0') ??
              0;
          final tagged = _scannedCount(d.cylinderID);
          if (tagged + untagged != d.quantity) return false;
        }
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    for (final d in _cylDetails) {
      _untaggedControllers[d.cylinderID] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    _scanController.dispose();
    for (final c in _untaggedControllers.values) c.dispose();
    super.dispose();
  }

  // ── Scanner logic ──────────────────────────────────────────────────────
  void _toggleScanner(bool active) {
    setState(() {
      _scannerActive = active;
      _scanError = null;
    });
    if (active && !_useCameraScanner) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => FocusScope.of(context).requestFocus(_scanFocus),
      );
    }
  }

  void _onKeyboardScanChanged(String value) {
    _scanBuffer = value;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scanBuffer == value && value.isNotEmpty) {
        _processBarcode(value.trim());
        _scanController.clear();
        _scanBuffer = '';
      }
    });
  }

  Future<void> _processBarcode(String barcode) async {
    if (barcode.isEmpty) return;
    setState(() {
      _scanError = null;
    });

    // ── Duplicate check ──────────────────────────────────────────────────
    for (final group in _scanned.values) {
      if (group.barcodes.contains(barcode)) {
        setState(() => _scanError = 'Barcode "$barcode" already scanned');
        return;
      }
    }

    // ── Validate cylinder via API ─────────────────────────────────────────
    try {
      final result = await ApiService.validateDispatchCylinder(
        barcode: barcode,
        stationId: widget.sale.stationID,
        allowedCylinderIds: _cylDetails.map((d) => d.cylinderID).toList(),
      );

      if (!result.isValid) {
        setState(() => _scanError = result.message);
        return;
      }

      final cylID = result.cylinderID!;

      // ── Check this type's tagged count won't exceed max ────────────────
      final already = _scannedCount(cylID);
      final max = _maxTagged(cylID);
      if (already >= max) {
        final detail = _cylDetails.firstWhere((d) => d.cylinderID == cylID);
        setState(
          () => _scanError =
              '${detail.lubName}: tagged limit reached ($already/$max)',
        );
        return;
      }

      setState(() {
        _scanned
            .putIfAbsent(
              cylID,
              () => _CylGroup(
                cylID: cylID,
                lubName: result.lubName ?? 'Cylinder',
              ),
            )
            .barcodes
            .add(barcode);
      });
    } catch (e) {
      setState(() => _scanError = 'Validation error: $e');
    }
  }

  // ── Submit dispatch ────────────────────────────────────────────────────
  Future<void> _dispatch() async {
    setState(() {
      _isSubmitting = true;
    });
    try {
      // Build tagged payload: { cylinderID: [barcodes] }
      final taggedMap = <int, List<String>>{};
      for (final entry in _scanned.entries) {
        taggedMap[entry.key] = entry.value.barcodes;
      }

      // Build untagged payload: { cylinderID: count }
      final untaggedMap = <int, int>{};
      if (_mode == 'Both' || _mode == 'NonTagged') {
        for (final entry in _untaggedControllers.entries) {
          untaggedMap[entry.key] = int.tryParse(entry.value.text) ?? 0;
        }
      }

      await ApiService.dispatchSale(
        saleId: widget.sale.lpgSaleID,
        mode: _mode!,
        tagged: taggedMap,
        untagged: untaggedMap,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onDispatched();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showSnack('Dispatch failed: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: _mode == null ? 0.45 : 0.92,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF2C1810), const Color(0xFF1A1A1A)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: AppTheme.primaryOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dispatch Sale',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.sale.invoiceNo,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 20),

              Expanded(
                child: _mode == null
                    ? _buildModeSelector(scrollCtrl)
                    : _buildDispatchContent(scrollCtrl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: Mode selector ──────────────────────────────────────────────
  Widget _buildModeSelector(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'How are cylinders being dispatched?',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
        const SizedBox(height: 20),
        _ModeCard(
          icon: Icons.qr_code_scanner,
          title: 'Tagged',
          subtitle: 'Scan barcode on each cylinder',
          color: const Color(0xFF1565C0),
          onTap: () => setState(() => _mode = 'Tagged'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.propane_tank,
          title: 'Non Tagged',
          subtitle: 'No barcodes — dispatch by quantity',
          color: const Color(0xFF2E7D32),
          onTap: () => setState(() => _mode = 'NonTagged'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.merge_type,
          title: 'Both',
          subtitle: 'Mix of tagged and untagged cylinders',
          color: const Color(0xFF6A1B9A),
          onTap: () => setState(() => _mode = 'Both'),
        ),
      ],
    );
  }

  // ── Step 2: dispatch content ───────────────────────────────────────────
  Widget _buildDispatchContent(ScrollController ctrl) {
    return Column(
      children: [
        // Mode badge + back
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _mode = null;
                  _scanned.clear();
                  _scanError = null;
                }),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white54,
                      size: 14,
                    ),
                    Text(
                      'Change',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryOrange.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  _mode!,
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (_mode != 'NonTagged') ...[
                // ── Scanner controls ─────────────────────────────────────────
                _buildScannerControls(),
                const SizedBox(height: 12),

                // ── Error banner ─────────────────────────────────────────────
                if (_scanError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _scanError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _scanError = null),
                          child: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Progress bar ─────────────────────────────────────────────
                _buildProgressBar(),
                const SizedBox(height: 12),
              ],

              // ── Cylinder type breakdown ───────────────────────────────────
              ..._cylDetails.map((d) => _buildCylRow(d)),

              const SizedBox(height: 20),

              // ── Dispatch button ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canDispatch && !_isSubmitting ? _dispatch : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canDispatch
                        ? AppTheme.primaryOrange
                        : Colors.white24,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm Dispatch',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Scanner controls ────────────────────────────────────────────────────
  Widget _buildScannerControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Camera / Physical toggle
          Row(
            children: [
              const Icon(Icons.camera_alt, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                'Camera Scanner',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Switch(
                value: _useCameraScanner,
                onChanged: (v) => setState(() {
                  _useCameraScanner = v;
                  if (_scannerActive && !v) {
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      () => FocusScope.of(context).requestFocus(_scanFocus),
                    );
                  }
                }),
                activeThumbColor: AppTheme.primaryOrange,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.barcode_reader, color: Colors.white54, size: 16),
              const SizedBox(width: 4),
              Text(
                'Physical',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Scan on/off button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(
                _scannerActive ? Icons.stop : Icons.play_arrow,
                color: _scannerActive
                    ? Colors.redAccent
                    : AppTheme.primaryOrange,
              ),
              label: Text(
                _scannerActive ? 'Stop Scanning' : 'Start Scanning',
                style: TextStyle(
                  color: _scannerActive
                      ? Colors.redAccent
                      : AppTheme.primaryOrange,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _scannerActive
                      ? Colors.redAccent
                      : AppTheme.primaryOrange,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _toggleScanner(!_scannerActive),
            ),
          ),

          // Hidden text field for physical scanner (keyboard wedge)
          if (_scannerActive && !_useCameraScanner)
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 1,
                child: TextField(
                  focusNode: _scanFocus,
                  controller: _scanController,
                  onChanged: _onKeyboardScanChanged,
                  autofocus: true,
                ),
              ),
            ),

          // Camera scanner view
          if (_scannerActive && _useCameraScanner)
            _CameraScanner(onBarcode: _processBarcode),
        ],
      ),
    );
  }

  // ── Progress bar ────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final progress = _totalSaleQty == 0 ? 0.0 : _totalScanned / _totalSaleQty;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Scanned',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            Text(
              '$_totalScanned / $_totalSaleQty',
              style: TextStyle(
                color: AppTheme.primaryOrange,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryOrange),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── Per-cylinder row ────────────────────────────────────────────────────
  Widget _buildCylRow(SaleDetailDto d) {
    final scannedBarcodes = _scanned[d.cylinderID]?.barcodes ?? [];
    final scannedCount = scannedBarcodes.length;
    final max = _maxTagged(d.cylinderID);
    final complete = _mode == 'NonTagged' || scannedCount >= max;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: complete
            ? Colors.green.withOpacity(0.08)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: complete
              ? Colors.green.withOpacity(0.4)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: complete ? Colors.green : AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _shortName(d.lubName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    d.lubName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Badge
                _CountBadge(
                  scanned: _mode == 'NonTagged' ? d.quantity : scannedCount,
                  total: d.quantity,
                ),
              ],
            ),
          ),

          // ── Untagged input (Both mode) ────────────────────────────────────
          if (_mode == 'Both')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Untagged:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    height: 32,
                    child: TextField(
                      controller: _untaggedControllers[d.cylinderID],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tagged: $scannedCount  Total: ${scannedCount + (int.tryParse(_untaggedControllers[d.cylinderID]?.text ?? "0") ?? 0)} / ${d.quantity}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

          // ── Barcode chips ─────────────────────────────────────────────────
          if (scannedBarcodes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: scannedBarcodes
                    .map(
                      (bc) => _BarcodeChip(
                        barcode: bc,
                        onDelete: () => setState(() {
                          _scanned[d.cylinderID]?.barcodes.remove(bc);
                          if (_scanned[d.cylinderID]?.barcodes.isEmpty ==
                              true) {
                            _scanned.remove(d.cylinderID);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _shortName(String name) {
    final match = RegExp(r'\d+\s*[Kk][Gg]').firstMatch(name);
    return match?.group(0)?.toUpperCase() ??
        name.split(' ').first.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int scanned;
  final int total;
  const _CountBadge({required this.scanned, required this.total});

  @override
  Widget build(BuildContext context) {
    final complete = scanned >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: complete
            ? Colors.green.withOpacity(0.2)
            : AppTheme.primaryOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: complete
              ? Colors.green.withOpacity(0.5)
              : AppTheme.primaryOrange.withOpacity(0.4),
        ),
      ),
      child: Text(
        '$scanned / $total',
        style: TextStyle(
          color: complete ? Colors.greenAccent : AppTheme.primaryOrange,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _BarcodeChip extends StatelessWidget {
  final String barcode;
  final VoidCallback onDelete;
  const _BarcodeChip({required this.barcode, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            barcode,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 12, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

// ── Cylinder group — holds scanned barcodes for one cylinder type ─────────────
class _CylGroup {
  final int cylID;
  final String lubName;
  final List<String> barcodes = [];

  _CylGroup({required this.cylID, required this.lubName});
}

// ── Camera scanner stub ───────────────────────────────────────────────────────
// Replace with your actual MobileScanner or camera_barcode_scan implementation.
// It just needs to call onBarcode(code) when a scan is detected.
class _CameraScanner extends StatelessWidget {
  final void Function(String) onBarcode;
  const _CameraScanner({required this.onBarcode});

  @override
  Widget build(BuildContext context) {
    // ── REPLACE THIS with your MobileScanner widget, e.g.:
    // return ClipRRect(
    //   borderRadius: BorderRadius.circular(8),
    //   child: SizedBox(
    //     height: 200,
    //     child: MobileScanner(
    //       onDetect: (capture) {
    //         final barcode = capture.barcodes.firstOrNull?.rawValue;
    //         if (barcode != null) onBarcode(barcode);
    //       },
    //     ),
    //   ),
    // );
    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: Colors.white38, size: 36),
            const SizedBox(height: 8),
            Text(
              'Camera scanner — wire in MobileScanner here',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
