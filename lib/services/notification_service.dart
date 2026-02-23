import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lpg_station/models/notification_model.dart';
import 'package:lpg_station/services/auth_service.dart';

class NotificationService extends ChangeNotifier {
  // static const String _baseUrl = 'https://10.0.2.2:7179/api/LpgMobile';
  static const String _baseUrl =
      'https://luqman-staging.lqadmin.com/api/LpgMobile';
  //static const String _baseUrl = 'https://lqadmin.com/api/LpgMobile';

  static const String _apiKey =
      'xj0F3qtEyk2Gyytvlc4FaEaazHMSyZCER4mXskX3IatStgDORlMvpwcEYQ4bowRxTsUbKSgBxcYtczV89djWtHoGea9Zv1w0Rfxt86l82ibSdWtQe0mgSioVK9Hesj7Q';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (AuthService.instance.token != null)
      'Authorization': 'Bearer ${AuthService.instance.token}',
    'X-Api-Key': _apiKey,
  };

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  int _unreadCount = 0;
  List<NotificationModel> _notifications = [];
  Timer? _pollTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _lastCount = 0;

  int get unreadCount => _unreadCount;
  List<NotificationModel> get notifications => _notifications;

  // ────────────────────────────────────────────────────────────────────────
  // Start polling for notifications every 30 seconds
  // ────────────────────────────────────────────────────────────────────────
  void startPolling() {
    stopPolling(); // Clear any existing timer
    fetchUnreadCount(); // Initial fetch
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchUnreadCount();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Fetch unread count
  // ────────────────────────────────────────────────────────────────────────
  Future<void> fetchUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/GetUnreadCount'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newCount = data['count'] ?? 0;

        // Play sound if count increased
        if (newCount > _lastCount) {
          _playNotificationSound();
        }

        _lastCount = newCount;
        _unreadCount = newCount;
        notifyListeners();
      }
    } catch (e) {
      log('Error fetching notification count: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Fetch all notifications
  // ────────────────────────────────────────────────────────────────────────
  Future<void> fetchNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/GetMyNotifications'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _notifications = data
            .map((e) => NotificationModel.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      log('Error fetching notifications: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Mark notification as read
  // ────────────────────────────────────────────────────────────────────────
  Future<void> markAsRead(int notificationId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/MarkAsRead?notificationId=$notificationId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        await Future.wait([fetchUnreadCount(), fetchNotifications()]);
      }
    } catch (e) {
      log('Error marking notification as read: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Mark all as read
  // ────────────────────────────────────────────────────────────────────────
  Future<void> markAllAsRead() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/MarkAllAsRead'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        await Future.wait([fetchUnreadCount(), fetchNotifications()]);
      }
    } catch (e) {
      log('Error marking all as read: $e');
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Play notification sound
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      log('Error playing notification sound: $e');
    }
  }
}
