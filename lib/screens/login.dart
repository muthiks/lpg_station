import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lpg_station/services/auth_service.dart';
import 'package:lpg_station/theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  /// 🔰 LOGO
                  const Icon(Icons.lock, size: 64, color: Colors.white),
                  const SizedBox(height: 12),

                  const Text(
                    'LOGIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 32),

                  /// 🧾 FORM
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          /// USERNAME
                          TextFormField(
                            controller: _usernameCtrl,
                            enabled: !_loading, // Disable when loading
                            decoration: InputDecoration(
                              labelText: 'Username / Email',
                              labelStyle: TextStyle(
                                color: _loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                              hintText: 'Enter your username',
                              hintStyle: TextStyle(
                                color: _loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: _loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),

                          const SizedBox(height: 16),

                          /// PASSWORD
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            enabled: !_loading, // Disable when loading
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: _loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                              hintText: 'Enter your password',
                              hintStyle: TextStyle(
                                color: _loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: _loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: _loading
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.white,
                                ),
                                onPressed: _loading
                                    ? null
                                    : () =>
                                          setState(() => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),

                          const SizedBox(height: 24),

                          /// 🔘 LOGIN BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B2C3D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          /// 🔑 FORGOT PASSWORD
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {}, // Disable when loading
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 12,
                                color: _loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // Add timeout to prevent infinite spinning
      final response = await AuthService.instance
          .login(_usernameCtrl.text.trim(), _passwordCtrl.text.trim())
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                'Connection timeout. Please check your internet connection.',
              );
            },
          );

      if (AuthService.instance.isAuth) {
        if (!mounted) return;

        // ✅ Navigate to MainLayout and clear login screen
        // Navigator.of(context).pushAndRemoveUntil(
        //   MaterialPageRoute(builder: (_) => const MainLayout()),
        //   (_) => false,
        // );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showError(response['message'] ?? 'Invalid username or password');
      }
    } on SocketException catch (_) {
      // No internet connection
      _showError('No internet connection. Please check your network settings.');
    } on TimeoutException catch (e) {
      // Connection timeout
      _showError(e.message ?? 'Connection timeout');
    } on FormatException catch (_) {
      // Server returned invalid response
      _showError('Unable to reach server. Please try again later.');
    } catch (e) {
      // Generic error handling
      String errorMessage = e.toString().replaceAll('Exception:', '').trim();

      // Check for common network-related errors in the message
      if (errorMessage.toLowerCase().contains('network') ||
          errorMessage.toLowerCase().contains('connection') ||
          errorMessage.toLowerCase().contains('failed host lookup')) {
        _showError('Network error. Please check your internet connection.');
      } else if (errorMessage.isEmpty) {
        _showError('An error occurred. Please try again.');
      } else {
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
