import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'dart:io' show Platform;
import 'dart:convert' show json;
import 'auth.dart';
import '../main.dart';
import '../dashboard/dashboard.dart';


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> saveUserInfoToPrefs({
    required String email,
    required String displayName,
    required String uid,
    Map<String, dynamic>? wizardData,
    Map<String, dynamic>? nutritionData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_display_name', displayName);
    await prefs.setString('user_id', uid);
    await prefs.setBool('isLoggedIn', true);
    if (wizardData != null) {
      await prefs.setString('wizard_data', json.encode(wizardData));
    }
    if (nutritionData != null) {
      nutritionData.forEach((key, value) async {
        if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        }
      });
    }
    print('[SharedPreferences] Saved: email=$email, displayName=$displayName, uid=$uid, wizardData=$wizardData, nutritionData=$nutritionData');
  }

  Future<void> _handleSignUpSuccess(UserCredential userCredential) async {
    try {
      final user = userCredential.user;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Save user info to SharedPreferences
      await prefs.setString('user_email', user.email ?? '');
      await prefs.setString('user_display_name', user.displayName ?? '');
      await prefs.setString('user_id', user.uid);
      await prefs.setBool('isLoggedIn', true);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Error during signup success handling: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('signup.error_generic'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'signup.create_account'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'signup.full_name'.tr(),
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.person, color: theme.iconTheme.color),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    fillColor: theme.colorScheme.surface,
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'signup.name_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'signup.email'.tr(),
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.email, color: theme.iconTheme.color),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    fillColor: theme.colorScheme.surface,
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'login.email_required'.tr();
                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'login.email_invalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'signup.password'.tr(),
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.lock, color: theme.iconTheme.color),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    fillColor: theme.colorScheme.surface,
                    filled: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'login.password_required'.tr();
                    } else if (value.length < 6) {
                      return 'signup.password_length'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.brightness == Brightness.light ? Colors.black : Colors.white,
                      foregroundColor: theme.brightness == Brightness.light ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoading ? null : () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _isLoading = true);
                        try {
                          final userCredential = await FirebaseAuth.instance
                              .createUserWithEmailAndPassword(
                            email: _emailController.text,
                            password: _passwordController.text,
                          );
                          await _handleSignUpSuccess(userCredential);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating account: $e'),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      }
                    },
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'signup.create_account'.tr(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'signup.already_have_account'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      },
                      child: Text(
                        'signup.sign_in'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}