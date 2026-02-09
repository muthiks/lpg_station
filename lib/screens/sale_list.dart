import 'package:flutter/material.dart';
import 'package:lpg_station/screens/sale_card.dart';
import 'package:lpg_station/theme/theme.dart';

class SaleList extends StatefulWidget {
  final VoidCallback? onNavigateToAdd;
  const SaleList({super.key, this.onNavigateToAdd});

  @override
  State<SaleList> createState() => _SaleListState();
}

class _SaleListState extends State<SaleList> {
  // Sample data - replace with actual API data
  String? selectedStation;
  String? selectedCustomer;

  final List<String> stations = ['Station 1', 'Station 2', 'Station 3'];

  List<String> customers = [];

  // Sample sales data - replace with actual API response
  final List<Map<String, dynamic>> sales = [
    {
      "LpgSaleID": 23679,
      "SaleDate": "2026-02-06T00:00:00",
      "Balance": 2200,
      "CustomerID": 7780,
      "CustomerName": "JAMWAS BEAUTY SHOP- CBD",
      "InvoiceNo": "3247/Feb/12-26",
      "DeliveryGuy": "N/A",
      "Dispatcher": null,
      "Total": 2200,
      "Status": "Draft",
      "IsApproved": true,
      "Comments": "",
      "CustomerType": "Prepaid",
      "SaleDetails": [
        {
          "SaleDetailID": 26177,
          "LpgSaleID": 23679,
          "CylinderID": 1,
          "LubId": 1,
          "PriceType": "Custom",
          "Price": 1100,
          "CylinderPrice": 2500,
          "CylinderAmount": 0,
          "Quantity": 2,
          "Amount": 2200,
          "CylStatus": "Lease",
          "LubName": "6KG",
          "Capacity": 6,
        },
      ],
    },
    {
      "LpgSaleID": 23678,
      "SaleDate": "2026-02-06T00:00:00",
      "Balance": 16000,
      "CustomerID": 7644,
      "CustomerName": "CAFE CASSIA",
      "InvoiceNo": "3246/Feb/12-26",
      "DeliveryGuy": "N/A",
      "Dispatcher": null,
      "Total": 16000,
      "Status": "Draft",
      "IsApproved": true,
      "Comments": "",
      "CustomerType": "Prepaid",
      "SaleDetails": [
        {
          "SaleDetailID": 26176,
          "LpgSaleID": 23678,
          "CylinderID": 4,
          "LubId": 4,
          "PriceType": "Custom",
          "Price": 8000,
          "CylinderPrice": 12000,
          "CylinderAmount": 0,
          "Quantity": 2,
          "Amount": 16000,
          "CylStatus": "Lease",
          "LubName": "50KG",
          "Capacity": 50,
        },
      ],
    },
    {
      "LpgSaleID": 23677,
      "SaleDate": "2026-02-05T00:00:00",
      "Balance": 35000,
      "CustomerID": 7799,
      "CustomerName": "HABESHA KILIMANI",
      "InvoiceNo": "3245/Feb/12-26",
      "DeliveryGuy": "N/A",
      "Dispatcher": null,
      "Total": 35000,
      "Status": "Draft",
      "IsApproved": true,
      "Comments": "",
      "CustomerType": "Prepaid",
      "SaleDetails": [
        {
          "SaleDetailID": 26173,
          "LpgSaleID": 23677,
          "CylinderID": 1,
          "LubId": 1,
          "PriceType": "Custom",
          "Price": 1000,
          "CylinderPrice": 2500,
          "CylinderAmount": 0,
          "Quantity": 3,
          "Amount": 3000,
          "CylStatus": "Lease",
          "LubName": "6KG",
          "Capacity": 6,
        },
        {
          "SaleDetailID": 26174,
          "LpgSaleID": 23677,
          "CylinderID": 2,
          "LubId": 2,
          "PriceType": "Custom",
          "Price": 2000,
          "CylinderPrice": 3650,
          "CylinderAmount": 0,
          "Quantity": 2,
          "Amount": 4000,
          "CylStatus": "Lease",
          "LubName": "13KG",
          "Capacity": 13,
        },
        {
          "SaleDetailID": 26175,
          "LpgSaleID": 23677,
          "CylinderID": 4,
          "LubId": 4,
          "PriceType": "Custom",
          "Price": 7000,
          "CylinderPrice": 12000,
          "CylinderAmount": 0,
          "Quantity": 4,
          "Amount": 28000,
          "CylStatus": "Lease",
          "LubName": "50KG",
          "Capacity": 50,
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  void _loadCustomers() {
    // Extract unique customers from sales data
    final customerSet = sales
        .map((sale) => sale['CustomerName'] as String)
        .toSet()
        .toList();
    setState(() {
      customers = ['All Customers', ...customerSet];
    });
  }

  List<Map<String, dynamic>> get filteredSales {
    return sales.where((sale) {
      if (selectedCustomer != null &&
          selectedCustomer != 'All Customers' &&
          sale['CustomerName'] != selectedCustomer) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showCustomerSelector() {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredCustomers = customers;

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
                  filteredCustomers = customers;
                } else {
                  filteredCustomers = customers
                      .where(
                        (customer) => customer.toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                      )
                      .toList();
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: const BorderRadius.only(
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
                            'Select Customer',
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
                              final isSelected = selectedCustomer == customer;

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
                                    customer,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      selectedCustomer = customer;
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

  @override
  Widget build(BuildContext context) {
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
              // Station Dropdown
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
                child: DropdownButtonFormField<String>(
                  initialValue: selectedStation,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  hint: Text('--Select Station--'),
                  decoration: InputDecoration(
                    // labelText: 'Select Station',
                    // labelStyle: TextStyle(color: AppTheme.primaryBlue),
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
                  items: stations.map((station) {
                    return DropdownMenuItem(
                      value: station,
                      child: Text(station),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStation = value;
                      // TODO: Load customers for selected station from API
                    });
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Customer Selector
              InkWell(
                onTap: () => _showCustomerSelector(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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
                  child: Row(
                    children: [
                      Icon(Icons.person, color: AppTheme.primaryOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedCustomer ?? 'Select Customer',
                          style: TextStyle(
                            color: selectedCustomer != null
                                ? Colors.black87
                                : Colors.grey[600],
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sales List
        Expanded(
          child: filteredSales.isEmpty
              ? Center(
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
                        'No sales found',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index];
                    return SaleCard(sale: sale);
                  },
                ),
        ),

        // Add Sale Button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.only(
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
}
