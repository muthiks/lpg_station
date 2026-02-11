// lib/screens/stock_balance.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:lpg_station/models/station.dart';
import 'package:lpg_station/models/stock.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/services/api_service.dart'; // Your API service

class StockBalanceScreen extends StatefulWidget {
  const StockBalanceScreen({super.key});

  @override
  State<StockBalanceScreen> createState() => _StockBalanceScreenState();
}

class _StockBalanceScreenState extends State<StockBalanceScreen> {
  bool _isLoading = true;
  bool _isLoadingStocks = false;
  String? _errorMessage;

  List<StationDto> _stations = [];
  int? _selectedStationId;
  StationStockDto? _currentStationStock;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get stations from user's claim
      final stations = await ApiService.getUserStations();

      if (stations.isEmpty) {
        setState(() {
          _stations = [];
          _isLoading = false;
          _errorMessage = 'No stations found';
        });
        return;
      }

      setState(() {
        _stations = stations;
        _isLoading = false;

        // If only one station, auto-select and load stocks
        if (_stations.length == 1) {
          _selectedStationId = _stations.first.stationID;
          _loadStationStocks(_selectedStationId!);
        } else {
          // Reset selection when multiple stations are available
          _selectedStationId = null;
          _currentStationStock = null;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _stations = [];
        _selectedStationId = null;
        _errorMessage = 'Failed to load stations: ${e.toString()}';
      });
      log('Error loading stations: $e');
    }
  }

  Future<void> _loadStationStocks(int stationId) async {
    setState(() {
      _isLoadingStocks = true;
      _errorMessage = null;
    });

    try {
      // Get stock for specific station
      final stationStock = await ApiService.getStationStock(stationId);

      setState(() {
        _currentStationStock = stationStock;
        _isLoadingStocks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStocks = false;
        _errorMessage = 'Failed to load stocks: ${e.toString()}';
      });
      log('Error loading stocks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.primaryOrange, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
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

    if (_stations.isEmpty) {
      return const Center(
        child: Text(
          'No stations assigned to your account',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      children: [
        // Station Dropdown (only show if multiple stations)
        if (_stations.length > 1) _buildStationDropdown(),

        const SizedBox(height: 16),

        // Stock Content
        Expanded(child: _buildStockContent()),
      ],
    );
  }

  Widget _buildStationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedStationId,
          hint: const Text(
            'Select Station',
            style: TextStyle(color: Colors.white70),
          ),
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
          items: _stations.isEmpty
              ? null
              : _stations.map((station) {
                  return DropdownMenuItem<int>(
                    value: station.stationID,
                    child: Text(
                      station.stationName,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
          isDense: true,
          onChanged: _stations.isEmpty
              ? null
              : (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedStationId = newValue;
                    });
                    _loadStationStocks(newValue);
                  }
                },
        ),
      ),
    );
  }

  Widget _buildStockContent() {
    if (_selectedStationId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 64,
              color: AppTheme.primaryBlue.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a station to view stocks',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isLoadingStocks) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    if (_currentStationStock == null ||
        (_currentStationStock!.cylinders.isEmpty &&
            _currentStationStock!.accessories.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.primaryBlue.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No stock available for this station',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadStationStocks(_selectedStationId!),
      color: AppTheme.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Cylinders Section
          if (_currentStationStock!.cylinders.isNotEmpty) ...[
            _buildSectionHeader('CYLINDERS', Icons.propane_tank),
            const SizedBox(height: 12),
            ..._currentStationStock!.cylinders.map(
              (cylinder) => _buildCylinderCard(cylinder),
            ),
            const SizedBox(height: 24),
          ],

          // Accessories Section
          if (_currentStationStock!.accessories.isNotEmpty) ...[
            _buildSectionHeader('ACCESSORIES', Icons.build_outlined),
            const SizedBox(height: 12),
            ..._currentStationStock!.accessories.map(
              (accessory) => _buildAccessoryCard(accessory),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 8),
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

  Widget _buildCylinderCard(CylinderStockDto cylinder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cylinder Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.propane_tank,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cylinder.cylinderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cylinder Items
          ...cylinder.items.map((item) => _buildCylinderItem(item)),
        ],
      ),
    );
  }

  Widget _buildCylinderItem(CylinderItemDto item) {
    final totalStock = (item.filled ?? 0) + (item.empty ?? 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Name and Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.lubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (item.retailPrice != null)
                Text(
                  'KSh ${item.retailPrice!.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Stock Values
          Row(
            children: [
              Expanded(
                child: _buildStockValue(
                  label: 'Filled',
                  value: item.filled ?? 0,
                  color: Colors.green,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStockValue(
                  label: 'Empty',
                  value: item.empty ?? 0,
                  color: Colors.orange,
                  icon: Icons.radio_button_unchecked,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStockValue(
                  label: 'Reserved',
                  value: item.reserved ?? 0,
                  color: AppTheme.primaryBlue,
                  icon: Icons.bookmark_outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Total Stock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Stock',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  totalStock.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessoryCard(AccessoryStockDto accessory) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accessory Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.build_outlined,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  accessory.lubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (accessory.retailPrice != null)
                Text(
                  'KSh ${accessory.retailPrice!.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Stock Values
          Row(
            children: [
              Expanded(
                child: _buildStockValue(
                  label: 'Available',
                  value: accessory.availableQty ?? 0,
                  color: Colors.green,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStockValue(
                  label: 'Reserved',
                  value: accessory.reserved ?? 0,
                  color: AppTheme.primaryBlue,
                  icon: Icons.bookmark_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockValue({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
