import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:lpg_station/models/customer_model.dart';
import 'package:lpg_station/models/driver.dart';
import 'package:lpg_station/models/receive_model.dart';
import 'package:lpg_station/models/sale_model.dart';
import 'package:lpg_station/models/stock.dart';
import 'package:lpg_station/services/auth_service.dart';

class ApiService {
  static const String _baseUrl = 'https://10.0.2.2:7179/api/LpgMobile';
  // static const String _baseUrl =
  //     'https://luqman-staging.lqadmin.com/api/LpgMobile';

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
    log('STATUS: ${response.statusCode}');
    log('BODY: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => StationDto.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load stations');
    }
  }

  ///GET Trucks/////
  static Future<List<Driver>> getStationDeliveryGuys(int stationId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/GetStationDeliveryGuys?stationId=$stationId'),
      headers: _headers,
    );

    // log('STATUS: ${response.statusCode}');
    // log('BODY: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to load drivers');
    }

    final List data = jsonDecode(response.body);
    return data.map((e) => Driver.fromJson(e)).toList();
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
  static Future<List<SaleDto>> getSalesList({int? stationId}) async {
    String url = '$_baseUrl/GetSalesList';
    if (stationId != null) {
      url += '?stationId=$stationId';
    }

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => SaleDto.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load sales');
    }
  }
}
