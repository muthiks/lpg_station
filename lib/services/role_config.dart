// lib/config/role_config.dart
class RoleConfig {
  static const String admin = 'Admin';
  static const String driver = 'Driver';
  static const String user = 'User';
  static const String manager = 'Store Manager';
  // Add more roles as needed
  // Add more roles as needed

  // Define which pages each role can access
  static Map<String, List<int>> rolePages = {
    admin: [0, 1, 2, 3, 4, 5, 6], // All pages
    driver: [0, 2, 6],
    user: [0, 1, 2, 3, 4, 5, 6],
    manager: [0, 1, 2, 3, 4, 5, 6], // Only home and delivery
  };

  // Define default page for each role after login
  static Map<String, int> roleDefaultPage = {
    admin: 3, // Home
    driver: 0,
    user: 3,
    manager: 3, // Delivery
  };

  // Get accessible page indices for a role
  static List<int> getAccessiblePages(String? role) {
    return rolePages[role] ?? [6]; // Default to just home if role not found
  }

  // Get default page for a role
  static int getDefaultPage(String? role) {
    return roleDefaultPage[role] ?? 4; // Default to home
  }

  // Check if user has access to a specific page
  static bool hasAccessToPage(String? role, int pageIndex) {
    return rolePages[role]?.contains(pageIndex) ?? false;
  }
}
