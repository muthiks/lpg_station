import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:lpg_station/models/return_summary_model.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';
import 'package:lpg_station/theme/theme.dart';

class ReturnSummary extends StatefulWidget {
  const ReturnSummary({super.key});

  @override
  State<ReturnSummary> createState() => _ReturnSummaryState();
}

class _ReturnSummaryState extends State<ReturnSummary> {
  // ── loading ─────────────────────────────────────────
  bool _isLoadingStations = true;
  bool _isLoadingData = false;
  String? _errorMessage;

  // ── data ────────────────────────────────────────────
  List<StationDto> _stations = [];
  ReturnSummaryResponse? _summaryData;

  // ── selection ───────────────────────────────────────
  StationDto? _selectedStation;
  DateTime _selectedDate = DateTime.now();

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
        if (_stations.length == 1) {
          _selectedStation = _stations.first;
          _loadSummary();
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingStations = false;
        _errorMessage = 'Failed to load stations: $e';
      });
      log('Error loading stations: $e');
    }
  }

  Future<void> _loadSummary() async {
    if (_selectedStation == null) return;

    setState(() {
      _isLoadingData = true;
      _summaryData = null;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getReturnSummary(
        stationId: _selectedStation!.stationID,
        returnDate: _selectedDate,
      );
      setState(() {
        _summaryData = data;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load summary: $e';
      });
      log('Error loading return summary: $e');
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
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
                // List
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
                                  Navigator.pop(ctx);
                                  _loadSummary();
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

  // ═══════════════════════════ DATE PICKER ═════════════════════════════

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.primaryOrange,
            onPrimary: Colors.white,
            surface: AppTheme.primaryBlue,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSummary();
    }
  }

  // ═══════════════════════════ BUILD ═══════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStations) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (_errorMessage != null && _stations.isEmpty) {
      return _errorView(_errorMessage!, _loadStations);
    }

    return Column(
      children: [
        // ── Station Selector ──────────────────────────
        if (_stations.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: InkWell(
              onTap: _showStationSelector,
              child: _dropdownBox(
                icon: Icons.warehouse,
                text: _selectedStation?.stationName ?? 'Select Station',
                hasValue: _selectedStation != null,
              ),
            ),
          ),

        if (_stations.length == 1 && _selectedStation != null)
          _singleStationLabel(_selectedStation!.stationName),

        const SizedBox(height: 12),

        // ── Date Picker ───────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: _pickDate,
            child: _dropdownBox(
              icon: Icons.calendar_today,
              text:
                  '${_selectedDate.day.toString().padLeft(2, '0')}/'
                  '${_selectedDate.month.toString().padLeft(2, '0')}/'
                  '${_selectedDate.year}',
              hasValue: true,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Content ───────────────────────────────────
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ═══════════════════════════ CONTENT ═════════════════════════════════

  Widget _buildContent() {
    if (_selectedStation == null) {
      return _emptyState(
        icon: Icons.warehouse,
        title: 'Select a station to view return summary',
        subtitle: 'Tap the dropdown above to choose a station',
      );
    }

    if (_isLoadingData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryBlue),
            const SizedBox(height: 16),
            const Text(
              'Loading summary...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _errorView(_errorMessage!, _loadSummary);
    }

    if (_summaryData == null || _summaryData!.isEmpty) {
      return _emptyState(
        icon: Icons.assignment_return,
        title: 'No returns found',
        subtitle: 'No received returns for the selected date and station.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSummary,
      color: AppTheme.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _sectionHeader('Cylinders', Icons.propane_tank, Colors.white),
          const SizedBox(height: 10),
          ..._summaryData!.cylinders.map(_buildItemCard),
        ],
      ),
    );
  }

  // ═══════════════════════════ CARD BUILDERS ════════════════════════════

  Widget _buildItemCard(ReturnSummaryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Name + return type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.lubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.returnType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        size: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.returnType,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Quantity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primaryOrange.withOpacity(0.7),
              ),
            ),
            child: Column(
              children: [
                Text(
                  item.quantity.toString(),
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Qty',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════ SMALL HELPERS ════════════════════════════

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

  Widget _dropdownBox({
    required IconData icon,
    required String text,
    required bool hasValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          Icon(icon, color: AppTheme.primaryOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? Colors.black87 : Colors.grey[600],
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
        ],
      ),
    );
  }

  Widget _singleStationLabel(String name) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppTheme.primaryOrange, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
