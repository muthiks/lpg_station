import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:lpg_station/models/receive_model.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/services/auth_service.dart';

class ApiService {
  //static const String _baseUrl = 'https://10.0.2.2:7179/api/LpgMobile';
  static const String _baseUrl =
      'https://luqman-staging.lqadmin.com/api/LpgMobile';

  static const String _apiKey =
      'xj0F3qtEyk2Gyytvlc4FaEaazHMSyZCER4mXskX3IatStgDORlMvpwcEYQ4bowRxTsUbKSgBxcYtczV89djWtHoGea9Zv1w0Rfxt86l82ibSdWtQe0mgSioVK9Hesj7Q';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (AuthService.instance.token != null)
      'Authorization': 'Bearer ${AuthService.instance.token}',
    'X-Api-Key': _apiKey,
  };

  static Future<List<Receive>> fetchPendingReceipts() async {
    // log('Using token: ${AuthService.instance.token}');
    final response = await http.get(
      Uri.parse('$_baseUrl/GetPendingReceipts'),
      headers: _headers,
    );

    // log('STATUS: ${response.statusCode}');
    // log('BODY: ${response.body}');
    if (response.statusCode == 200) {
      /// if API returns { data: [...] }
      final List list = jsonDecode(response.body);

      return list.map((e) => Receive.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load deliveries');
    }
  }

  // Get user's stations for dropdown
  static Future<List<StationDto>> getUserStations() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/GetLpgUserStations'),
      headers: _headers,
    );
    // log('STATUS: ${response.statusCode}');
    // log('BODY: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => StationDto.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load stations');
    }
  }

  static Future<bool> receiveLpgSupply(Map<String, dynamic> payload) async {
    final url = Uri.parse('$_baseUrl/ReceiveLpgSupply');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(payload), // Just send the string directly
    );
    // log('STATUS: ${response.statusCode}');
    // log('BODY: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['IsValid'] == true;
    }
    return false;
  }

  ///GET Trucks/////
  static Future<List<DeliveryGuyDto>> getStationDeliveryGuys(
    int stationId,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/GetStationDeliveryGuys?stationId=$stationId'),
      headers: _headers,
    );

    // log('STATUS: ${response.statusCode}');
    // log('BODY: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((j) => DeliveryGuyDto.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load delivery guys: ${response.body}');
    }
  }

  // Get station stocks
  static Future<StationStockDto> getStationStock(int stationId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/GetStationLpgStock?stationId=$stationId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return StationStockDto.fromJson(data);
    } else {
      throw Exception('Failed to load stocks');
    }
  }

  static Future<List<CustomerDto>> getCustomersByStation(int stationId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/GetCustomersByStation?stationId=$stationId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => CustomerDto.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load customers');
    }
  }

  // Get sales list (optionally filtered by station)
  static Future<List<SaleDto>> getStationLpgSales({int? stationId}) async {
    String url = '$_baseUrl/GetStationLpgSales';
    if (stationId != null) {
      url += '?stationId=$stationId';
    }

    final response = await http.get(Uri.parse(url), headers: _headers);
    // log('STATUS: ${response.statusCode}');
    // log('BODY: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => SaleDto.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load sales');
    }
  }

  // Update sale status (Draft → Confirmed → Dispatched → Delivered)
  static Future<void> updateSaleStatus(int saleId, String newStatus) async {
    final response = await http.patch(
      Uri.parse('$_baseUrl/UpdateSaleStatus?saleId=$saleId&status=$newStatus'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update status: ${response.body}');
    }
  }

  // Delete a sale
  static Future<void> deleteSale(int saleId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/DeleteSale?saleId=$saleId'),
        headers: _headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete sale: ${response.body}');
      }
    } catch (e) {
      log('Error deleting sale: $e');
      rethrow;
    }
  }

  // Create a new sale
  static Future<void> createSale(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$_baseUrl/PostLpgSale');

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(data), // Just send the string directly
      );

      log('createSale status: ${response.statusCode} body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create sale: ${response.body}');
      }
      // ResponseObject: IsValid:false = business rule failure (e.g. insufficient stock)
      final result = json.decode(response.body) as Map<String, dynamic>;
      final isValid = result['isValid'] ?? result['IsValid'] ?? true;
      if (isValid == false) {
        final msg =
            result['message'] ??
            result['Message'] ??
            'Sale could not be created';
        throw Exception(msg);
      }
    } catch (e) {
      log('Error creating sale: $e');
      rethrow;
    }
  }

  // Update an existing sale
  static Future<void> updateSale(Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('$_baseUrl/UpdateLpgSale');
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(payload), // Just send the string directly
      );

      log('updateSale status: ${response.statusCode} body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to update sale: ${response.body}');
      }
      // ResponseObject: IsValid:false = business rule failure (e.g. insufficient stock)
      if (response.body.isNotEmpty) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        final isValid = result['isValid'] ?? result['IsValid'] ?? true;
        if (isValid == false) {
          final msg =
              result['message'] ??
              result['Message'] ??
              'Sale could not be updated';
          throw Exception(msg);
        }
      }
    } catch (e) {
      log('Error updating sale: $e');
      rethrow;
    }
  }
}
