import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/services/auth_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ReturnAddScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ReturnAddScreen({super.key, required this.onBack});

  @override
  State<ReturnAddScreen> createState() => _ReturnAddScreenState();
}

class _ReturnAddScreenState extends State<ReturnAddScreen> {
  // ───────────────── SCANNER ─────────────────
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  bool _isProcessingScan = false;
  int? _filteredLubId;

  Timer? _scanTimer;
  String _buffer = '';

  // ───────────────── SEARCH ─────────────────
  final TextEditingController _searchController = TextEditingController();
  bool _userIsTyping = false;

  // ───────────────── DATA ─────────────────
  // barcode → lubId
  final Map<String, int> _scannedBarcodes = {};
  // barcode → lubName
  final Map<String, String> _scannedBarcodeLubName = {};
  List<MapEntry<String, int>> _filteredScans = [];

  // untagged: lubId → TextEditingController
  final Map<int, TextEditingController> _untaggedQtyControllers = {};
  // lubId → lubName
  final Map<int, String> _lubNames = {};

  // ───────────────── DROPDOWNS ─────────────────
  bool _isLoadingStations = true;
  bool _isLoadingCustomers = false;
  bool _isLoadingLubricants = false;
  bool _isCreatingReturn = false;

  List<StationDto> _stations = [];
  List<CustomerDto> _customers = [];
  // All lubricants for untagged selection: {LubId, LubName}
  List<Map<String, dynamic>> _lubricants = [];

  StationDto? _selectedStation;
  CustomerDto? _selectedCustomer;

  String _returnStatus = 'both'; // 'tagged' | 'not-tagged' | 'both'

  // ───────────────── CAMERA SCANNER ─────────────────
  bool _useCameraScanner = false; // false = physical (gun), true = camera
  MobileScannerController? _cameraController;

  // ───────────────── ITEMS TO RETURN (from API) ─────
  // lubId -> {lubName, maxQty}  — loaded when customer is selected
  List<Map<String, dynamic>> _itemsToReturn = [];
  bool _isLoadingItemsToReturn = false;
  // lubId -> TextEditingController  (only for not-tagged / both)
  // (reuses _untaggedQtyControllers — no separate map needed)

  @override
  void initState() {
    super.initState();
    _loadStations();
    _filteredScans = _scannedBarcodes.entries.toList();
    _searchController.addListener(_applySearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_userIsTyping) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _player.dispose();
    _searchController.dispose();
    _scanTimer?.cancel();
    _cameraController?.dispose();
    for (final c in _untaggedQtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ═══════════════════════════ DATA LOADING ════════════════════════════

  Future<void> _loadStations() async {
    setState(() => _isLoadingStations = true);
    try {
      final stations = await ApiService.getUserStations();
      setState(() {
        _stations = stations;
        _isLoadingStations = false;
        if (_stations.length == 1) {
          _selectedStation = _stations.first;
          _loadCustomers(_selectedStation!.stationID);
        }
      });
    } catch (e) {
      setState(() => _isLoadingStations = false);
      _showSnack('Failed to load stations: $e', isError: true);
    }
  }

  Future<void> _loadCustomers(int stationId) async {
    setState(() {
      _isLoadingCustomers = true;
      _selectedCustomer = null;
      _customers = [];
    });
    try {
      final customers = await ApiService.getCustomersByStation(stationId);
      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
      });
      // If station was auto-selected + customer auto-matched, load items
      if (_selectedCustomer != null) _loadItemsToReturn();
    } catch (e) {
      setState(() => _isLoadingCustomers = false);
      _showSnack('Failed to load customers: $e', isError: true);
    }
  }

  Future<void> _loadItemsToReturn() async {
    if (_selectedStation == null || _selectedCustomer == null) return;
    setState(() {
      _isLoadingItemsToReturn = true;
      _itemsToReturn = [];
      // Reset untagged controllers when items reload
      for (final c in _untaggedQtyControllers.values) c.dispose();
      _untaggedQtyControllers.clear();
    });
    try {
      final items = await ApiService.getItemsToReturnPerCustomer(
        customerId: _selectedCustomer!.customerID,
        stationId: _selectedStation!.stationID,
      );
      setState(() {
        _itemsToReturn = items;
        _isLoadingItemsToReturn = false;
        // Pre-populate lubNames + create qty controllers for each item
        for (final item in items) {
          final lubId = item['LubId'] as int;
          final lubName = item['LubName'] as String;
          _lubNames[lubId] = lubName;
          _untaggedQtyControllers[lubId] = TextEditingController();
        }
      });
    } catch (e) {
      setState(() => _isLoadingItemsToReturn = false);
      log('Error loading items to return: $e');
      _showSnack('Failed to load return items: $e', isError: true);
    }
  }

