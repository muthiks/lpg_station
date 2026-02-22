import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:lpg_station/models/cylinder_return.dart';
import 'package:lpg_station/models/dispatch_cylinder_validation_result.dart';
import 'package:lpg_station/models/receive_model.dart';
import 'package:lpg_station/models/return_summary_model.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/models/sale_summary_model.dart';
import 'package:lpg_station/services/auth_service.dart';

class ApiService {
  static const String _baseUrl = 'https://10.0.2.2:7179/api/LpgMobile';
  // static const String _baseUrl = 'https://lqadmin.com/api/LpgMobile';
  //static const String _baseUrl = 'https://lqadmin.com/api/LpgMobile';

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
    try {
      final response = await http.patch(
        Uri.parse(
          '$_baseUrl/UpdateSaleStatus?saleId=$saleId&status=$newStatus',
        ),
        headers: _headers,
      );

      log('updateSaleStatus: ${response.statusCode} body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to update status: \${response.body}');
      }

      // Parse ResponseObject — IsValid:false means a business rule blocked the change
      // e.g. "Cannot skip stages" or "Sale not found"
      final result = json.decode(response.body) as Map<String, dynamic>;
      final isValid = result['isValid'] ?? result['IsValid'] ?? true;
      if (isValid == false) {
        final msg =
            result['message'] ?? result['Message'] ?? 'Status update failed';
        throw Exception(msg);
      }
    } catch (e) {
      log('Error updating sale status: $e');
      rethrow;
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

  //── Dispatch sale (POST /DispatchSale) ────────────────────────────────────────
  // mode: 'Tagged' | 'NonTagged' | 'Both'
  // tagged:   { cylinderID: [barcodes] }
  // untagged: { cylinderID: count }
  static Future<void> dispatchSale({
    required int saleId,
    required String mode,
    required Map<int, List<String>> tagged,
    required Map<int, int> untagged,
  }) async {
    try {
      final payload = {
        'SaleId': saleId,
        'Mode': mode,
        'Tagged': tagged.map((k, v) => MapEntry(k.toString(), v)),
        'Untagged': untagged.map((k, v) => MapEntry(k.toString(), v)),
      };
      final url = Uri.parse('$_baseUrl/DispatchSale');
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(payload), // Just send the string directly
      );

      log('dispatchSale: ${response.statusCode} body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to dispatch: ${response.body}');
      }
      final result = json.decode(response.body) as Map<String, dynamic>;
      final isValid = result['isValid'] ?? result['IsValid'] ?? true;
      if (isValid == false) {
        throw Exception(
          result['message'] ?? result['Message'] ?? 'Dispatch failed',
        );
      }
    } catch (e) {
      log('Error dispatching sale: $e');
      rethrow;
    }
  }

  // ── Validate a scanned cylinder before adding to dispatch list ────────────────
  static Future<CylinderValidationResult> validateDispatchCylinder({
    required String barcode,
    required int stationId,
    required int saleId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/ValidateDispatchCylinder?barcode=${Uri.encodeComponent(barcode)}&stationId=$stationId&saleId=$saleId',
        ),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        return CylinderValidationResult(
          isValid: false,
          message: 'Validation request failed',
        );
      }
      final data = json.decode(response.body) as Map<String, dynamic>;
      final isValid = data['isValid'] ?? data['IsValid'] ?? false;
      final message = data['message'] ?? data['Message'] ?? '';
      final cylID = data['lubId'] ?? data['LubId'];
      final lubName = data['lubName'] ?? data['LubName'] ?? '';

      if (isValid == false) {
        return CylinderValidationResult(isValid: false, message: message);
      }
      // Server already validated LubId — trust the response
      return CylinderValidationResult(
        isValid: true,
        message: '',
        lubId: cylID as int?,
        lubName: lubName,
      );
    } catch (e) {
      log('Error validating cylinder: $e');
      return CylinderValidationResult(
        isValid: false,
        message: 'Validation error: $e',
      );
    }
  }

  // Get sale summary grouped by cylinders and accessories
  static Future<SaleSummaryResponse> getItemsSaleSummary({
    required int stationId,
    required DateTime saleDate,
  }) async {
    final formattedDate =
        '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}-${saleDate.day.toString().padLeft(2, '0')}';

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/GetItemsSaleSummary?stationId=$stationId&saleDate=$formattedDate',
      ),
      headers: _headers,
    );

    log('getItemsSaleSummary: ${response.statusCode} body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SaleSummaryResponse.fromJson(data);
    } else {
      throw Exception('Failed to load sale summary: ${response.body}');
    }
  }

  static Future<ReturnSummaryResponse> getReturnSummary({
    required int stationId,
    required DateTime returnDate,
  }) async {
    final formattedDate =
        '${returnDate.year}-${returnDate.month.toString().padLeft(2, '0')}-${returnDate.day.toString().padLeft(2, '0')}';

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/GetReturnSummary?stationId=$stationId&returnDate=$formattedDate',
      ),
      headers: _headers,
    );

    log('getReturnSummary: ${response.statusCode} body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return ReturnSummaryResponse.fromJson(data);
    } else {
      throw Exception('Failed to load return summary: ${response.body}');
    }
  }

  static Future<List<CylinderReturn>> fetchPendingReturns({
    int? stationId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/GetPendingStationReturns'),
      headers: _headers,
    );

    log('fetchPendingReturns: ${response.statusCode} body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final returns = data
          .map((e) => CylinderReturn.fromJson(e as Map<String, dynamic>))
          .toList();
      // Client-side station filter if provided
      if (stationId != null) {
        return returns.where((r) => r.stationId == stationId).toList();
      }
      return returns;
    } else {
      throw Exception('Failed to load pending returns: ${response.body}');
    }
  }

  static Future<List<CylinderReturn>> fetchCompletedReturns({
    int? stationId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/GetCompletedStationReturns'),
      headers: _headers,
    );

    log('fetchCompletedReturns: ${response.statusCode} body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final returns = data
          .map((e) => CylinderReturn.fromJson(e as Map<String, dynamic>))
          .toList();
      // Client-side station filter if provided
      if (stationId != null) {
        return returns.where((r) => r.stationId == stationId).toList();
      }
      return returns;
    } else {
      throw Exception('Failed to load completed returns: ${response.body}');
    }
  }

  // Validate return cylinder
  static Future<Map<String, dynamic>> validateReturnCylinder({
    required String barcode,
    required int stationId,
  }) async {
    final uri = Uri.parse('$_baseUrl/ValidateStationReturnCylinder').replace(
      queryParameters: {'barcode': barcode, 'stationId': stationId.toString()},
    );

    final response = await http.get(uri, headers: _headers);

    log(
      'validateReturnCylinder: ${response.statusCode} body: ${response.body}',
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    // Surface the server message to the UI as the error text
    String message;
    try {
      final body = json.decode(response.body);
      message = body is String
          ? body
          : (body['message'] ?? body['Message'] ?? response.body);
    } catch (_) {
      message = response.body;
    }

    throw Exception(message);
  }

  // Create return
  static Future<Map<String, dynamic>> createStationReturn(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/PostStationCylinderReturn'),
      headers: _headers,
      body: jsonEncode(payload),
    );

    // log('STATUS: ${response.statusCode}');
    // log('BODY: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Refill failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getItemsToReturnPerCustomer({
    required int customerId,
    required int stationId,
  }) async {
    final uri = Uri.parse('$_baseUrl/GetItemsToReturnPerCustomer').replace(
      queryParameters: {
        'customerId': customerId.toString(),
        'stationId': stationId.toString(),
      },
    );

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List;
      return list
          .map(
            (e) => {
              'LubId': (e['lubId'] ?? e['LubId']) as int,
              'LubName': (e['lubName'] ?? e['LubName']) as String,
              'Quantity': (e['quantity'] ?? e['Quantity']) as int,
            },
          )
          .toList();
    }

    throw Exception('Failed to load items to return: ${response.body}');
  }
}
