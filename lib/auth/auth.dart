import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:io';
import '../dashboard/dashboard.dart';
import 'signup.dart';
import 'login_with_email.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.iconTheme.color),
          onPressed:
              () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
                (Route<dynamic> route) => false,
              ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Text(
                  'login.welcome'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'login.subtitle'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          theme.brightness == Brightness.light
                              ? Colors.black
                              : Colors.white,
                      foregroundColor:
                          theme.brightness == Brightness.light
                              ? Colors.white
                              : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginWithEmailScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'login.continue_with_email'.tr(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color:
                            theme.brightness == Brightness.light
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'login.or_continue_with'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (Platform.isIOS)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAppleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outline),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apple, color: theme.iconTheme.color),
                          const SizedBox(width: 8),
                          Text(
                            'login.apple'.tr(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (Platform.isAndroid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outline),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, color: theme.iconTheme.color),
                          const SizedBox(width: 8),
                          Text(
                            'login.google'.tr(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAppleSignIn() async {
    try {
      setState(() => _isLoading = true);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        oauthCredential,
      );
      await _handleLoginSuccess(userCredential);
    } catch (e) {
      print('Error during Apple sign in: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Apple sign in failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      await _handleLoginSuccess(userCredential);
    } catch (e) {
      print('Error during Google sign in: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google sign in failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLoginSuccess(UserCredential userCredential) async {
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
      print('Error during login success handling: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('login.error_generic'.tr()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
