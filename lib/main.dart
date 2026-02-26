import 'dart:io';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpg_station/screens/delivery_list.dart';
import 'package:lpg_station/screens/login.dart';
import 'package:lpg_station/screens/notification_list.dart';
import 'package:lpg_station/screens/profile.dart';
import 'package:lpg_station/screens/return_container.dart';
import 'package:lpg_station/screens/sale_container.dart';
import 'package:lpg_station/screens/splash_screen.dart';
import 'package:lpg_station/screens/store_container.dart';
import 'package:lpg_station/screens/summary_container.dart';
import 'package:lpg_station/services/auth_gate.dart';
import 'package:lpg_station/services/auth_service.dart';
import 'package:lpg_station/services/notification_service.dart';
import 'package:lpg_station/services/role_config.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/gradient_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: primaryTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainLayout(),
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int selectedIndex;
  late final List<Widget> screens;
  late List<Widget> accessibleScreens;
  late List<Widget> accessibleNavItems;
  late List<int> accessibleIndices;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    screens = [
      const DeliveryList(),
      const StockTabsContainer(),
      const ReturnContainer(),
      const SaleContainer(),
      const SummaryTabsContainer(),
      const ProfileScreen(),
    ];

    final userRole = AuthService.instance.userRole;
    accessibleIndices = RoleConfig.getAccessiblePages(userRole);
    accessibleScreens = accessibleIndices
        .map((index) => screens[index])
        .toList();

    final defaultPage = RoleConfig.getDefaultPage(userRole);
    selectedIndex = accessibleIndices.indexOf(defaultPage);

    if (selectedIndex == -1) {
      selectedIndex = 0;
    }

    // ── Start notification polling ────────────────────────────────────────
    _notificationService.startPolling();
    _notificationService.addListener(_onNotificationUpdate);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationUpdate);
    _notificationService.stopPolling();
    super.dispose();
  }

  void _onNotificationUpdate() {
    if (mounted) {
      setState(() {}); // Rebuild to update notification badge
    }
  }

  void navigateToIndex(int index) {
    final userRole = AuthService.instance.userRole;
    if (!RoleConfig.hasAccessToPage(userRole, index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have access to this page'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final accessibleIndex = accessibleIndices.indexOf(index);
    if (accessibleIndex != -1) {
      setState(() {
        selectedIndex = accessibleIndex;
      });
    }
  }

  Future<bool> _confirmLogout() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Logout', style: TextStyle(fontSize: 15)),
            content: const Text(
              'Are you sure you want to log out?',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      const Icon(Icons.delivery_dining_sharp, size: 25),
      const Icon(Icons.warehouse_sharp, size: 25),
      const Icon(Icons.download_sharp, size: 25),
      const Icon(Icons.shopping_cart_checkout_sharp, size: 25),
      const Icon(Icons.bar_chart_sharp, size: 25),
      const Icon(Icons.person_2_sharp, size: 25),
    ];

    final accessibleNavItems = accessibleIndices
        .map((index) => items[index])
        .toList();

    return GradientScaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warehouse, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'Luqman Gas',
              style: TextStyle(
                color: AppTheme.titleColor,
                fontSize: 15,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                AuthService.instance.userRole ?? 'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // ── Notification Bell (only show if there are notifications) ──────
          if (_notificationService.unreadCount > 0)
            SizedBox(
              width: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationListScreen(),
                        ),
                      ).then((_) {
                        // Refresh count after returning from notification screen
                        _notificationService.fetchUnreadCount();
                      });
                    },
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _notificationService.unreadCount > 99
                            ? '99+'
                            : '${_notificationService.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Logout Button ──────────────────────────────────────────────────
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                final shouldLogout = await _confirmLogout();

                if (!shouldLogout) return;

                await AuthService.instance.logout();

                if (mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/auth', (route) => false);
                }
              },
            ),
          ),
        ],
      ),
      body: accessibleScreens[selectedIndex],
      navigationBar: SafeArea(
        bottom: true,
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(iconTheme: IconThemeData(color: AppTheme.primaryOrange)),
          child: CurvedNavigationBar(
            color: AppTheme.primaryBlue,
            buttonBackgroundColor: Colors.white,
            items: accessibleNavItems,
            backgroundColor: Colors.transparent,
            height: 50,
            animationCurve: Curves.easeInOut,
            animationDuration: const Duration(milliseconds: 300),
            index: selectedIndex,
            onTap: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