  // ═══════════════════════════ SCAN SECURITY ═══════════════════════════

  bool _canScan() =>
      _selectedStation != null &&
      _selectedCustomer != null &&
      (_returnStatus == 'tagged' || _returnStatus == 'both');

  // ═══════════════════════════ SCAN HANDLER ════════════════════════════

  void _onTextChanged(String value) {
    _buffer = value;
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 120), () {
      _processScan(_buffer.trim());
    });
  }

  Future<void> _processScan(String barcode) async {
    if (barcode.isEmpty) return;

    if (!_canScan()) {
      await _errorBeep();
      _resetInput();
      return;
    }

    if (_isProcessingScan) return;
    _isProcessingScan = true;

    if (_scannedBarcodes.containsKey(barcode)) {
      await _errorBeep();
      final confirmed = await _confirmDelete(barcode);
      if (confirmed) _deleteBarcode(barcode);
      _resetInput();
      _isProcessingScan = false;
      return;
    }

    await _handleReturnScan(barcode);
    _resetInput();
    _isProcessingScan = false;
  }

  Future<void> _handleReturnScan(String barcode) async {
    try {
      final result = await ApiService.validateReturnCylinder(
        barcode: barcode,
        stationId: _selectedStation!.stationID,
      );
      final lubId = result['LubId'] as int;
      final lubName = result['LubName'] as String;

      setState(() {
        _scannedBarcodes[barcode] = lubId;
        _scannedBarcodeLubName[barcode] = lubName;
        _lubNames[lubId] = lubName;
      });
      _applySearch();
      await _successBeep();
    } catch (e) {
      await _errorBeep();
      _showErrorModal(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _deleteBarcode(String barcode) {
    setState(() {
      _scannedBarcodes.remove(barcode);
      _scannedBarcodeLubName.remove(barcode);
    });
    _applySearch();
  }

  void _resetInput() {
    _controller.clear();
    _buffer = '';
    if (!_userIsTyping) FocusScope.of(context).requestFocus(_focusNode);
  }

  void _returnFocusToScanner() {
    _userIsTyping = false;
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_userIsTyping) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _errorBeep() async {
    await _player.play(AssetSource('sounds/error_beep.mp3'));
    HapticFeedback.heavyImpact();
  }

  Future<void> _successBeep() async {
    await _player.stop();
    await _player.play(AssetSource('sounds/success_beep.mp3'));
    HapticFeedback.mediumImpact();
  }

  // ═══════════════════════════ SEARCH ══════════════════════════════════

  void _applySearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredScans = _scannedBarcodes.entries.where((e) {
        final matchSearch = q.isEmpty || e.key.toLowerCase().contains(q);
        final matchLub = _filteredLubId == null || e.value == _filteredLubId;
        return matchSearch && matchLub;
      }).toList();
    });
  }

  // ═══════════════════════════ UNTAGGED ════════════════════════════════

  void _addUntaggedType(int lubId) {
    if (!_untaggedQtyControllers.containsKey(lubId)) {
      setState(() => _untaggedQtyControllers[lubId] = TextEditingController());
    }
  }

  void _removeUntaggedType(int lubId) {
    setState(() {
      _untaggedQtyControllers[lubId]?.dispose();
      _untaggedQtyControllers.remove(lubId);
    });
  }

  // ═══════════════════════════ VALIDATION ══════════════════════════════

  bool get _isActionEnabled {
    if (_selectedStation == null || _selectedCustomer == null) return false;
    if (_returnStatus == 'tagged') return _scannedBarcodes.isNotEmpty;
    if (_returnStatus == 'not-tagged') {
      return _untaggedQtyControllers.values.any((c) {
        final qty = int.tryParse(c.text);
        return qty != null && qty > 0;
      });
    }
    // 'both': must have at least one tagged scan AND at least one untagged qty
    final hasTagged = _scannedBarcodes.isNotEmpty;
    final hasUntagged = _untaggedQtyControllers.values.any((c) {
      final qty = int.tryParse(c.text);
      return qty != null && qty > 0;
    });
    return hasTagged && hasUntagged;
  }

  bool get _canReset =>
      _selectedCustomer != null ||
      _scannedBarcodes.isNotEmpty ||
      _untaggedQtyControllers.isNotEmpty ||
      _filteredLubId != null;

  Map<int, int> get _lubIdCounts {
    final counts = <int, int>{};
    for (final lubId in _scannedBarcodes.values) {
      counts[lubId] = (counts[lubId] ?? 0) + 1;
    }
    return counts;
  }

  // ═══════════════════════════ SUBMIT ══════════════════════════════════

  void _submitAction() {
    if (!_isActionEnabled) return;

    final Map<String, Map<String, int>> summary = {};
    for (final lubName in _scannedBarcodeLubName.values) {
      summary[lubName] ??= {'tagged': 0, 'untagged': 0};
      summary[lubName]!['tagged'] = summary[lubName]!['tagged']! + 1;
    }
    _untaggedQtyControllers.forEach((lubId, ctrl) {
      final qty = int.tryParse(ctrl.text) ?? 0;
      if (qty > 0) {
        final name = _lubNames[lubId] ?? 'Unknown';
        summary[name] ??= {'tagged': 0, 'untagged': 0};
        summary[name]!['untagged'] = summary[name]!['untagged']! + qty;
      }
    });

    String text =
        'Station: ${_selectedStation!.stationName}\n'
        'Customer: ${_selectedCustomer!.customerName}\n\n';
    int grandTotal = 0;
    summary.forEach((type, counts) {
      final total = counts['tagged']! + counts['untagged']!;
      grandTotal += total;
      text += '$type:\n';
      if (counts['tagged']! > 0) text += '  Tagged: ${counts['tagged']}\n';
      if (counts['untagged']! > 0)
        text += '  Untagged: ${counts['untagged']}\n';
      text += '  Total: $total\n\n';
    });
    text += 'Grand Total: $grandTotal cylinders';

    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Return Summary'),
        content: Text(text, style: const TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) _sendToApi();
    });
  }

  Future<void> _sendToApi() async {
    setState(() => _isCreatingReturn = true);
    try {
      final payload = _buildPayload();
      log(
        'RETURN PAYLOAD:\n${const JsonEncoder.withIndent('  ').convert(payload)}',
      );
      await ApiService.createStationReturn(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return created successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 6),
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      log('RETURN API ERROR: $e');
      if (mounted) {
        _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isCreatingReturn = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    final Map<int, List<String>> taggedByLub = {};
    _scannedBarcodes.forEach((barcode, lubId) {
      taggedByLub[lubId] ??= [];
      taggedByLub[lubId]!.add(barcode);
    });

    final taggedArray = taggedByLub.entries
        .map((e) => {'LubId': e.key, 'Barcodes': e.value})
        .toList();

    final untaggedArray = <Map<String, dynamic>>[];
    _untaggedQtyControllers.forEach((lubId, ctrl) {
      final qty = int.tryParse(ctrl.text) ?? 0;
      if (qty > 0) untaggedArray.add({'LubId': lubId, 'Qty': qty});
    });

    return {
      'ReturnDate': DateTime.now().toUtc().toIso8601String(),
      'StationID': _selectedStation!.stationID,
      'CustomerID': _selectedCustomer!.customerID,
      'AddedBy': AuthService.instance.userId ?? 'unknown',
      'ReturnType': _returnStatus,
      'Tagged': taggedArray,
      'Untagged': untaggedArray,
    };
  }

  Future<void> _resetForm() async {
    final confirmed =
        await showGeneralDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Reset',
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (_, __, ___) => const SizedBox.shrink(),
          transitionBuilder: (_, animation, __, ___) => ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: FadeTransition(
              opacity: animation,
              child: AlertDialog(
                title: const Text('Reset'),
                content: const Text(
                  'Reset all selections and scans?',
                  style: TextStyle(color: Colors.black),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _selectedCustomer = null;
      _returnStatus = 'both';
      _scannedBarcodes.clear();
      _scannedBarcodeLubName.clear();
      _filteredLubId = null;
      for (final c in _untaggedQtyControllers.values) c.dispose();
      _untaggedQtyControllers.clear();
    });
    _applySearch();
  }

  // ═══════════════════════════ STATION SELECTOR ════════════════════════

  void _showStationSelector() {
    final ctrl = TextEditingController();
    List<StationDto> filtered = _stations;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => _sheet(
          height: 0.65,
          child: Column(
            children: [
              _sheetHeader('Select Station', Icons.warehouse, ctx),
              _searchField(ctrl, 'Search stations...', (q) {
                setModal(() {
                  filtered = q.isEmpty
                      ? _stations
                      : _stations
                            .where(
                              (s) => s.stationName.toLowerCase().contains(
                                q.toLowerCase(),
                              ),
                            )
                            .toList();
                });
              }),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final sel = _selectedStation?.stationID == s.stationID;
                    return _sheetItemTile(
                      label: s.stationName,
                      icon: Icons.warehouse,
                      isSelected: sel,
                      onTap: () {
                        setState(() {
                          _selectedStation = s;
                          _selectedCustomer = null;
                        });
                        _loadCustomers(s.stationID);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════ CUSTOMER SELECTOR ═══════════════════════

  void _showCustomerSelector() {
    if (_selectedStation == null) {
      _showSnack('Select a station first', isError: true);
      return;
    }
    if (_customers.isEmpty) {
      _showSnack('No customers for this station', isError: true);
      return;
    }

    final ctrl = TextEditingController();
    List<CustomerDto> filtered = _customers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => _sheet(
          height: 0.75,
          child: Column(
            children: [
              _sheetHeader('Select Customer', Icons.person, ctx),
              _searchField(ctrl, 'Search customers...', (q) {
                setModal(() {
                  filtered = q.isEmpty
                      ? _customers
                      : _customers
                            .where(
                              (c) => c.customerName.toLowerCase().contains(
                                q.toLowerCase(),
                              ),
                            )
                            .toList();
                });
              }),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final sel = _selectedCustomer?.customerID == c.customerID;
                    return _sheetItemTile(
                      label: c.customerName,
                      icon: Icons.person_outline,
                      isSelected: sel,
                      subtitle: c.customerPhone,
                      onTap: () {
                        setState(() => _selectedCustomer = c);
                        Navigator.pop(ctx);
                        _loadItemsToReturn();
                        _returnFocusToScanner();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════ ADD UNTAGGED TYPE ════════════════════════

  void _showAddCylinderTypeDialog() {
    // Available = all lubricants not already added to untagged list
    final available = _lubricants
        .where((e) => !_untaggedQtyControllers.containsKey(e['LubId'] as int))
        .toList();

    if (available.isEmpty && _lubricants.isEmpty) {
      _showSnack('Loading cylinder types, please wait...', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add Cylinder Type',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (available.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'All cylinder types have already been added.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                // List of cylinder types — tap to select immediately (no Add btn)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: available.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (_, i) {
                      final item = available[i];
                      final lubId = item['LubId'] as int;
                      final lubName = item['LubName'] as String;
                      return InkWell(
                        onTap: () {
                          _addUntaggedType(lubId);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Text(
                            lubName,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════ CAMERA SCANNER ════════════════════════════

  void _toggleScannerMode(bool useCamera) {
    setState(() {
      _useCameraScanner = useCamera;
      if (useCamera) {
        _cameraController = MobileScannerController();
        _userIsTyping = true; // stop physical scanner stealing focus
      } else {
        _cameraController?.dispose();
        _cameraController = null;
        _userIsTyping = false;
        Future.delayed(const Duration(milliseconds: 100), () {
          FocusScope.of(context).requestFocus(_focusNode);
        });
      }
    });
  }

  void _onCameraDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode != null && barcode.isNotEmpty) {
      _processScan(barcode.trim());
    }
  }

  // ═══════════════════════════ BUILD ═══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStations) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      );
    }

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              // ── Title ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_circle_left,
                        color: Colors.white,
                      ),
                      onPressed: _isCreatingReturn ? null : widget.onBack,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ADD RETURN',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // ── Scanner toggle ──────────────────────────────
                    if (_returnStatus == 'tagged' || _returnStatus == 'both')
                      _buildScannerToggle(),
                  ],
                ),
              ),

              // ── Camera scanner view ────────────────────────────────
              if (_useCameraScanner &&
                  (_returnStatus == 'tagged' || _returnStatus == 'both'))
                Container(
                  height: 180,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryOrange, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: MobileScanner(
                      controller: _cameraController!,
                      onDetect: _onCameraDetect,
                    ),
                  ),
                ),

              // ── Scrollable content ────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // ── Search ────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          onTap: () => _userIsTyping = true,
                          onChanged: (_) => _userIsTyping = true,
                          decoration: InputDecoration(
                            hintText: 'Search scanned barcodes',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _applySearch();
                                      _userIsTyping = false;
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_focusNode);
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),

                      // ── Dropdowns + Status ────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            // Station
                            _stations.length == 1
                                ? _autoField(
                                    Icons.warehouse,
                                    _selectedStation!.stationName,
                                  )
                                : _tapField(
                                    icon: Icons.warehouse,
                                    value: _selectedStation?.stationName,
                                    placeholder: 'Select Station',
                                    onTap: _showStationSelector,
                                  ),

                            const SizedBox(height: 10),

                            // Customer
                            _isLoadingCustomers
                                ? _loadingField('Loading customers...')
                                : _tapField(
                                    icon: Icons.person,
                                    value: _selectedCustomer?.customerName,
                                    placeholder: _selectedStation == null
                                        ? 'Select station first'
                                        : 'Select Customer',
                                    isDisabled: _selectedStation == null,
                                    onTap: _selectedStation == null
                                        ? null
                                        : _showCustomerSelector,
                                  ),

                            const SizedBox(height: 10),

                            // Return Status
                            _buildReturnStatusSelector(),

                            // Cylinder filter badges
                            if (_scannedBarcodes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 10,
                                ),
                                child: _buildCylinderBadges(),
                              ),
                          ],
                        ),
                      ),

                      // ── Scanned list ──────────────────────────────
                      SizedBox(
                        height: 300,
                        child:
                            _filteredScans.isEmpty &&
                                _returnStatus != 'not-tagged' &&
                                _returnStatus != 'both'
                            ? const Center(
                                child: Text(
                                  'No scans',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredScans.length,
                                itemBuilder: (_, i) {
                                  final barcode = _filteredScans[i].key;
                                  final lubName =
                                      _scannedBarcodeLubName[barcode] ?? '';
                                  return Dismissible(
                                    key: ValueKey(barcode),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (_) =>
                                        _confirmDelete(barcode),
                                    onDismissed: (_) => _deleteBarcode(barcode),
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: Colors.red,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.propane_tank_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        title: Text(
                                          barcode,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                        trailing: Text(
                                          lubName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ── Action Buttons ────────────────────────────────────
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Submit
                    Expanded(
                      child: TextButton(
                        onPressed: _isCreatingReturn
                            ? null
                            : (_isActionEnabled ? _submitAction : null),
                        child: Opacity(
                          opacity: _isActionEnabled && !_isCreatingReturn
                              ? 1.0
                              : 0.4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isCreatingReturn
                                    ? [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500,
                                      ]
                                    : [Colors.white, AppTheme.primaryOrange],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isCreatingReturn) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    _isCreatingReturn
                                        ? 'Creating...'
                                        : 'Create Return',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _isCreatingReturn
                                          ? Colors.white
                                          : Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Reset
                    TextButton(
                      onPressed: _canReset && !_isCreatingReturn
                          ? _resetForm
                          : null,
                      child: Opacity(
                        opacity: _canReset && !_isCreatingReturn ? 1.0 : 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 18,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white, Colors.redAccent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restart_alt,
                                color: Colors.red,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Reset',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
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

              // ── Hidden scanner ────────────────────────────────────
              SizedBox(
                height: 0,
                width: 0,
                child: TextField(
                  focusNode: _focusNode,
                  controller: _controller,
                  autofocus: true,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: _onTextChanged,
                ),
              ),
            ],
          ),
        ),

        // ── Loading overlay ───────────────────────────────────────
        if (_isCreatingReturn)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Creating return...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════ RETURN STATUS SELECTOR ══════════════════

  Widget _buildReturnStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Return Status',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildStatusButton('Tagged', 'tagged')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatusButton('Not Tagged', 'not-tagged')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatusButton('Both', 'both')),
          ],
        ),
        const SizedBox(height: 10),

        if (_returnStatus == 'tagged' || _returnStatus == 'both')
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tagged Cylinders - Scan to Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Scanned: ${_scannedBarcodes.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cylinder type will be determined automatically from barcode',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

        if (_returnStatus == 'not-tagged' || _returnStatus == 'both')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.propane_tank, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Cylinders to Return',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingItemsToReturn)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: Colors.orange),
                      ),
                    )
                  else if (_selectedCustomer == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Select a customer to see items to return',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else if (_itemsToReturn.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'No cylinders pending return for this customer',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._itemsToReturn.map((item) {
                      final lubId = item['LubId'] as int;
                      final lubName = item['LubName'] as String;
                      final maxQty = item['Quantity'] as int;
                      final ctrl = _untaggedQtyControllers[lubId];
                      if (ctrl == null) return const SizedBox.shrink();
                      return _buildItemToReturnRow(
                        lubId,
                        lubName,
                        maxQty,
                        ctrl,
                      );
                    }),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItemToReturnRow(
    int lubId,
    String lubName,
    int maxQty,
    TextEditingController ctrl,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // ── Total-to-return badge ──────────────────────────────────
            SizedBox(
              width: 72,
              height: 55,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$maxQty',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        lubName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // ── Qty input ─────────────────────────────────────────────
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                onTap: () => _userIsTyping = true,
                onChanged: (v) {
                  _userIsTyping = true;
                  // Clamp to max
                  final parsed = int.tryParse(v);
                  if (parsed != null && parsed > maxQty) {
                    ctrl.text = '$maxQty';
                    ctrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: ctrl.text.length),
                    );
                  }
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Enter qty (max $maxQty)',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, String value) {
    final isSelected = _returnStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() => _returnStatus = value);
        _returnFocusToScanner();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.white24,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.white38,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCylinderBadges() {
    final counts = _lubIdCounts;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: counts.entries.map((e) {
        final lubId = e.key;
        final count = e.value;
        final selected = _filteredLubId == lubId;
        return GestureDetector(
          onTap: () {
            setState(() => _filteredLubId = selected ? null : lubId);
            _applySearch();
          },
          child: Chip(
            backgroundColor: selected
                ? AppTheme.primaryBlue
                : AppTheme.primaryBlue.withOpacity(0.1),
            avatar: CircleAvatar(
              backgroundColor: selected ? Colors.white : AppTheme.primaryBlue,
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: selected ? AppTheme.primaryBlue : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            label: Text(
              _lubNames[lubId] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════ SCANNER TOGGLE ════════════════════════════

  Widget _buildScannerToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Physical gun icon
        Icon(
          Icons.barcode_reader,
          size: 18,
          color: !_useCameraScanner ? Colors.white : Colors.white38,
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _toggleScannerMode(!_useCameraScanner),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _useCameraScanner
                  ? AppTheme.primaryOrange
                  : Colors.white24,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: _useCameraScanner
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Camera icon
        Icon(
          Icons.camera_alt,
          size: 18,
          color: _useCameraScanner ? Colors.white : Colors.white38,
        ),
      ],
    );
  }

  // ═══════════════════════════ DIALOGS ═════════════════════════════════

  void _showErrorModal(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scan Failed'),
        content: Text(message, style: const TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _returnFocusToScanner();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String barcode) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Scan'),
          content: Text(
            'Remove barcode:\n$barcode ?',
            style: const TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ═══════════════════════════ FIELD HELPERS ════════════════════════════

  Widget _tapField({
    required IconData icon,
    required String? value,
    required String placeholder,
    VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, color: AppTheme.primaryOrange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      style: TextStyle(
                        color: value != null
                            ? Colors.black87
                            : Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _autoField(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'AUTO',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingField(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryOrange,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════ SHEET HELPERS ════════════════════════════

  Widget _sheet({required double height, required Widget child}) {
    return Container(
      height: MediaQuery.of(context).size.height * height,
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    );
  }

  Widget _sheetHeader(String title, IconData icon, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _searchField(
    TextEditingController ctrl,
    String hint,
    void Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _sheetItemTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? AppTheme.primaryOrange.withOpacity(0.2)
          : Colors.white.withOpacity(0.1),
      child: ListTile(
        leading: Icon(
          isSelected ? Icons.check_circle : icon,
          color: isSelected ? AppTheme.primaryOrange : Colors.white,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
