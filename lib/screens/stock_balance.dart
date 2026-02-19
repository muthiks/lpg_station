// lib/screens/stock_balance.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';

class StockBalanceScreen extends StatefulWidget {
  const StockBalanceScreen({super.key});

  @override
  State<StockBalanceScreen> createState() => _StockBalanceState();
}

class _StockBalanceState extends State<StockBalanceScreen> {
  // ── loading ─────────────────────────────────────────
  bool _isLoadingStations = true;
  bool _isLoadingStock = false;
  String? _errorMessage;

  // ── data ────────────────────────────────────────────
  List<StationDto> _stations = [];
  StationStockDto? _currentStock;

  // ── selection ───────────────────────────────────────
  StationDto? _selectedStation;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  // ═══════════════════════════ DATA LOADING ════════════════════════════

  Future<void> _loadStations() async {
    setState(() {
      _isLoadingStations = true;
      _errorMessage = null;
    });

    try {
      final stations = await ApiService.getUserStations();

      setState(() {
        _stations = stations;
        _isLoadingStations = false;

        // Auto-select if only one station
        if (_stations.length == 1) {
          _selectedStation = _stations.first;
          _loadStock(_selectedStation!.stationID);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingStations = false;
        _errorMessage = 'Failed to load stations: ${e.toString()}';
      });
      log('Error loading stations: $e');
    }
  }

  Future<void> _loadStock(int stationId) async {
    setState(() {
      _isLoadingStock = true;
      _currentStock = null;
      _errorMessage = null;
    });

    try {
      final stock = await ApiService.getStationStock(stationId);

      setState(() {
        _currentStock = stock;
        _isLoadingStock = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStock = false;
        _errorMessage = 'Failed to load stock: ${e.toString()}';
      });
      log('Error loading stock: $e');
    }
  }

  // ═══════════════════════════ STATION SELECTOR ════════════════════════

  void _showStationSelector() {
    final TextEditingController search = TextEditingController();
    List<StationDto> filtered = _stations;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warehouse, color: AppTheme.primaryOrange),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Select Station',
                          style: TextStyle(
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
                ),
                // Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: search,
                    autofocus: true,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search stations...',
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
                    onChanged: (q) {
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
                    },
                  ),
                ),
                // Station list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No stations found',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final s = filtered[i];
                            final isSelected =
                                _selectedStation?.stationID == s.stationID;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected
                                  ? AppTheme.primaryOrange.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                              child: ListTile(
                                leading: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.warehouse,
                                  color: isSelected
                                      ? AppTheme.primaryOrange
                                      : Colors.white,
                                ),
                                title: Text(
                                  s.stationName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                onTap: () {
                                  setState(() => _selectedStation = s);
                                  _loadStock(s.stationID);
                                  Navigator.pop(ctx);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════ BUILD ═══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ── Initial stations loading
    if (_isLoadingStations) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    // ── Station load error
    if (_errorMessage != null && _stations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.primaryOrange, size: 48),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStations,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Station Selector ────────────────────────
        if (_stations.length > 1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: InkWell(
              onTap: _showStationSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warehouse,
                      color: AppTheme.primaryOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedStation?.stationName ?? 'Select Station',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedStation != null
                              ? Colors.black87
                              : Colors.grey[600],
                          fontWeight: _selectedStation != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
                  ],
                ),
              ),
            ),
          ),

        // ── Single station label ─────────────────────
        if (_stations.length == 1 && _selectedStation != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warehouse, color: AppTheme.primaryBlue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedStation!.stationName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
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
          ),

        // ── Content area ─────────────────────────────
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    // No station selected
    if (_selectedStation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warehouse,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a station to view stock',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the dropdown above to choose a station',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Loading stock
    if (_isLoadingStock) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBlue),
            SizedBox(height: 16),
            Text('Loading stock...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    // Stock load error
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.primaryOrange, size: 48),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadStock(_selectedStation!.stationID),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // No stock data
    if (_currentStock == null) {
      return Center(
        child: Text(
          'No stock data available',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ),
      );
    }

    final stock = _currentStock!;
    final hasCylinders = stock.cylinders.isNotEmpty;
    final hasAccessories = stock.accessories.isNotEmpty;

    if (!hasCylinders && !hasAccessories) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No stock items found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadStock(_selectedStation!.stationID),
      color: AppTheme.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Cylinders Section ──────────────────────
          if (hasCylinders) ...[
            _sectionHeader('Cylinders', Icons.propane_tank, Colors.white),
            const SizedBox(height: 10),
            ...stock.cylinders.map((c) => _buildCylinderCard(c)),
          ],

          if (hasCylinders && hasAccessories) const SizedBox(height: 8),

          // ── Accessories Section ────────────────────
          if (hasAccessories) ...[
            _sectionHeader('Accessories', Icons.settings, Colors.purple),
            const SizedBox(height: 10),
            ...stock.accessories.map((a) => _buildAccessoryCard(a)),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════ CARD BUILDERS ════════════════════════════

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCylinderCard(CylinderTypeDto cylinder) {
    // Sum totals across all items in this cylinder group
    final totalFilled = cylinder.items.fold<int>(
      0,
      (s, i) => s + (i.filled ?? 0),
    );
    final totalEmpty = cylinder.items.fold<int>(
      0,
      (s, i) => s + (i.empty ?? 0),
    );
    final totalReserved = cylinder.items.fold<int>(
      0,
      (s, i) => s + (i.reserved ?? 0),
    );
    final grandTotal = totalFilled + totalEmpty + totalReserved;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.propane_tank, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cylinder.cylinderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total: $grandTotal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats Row ──────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _statBox(
                  'Filled',
                  totalFilled,
                  Colors.tealAccent,
                  Icons.check_circle,
                ),
                const SizedBox(width: 8),
                _statBox(
                  'Empty',
                  totalEmpty,
                  Colors.orange,
                  Icons.circle_outlined,
                ),
                const SizedBox(width: 8),
                _statBox(
                  'Reserved',
                  totalReserved,
                  Colors.deepPurple,
                  Icons.lock_outline,
                ),
              ],
            ),
          ),

          // ── Per-item breakdown (if multiple items per cylinder) ──
          if (cylinder.items.length > 1)
            ...cylinder.items.map((item) => _buildCylinderItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildCylinderItemRow(CylinderItemDto item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Expanded(
            child: Text(
              item.lubName,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
          _miniStat('F', item.filled ?? 0, Colors.green),
          const SizedBox(width: 8),
          _miniStat('E', item.empty ?? 0, Colors.orange),
          const SizedBox(width: 8),
          _miniStat('R', item.reserved ?? 0, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildAccessoryCard(AccessoryDto accessory) {
    final available = accessory.availableQty ?? 0;
    final reserved = accessory.reserved ?? 0;
    final total = available + reserved;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 12),
          // Name + total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accessory.lubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total: $total',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Stats
          Row(
            children: [
              _statPill('Available', available, Colors.tealAccent),
              const SizedBox(width: 8),
              _statPill('Reserved', reserved, Colors.deepPurple),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════ SMALL HELPERS ════════════════════════════

  Widget _statBox(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
