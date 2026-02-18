import 'dart:io';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lpg_station/screens/login.dart';
import 'package:lpg_station/screens/profile.dart';
import 'package:lpg_station/screens/sale_container.dart';
import 'package:lpg_station/screens/splash_screen.dart';
import 'package:lpg_station/screens/store_container.dart';
import 'package:lpg_station/services/auth_gate.dart';
import 'package:lpg_station/services/auth_service.dart';
import 'package:lpg_station/services/role_config.dart';
import 'package:lpg_station/theme/theme.dart';
import 'package:lpg_station/widget/gradient_scaffold.dart';

void main() async {
  // ✅ Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: primaryTheme,
      debugShowCheckedModeBanner: false,
      // ✅ Set splash as initial route
      initialRoute: '/',
      // ✅ Define named routes
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainLayout(),
      },
    );
  }
}

/// 🔥 ROOT LAYOUT — ONLY PLACE GradientScaffold IS USED
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

  @override
  void initState() {
    super.initState();
    screens = [
      const Text('Delivery'),
      const StockTabsContainer(),
      const Text('Returns'),
      const SaleContainer(),
      const Text('Summaries'),
      const ProfileScreen(),
    ];

    // Get user role
    final userRole = AuthService.instance.userRole;
    // log('ROLE: $userRole');

    // Get accessible page indices for this role
    accessibleIndices = RoleConfig.getAccessiblePages(userRole);

    // Build accessible screens based on role
    accessibleScreens = accessibleIndices
        .map((index) => screens[index])
        .toList();

    // Set default selected page based on role
    final defaultPage = RoleConfig.getDefaultPage(userRole);
    selectedIndex = accessibleIndices.indexOf(defaultPage);

    // If default page not accessible, use first accessible page
    if (selectedIndex == -1) {
      selectedIndex = 0;
    }
  }

  /// 🔹 Centralized navigation method
  void navigateToIndex(int index) {
    // Check if user has access to this page
    final userRole = AuthService.instance.userRole;
    if (!RoleConfig.hasAccessToPage(userRole, index)) {
      // Show access denied message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have access to this page'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Convert original index to accessible index
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
      // const Icon(Icons.account_balance_wallet_sharp, size: 25),
      const Icon(Icons.person_2_sharp, size: 25),
    ];

    // Build accessible nav items based on role
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
          // 🔔 Notification with badge
          SizedBox(
            width: 48,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    // open notifications
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🚪 Logout
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                final shouldLogout = await _confirmLogout();

                if (!shouldLogout) return;

                await AuthService.instance.logout();

                // ✅ Navigate to splash/auth using named route
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/auth', (route) => false);
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
