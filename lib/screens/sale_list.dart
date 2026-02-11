// lib/screens/sale_list.dart

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:lpg_station/models/customer_model.dart';
import 'package:lpg_station/models/stock.dart';
import 'package:lpg_station/screens/sale_card.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/api_service.dart';

class SaleList extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;
  const SaleList({super.key, this.onNavigateToAdd});

  @override
  State<SaleList> createState() => _SaleListState();
}

class _SaleListState extends State<SaleList> {
  bool _isLoadingStations = true;
  bool _isLoadingCustomers = false;
  bool _isLoadingSales = false;
  String? _errorMessage;

  List<StationDto> _stations = [];
  List<CustomerDto> _customers = [];
  List<SaleDto> _sales = [];

  int? _selectedStationId;
  int? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingStations = true;
      _errorMessage = null;
    });

    try {
      final stations = await ApiService.getUserStations();

      setState(() {
        _stations = stations;
        _isLoadingStations = false;
      });

      // Load all sales for all stations
      _loadSales(null);
    } catch (e) {
      setState(() {
        _isLoadingStations = false;
        _errorMessage = 'Failed to load stations: ${e.toString()}';
      });
      log('Error loading stations: $e');
    }
  }

  Future<void> _loadCustomers(int stationId) async {
    setState(() {
      _isLoadingCustomers = true;
    });

    try {
      final customers = await ApiService.getCustomersByStation(stationId);

      setState(() {
        _customers = customers;
        _isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCustomers = false;
      });
      log('Error loading customers: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customers: ${e.toString()}'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
    }
  }

  Future<void> _loadSales(int? stationId) async {
    setState(() {
      _isLoadingSales = true;
      _errorMessage = null;
    });

    try {
      final sales = await ApiService.getSalesList(stationId: stationId);

      setState(() {
        _sales = sales;
        _isLoadingSales = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSales = false;
        _errorMessage = 'Failed to load sales: ${e.toString()}';
      });
      log('Error loading sales: $e');
    }
  }

  List<SaleDto> get filteredSales {
    List<SaleDto> filtered = _sales;

    // Filter by station if selected
    if (_selectedStationId != null) {
      filtered = filtered
          .where((sale) => sale.stationID == _selectedStationId)
          .toList();
    }

    // Filter by customer if selected
    if (_selectedCustomerId != null) {
      filtered = filtered
          .where((sale) => sale.customerID == _selectedCustomerId)
          .toList();
    }

    return filtered;
  }

  void _onStationChanged(int? stationId) {
    setState(() {
      _selectedStationId = stationId;
      _selectedCustomerId = null; // Reset customer filter
      _customers = []; // Clear customers list
    });

    // Load customers for the selected station
    if (stationId != null) {
      _loadCustomers(stationId);
    }
  }

  void _showCustomerSelector() {
    if (_selectedStationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a station first'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
      return;
    }

    if (_customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No customers available for this station'),
          backgroundColor: AppTheme.primaryOrange,
        ),
      );
      return;
    }

    final TextEditingController searchController = TextEditingController();
    List<CustomerDto> filteredCustomers = _customers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterCustomers(String query) {
              setModalState(() {
                if (query.isEmpty) {
                  filteredCustomers = _customers;
                } else {
                  filteredCustomers = _customers
                      .where(
                        (customer) => customer.customerName
                            .toLowerCase()
                            .contains(query.toLowerCase()),
                      )
                      .toList();
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, color: AppTheme.primaryOrange),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Filter by Customer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Search Box
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search customers...',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  filterCustomers('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: filterCustomers,
                    ),
                  ),

                  // "All Customers" option
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: _selectedCustomerId == null
                          ? AppTheme.primaryOrange.withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
                      child: ListTile(
                        leading: Icon(
                          _selectedCustomerId == null
                              ? Icons.check_circle
                              : Icons.people_outline,
                          color: _selectedCustomerId == null
                              ? AppTheme.primaryOrange
                              : Colors.white,
                        ),
                        title: Text(
                          'All Customers',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: _selectedCustomerId == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = null;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),

                  // Customer List
                  Expanded(
                    child: filteredCustomers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No customers found',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              final isSelected =
                                  _selectedCustomerId == customer.customerID;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: isSelected
                                    ? AppTheme.primaryOrange.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.1),
                                child: ListTile(
                                  leading: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.person_outline,
                                    color: isSelected
                                        ? AppTheme.primaryOrange
                                        : Colors.white,
                                  ),
                                  title: Text(
                                    customer.customerName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: customer.customerPhone != null
                                      ? Text(
                                          customer.customerPhone!,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  trailing: customer.hasBalance
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryOrange
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'Bal: ${customer.balance.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              color: AppTheme.primaryOrange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedCustomerId = customer.customerID;
                                    });
                                    Navigator.pop(context);
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
        );
      },
    );
  }

  String? _getSelectedCustomerName() {
    if (_selectedCustomerId == null) return null;
    final customer = _customers.firstWhere(
      (c) => c.customerID == _selectedCustomerId,
      orElse: () => CustomerDto(
        customerID: 0,
        customerName: 'Unknown',
        balance: 0,
        // cylinderBalance: 0,
        // prepaidBalance: 0,
      ),
    );
    return customer.customerName;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStations) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

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
              onPressed: _loadInitialData,
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
        // Search Filters Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Station Dropdown (always show for filtering)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<int?>(
                  value: _selectedStationId,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  hint: const Text('All Stations'),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.warehouse,
                      color: AppTheme.primaryOrange,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Stations'),
                    ),
                    ..._stations.map((station) {
                      return DropdownMenuItem<int?>(
                        value: station.stationID,
                        child: Text(station.stationName),
                      );
                    }).toList(),
                  ],
                  onChanged: _onStationChanged,
                ),
              ),

              const SizedBox(height: 12),

              // Customer Selector (show always, but disabled if no station selected)
              InkWell(
                onTap: _selectedStationId == null || _isLoadingCustomers
                    ? null
                    : _showCustomerSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedStationId == null
                        ? Colors.grey.shade300
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: _selectedStationId == null
                            ? Colors.grey.shade600
                            : AppTheme.primaryOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isLoadingCustomers
                            ? const Text(
                                'Loading customers...',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              )
                            : Text(
                                _selectedStationId == null
                                    ? 'Select station first'
                                    : (_getSelectedCustomerName() ??
                                          'All Customers'),
                                style: TextStyle(
                                  color: _selectedStationId == null
                                      ? Colors.grey.shade600
                                      : (_selectedCustomerId != null
                                            ? Colors.black87
                                            : Colors.grey[600]),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (!_isLoadingCustomers && _selectedStationId != null)
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.primaryBlue,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sales List
        Expanded(child: _buildSalesContent()),

        // Add Sale Button (always visible)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: ElevatedButton(
            onPressed: widget.onNavigateToAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 24),
                SizedBox(width: 8),
                Text(
                  'Add Sale',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesContent() {
    // Loading sales
    if (_isLoadingSales) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }

    // Error state
    if (_errorMessage != null && _sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.primaryOrange, size: 64),
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
              onPressed: () => _loadSales(_selectedStationId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (filteredSales.isEmpty) {
      String message = 'No sales found';
      if (_selectedStationId != null && _selectedCustomerId != null) {
        message = 'No sales found for this customer';
      } else if (_selectedStationId != null) {
        message = 'No sales found for this station';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
            if (_selectedStationId != null || _selectedCustomerId != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedStationId = null;
                    _selectedCustomerId = null;
                    _customers = [];
                  });
                },
                icon: Icon(Icons.clear_all, color: AppTheme.primaryBlue),
                label: Text(
                  'Clear Filters',
                  style: TextStyle(color: AppTheme.primaryBlue),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Sales list
    return RefreshIndicator(
      onRefresh: () => _loadSales(null),
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredSales.length,
        itemBuilder: (context, index) {
          final sale = filteredSales[index];
          return SaleCard(sale: sale);
        },
      ),
    );
  }
}
