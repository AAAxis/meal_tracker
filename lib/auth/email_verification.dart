import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'auth.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendCountdown();
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_isLoading) return;

    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('verification.enter_code'.tr())),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedCode = prefs.getString('verification_code');

      if (storedCode == null) {
        throw Exception('verification.no_code_found'.tr());
      }

      if (code != storedCode) {
        throw Exception('verification.invalid_code'.tr());
      }

      await prefs.setBool('isEmailVerified', true);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isEmailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final wizardId = prefs.getString('wizard_id');
        if (wizardId != null) {
          await _firestore.collection('wizard').doc(wizardId).update({
            'isEmailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await prefs.remove('verification_code');

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
          );
        }
      } else {
        throw Exception('verification.user_not_found'.tr());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('verification.verification_error'.tr(args: [e.toString()])),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() => _isResending = true);

    try {
      final response = await http.get(
        Uri.parse('https://api.theholylabs.com/global_auth').replace(
          queryParameters: {'email': widget.email},
        ),
      );

      if (response.statusCode == 200) {
        // Store the new verification code
        final prefs = await SharedPreferences.getInstance();
        final responseData = jsonDecode(response.body);
        await prefs.setString('verification_code', responseData['verification_code']);

        setState(() {
          _resendCountdown = 60;
          _isResending = false;
        });
        _startResendCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('verification.code_resent'.tr()),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        throw Exception('Failed to resend code: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resending code: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
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
        iconTheme: theme.appBarTheme.iconTheme,
        title: Text(
          'email_verification.title'.tr(),
          style: theme.textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'verification.verify_email'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'email_verification.check_inbox'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 40,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: theme.textTheme.titleLarge,
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.colorScheme.primary),
                        ),
                        fillColor: theme.colorScheme.surface,
                        filled: true,
                      ),
                      onChanged: (value) {
                        if (value.length == 1 && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.brightness == Brightness.light ? Colors.black : Colors.white,
                  foregroundColor: theme.brightness == Brightness.light ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _verifyCode,
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'verification.verify'.tr(),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isResending || _resendCountdown > 0 ? null : _resendCode,
                child: Text(
                  _isResending
                      ? 'verification.resending'.tr()
                      : _resendCountdown > 0
                          ? 'verification.resend_countdown'.tr(args: [_resendCountdown.toString()])
                          : 'verification.resend_code'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isResending || _resendCountdown > 0
                        ? theme.colorScheme.secondary
                        : theme.brightness == Brightness.light ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
} 