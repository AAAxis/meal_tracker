import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'referral_code_screen.dart';
import '../meal_analysis.dart';

// Language selector widget
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  String _getFlagEmoji(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸';
      case 'ru':
        return '🇷🇺';
      case 'he':
        return '🇮🇱';
      default:
        return '🇺🇸';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      offset: const Offset(0, 56),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getFlagEmoji(context.locale.languageCode),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
            ),
          ],
        ),
      ),
      onSelected: (String languageCode) async {
        await context.setLocale(Locale(languageCode));
        // Save selected language
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_language', languageCode);
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              Text(
                _getFlagEmoji('en'),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'language.english'.tr(),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'ru',
          child: Row(
            children: [
              Text(
                _getFlagEmoji('ru'),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'language.russian'.tr(),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'he',
          child: Row(
            children: [
              Text(
                _getFlagEmoji('he'),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'language.hebrew'.tr(),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WelcomeContentScreen extends StatefulWidget {
  const WelcomeContentScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeContentScreen> createState() => _WelcomeContentScreenState();
}

class _WelcomeContentScreenState extends State<WelcomeContentScreen> {

  Future<void> _onNext() async {
    // Add vibration feedback
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 30);
    }

    // Save welcome screen completion
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);

    // Navigate to referral code screen immediately
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReferralCodeScreen(
            onNext: () {
              // This callback is handled by the referral screen itself
              // No navigation needed here
            },
            onBack: () {
              // Navigate back to welcome screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const WelcomeContentScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  Future<bool> _hasCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for various indicators of cached data
      final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
      final hasUserEmail = prefs.getString('user_email') != null;
      final hasUserName = prefs.getString('user_display_name') != null;
      final hasLocalMeals = (await Meal.loadFromLocalStorage()).isNotEmpty;
      
      // Return true if we have any cached data (indicating this might not be a fresh install)
      return hasSeenWelcome || hasUserEmail || hasUserName || hasLocalMeals;
    } catch (e) {
      print('Error checking cached data: $e');
      return false;
    }
  }

  Future<void> _clearCachedData(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all cached data
      await prefs.clear();
      await Meal.clearLocalStorage();
      
      // Set fresh install markers
      await prefs.setBool('has_seen_welcome', false);
      await prefs.setInt('app_install_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All cached data cleared! The app is now in fresh install state.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Restart the widget to reflect changes
        setState(() {});
      }
    } catch (e) {
      print('Error clearing cached data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cached data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'images/main.jpg',
            fit: BoxFit.cover,
          ),
          // Language selector
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const LanguageSelector(),
                  ],
                ),
              ),
            ),
          ),
          // Content area - bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 48.0, bottom: 16.0),
                            child: Text(
                              'wizard.welcome_title'.tr(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'wizard.welcome_subtitle'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const Spacer(),
                          // Debug option - only show in debug mode when cached data is detected
                          if (!const bool.fromEnvironment('dart.vm.product')) 
                            FutureBuilder<bool>(
                              future: _hasCachedUserData(),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) {
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.warning, color: Colors.orange, size: 20),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Debug: Cached data detected from previous install',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton(
                                              onPressed: () async {
                                                await _clearCachedData(context);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                minimumSize: Size.zero,
                                              ),
                                              child: const Text(
                                                'Clear Cached Data',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          // Next button
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _onNext,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                  child: Text(
                                    'wizard.next'.tr(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
}
