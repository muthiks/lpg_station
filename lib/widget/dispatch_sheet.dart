import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/barcode_scanner_view.dart';

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
  String? _mode;
  bool _useCameraScanner = true;
  bool _scannerActive = false;

  final FocusNode _scanFocus = FocusNode();
  final TextEditingController _scanController = TextEditingController();
  String _scanBuffer = '';

  final Map<int, _CylGroup> _scanned = {};
  final Map<int, TextEditingController> _untaggedControllers = {};

  bool _isSubmitting = false;
  String? _scanError;

  List<SaleDetailDto> get _cylDetails =>
      widget.sale.saleDetails.where((d) => d.cylStatus != 'Accessory').toList();

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
        // All quantities must be entered
        for (final d in _cylDetails) {
          final untagged =
              int.tryParse(_untaggedControllers[d.cylinderID]?.text ?? '0') ??
              0;
          if (untagged != d.quantity) return false;
        }
        return true;

      case 'Tagged':
        return _allTaggedComplete;

      case 'Both':
        // Both requires: total correct AND at least 1 tagged AND at least 1 untagged per type
        bool hasAtLeastOneTagged = false;
        bool hasAtLeastOneUntagged = false;

        for (final d in _cylDetails) {
          final tagged = _scannedCount(d.cylinderID);
          final untagged =
              int.tryParse(_untaggedControllers[d.cylinderID]?.text ?? '0') ??
              0;

          if (tagged + untagged != d.quantity) return false;

          if (tagged > 0) hasAtLeastOneTagged = true;
          if (untagged > 0) hasAtLeastOneUntagged = true;
        }

        return hasAtLeastOneTagged && hasAtLeastOneUntagged;

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
  void didUpdateWidget(DispatchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-start scanner when mode is selected (Tagged or Both)
    if (_mode != null && _mode != 'NonTagged' && !_scannerActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_scannerActive) {
          setState(() => _scannerActive = true);
          if (!_useCameraScanner) {
            Future.delayed(
              const Duration(milliseconds: 100),
              () => FocusScope.of(context).requestFocus(_scanFocus),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    _scanController.dispose();
    for (final c in _untaggedControllers.values) c.dispose();
    super.dispose();
  }

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
    setState(() => _scanError = null);

    for (final group in _scanned.values) {
      if (group.barcodes.contains(barcode)) {
        setState(() => _scanError = 'Barcode "$barcode" already scanned');
        return;
      }
    }

    try {
      final result = await ApiService.validateDispatchCylinder(
        barcode: barcode,
        stationId: widget.sale.stationID,
        saleId: widget.sale.lpgSaleID,
      );

      if (!result.isValid) {
        setState(() => _scanError = result.message);
        return;
      }

      final cylID = result.lubId!;
      final already = _scannedCount(cylID);
      final max = _maxTagged(cylID);
      if (already >= max) {
        final detail = _cylDetails.firstWhere((d) => d.cylinderID == cylID);
        setState(
          () => _scanError = '${detail.lubName}: limit reached ($already/$max)',
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
      log('Scan error: $e');
      setState(() => _scanError = 'Validation error: $e');
    }
  }

  Future<void> _dispatch() async {
    setState(() => _isSubmitting = true);
    try {
      if (_mode == 'NonTagged') {
        await ApiService.updateSaleStatus(widget.sale.lpgSaleID, 'Dispatched');
      } else {
        await ApiService.dispatchSale(
          saleId: widget.sale.lpgSaleID,
          mode: _mode!,
          tagged: {for (final e in _scanned.entries) e.key: e.value.barcodes},
          untagged: _mode == 'Both'
              ? {
                  for (final e in _untaggedControllers.entries)
                    e.key: int.tryParse(e.value.text) ?? 0,
                }
              : {},
        );
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onDispatched();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2C1810), Color(0xFF1A1A1A)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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

  Widget _buildDispatchContent(ScrollController ctrl) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _mode = null;
                  _scanned.clear();
                  _scanError = null;
                  _scannerActive = false;
                }),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_circle_left,
                      color: Colors.white54,
                      size: 15,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Change',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Scanner toggle (Camera/Physical)
              if (_mode != 'NonTagged')
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: _useCameraScanner
                        ? 'Switch to physical scanner'
                        : 'Switch to camera scanner',
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _useCameraScanner = !_useCameraScanner;
                        _scannerActive = false;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 30,
                        width: 38,
                        decoration: BoxDecoration(
                          color: _useCameraScanner
                              ? AppTheme.primaryOrange
                              : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _useCameraScanner
                                ? AppTheme.primaryOrange
                                : Colors.white38,
                          ),
                        ),
                        child: Icon(
                          _useCameraScanner
                              ? Icons.camera_alt
                              : Icons.barcode_reader,
                          size: 18,
                          color: _useCameraScanner
                              ? Colors.white
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),

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
                _buildScannerSection(),
                const SizedBox(height: 12),
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
                _buildProgressBar(),
                const SizedBox(height: 12),
              ],

              ..._cylDetails.map(_buildCylRow),
              const SizedBox(height: 20),

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
                            color: Colors.white,
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

  Widget _buildScannerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scanner on/off toggle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _scannerActive
                ? AppTheme.primaryOrange.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _scannerActive
                  ? AppTheme.primaryOrange.withOpacity(0.5)
                  : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _scannerActive ? Icons.qr_code_scanner : Icons.qr_code,
                color: _scannerActive ? AppTheme.primaryOrange : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _scannerActive
                      ? (_useCameraScanner
                            ? 'Camera Active - Point at barcode'
                            : 'Physical Scanner Active')
                      : 'Tap to activate scanner',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: _scannerActive
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              Switch(
                value: _scannerActive,
                onChanged: _toggleScanner,
                activeThumbColor: AppTheme.primaryOrange,
              ),
            ],
          ),
        ),

        // Physical: hidden TextField captures keyboard wedge input
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

        // Camera: real BarcodeScannerView
        if (_scannerActive && _useCameraScanner) ...[
          const SizedBox(height: 10),
          BarcodeScannerView(
            onDetected: _processBarcode,
            height: 220,
            rescanDelayMs: 1500,
          ),
        ],
      ],
    );
  }

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
                _CountBadge(
                  scanned: _mode == 'NonTagged' ? d.quantity : scannedCount,
                  total: d.quantity,
                ),
              ],
            ),
          ),

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
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Tagged: $scannedCount  Total: ${scannedCount + (int.tryParse(_untaggedControllers[d.cylinderID]?.text ?? "0") ?? 0)} / ${d.quantity}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                          if (_scanned[d.cylinderID]?.barcodes.isEmpty == true)
                            _scanned.remove(d.cylinderID);
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
                    style: const TextStyle(
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

class _CylGroup {
  final int cylID;
  final String lubName;
  final List<String> barcodes = [];
  _CylGroup({required this.cylID, required this.lubName});
}
