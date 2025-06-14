import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'wizard/welcome_screen.dart';
import 'user_info.dart';
import 'services/paywall_service.dart';
import 'main.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'auth/auth.dart';
import '../meal_analysis.dart';
import 'dashboard/notifications_screen.dart';
import 'dart:io';

// Extension must be outside of the class
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String userName = 'Loading...';
  String email = 'Loading...';
  bool notificationsEnabled = false;
  bool isDarkTheme = false;
  String subscriptionPlan = '';
  String subscriptionType = '';
  String subscriptionEndDate = '';
  String subscriptionStartDate = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Add a loading state for profile image upload
  bool _isUploadingProfileImage = false;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
    _checkNotificationPermission();
    _loadThemePreference();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      notificationsEnabled = status.isGranted;
    });
  }

  Future<void> _loadThemePreference() async {
    // Theme is now handled by ThemeNotifier, no need to load separately
    // The Consumer widget will automatically update when theme changes
  }

  Future<void> _toggleTheme(bool value) async {
    // Use ThemeNotifier instead of manual preference handling
    Provider.of<ThemeNotifier>(context, listen: false).setTheme(value);
  }

  Future<void> loadUserInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Initialize SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        email = user.email ?? 'No email found';
        // Immediately set display name from Firebase user
        userName = user.displayName ?? 'User';
      });

      // Get user data from Firestore as backup
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          final displayName = userData['displayName'];
          if (displayName != null && displayName.isNotEmpty) {
            setState(() {
              userName = displayName;
            });
          }
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }

      // Load subscription data from SharedPreferences
      setState(() {
        subscriptionPlan = prefs.getString('subscriptionPlan') ?? '';
        subscriptionType = prefs.getString('subscriptionType') ?? '';
        subscriptionEndDate = prefs.getString('subscriptionEndDate') ?? '';
        subscriptionStartDate = prefs.getString('subscriptionStartDate') ?? '';
      });

      // If no subscription data in SharedPreferences, try to get from Firestore
      // (Removed: Do not read from Firestore subscriptions collection)

      print(
        'Subscription Status: Plan=$subscriptionPlan, Type=$subscriptionType',
      );
      print('Dates: Start=$subscriptionStartDate, End=$subscriptionEndDate');
    }
  }

  Widget _buildSubscriptionBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 16, color: Colors.amber),
          SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              fontSize: 12,
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Show language selection dialog
  void showLanguageDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Choose Language'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('English'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Show delete account confirmation dialog
  void showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Delete Account'),
            content: Text(
              'Are you sure you want to delete your account? This cannot be undone.',
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  try {
                    User? user = _auth.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .delete();
                      await user.delete();

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Account deleted')),
                      );

                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      await prefs.clear();
                      // Reset welcome screen flag
                      await prefs.setBool('has_seen_welcome', false);
                      await _auth.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WelcomeContentScreen(),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting account: $e')),
                    );
                  }
                },
              ),
            ],
          ),
    );
  }

  // Logout and clear user data
  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Reset welcome screen flag
    await prefs.setBool('has_seen_welcome', false);
    
    // Logout from RevenueCat
    await PaywallService.logoutUser();
    
    await _auth.signOut();
    
    // Clear dashboard meals when logging out
    await handleDashboardAuthStateChange();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeContentScreen()),
    );
  }

  String _getSubscriptionTypeWithDuration(String type) {
    switch (type.toLowerCase()) {
      case 'trial':
        return 'Trial - 3 days';
      case 'premium':
        if (subscriptionPlan.contains('monthly')) {
          return 'Monthly - 30 days';
        } else if (subscriptionPlan.contains('yearly')) {
          return 'Yearly - 365 days';
        }
        return type.capitalize();
      default:
        return type.capitalize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final surfaceColor = isDark ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white70 : Colors.grey[600];
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          'settings.title'.tr(),
          style: TextStyle(color: textColor),
        ),
        iconTheme: IconThemeData(color: iconColor),
        centerTitle: false,
      ),
      body: Container(
        color: backgroundColor,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                    ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                    : null,
                  builder: (context, snapshot) {
                    String userName = this.userName;
                    String? profileImageUrl;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null) {
                        userName = data['displayName'] ?? userName;
                        profileImageUrl = data['profileImage'] as String?;
                      }
                    }
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            final picker = ImagePicker();
                            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              try {
                                setState(() { _isUploadingProfileImage = true; });
                                final storageRef = FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');
                                await storageRef.putFile(File(image.path));
                                final url = await storageRef.getDownloadURL();
                                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                                  'profileImage': url,
                                }, SetOptions(merge: true));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Profile image updated!')),
                                );
                                setState(() {}); 
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to upload profile image')),
                                );
                              } finally {
                                setState(() { _isUploadingProfileImage = false; });
                              }
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              profileImageUrl != null && profileImageUrl.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: profileImageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => CircleAvatar(
                                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                        radius: 40,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => CircleAvatar(
                                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                        radius: 40,
                                        child: Icon(Icons.person, size: 40, color: isDark ? Colors.white70 : Colors.grey[400]),
                                      ),
                                      cacheKey: profileImageUrl.hashCode.toString(),
                                      memCacheHeight: 160,
                                      memCacheWidth: 160,
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                    radius: 40,
                                    child: Icon(Icons.person, size: 40, color: isDark ? Colors.white70 : Colors.grey[400]),
                                  ),
                              if (_isUploadingProfileImage)
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userName,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode, 
                color: iconColor,
              ),
              title: Text(
                'settings.theme'.tr(),
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                isDark ? 'settings.theme_dark'.tr() : 'settings.theme_light'.tr(),
                style: TextStyle(color: subtitleColor),
              ),
              trailing: Switch(
                value: isDark,
                onChanged: _toggleTheme,
                activeColor: isDark ? Colors.white : Colors.black,
                activeTrackColor: isDark ? Colors.white54 : Colors.black54,
                inactiveThumbColor: isDark ? Colors.white : Colors.black,
                inactiveTrackColor: isDark ? Colors.white : Colors.black26,
              ),
            ),
            
            ListTile(
              leading: Icon(Icons.person, color: iconColor),
              title: Text(
                'settings.my_profile'.tr(),
                style: TextStyle(color: textColor),
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: iconColor),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserInfoScreen()),
                );
              },
            ),

            // Show subscriptions only for premium users
            FutureBuilder<bool>(
              future: PaywallService.hasActiveSubscription(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == true) {
                  return ListTile(
                    leading: Icon(Icons.subscriptions, color: iconColor),
                    title: Text(
                      'settings.subscriptions'.tr(),
                      style: TextStyle(color: textColor),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, color: iconColor),
                    onTap: () async {
                      try {
                        if (Platform.isIOS) {
                          await launchUrl(
                            Uri.parse(
                              'itms-apps://apps.apple.com/account/subscriptions',
                            ),
                          );
                        } else if (Platform.isAndroid) {
                          await launchUrl(Uri.parse('market://subscriptions'));
                        }
                      } catch (e) {
                        print('Error opening subscription settings: $e');
                      }
                    },
                  );
                } else {
                  return const SizedBox.shrink(); // Hide for non-premium users
                }
              },
            ),

            ListTile(
              leading: Icon(Icons.language, color: iconColor),
              title: Text(
                'settings.language'.tr(),
                style: TextStyle(color: textColor),
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: iconColor),
              onTap: () => _showLanguageDialog(context),
            ),
            ListTile(
              leading: Icon(Icons.privacy_tip, color: iconColor),
              title: Text(
                'settings.privacy_policy'.tr(),
                style: TextStyle(color: textColor),
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: iconColor),
              onTap: () async {
                const url = 'https://theholylabs.com/privacy';
                await launch(url);
              },
            ),
  
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text(
                'settings.logout'.tr(),
                style: TextStyle(color: Colors.red),
              ),
              onTap: logout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('settings.choose_language'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('settings.english'.tr()),
                  onTap: () {
                    context.setLocale(const Locale('en'));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('settings.hebrew'.tr()),
                  onTap: () {
                    context.setLocale(const Locale('he'));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('settings.russian'.tr()),
                  onTap: () {
                    context.setLocale(const Locale('ru'));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('settings.delete_account'.tr()),
            content: Text('settings.delete_account_confirm'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('dashboard.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'settings.delete_account'.tr(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await FirebaseAuth.instance.currentUser?.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings.account_deleted'.tr())),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.delete_error'.tr(args: [e.toString()])),
          ),
        );
      }
    }
  }
}
