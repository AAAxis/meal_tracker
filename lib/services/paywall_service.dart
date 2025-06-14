import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../config/api_config.dart';
import '../main.dart';

class PaywallService {
  // Show RevenueCat remote paywall
  // Note: There's a known issue where the paywall doesn't automatically close on successful restore
  // on iOS (see: https://github.com/RevenueCat/purchases-flutter/issues/1161)
  // The paywall should return PaywallResult.restored when restore is successful, even if it doesn't auto-close
  // Set forceCloseOnRestore=true to use PaywallView with custom restore handling that always closes
  static Future<bool> showPaywall(BuildContext context, {String? offeringId, bool forceCloseOnRestore = false, Map<String, String>? metadata}) async {
    // Use custom PaywallView if user wants guaranteed close on restore
    if (forceCloseOnRestore) {
      return showPaywallWithCustomRestore(context, offeringId: offeringId, metadata: metadata);
    }
    try {
      // Check if we're on a supported platform
      if (!Platform.isIOS && !Platform.isAndroid) {
        print('❌ Paywall not supported on this platform');
        return false;
      }
      
      // Validate context
      if (!context.mounted) {
        print('❌ Context not mounted when showing paywall');
        return false;
      }
      
      // Set metadata attributes if provided
      if (metadata != null && metadata.isNotEmpty) {
        try {
          print('🏷️ Setting paywall metadata: $metadata');
          await Purchases.setAttributes(metadata);
        } catch (e) {
          print('⚠️ Error setting metadata attributes: $e');
        }
      }
      
      print('🔍 Showing RevenueCat remote paywall...');
      print('🎯 Using offering ID: ${offeringId ?? 'default'}');
      print('🔧 App context state: mounted=${context.mounted}');
      
      // Get the offering object if offeringId is provided
      Offering? offering;
      if (offeringId != null) {
        try {
          final offerings = await Purchases.getOfferings();
          
          // Debug: Print all available offerings
          print('🔍 Available offerings:');
          for (var entry in offerings.all.entries) {
            print('  - ${entry.key}: ${entry.value.identifier}');
          }
          print('🔍 Current offering: ${offerings.current?.identifier ?? 'none'}');
          
          offering = offerings.all[offeringId];
          if (offering == null) {
            print('⚠️ Offering "$offeringId" not found, using default offering');
            print('💡 Available offering IDs: ${offerings.all.keys.toList()}');
          } else {
            print('✅ Found offering: ${offering.identifier}');
          }
        } catch (e) {
          print('❌ Error fetching offering: $e');
        }
      }
      
      // Validate that we can present the paywall
      if (!context.mounted) {
        print('❌ Context became unmounted before presenting paywall');
        return false;
      }
      
      print('📱 About to present RevenueCat paywall...');
      
      // Use RevenueCatUI.presentPaywallIfNeeded method for remote paywall
      final paywallResult = offering != null 
        ? await RevenueCatUI.presentPaywallIfNeeded(ApiConfig.entitlementID, offering: offering)
        : await RevenueCatUI.presentPaywallIfNeeded(ApiConfig.entitlementID);
      
      print('📊 Paywall result: $paywallResult');
      
      if (paywallResult == PaywallResult.purchased) {
        print('✅ User made a purchase!');
        appData.entitlementIsActive = true;
        return true;
      } else if (paywallResult == PaywallResult.cancelled) {
        print('❌ User cancelled the paywall');
        return false;
      } else if (paywallResult == PaywallResult.notPresented) {
        print('ℹ️ Paywall not presented - user already has entitlement');
        appData.entitlementIsActive = true;
        return true;
      } else if (paywallResult == PaywallResult.error) {
        print('❌ Error presenting paywall');
        return false;
      } else if (paywallResult == PaywallResult.restored) {
        print('✅ User restored purchases!');
        appData.entitlementIsActive = true;
        // Check subscription status after restore to ensure it's properly updated
        await hasActiveSubscription();
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      print('❌ Platform error showing paywall: ${e.message}');
      print('❌ Platform error code: ${e.code}');
      print('❌ Platform error details: ${e.details}');
      return false;
    } catch (e) {
      print('❌ Unexpected error showing paywall: $e');
      print('❌ Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Present promo code redemption sheet (iOS only)
  static Future<bool> presentPromoCodeRedemption(BuildContext context) async {
    try {
      if (!Platform.isIOS) {
        print('⚠️ Promo code redemption is only supported on iOS');
        _showAndroidPromoCodeDialog(context);
        return false;
      }

      print('🎟️ Presenting promo code redemption sheet...');
      
      // Present the iOS promo code redemption sheet
      await Purchases.presentCodeRedemptionSheet();
      
      // Since presentCodeRedemptionSheet has no callback, we need to listen for customer info updates
      // The calling code should listen to customer info updates to detect successful redemption
      return true;
      
    } on PlatformException catch (e) {
      print('❌ Error presenting promo code redemption: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Unexpected error presenting promo code redemption: $e');
      return false;
    }
  }

  // Show Android-specific promo code dialog (since Android doesn't support discount codes)
  static void _showAndroidPromoCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Promo Codes'),
          content: const Text(
            'Discount promo codes are not supported on Android. '
            'However, you can check our special offers in the subscription options!'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showPaywall(context); // Show paywall with potential offers
              },
              child: const Text('View Offers'),
            ),
          ],
        );
      },
    );
  }

  // Create a promo code URL for iOS (for sharing via email, social media, etc.)
  static String createPromoCodeUrl(String promoCode) {
    // App ID from App Store Connect for com.theholylabs.kaliai
    const String appId = '6744427369'; // Apple App ID from App Store Connect
    return 'https://apps.apple.com/redeem?ctx=offercodes&id=$appId&code=$promoCode';
  }

  // Check if promotional offers are available for a specific product
  static Future<bool> checkPromotionalOfferEligibility(String productId) async {
    try {
      final offerings = await Purchases.getOfferings();
      final packages = offerings.current?.availablePackages ?? [];
      
      for (final package in packages) {
        if (package.storeProduct.identifier == productId) {
          // On iOS, check if there are promotional offers
          if (Platform.isIOS) {
            // This would require additional implementation to check specific promotional offers
            // For now, we'll return true if the product exists
            return true;
          }
          // On Android, check if there are subscription options with offers
          else if (Platform.isAndroid) {
            // Check if there are any subscription options beyond the base plan
            final subscriptionOptions = package.storeProduct.subscriptionOptions;
            return subscriptionOptions != null && subscriptionOptions.length > 1;
          }
        }
      }
      return false;
    } catch (e) {
      print('❌ Error checking promotional offer eligibility: $e');
      return false;
    }
  }

  // Listen for customer info updates (useful after promo code redemption)
  static void listenForCustomerInfoUpdates(
    Function(CustomerInfo) onCustomerInfoUpdate
  ) {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      onCustomerInfoUpdate(customerInfo);
    });
  }

  // Convenience method to show the specific Kali offering
  static Future<bool> showKaliProOffering(BuildContext context, {bool forceCloseOnRestore = false}) async {
    return showPaywall(context, offeringId: ApiConfig.defaultOfferingId, forceCloseOnRestore: forceCloseOnRestore);
  }

  // Show paywall for a specific entitlement ID
  static Future<bool> showPaywallForEntitlement(BuildContext context, {required String entitlementId, String? offeringId, bool forceCloseOnRestore = false}) async {
    // Use custom PaywallView if user wants guaranteed close on restore
    if (forceCloseOnRestore) {
      return showPaywallWithCustomRestoreForEntitlement(context, entitlementId: entitlementId, offeringId: offeringId);
    }
    try {
      // Check if we're on a supported platform
      if (!Platform.isIOS && !Platform.isAndroid) {
        print('Paywall not supported on this platform');
        return false;
      }
      
      print('🔍 Showing RevenueCat remote paywall for entitlement: $entitlementId');
      print('🎯 Using offering ID: ${offeringId ?? 'default'}');
      
      // Get the offering object if offeringId is provided
      Offering? offering;
      if (offeringId != null) {
        try {
          final offerings = await Purchases.getOfferings();
          
          // Debug: Print all available offerings
          print('🔍 Available offerings for entitlement:');
          for (var entry in offerings.all.entries) {
            print('  - ${entry.key}: ${entry.value.identifier}');
          }
          
          offering = offerings.all[offeringId];
          if (offering == null) {
            print('⚠️ Offering "$offeringId" not found, using default offering');
            print('💡 Available offering IDs: ${offerings.all.keys.toList()}');
          } else {
            print('✅ Found offering: ${offering.identifier}');
          }
        } catch (e) {
          print('❌ Error fetching offering: $e');
        }
      }
      
      // Use RevenueCatUI.presentPaywallIfNeeded method for remote paywall
      final paywallResult = offering != null 
        ? await RevenueCatUI.presentPaywallIfNeeded(entitlementId, offering: offering)
        : await RevenueCatUI.presentPaywallIfNeeded(entitlementId);
      
      print('📊 Paywall result: $paywallResult');
      
      if (paywallResult == PaywallResult.purchased) {
        print('✅ User made a purchase!');
        appData.entitlementIsActive = true;
        return true;
      } else if (paywallResult == PaywallResult.cancelled) {
        print('❌ User cancelled the paywall');
        return false;
      } else if (paywallResult == PaywallResult.notPresented) {
        print('ℹ️ Paywall not presented - user already has entitlement');
        appData.entitlementIsActive = true;
        return true;
      } else if (paywallResult == PaywallResult.error) {
        print('❌ Error presenting paywall');
        return false;
      } else if (paywallResult == PaywallResult.restored) {
        print('✅ User restored purchases!');
        appData.entitlementIsActive = true;
        // Check subscription status after restore to ensure it's properly updated
        await hasActiveSubscriptionForEntitlement(entitlementId);
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      print('❌ Platform error showing paywall: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Unexpected error showing paywall: $e');
      return false;
    }
  }

  // Check if user has active subscription
  static Future<bool> hasActiveSubscription() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      print('🔍 Checking subscription for user: ${customerInfo.originalAppUserId}');
      print('📋 Available entitlements: ${customerInfo.entitlements.all.keys.toList()}');
      
          EntitlementInfo? entitlement = customerInfo.entitlements.all[ApiConfig.entitlementID];
    bool isActive = entitlement?.isActive ?? false;
    
    if (entitlement != null) {
      print('✅ Found entitlement "${ApiConfig.entitlementID}": active=$isActive, expires=${entitlement.expirationDate}');
    } else {
      print('❌ Entitlement "${ApiConfig.entitlementID}" not found');
    }
      
      appData.entitlementIsActive = isActive;
      return isActive;
    } catch (e) {
      print('❌ Error checking subscription status: $e');
      return false;
    }
  }

  // Check if user is within their first 24 hours (ad-free period)
  static Future<bool> isWithinFirst24Hours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstLaunchTime = prefs.getInt('first_launch_timestamp');
      
      if (firstLaunchTime == null) {
        // First time user - set the timestamp
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('first_launch_timestamp', now);
        print('🆕 First time user - setting launch timestamp: $now');
        return true;
      }
      
      final firstLaunch = DateTime.fromMillisecondsSinceEpoch(firstLaunchTime);
      final now = DateTime.now();
      final difference = now.difference(firstLaunch);
      
      final isWithin24Hours = difference.inHours < 24;
      print('⏰ First launch: $firstLaunch');
      print('⏰ Current time: $now');
      print('⏰ Hours since first launch: ${difference.inHours}');
      print('⏰ Within 24 hours: $isWithin24Hours');
      
      return isWithin24Hours;
    } catch (e) {
      print('❌ Error checking first 24 hours: $e');
      return false;
    }
  }

  // Check if user should see ads (considers both subscription and 24-hour grace period)
  static Future<bool> shouldShowAds() async {
    try {
      // Check if user has active subscription
      final hasSubscription = await hasActiveSubscription();
      if (hasSubscription) {
        print('💎 User has subscription - no ads');
        return false;
      }
      
      // Check if user is within first 24 hours
      final isWithin24Hours = await isWithinFirst24Hours();
      if (isWithin24Hours) {
        print('🆓 User within first 24 hours - no ads');
        return false;
      }
      
      print('📺 User should see ads');
      return true;
    } catch (e) {
      print('❌ Error checking if should show ads: $e');
      // Default to showing ads on error
      return true;
    }
  }

  // Check if user has active subscription for a specific entitlement
  static Future<bool> hasActiveSubscriptionForEntitlement(String entitlementId) async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      print('🔍 Checking subscription for user: ${customerInfo.originalAppUserId}');
      print('📋 Available entitlements: ${customerInfo.entitlements.all.keys.toList()}');
      
      EntitlementInfo? entitlement = customerInfo.entitlements.all[entitlementId];
      bool isActive = entitlement?.isActive ?? false;
      
      if (entitlement != null) {
        print('✅ Found entitlement "$entitlementId": active=$isActive, expires=${entitlement.expirationDate}');
      } else {
        print('❌ Entitlement "$entitlementId" not found');
      }
      
          // Update appData if this is the main Premium entitlement
    if (entitlementId == ApiConfig.entitlementID) {
      appData.entitlementIsActive = isActive;
    }
      
      return isActive;
    } catch (e) {
      print('❌ Error checking subscription status for entitlement $entitlementId: $e');
      return false;
    }
  }

  // Link authenticated user to RevenueCat (call after user login)
  static Future<void> loginUser(String userId) async {
    try {
      await Purchases.logIn(userId);
      appData.appUserID = userId;
      print('User logged in to RevenueCat: $userId');
      
      // Check subscription status after login
      await hasActiveSubscription();
    } catch (e) {
      print('Error logging in user: $e');
    }
  }

  // Logout user from RevenueCat (call when user logs out)
  static Future<void> logoutUser() async {
    try {
      await Purchases.logOut();
      appData.appUserID = '';
      appData.entitlementIsActive = false;
      print('User logged out from RevenueCat');
    } catch (e) {
      print('Error logging out user: $e');
    }
  }

  // Complete reset of RevenueCat data (for debugging/testing)
  static Future<void> resetRevenueCatData() async {
    try {
      print('🔄 Resetting all RevenueCat data...');
      
      // Logout to clear anonymous user
      await Purchases.logOut();
      
      // Clear app data
      appData.appUserID = '';
      appData.entitlementIsActive = false;
      
      // Clear local promo code data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('used_promo_codes');
      await prefs.remove('referral_code');
      await prefs.remove('has_used_referral_code');
      await prefs.remove('referral_free_scans');
      await prefs.remove('used_referral_scans');
      
      print('✅ All RevenueCat data cleared successfully');
    } catch (e) {
      print('❌ Error resetting RevenueCat data: $e');
    }
  }

  // Restore purchases and promo code data
  // Note: If called while a paywall is open, the paywall should automatically close on successful restore
  // However, there's a known issue on iOS where this doesn't always work as expected
  static Future<bool> restorePurchases() async {
    try {
      print('🔄 Restoring purchases...');
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      print('🔍 Restore complete for user: ${customerInfo.originalAppUserId}');
      print('📋 Available entitlements after restore: ${customerInfo.entitlements.all.keys.toList()}');
      
          EntitlementInfo? entitlement = customerInfo.entitlements.all[ApiConfig.entitlementID];
    bool isActive = entitlement?.isActive ?? false;
    
    if (entitlement != null) {
      print('✅ Found entitlement "${ApiConfig.entitlementID}" after restore: active=$isActive, expires=${entitlement.expirationDate}');
    } else {
      print('❌ Entitlement "${ApiConfig.entitlementID}" not found after restore');
    }
      
      appData.entitlementIsActive = isActive;
      
      // If user has active subscription, try to restore promo code data
      if (isActive) {
        await _restorePromoCodeData(customerInfo);
      }
      
      return isActive;
    } catch (e) {
      print('❌ Error restoring purchases: $e');
      return false;
    }
  }

  // Restore promo code data from RevenueCat customer info
  static Future<void> _restorePromoCodeData(CustomerInfo customerInfo) async {
    try {
      // Check if this user has promo code attributes
      // Note: RevenueCat SDK doesn't expose custom attributes directly,
      // but we can infer from subscription details and restore basic info
      
      final prefs = await SharedPreferences.getInstance();
      final existingCodes = prefs.getStringList('used_promo_codes') ?? [];
      
      // If no local promo codes but user has active subscription,
      // create a placeholder entry indicating restored subscription
          if (existingCodes.isEmpty && customerInfo.entitlements.all[ApiConfig.entitlementID]?.isActive == true) {
      final entitlement = customerInfo.entitlements.all[ApiConfig.entitlementID]!;
        final String? purchaseDateString = entitlement.latestPurchaseDate;
        final restoreData = {
          'code': 'RESTORED_SUBSCRIPTION',
          'timestamp': purchaseDateString ?? DateTime.now().toIso8601String(),
          'platform': Platform.operatingSystem,
          'method': 'subscription_restore',
          'note': 'Subscription restored - original promo code data may be unavailable',
        };
        
        await storePromoCodeLocally('RESTORED_SUBSCRIPTION', restoreData);
        print('✅ Created restore placeholder for subscription');
      }
      
      print('✅ Promo code data restoration completed');
    } catch (e) {
      print('❌ Error restoring promo code data: $e');
    }
  }

  // Track promo code usage in RevenueCat customer attributes
  static Future<void> trackPromoCodeUsage(String promoCode) async {
    try {
      final now = DateTime.now();
      await Purchases.setAttributes({
        'promo_code_used': promoCode,
        'promo_code_date': now.toIso8601String(),
        'redemption_method': 'app_promo_screen',
      });
      print('✅ Promo code usage tracked in RevenueCat: $promoCode');
    } catch (e) {
      print('❌ Error tracking promo code usage: $e');
    }
  }

  // Get all promo codes used by current customer
  static Future<List<Map<String, String>>> getCustomerPromoCodes() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final promoCodes = <Map<String, String>>[];
      
      // Note: RevenueCat doesn't directly expose customer attributes in the SDK
      // But you can track them locally or use RevenueCat's REST API
      
      // For now, return locally stored promo codes
      final prefs = await SharedPreferences.getInstance();
      final storedCodes = prefs.getStringList('used_promo_codes') ?? [];
      
      for (String codeData in storedCodes) {
        try {
          final Map<String, dynamic> decoded = json.decode(codeData);
          promoCodes.add({
            'code': decoded['code'] ?? '',
            'date': decoded['timestamp'] ?? '',
            'platform': decoded['platform'] ?? '',
          });
        } catch (e) {
          print('Error parsing stored promo code: $e');
        }
      }
      
      return promoCodes;
    } catch (e) {
      print('❌ Error getting customer promo codes: $e');
      return [];
    }
  }

  // Store promo code locally for easy retrieval
  static Future<void> storePromoCodeLocally(String code, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedCodes = prefs.getStringList('used_promo_codes') ?? [];
      
      // Add new code data
      storedCodes.add(json.encode(data));
      
      // Keep only last 50 codes to prevent storage bloat
      if (storedCodes.length > 50) {
        storedCodes.removeRange(0, storedCodes.length - 50);
      }
      
      await prefs.setStringList('used_promo_codes', storedCodes);
      print('✅ Promo code stored locally: $code');
    } catch (e) {
      print('❌ Error storing promo code locally: $e');
    }
  }

  // Check if current subscription might be from a promo code
  static Future<bool> isSubscriptionFromPromoCode() async {
    try {
      final promoCodes = await getCustomerPromoCodes();
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.all[ApiConfig.entitlementID];
      
      if (entitlement?.isActive == true && promoCodes.isNotEmpty) {
        // Check if any promo code was used around the subscription start time
        final subscriptionDateString = entitlement!.latestPurchaseDate;
        final subscriptionDate = subscriptionDateString != null 
            ? DateTime.tryParse(subscriptionDateString) 
            : null;
        
        for (var code in promoCodes) {
          final codeDate = DateTime.tryParse(code['date'] ?? '');
          if (codeDate != null && subscriptionDate != null) {
            final difference = subscriptionDate.difference(codeDate).inDays.abs();
            // If promo code was used within 1 day of subscription, likely related
            if (difference <= 1) {
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking if subscription is from promo code: $e');
      return false;
    }
  }

  // Get customer attributes (useful for checking promo code usage)
  static Future<Map<String, String>> getCustomerAttributes() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // Note: Customer attributes are not directly accessible from CustomerInfo
      // They are stored on RevenueCat's servers and used for analytics
      // For local checking, we should use SharedPreferences or local storage
      return {};
    } catch (e) {
      print('❌ Error getting customer attributes: $e');
      return {};
    }
  }

  // Alternative paywall method that ensures closure after restore
  // This uses PaywallView in a modal bottom sheet with custom restore handling
  // The paywall ALWAYS closes after restore, regardless of whether subscriptions were found
  static Future<bool> showPaywallWithCustomRestore(BuildContext context, {String? offeringId, Map<String, String>? metadata}) async {
    try {
      print('🔍 Showing PaywallView with custom restore handling...');
      print('🎯 Using offering ID: ${offeringId ?? 'default'}');
      
      // Set metadata attributes if provided
      if (metadata != null && metadata.isNotEmpty) {
        try {
          print('🏷️ Setting PaywallView metadata: $metadata');
          await Purchases.setAttributes(metadata);
        } catch (e) {
          print('⚠️ Error setting metadata attributes for PaywallView: $e');
        }
      }
      
      // Get the offering object if offeringId is provided
      Offering? offering;
      if (offeringId != null) {
        try {
          final offerings = await Purchases.getOfferings();
          
          // Debug: Print all available offerings
          print('🔍 Available offerings for PaywallView:');
          for (var entry in offerings.all.entries) {
            print('  - ${entry.key}: ${entry.value.identifier}');
          }
          
          offering = offerings.all[offeringId];
          if (offering == null) {
            print('⚠️ Offering "$offeringId" not found for PaywallView, using default');
            print('💡 Available offering IDs: ${offerings.all.keys.toList()}');
          } else {
            print('✅ Found offering for PaywallView: ${offering.identifier}');
          }
        } catch (e) {
          print('❌ Error fetching offering for PaywallView: $e');
        }
      }
      
      bool paywallResult = false;
      
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        builder: (BuildContext modalContext) {
          return SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Builder(
                  builder: (context) {
                    try {
                      return PaywallView(
                        displayCloseButton: true,
                        offering: offering,
                        onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
                          print('✅ Purchase completed in PaywallView');
                          appData.entitlementIsActive = true;
                          paywallResult = true;
                          // Navigate back to dashboard instead of just popping
                          Navigator.of(modalContext).pushReplacement(
                            MaterialPageRoute(builder: (_) => MainTabScreen()),
                          );
                        },
                        onRestoreCompleted: (CustomerInfo customerInfo) async {
                          print('🔄 Restore completed in PaywallView');
                          
                          // Check if restore actually gave us an active subscription
                          EntitlementInfo? entitlement = customerInfo.entitlements.all[ApiConfig.entitlementID];
                          bool isActive = entitlement?.isActive ?? false;
                          
                          if (isActive) {
                            print('✅ Restore found active subscription');
                            appData.entitlementIsActive = true;
                            paywallResult = true;
                          } else {
                            print('ℹ️ Restore completed but no active subscriptions found');
                            paywallResult = false;
                          }
                          
                          // Navigate back to dashboard instead of just popping
                          Navigator.of(modalContext).pushReplacement(
                            MaterialPageRoute(builder: (_) => MainTabScreen()),
                          );
                        },
                        onDismiss: () {
                          print('❌ PaywallView dismissed by user');
                          Navigator.of(modalContext).pop(false);
                        },
                      );
                    } catch (e) {
                      print('❌ Error rendering PaywallView: $e');
                      return Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Unable to load paywall',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please try again later',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => Navigator.of(modalContext).pop(false),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          );
        },
      );
      
      // If result is null (dismissed without action), return false
      paywallResult = result ?? false;
      
      return paywallResult;
    } catch (e) {
      print('❌ Error showing PaywallView: $e');
      return false;
    }
  }

  // Alternative paywall method for specific entitlement that ensures closure after restore
  static Future<bool> showPaywallWithCustomRestoreForEntitlement(BuildContext context, {required String entitlementId, String? offeringId}) async {
    try {
      print('🔍 Showing PaywallView with custom restore handling for entitlement: $entitlementId');
      print('🎯 Using offering ID: ${offeringId ?? 'default'}');
      
      // Get the offering object if offeringId is provided
      Offering? offering;
      if (offeringId != null) {
        try {
          final offerings = await Purchases.getOfferings();
          offering = offerings.all[offeringId];
          if (offering == null) {
            print('⚠️ Offering "$offeringId" not found for PaywallView, using default');
          } else {
            print('✅ Found offering for PaywallView: ${offering.identifier}');
          }
        } catch (e) {
          print('❌ Error fetching offering for PaywallView: $e');
        }
      }
      
      bool paywallResult = false;
      
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        useRootNavigator: true,
        builder: (BuildContext modalContext) {
          return SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Builder(
                  builder: (context) {
                    try {
                      return PaywallView(
                        displayCloseButton: true,
                        offering: offering,
                        onPurchaseCompleted: (CustomerInfo customerInfo, StoreTransaction storeTransaction) {
                          print('✅ Purchase completed in PaywallView for entitlement: $entitlementId');
                          // Update appData if this is the main Premium entitlement
                          if (entitlementId == ApiConfig.entitlementID) {
                            appData.entitlementIsActive = true;
                          }
                          paywallResult = true;
                          // Navigate back to dashboard instead of just popping
                          Navigator.of(modalContext).pushReplacement(
                            MaterialPageRoute(builder: (_) => MainTabScreen()),
                          );
                        },
                        onRestoreCompleted: (CustomerInfo customerInfo) async {
                          print('🔄 Restore completed in PaywallView for entitlement: $entitlementId');
                          
                          // Check if restore actually gave us an active subscription for this entitlement
                          EntitlementInfo? entitlement = customerInfo.entitlements.all[entitlementId];
                          bool isActive = entitlement?.isActive ?? false;
                          
                          if (isActive) {
                            print('✅ Restore found active subscription for entitlement: $entitlementId');
                            // Update appData if this is the main Premium entitlement
                            if (entitlementId == ApiConfig.entitlementID) {
                              appData.entitlementIsActive = true;
                            }
                            paywallResult = true;
                          } else {
                            print('ℹ️ Restore completed but no active subscriptions found for entitlement: $entitlementId');
                            paywallResult = false;
                          }
                          
                          // Navigate back to dashboard instead of just popping
                          Navigator.of(modalContext).pushReplacement(
                            MaterialPageRoute(builder: (_) => MainTabScreen()),
                          );
                        },
                        onDismiss: () {
                          print('❌ PaywallView dismissed by user');
                          Navigator.of(modalContext).pop(false);
                        },
                      );
                    } catch (e) {
                      print('❌ Error rendering PaywallView for entitlement $entitlementId: $e');
                      return Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Unable to load paywall',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please try again later',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => Navigator.of(modalContext).pop(false),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          );
        },
      );
      
      // If result is null (dismissed without action), return false
      paywallResult = result ?? false;
      
      return paywallResult;
    } catch (e) {
      print('❌ Error showing PaywallView for entitlement $entitlementId: $e');
      return false;
    }
  }

  // Debug method to show available products (for App Store review)
  static Future<void> debugShowAvailableProducts(BuildContext context) async {
    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;
      
      if (currentOffering != null) {
        final products = currentOffering.availablePackages;
        
        String productInfo = 'Available Subscription Products:\n\n';
        for (var package in products) {
          final product = package.storeProduct;
          productInfo += '• ${product.title}\n';
          productInfo += '  ID: ${product.identifier}\n';
          productInfo += '  Price: ${product.priceString}\n';
          productInfo += '  Type: ${product.productType}\n\n';
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug: Subscription Products'),
            content: SingleChildScrollView(
              child: Text(productInfo),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error showing debug products: $e');
    }
  }
} 