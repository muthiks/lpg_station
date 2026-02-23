// lib/screens/notification_list.dart

import 'package:flutter/material.dart';
import 'package:lpg_station/services/notification_service.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    await _notificationService.fetchNotifications();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      appBar: AppBar(
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryBlue,
        actions: [
          if (_notificationService.notifications.any((n) => !n.read))
            TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                _loadNotifications();
              },
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _notificationService.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notificationService.notifications.length,
                itemBuilder: (context, index) {
                  final notification =
                      _notificationService.notifications[index];
                  return Card(
                    color: notification.read
                        ? Colors.white.withOpacity(0.08)
                        : AppTheme.primaryOrange.withOpacity(0.15),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: notification.read
                              ? Colors.white.withOpacity(0.1)
                              : AppTheme.primaryOrange.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_shipping,
                          color: notification.read
                              ? Colors.white54
                              : AppTheme.primaryOrange,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        notification.description,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: notification.read
                              ? FontWeight.normal
                              : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Invoice: ${notification.invoiceNo}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeago.format(notification.dateAdded),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      trailing: notification.read
                          ? null
                          : Icon(
                              Icons.circle,
                              color: AppTheme.primaryOrange,
                              size: 12,
                            ),
                      onTap: () async {
                        if (!notification.read) {
                          await _notificationService.markAsRead(
                            notification.notificationID,
                          );
                          _loadNotifications();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
