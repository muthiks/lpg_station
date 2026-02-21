import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  String? _token;
  DateTime? _expiryDate;
  String? _userId;
  Timer? _authTimer;
  String? _userRole;

  // ------------------------
  // API
  // ------------------------
  //static const String _baseUrl = 'https://10.0.2.2:7179/api/Account';
  static const String _baseUrl =
      'https://luqman-staging.lqadmin.com/api/Account';

  factory AuthService() {
    return instance;
  }

  AuthService._internal();

  // ------------------------
  // Getters
  // ------------------------

  bool get isAuth => _token != null;
  String? get userId => _userId;
  String? get userRole => _userRole;

  String? get token {
    if (_expiryDate != null &&
        _expiryDate!.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }
    return null;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userId');

    if (token != null && userId != null) {
      // Load user data
      _token = token;
      _userId = userId;
      _userRole = prefs.getString('userRole');
      return true;
    }

    return false;
  }

  Future<Map<String, dynamic>> login(String userName, String password) async {
    try {
      var body = jsonEncode({'UserName': userName, 'Password': password});

      final response = await post(
        Uri.parse('$_baseUrl/Login'),
        body: body,
        headers: {"content-type": "application/json"},
      );
      log('STATUS: ${response.statusCode}');
      log('BODY: ${response.body}');

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      log('STATUS: $responseData');

      if (responseData.toString().contains('token')) {
        _token = responseData['token'];
        _expiryDate = DateTime.parse(responseData['expiration']);
        _userId = responseData['userid'];
        _userRole = responseData['userRole'];
        _autoLogout();
        // notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        final userData = json.encode({
          'token': _token,
          'userId': _userId,
          'expiryDate': _expiryDate?.toIso8601String(),
          'userRole': _userRole,
        });
        prefs.setString('userData', userData);
      } else {}

      return responseData;
    } catch (error) {
      throw Exception('Failed to load User Data: $error');
    }
  }

  // ------------------------
  // Auto Login
  // ------------------------
  Future<bool> autoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }
    final extractedUserData =
        json.decode(prefs.getString('userData').toString()) as Map;
    final expiryDate = DateTime.parse(extractedUserData['expiryDate']);

    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }
    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _expiryDate = expiryDate;
    _userRole = extractedUserData['userRole'];
    // notifyListeners();
    _autoLogout();
    return true;
  }

  // ------------------------
  // Logout (USE THIS EVERYWHERE)
  // ------------------------
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _expiryDate = null;
    _userRole = null;
    if (_authTimer != null) {
      _authTimer!.cancel();
      _authTimer = null;
    }
    // notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  // ------------------------
  // Auto Logout
  // ------------------------
  void _autoLogout() {
    _authTimer?.cancel();

    if (_expiryDate == null) return;

    final secondsToExpiry = _expiryDate!.difference(DateTime.now()).inSeconds;

    _authTimer = Timer(Duration(seconds: secondsToExpiry), logout);
  }
}
