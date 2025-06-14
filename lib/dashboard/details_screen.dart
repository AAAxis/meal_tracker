import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'ingridients_edit.dart';
import 'nutrition_edit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../meal_analysis.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/paywall_service.dart';
import 'dart:io';
import 'package:advertising_id/advertising_id.dart';

class AnalysisDetailsScreen extends StatefulWidget {
  final String analysisId;

  const AnalysisDetailsScreen({Key? key, required this.analysisId})
    : super(key: key);

  @override
  State<AnalysisDetailsScreen> createState() => _AnalysisDetailsScreenState();
}

class _AnalysisDetailsScreenState extends State<AnalysisDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _analysisData;
  String? _error;
  List<String> _notes = [];
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _hasActiveSubscription = false;
  String? _advertisingId;

  Color _getThemeAwareColor(
    BuildContext context,
    Color lightColor,
    Color darkColor,
  ) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkColor
        : lightColor;
  }

  Color getThemeAwareColor(
    BuildContext context, {
    required Color lightColor,
    required Color darkColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkColor : Colors.white;
  }

  Color _getHealthinessBackgroundColor(bool isDark) {
    String healthiness =
        (_analysisData?['healthiness'] ?? '').toString().toLowerCase();
    double opacity = isDark ? 0.15 : 0.1;

    if (healthiness.contains('healthy')) {
      return Colors.green.withOpacity(opacity);
    } else if (healthiness.contains('medium')) {
      return Colors.amber.withOpacity(opacity);
    } else if (healthiness.contains('unhealthy')) {
      return Colors.red.withOpacity(opacity);
    } else {
      return Colors.red.withOpacity(opacity);
    }
  }

  IconData _getHealthinessIcon() {
    String healthiness =
        (_analysisData?['healthiness'] ?? '').toString().toLowerCase();

    if (healthiness.contains('healthy')) {
      return Icons.check_circle;
    } else if (healthiness.contains('medium')) {
      return Icons.info;
    } else if (healthiness.contains('unhealthy')) {
      return Icons.warning;
    } else {
      return Icons.warning;
    }
  }

  Color _getHealthinessIconColor() {
    String healthiness =
        (_analysisData?['healthiness'] ?? '').toString().toLowerCase();

    if (healthiness.contains('healthy')) {
      return Colors.green;
    } else if (healthiness.contains('medium')) {
      return Colors.amber;
    } else if (healthiness.contains('unhealthy')) {
      return Colors.red;
    } else {
      return Colors.red;
    }
  }

  @override
  void initState() {
    super.initState();
    _getAdvertisingId();
    _checkSubscriptionStatus();
    _loadAnalysisFromLocal().then((_) {
      _fetchAnalysisDetails().then((_) {
        _loadNotes(); // Load notes after analysis data is fetched
      });
    });
  }

  Future<void> _getAdvertisingId() async {
    try {
      final advertisingId = await AdvertisingId.id(true);
      setState(() {
        _advertisingId = advertisingId;
      });
      print('📱 Advertising ID (IDFA/AAID): $advertisingId');
      print('📝 Add this ID as a test device in AdMob console');
    } catch (e) {
      print('❌ Error getting advertising ID: $e');
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final hasSubscription = await PaywallService.hasActiveSubscription();
      final shouldShowAds = await PaywallService.shouldShowAds();
      
      print('🔍 Subscription status: $hasSubscription');
      print('🔍 Should show ads: $shouldShowAds');
      
      setState(() {
        _hasActiveSubscription = !shouldShowAds; // Use inverse of shouldShowAds for UI logic
      });
      
      // Only load ads if user should see them (not premium and not within first 24 hours)
      if (shouldShowAds) {
        print('📱 Loading banner ad for user who should see ads');
        _loadBannerAd();
      } else {
        print('🚫 Not loading ads - user is premium or within first 24 hours');
      }
    } catch (e) {
      print('❌ Error checking subscription status: $e');
      // Load ads by default if we can't check subscription
      print('📱 Loading banner ad due to subscription check error');
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    // Try production ad units first, fallback to test ads if they fail
    final prodAdUnitId = Platform.isIOS 
        ? 'ca-app-pub-9876848164575099/4289816910'
        : 'ca-app-pub-9876848164575099/6971820574';
    
    final testAdUnitId = Platform.isIOS
        ? 'ca-app-pub-3940256099942544/2934735716'  // iOS test banner
        : 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    
    final adUnitId = prodAdUnitId; // Start with production
    
    print('📺 Loading banner ad with unit ID: $adUnitId (Platform: ${Platform.isIOS ? 'iOS' : 'Android'})');
    
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          print('✅ Banner ad loaded successfully with production ID');
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('❌ Failed to load banner ad: ${err.message} (Code: ${err.code})');
          ad.dispose();
          
          // If production ad fails, try test ad
          if (adUnitId != testAdUnitId) {
            print('🔄 Retrying with test ad unit ID: $testAdUnitId');
            _loadTestBannerAd(testAdUnitId);
          } else {
            setState(() {
              _isBannerAdReady = false;
            });
          }
        },
        onAdOpened: (_) {
          print('📺 Banner ad opened');
        },
        onAdClosed: (_) {
          print('📺 Banner ad closed');
        },
      ),
    );

    _bannerAd!.load();
  }

  void _loadTestBannerAd(String testAdUnitId) {
    _bannerAd = BannerAd(
      adUnitId: testAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          print('✅ Test banner ad loaded successfully');
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          print('❌ Test banner ad also failed: ${err.message} (Code: ${err.code})');
          setState(() {
            _isBannerAdReady = false;
          });
          ad.dispose();
        },
        onAdOpened: (_) {
          print('📺 Test banner ad opened');
        },
        onAdClosed: (_) {
          print('📺 Test banner ad closed');
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAnalysisFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('analysis_${widget.analysisId}');
      if (cached != null) {
        setState(() {
          _analysisData = json.decode(cached);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading analysis from local: $e');
    }
  }

  Future<void> _saveAnalysisToLocal(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('analysis_${widget.analysisId}', json.encode(data));
    } catch (e) {
      print('Error saving analysis to local: $e');
    }
  }

  Future<void> _fetchAnalysisDetails() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // User is authenticated - try to load from Firebase
        print('🔥 Loading meal details from Firebase for user: ${user.uid}');
        final doc = await FirebaseFirestore.instance
            .collection('analyzed_meals')
            .doc(widget.analysisId)
            .get();

        if (doc.exists && doc.data()?['userId'] == user.uid) {
          final data = doc.data()!;
          print("✅ Firebase data loaded: $data");

          // Convert Timestamp to ISO8601 string before saving to local
          if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
            data['timestamp'] =
                (data['timestamp'] as Timestamp).toDate().toIso8601String();
          }

          setState(() {
            _analysisData = data;
            _isLoading = false;
          });
          await _saveAnalysisToLocal(data);
          return;
        }
      }
      
      // User is not authenticated or meal not found in Firebase - try local storage
      print('📱 Loading meal details from local storage');
      final localMeals = await Meal.loadFromLocalStorage();
      final localMeal = localMeals.firstWhere(
        (meal) => meal.id == widget.analysisId,
        orElse: () => throw Exception('Meal not found in local storage'),
      );
      
      // Convert Meal to analysis data format
      final data = localMeal.toJson();
      print("✅ Local storage data loaded: $data");
      
      setState(() {
        _analysisData = data;
        _isLoading = false;
      });
      await _saveAnalysisToLocal(data);
      
    } catch (e) {
      print('❌ Error fetching analysis details: $e');
      setState(() {
        _error = 'Failed to fetch analysis details: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString('meal_notes_${widget.analysisId}');
      List<String> loadedNotes = [];

      if (notesJson != null) {
        final decoded = json.decode(notesJson);
        if (decoded is List) {
          loadedNotes = List<String>.from(decoded);
        } else if (decoded is Map) {
          // If notes were accidentally saved as a Map, take the values
          loadedNotes = decoded.values.map((e) => e.toString()).toList();
        }
      }

      // Add ingredients to notes if they exist and aren't already in notes
      if (_analysisData != null) {
        List<String> ingredients = [];
        
        // Handle multilingual ingredients
        if (_analysisData!['ingredients'] is Map) {
          final ingredientsMap = _analysisData!['ingredients'] as Map<String, dynamic>;
          final locale = Localizations.localeOf(context).languageCode;
          final localeIngredients = ingredientsMap[locale] ?? ingredientsMap['en'] ?? [];
          if (localeIngredients is List) {
            ingredients = List<String>.from(localeIngredients);
          }
        } else if (_analysisData!['ingredients'] is List) {
          ingredients = List<String>.from(_analysisData!['ingredients']);
        }
        
        for (var ingredient in ingredients) {
          final ingredientNote = 'Ingredient: $ingredient';
          if (!loadedNotes.contains(ingredientNote)) {
            loadedNotes.add(ingredientNote);
          }
        }
      }

      setState(() {
        _notes = loadedNotes;
      });

      // Save the updated notes
      await _saveNotes();
    } catch (e) {
      print('Error loading notes: $e');
    }
  }

  // Add a new method to refresh notes when analysis data changes
  void _refreshNotes() {
    if (_analysisData != null) {
      _loadNotes();
    }
  }

  Future<void> _saveNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'meal_notes_${widget.analysisId}',
        json.encode(_notes),
      );
    } catch (e) {
      print('Error saving notes: $e');
    }
  }

  String _formatDate(dynamic date) {
    if (date is String) {
      try {
        return DateFormat('MMMM dd, yyyy').format(DateTime.parse(date));
      } catch (e) {
        return 'Unknown date';
      }
    }
    return 'Unknown date';
  }

  String _translateValue(String key, String value) {
    // Define translation mappings
    final Map<String, Map<String, String>> translations = {
      'healthiness': {
        'healthy': 'details.healthiness.healthy',
        'medium': 'details.healthiness.medium',
        'unhealthy': 'details.healthiness.unhealthy',
      },
      'benefits': {
        'high in protein': 'details.benefits.high_protein',
        'low in fat': 'details.benefits.low_fat',
        'good source of fiber': 'details.benefits.good_fiber',
        // Add more benefit translations as needed
      },
      'nutrients': {
        'protein': 'details.nutrients.protein',
        'fiber': 'details.nutrients.fiber',
        'vitamin c': 'details.nutrients.vitamin_c',
        // Add more nutrient translations as needed
      },
    };

    // Try to find and translate the value
    if (translations.containsKey(key)) {
      final translationMap = translations[key]!;
      final lowercaseValue = value.toLowerCase();

      // Try exact match first
      if (translationMap.containsKey(lowercaseValue)) {
        return translationMap[lowercaseValue]!.tr();
      }

      // If no exact match, try partial matches
      for (var entry in translationMap.entries) {
        if (lowercaseValue.contains(entry.key)) {
          return entry.value.tr();
        }
      }
    }

    // Return original value if no translation found
    return value;
  }

  void _showEditNameDialog() {
    final locale = Localizations.localeOf(context).languageCode;
    String currentName = 'Unknown';
    if (_analysisData?['mealName'] is Map) {
      currentName = _analysisData?['mealName'][locale] ?? _analysisData?['mealName']['en'] ?? 'Unknown';
    } else {
      currentName = _analysisData?['name'] ?? _analysisData?['mealName'] ?? 'Unknown';
    }
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('details.edit_name'.tr()),
            content: TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'details.meal_name'.tr()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('dashboard.cancel'.tr()),
              ),
              TextButton(
                onPressed: () async {
                  if (nameController.text.trim().isNotEmpty) {
                    // Update only the current language in the mealName map
                    Map<String, dynamic> mealNameMap = {};
                    if (_analysisData?['mealName'] is Map) {
                      mealNameMap = Map<String, dynamic>.from(_analysisData?['mealName']);
                    } else if (_analysisData?['mealName'] is String) {
                      mealNameMap['en'] = _analysisData?['mealName'];
                    } else if (_analysisData?['name'] is String) {
                      mealNameMap['en'] = _analysisData?['name'];
                    }
                    mealNameMap[locale] = nameController.text.trim();
                    await _updateMealDetails({
                      'mealName': mealNameMap,
                    });
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: Text('dashboard.save'.tr()),
              ),
            ],
          ),
    );
  }

  Future<void> _updateMealDetails(Map<String, dynamic> updatedData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // User is authenticated - update in Firebase
        print('🔥 Updating meal details in Firebase');
        final docRef = FirebaseFirestore.instance
            .collection('analyzed_meals')
            .doc(widget.analysisId);

        final Map<String, dynamic> firestoreData = {};
        if (updatedData.containsKey('calories')) {
          firestoreData['calories'] = updatedData['calories'];
        }
        if (updatedData.containsKey('macros')) {
          firestoreData['macros'] = updatedData['macros'];
        }
        if (updatedData.containsKey('name')) {
          firestoreData['name'] = updatedData['name'];
        }
        if (updatedData.containsKey('mealName')) {
          firestoreData['mealName'] = updatedData['mealName'];
        }
        if (updatedData.containsKey('healthiness')) {
          firestoreData['healthiness'] = updatedData['healthiness'];
        }
        if (updatedData.containsKey('imageUrl')) {
          firestoreData['imageUrl'] = updatedData['imageUrl'];
        }
        if (updatedData.containsKey('date')) {
          firestoreData['date'] = updatedData['date'];
        }
        if (updatedData.containsKey('ingredients')) {
          firestoreData['ingredients'] = updatedData['ingredients'];
        }
        if (updatedData.containsKey('nutrients')) {
          firestoreData['nutrients'] = updatedData['nutrients'];
        }

        await docRef.update(firestoreData);
        final doc = await docRef.get();

        if (mounted) {
          setState(() {
            _analysisData = doc.data();
          });
        }
        print('✅ Meal updated in Firebase');
      } else {
        // User is not authenticated - update in local storage
        print('📱 Updating meal details in local storage');
        
        // Update the current analysis data
        if (_analysisData != null) {
          _analysisData!.addAll(updatedData);
          
          // Update the meal in local storage
          final localMeals = await Meal.loadFromLocalStorage();
          final updatedMeals = localMeals.map((meal) {
            if (meal.id == widget.analysisId) {
              return Meal.fromJson(_analysisData!);
            }
            return meal;
          }).toList();
          
          // Save updated meals back to local storage
          final prefs = await SharedPreferences.getInstance();
          final mealsJson = updatedMeals.map((meal) => jsonEncode(meal.toJson())).toList();
          await prefs.setStringList('local_meals', mealsJson);
          
          if (mounted) {
            setState(() {
              // _analysisData is already updated above
            });
          }
          print('✅ Meal updated in local storage');
        }
      }

      if (_analysisData != null) {
        await _saveAnalysisToLocal(_analysisData!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal details updated successfully')),
        );
      }
    } catch (e) {
      print('❌ Error updating meal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update meal: ${e.toString()}')),
        );
      }
    }
  }

  // Add method to edit ingredients
  Future<void> _editIngredients() async {
    if (_analysisData == null) return;
    // Only edit the current language's list if ingredients is a map
    final String currentLocale = Localizations.localeOf(context).languageCode;
    List<String> currentIngredients = [];
    if (_analysisData?['ingredients'] is Map) {
      final Map<String, dynamic> ingMap = Map<String, dynamic>.from(_analysisData?['ingredients']);
      currentIngredients = List<String>.from(
        ingMap[currentLocale] ?? ingMap['en'] ?? [],
      );
    } else if (_analysisData?['ingredients'] is List) {
      currentIngredients = List<String>.from(_analysisData?['ingredients'] ?? []);
    }

    final updatedIngredients = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => IngredientsEditScreen(
          ingredients: currentIngredients,
          mealId: widget.analysisId,
          language: currentLocale,
        ),
      ),
    );

    if (updatedIngredients != null) {
      setState(() {
        if (_analysisData != null) {
          if (_analysisData!['ingredients'] is Map) {
            final Map<String, dynamic> ingMap = Map<String, dynamic>.from(_analysisData!['ingredients']);
            ingMap[currentLocale] = updatedIngredients;
            _analysisData!['ingredients'] = ingMap;
          } else {
            _analysisData!['ingredients'] = updatedIngredients;
          }
        }
      });
      await _saveAnalysisToLocal(_analysisData!);
    }
  }
  
  // Add method to edit nutrition
  Future<void> _editNutrition() async {
    if (_analysisData == null) return;
    
    final calories = (_analysisData?['calories'] ?? 0.0).toDouble();
    final proteins = (_analysisData?['macros']?['proteins'] ?? 0.0).toDouble();
    final carbs = (_analysisData?['macros']?['carbs'] ?? 0.0).toDouble();
    final fats = (_analysisData?['macros']?['fats'] ?? 0.0).toDouble();
    
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => NutritionEditScreen(
          initialCalories: calories,
          initialProteins: proteins,
          initialCarbs: carbs,
          initialFats: fats,
        ),
      ),
    );
    
    if (result != null) {
      final updatedData = {
        'calories': result['calories'],
        'macros': {
          'proteins': result['proteins'],
          'carbs': result['carbs'],
          'fats': result['fats'],
        },
      };
      
      await _updateMealDetails(updatedData);
    }
  }

  Widget _buildMacroInfo(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text('$label ($unit)', style: TextStyle(fontSize: 14, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = isDark ? Color(0xFF121212) : Color(0xFFF5F5F5);
    final cardColor = isDark ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white70 : Colors.black87;
    final shadowColor =
        isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05);

    // Debug print for banner ad conditions
    print('🔍 Banner Ad Debug:');
    print('   - Advertising ID: $_advertisingId');
    print('   - Has Active Subscription: $_hasActiveSubscription');
    print('   - Banner Ad Ready: $_isBannerAdReady');
    print('   - Banner Ad Not Null: ${_bannerAd != null}');
    print('   - Should Show Ad: ${!_hasActiveSubscription && _isBannerAdReady && _bannerAd != null}');

    // Debug print for analysis data
    print('Analysis data in UI: ${_analysisData?.keys}');

    final locale = Localizations.localeOf(context).languageCode;
    final mealName =
        (_analysisData?['mealName'] is Map)
            ? (_analysisData?['mealName'][locale] ?? _analysisData?['mealName']['en'] ?? 'Unknown')
            : (_analysisData?['name'] ?? _analysisData?['mealName'] ?? 'Unknown');
    // Multilingual ingredients support
    List<String> ingredients = [];
    if (_analysisData?['ingredients'] is Map) {
      final Map<String, dynamic> ingMap = Map<String, dynamic>.from(_analysisData?['ingredients']);
      ingredients = List<String>.from(
        ingMap[locale] ?? ingMap['en'] ?? [],
      );
    } else if (_analysisData?['ingredients'] is List) {
      ingredients = List<String>.from(_analysisData?['ingredients'] ?? []);
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: scaffoldColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: scaffoldColor,
        body: Center(
          child: Text(
            _error!,
            style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: Stack(
        children: [
          // Image with Back Button
          Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.33,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child:
                    _analysisData?['imageUrl'] != null
                        ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: Image.network(
                            _analysisData!['imageUrl'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                        : Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 50,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                        ),
              ),
              const Spacer(),
            ],
          ),

          // Back Button
          Positioned(
            top: 40,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Main Content
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: // Keep existing child content...
                  SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Title
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap:
                                  _isLoading
                                      ? null
                                      : () => _showEditNameDialog(),
                              child: Text(
                                mealName,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: iconColor),
                            tooltip: 'Edit Name',
                            onPressed: _isLoading ? null : _showEditNameDialog,
                          ),
                        ],
                      ),

                      // Healthiness Block
                      if ((_analysisData?['healthiness'] ?? '').isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getHealthinessBackgroundColor(isDark),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getHealthinessIcon(),
                                    color: _getHealthinessIconColor(),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _translateValue(
                                      'healthiness',
                                      _analysisData?['healthiness'] ??
                                          'Unknown',
                                    ),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              // ...existing healthiness content...
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Nutrition Benefits Block
                      if ((_analysisData?['benefits'] as List?)?.isNotEmpty ==
                          true) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'details.nutrition_benefits'.tr(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...List<String>.from(
                                _analysisData?['benefits'] ?? [],
                              ).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 4,
                                    bottom: 4,
                                    right: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '• ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: textColor,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _translateValue('benefits', item),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor,
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
                        const SizedBox(height: 16),
                      ],

                      // Calories and Macros Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${(_analysisData?['calories'] ?? 0.0).toStringAsFixed(1)} kcal',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.add, color: iconColor),
                                  tooltip: 'Add Nutrition',
                                  onPressed: _isLoading ? null : _editNutrition,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMacroInfo(
                                  'details.protein'.tr(),
                                  (_analysisData?['macros']?['proteins'] ?? 0.0)
                                      .toStringAsFixed(1),
                                  'g',
                                  isDark
                                      ? Colors.grey[400]!
                                      : Colors.grey[600]!,
                                ),
                                _buildMacroInfo(
                                  'details.carbs'.tr(),
                                  (_analysisData?['macros']?['carbs'] ?? 0.0)
                                      .toStringAsFixed(1),
                                  'g',
                                  isDark
                                      ? Colors.grey[400]!
                                      : Colors.grey[600]!,
                                ),
                                _buildMacroInfo(
                                  'details.fats'.tr(),
                                  (_analysisData?['macros']?['fats'] ?? 0.0)
                                      .toStringAsFixed(1),
                                  'g',
                                  isDark
                                      ? Colors.grey[400]!
                                      : Colors.grey[600]!,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Ingredients Block
                      if (ingredients.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.restaurant_menu,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'details.ingredients'.tr(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add, color: iconColor),
                                    tooltip: 'Add Ingredients',
                                    onPressed: _isLoading ? null : _editIngredients,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (ingredients.isEmpty)
                                Center(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 20),
                                      Icon(
                                        Icons.restaurant_menu,
                                        size: 40,
                                        color:
                                            isDark
                                                ? Colors.grey[600]
                                                : Colors.grey[400],
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                )
                              else
                                ...ingredients.map(
                                  (ingredient) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            ingredient,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: textColor,
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
                      ],

                      // Source Link
                      if (_analysisData?['source'] != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'details.source'.tr(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Check if source is a URL or just a text
                              GestureDetector(
                                onTap: () async {
                                  final source = _analysisData?['source'];
                                  if (source != null && source.toString().startsWith('http')) {
                                    final uri = Uri.parse(source.toString());
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not open URL')),
                                        );
                                      }
                                    }
                                  }
                                },
                                                                  child: Text(
                                  _analysisData?['source']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : (_analysisData?['source']?.toString()?.startsWith('http') ?? false
                                            ? Theme.of(context).primaryColor
                                            : textColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // AdMob Banner Ad
                      if (!_hasActiveSubscription && _isBannerAdReady && _bannerAd != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  'Advertisement',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ),
                              Container(
                                alignment: Alignment.center,
                                width: _bannerAd!.size.width.toDouble(),
                                height: _bannerAd!.size.height.toDouble(),
                                child: AdWidget(ad: _bannerAd!),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],

                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
