import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lpg_station/models/receive_model.dart';
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
}
