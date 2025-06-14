import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/paywall_service.dart';
import '../auth/auth.dart';

class ReferralCodeScreen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ReferralCodeScreen({
    Key? key,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  _ReferralCodeScreenState createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDarkMode 
                        ? Theme.of(context).cardColor 
                        : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.card_giftcard,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Subtitle
                  Text(
                    'wizard.have_referral_code'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Input field
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Theme.of(context).cardColor : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _errorMessage != null ? Colors.red : Theme.of(context).dividerColor,
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'wizard.enter_code'.tr(),
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.normal,
                          letterSpacing: 1,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return newValue.copyWith(
                            text: newValue.text.toUpperCase(),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _applyReferralCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                              ),
                            )
                          : Text(
                              'wizard.apply_code'.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Skip button - navigate directly to auth
                  TextButton(
                    onPressed: _isLoading ? null : () async {
                      // Save wizard completion status
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('has_seen_welcome', true);
                      
                      // Navigate directly to auth screen
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      }
                    },
                    child: Text(
                      'wizard.skip'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyReferralCode() async {
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'wizard.enter_code_error'.tr();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if the referral code exists in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('referralCodes')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Valid referral code found
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('referral_code', code);
        await prefs.setBool('has_seen_welcome', true);
        
        // Track referral code in RevenueCat
        await PaywallService.trackPromoCodeUsage(code);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('wizard.referral_applied'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate directly to auth screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
          );
        }
      } else {
        // Invalid referral code
        setState(() {
          _errorMessage = 'wizard.invalid_code'.tr();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'wizard.code_check_error'.tr();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
} 