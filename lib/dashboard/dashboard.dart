import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../meal_analysis.dart';
import '../settings.dart';
import '../auth/auth.dart';
import '../widgets/pantry_section.dart';
import '../widgets/nutrition_summary.dart';
import 'notifications_screen.dart';
import '../services/paywall_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class DashboardScreen extends StatefulWidget {
  final bool isAnalyzing;
  final Function(int, {String? categoryId, String? categoryName})? onTabChange;

  const DashboardScreen({
    Key? key,
    this.isAnalyzing = false,
    this.onTabChange,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<Meal> meals = [];
  bool _isLoading = true;
  final ImagePicker picker = ImagePicker();
  bool _isAnalyzing = false;
  String userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    loadMealsFromFirebase();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        });
      } else {
        setState(() {
          userName = 'Foodiex';
        });
      }
    } catch (e) {
      print('Error loading user name: $e');
      setState(() {
        userName = 'Foodiex';
      });
    }
  }

  void setAnalyzingState(bool analyzing) {
    setState(() {
      _isAnalyzing = analyzing;
    });
  }

  void updateMeals(List<Meal> newMeals) {
    setState(() {
      meals = newMeals;
    });
  }

  Future<void> loadMealsFromFirebase() async {
    try {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load from Firebase for authenticated users
        final snapshot = await FirebaseFirestore.instance
            .collection('analyzed_meals')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .get();

        final firebaseMeals = snapshot.docs.map((doc) {
          final data = doc.data();
          return Meal.fromMap(data, doc.id);
        }).toList();

        setState(() {
          meals = firebaseMeals;
          _isLoading = false;
        });
      } else {
        // Load from local storage for non-authenticated users
        final localMeals = await Meal.loadFromLocalStorage();
        setState(() {
          meals = localMeals;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading meals: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> refreshDashboard() async {
    await loadMealsFromFirebase();
  }

  Future<void> handleAuthStateChange() async {
    await _loadUserName();
    await loadMealsFromFirebase();
  }

  Future<void> _deleteMeal(String mealId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete from Firebase
        await FirebaseFirestore.instance
            .collection('analyzed_meals')
            .doc(mealId)
            .delete();
      } else {
        // Delete from local storage
        await Meal.deleteFromLocalStorage(mealId);
      }
      
      // Refresh the meals list
      await loadMealsFromFirebase();
    } catch (e) {
      print('Error deleting meal: $e');
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                );
              }
            },
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                : null,
              builder: (context, snapshot) {
                String? profileImageUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
                    profileImageUrl = data['profileImage'] as String?;
                  }
                }
                
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: profileImageUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                          cacheKey: profileImageUrl.hashCode.toString(),
                          memCacheHeight: 88,
                          memCacheWidth: 88,
                        ),
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      radius: 22,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'dashboard.ready_to_cook'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Debug button for App Store review (remove after approval)
          if (!ApiConfig.isProduction)
            GestureDetector(
              onTap: () => PaywallService.debugShowAvailableProducts(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Icon(
                  Icons.bug_report,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
            ),
          if (!ApiConfig.isProduction) const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationsScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection() {
    return NutritionSummary(
      meals: meals,
    );
  }

  bool _hasScansToday() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    return meals.any((meal) =>
        meal.timestamp.isAfter(startOfToday) &&
        meal.timestamp.isBefore(endOfToday) &&
        !meal.isAnalyzing &&
        !meal.analysisFailed
    );
  }

  // Helper function to check if user should have free camera access
  Future<bool> _shouldAllowFreeCameraAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      
      if (user == null) {
        // Non-authenticated user - check daily scan limit
        final localMeals = await Meal.loadFromLocalStorage();
        
        // Check referral scans first
        final hasUsedReferralCode = prefs.getBool('has_used_referral_code') ?? false;
        if (hasUsedReferralCode) {
          final referralFreeScans = prefs.getInt('referral_free_scans') ?? 0;
          final usedReferralScans = prefs.getInt('used_referral_scans') ?? 0;
          
          if (usedReferralScans < referralFreeScans) {
            print('🎁 Non-auth user has ${referralFreeScans - usedReferralScans} referral scans');
            return true;
          }
        }
        
        // Check daily scan limit (1 scan per day for non-authenticated users without referral)
        final today = DateTime.now();
        final startOfToday = DateTime(today.year, today.month, today.day);
        final endOfToday = startOfToday.add(const Duration(days: 1));
        
        final todayScans = localMeals.where((meal) =>
            meal.timestamp.isAfter(startOfToday) &&
            meal.timestamp.isBefore(endOfToday) &&
            !meal.isAnalyzing &&
            !meal.analysisFailed
        ).length;
        
        final canUseFreeScan = todayScans < 1;
        print('🔍 Non-auth user daily scan check: $canUseFreeScan (${todayScans}/1 used today)');
        return canUseFreeScan;
      } else {
        // Authenticated user - check both subscription and daily scans
        final hasActiveSubscription = await PaywallService.hasActiveSubscription();
        if (hasActiveSubscription) {
          print('✅ Auth user has active subscription');
          return true;
        }
        
        // Check referral scans first for authenticated users
        final hasUsedReferralCode = prefs.getBool('has_used_referral_code') ?? false;
        if (hasUsedReferralCode) {
          final referralFreeScans = prefs.getInt('referral_free_scans') ?? 0;
          final usedReferralScans = prefs.getInt('used_referral_scans') ?? 0;
          
          if (usedReferralScans < referralFreeScans) {
            print('🎁 Auth user has ${referralFreeScans - usedReferralScans} referral scans');
            return true;
          }
        }
        
        // Check daily scan limit for authenticated users without subscription (1 scan per day)
        final today = DateTime.now();
        final startOfToday = DateTime(today.year, today.month, today.day);
        final endOfToday = startOfToday.add(const Duration(days: 1));
        
        final snapshot = await FirebaseFirestore.instance
            .collection('analyzed_meals')
            .where('userId', isEqualTo: user.uid)
            .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfToday))
            .where('timestamp', isLessThan: Timestamp.fromDate(endOfToday))
            .get();

        final todayScans = snapshot.docs.length;
        final canUseFreeScan = todayScans < 1;
        print('🔍 Auth user daily scan check: $canUseFreeScan (${todayScans}/1 used today)');
        return canUseFreeScan;
      }
    } catch (e) {
      print('❌ Error checking free camera access: $e');
      // On error, allow access for better UX
      return true;
    }
  }

  // Trigger camera access - moved from main.dart for better architecture
  Future<void> _triggerCameraAccess() async {
    print('🚀 _triggerCameraAccess called');
    print('🎯 Context mounted: ${context.mounted}');
    
    try {
      print('🎯 About to show image source selection dialog...');
      
      final source = await showDialog<ImageSource>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          print('🎯 Dialog builder called, building AlertDialog...');
          return AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () {
                    print('📷 Gallery option tapped');
                    Navigator.of(dialogContext).pop(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () {
                    print('📸 Camera option tapped');
                    Navigator.of(dialogContext).pop(ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        },
      );
      
      print('🎯 Dialog result: $source');
      
      if (source != null) {
        print('✅ User selected: ${source == ImageSource.gallery ? "Gallery" : "Camera"}');
        
        if (context.mounted) {
          try {
            print('🎯 About to call image picker with source: $source');
            
            if (source == ImageSource.camera) {
              print('📸 Opening camera...');
              await pickAndAnalyzeImageFromCamera(
                picker: picker,
                meals: meals,
                updateMeals: updateMeals,
                context: context,
              );
            } else {
              print('📷 Opening gallery...');
              await pickAndAnalyzeImageFromGallery(
                picker: picker,
                meals: meals,
                updateMeals: updateMeals,
                context: context,
              );
            }
            
            // Refresh dashboard
            await refreshDashboard();
            
          } catch (e) {
            print('❌ Error during image analysis: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error analyzing image. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else {
        print('❌ User cancelled dialog');
      }
      
    } catch (e) {
      print('❌ Error in _triggerCameraAccess: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  Widget _buildPantrySection() {
    return PantrySection(
      meals: meals,
      onDelete: _deleteMeal,
      onRefresh: refreshDashboard,
      updateMeals: updateMeals,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: refreshDashboard,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    _buildNutritionSection(),
                    const SizedBox(height: 10),
                    _buildPantrySection(), 
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      floatingActionButton: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              // Check if user has premium subscription
              final hasActiveSubscription = await PaywallService.hasActiveSubscription();
              if (hasActiveSubscription) {
                print('✅ Auth user has active subscription');
                await _triggerCameraAccess();
                return;
              }

              // Check if user can still use free camera access
              final canUseFreeAccess = await _shouldAllowFreeCameraAccess();
              if (canUseFreeAccess) {
                print('✅ Free camera access granted');
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  print('📱 Authenticated user with subscription: unlimited scans');
                } else {
                  print('📱 Anonymous or authenticated user without subscription: checking free scans');
                }
                await _triggerCameraAccess();
                return;
              }

              // User has exceeded free scans, show paywall
              print('❌ Free scans exhausted, showing paywall');
              final prefs = await SharedPreferences.getInstance();
              final hasUsedReferralCode = prefs.getBool('has_used_referral_code') ?? false;
              final referralCode = prefs.getString('referral_code') ?? 'none';

              final paywallResult = await PaywallService.showPaywall(
                context,
                forceCloseOnRestore: true,
                metadata: {
                  'referral_code_used': hasUsedReferralCode ? referralCode : 'none',
                  'source': 'free_scans_exhausted_paywall',
                },
              );
              
              // If paywall was successful, proceed with camera access
              if (paywallResult && context.mounted) {
                await _triggerCameraAccess();
              }
            },
            child: Icon(
              Icons.add,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
} 