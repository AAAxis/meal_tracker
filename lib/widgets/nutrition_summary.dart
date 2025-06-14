import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../meal_analysis.dart';
import '../dashboard/nutrition_goals_screen.dart';

class NutritionSummary extends StatefulWidget {
  final List<Meal> meals;

  const NutritionSummary({
    Key? key,
    required this.meals,
  }) : super(key: key);

  @override
  State<NutritionSummary> createState() => _NutritionSummaryState();
}

class _NutritionSummaryState extends State<NutritionSummary> {
  int selectedDaysAgo = 0; // 0 = Today, 1 = Yesterday, etc.
  bool _goalsSet = false;
  double _caloriesGoal = 2000;
  double _proteinGoal = 150;
  double _carbsGoal = 250;
  double _fatsGoal = 65;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _goalsSet = prefs.getBool('nutrition_goals_set') ?? false;
        _caloriesGoal = prefs.getDouble('nutrition_goal_calories') ?? 2000;
        _proteinGoal = prefs.getDouble('nutrition_goal_protein') ?? 150;
        _carbsGoal = prefs.getDouble('nutrition_goal_carbs') ?? 250;
        _fatsGoal = prefs.getDouble('nutrition_goal_fats') ?? 65;
      });
    } catch (e) {
      print('Error loading nutrition goals: $e');
    }
  }

  List<DropdownMenuItem<int>> _buildDropdownItems() {
    final List<DropdownMenuItem<int>> items = [];
    final now = DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      String label;
      
      if (i == 0) {
        label = 'nutrition.today'.tr();
      } else if (i == 1) {
        label = 'nutrition.yesterday'.tr();
      } else {
        label = 'nutrition.days_ago'.tr(args: [i.toString()]);
      }
      
      // Add the formatted date
      final dateFormat = DateFormat('MMM dd');
      label += ' (${dateFormat.format(date)})';
      
      items.add(DropdownMenuItem<int>(
        value: i,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ));
    }
    
    return items;
  }

  Map<String, double> _calculateNutritionForDay(int daysAgo) {
    double totalCalories = 0;
    double totalProteins = 0;
    double totalCarbs = 0;
    double totalFats = 0;

    // Get the selected date
    final today = DateTime.now();
    final targetDate = DateTime(today.year, today.month, today.day).subtract(Duration(days: daysAgo));
    final startOfDay = targetDate;
    final endOfDay = targetDate.add(const Duration(days: 1));

    // Filter meals for the selected day only
    final dayMeals = widget.meals.where((meal) =>
        meal.timestamp.isAfter(startOfDay) &&
        meal.timestamp.isBefore(endOfDay) &&
        !meal.isAnalyzing &&
        !meal.analysisFailed
    ).toList();

    for (final meal in dayMeals) {
      totalCalories += meal.calories;
      totalProteins += meal.macros['proteins'] ?? 0.0;
      totalCarbs += meal.macros['carbs'] ?? 0.0;
      totalFats += meal.macros['fats'] ?? 0.0;
    }

    return {
      'calories': totalCalories,
      'proteins': totalProteins,
      'carbs': totalCarbs,
      'fats': totalFats,
    };
  }

  String _getPeriodLabel() {
    if (selectedDaysAgo == 0) {
      return 'nutrition.todays_nutrition'.tr();
    } else if (selectedDaysAgo == 1) {
      return 'nutrition.yesterdays_nutrition'.tr();
    } else {
      return 'nutrition.days_ago_nutrition'.tr(args: [selectedDaysAgo.toString()]);
    }
  }

  String _formatNutritionValue(double value) {
    // If the value is a whole number (or very close to it), show without decimals
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    // Otherwise, show one decimal place
    return value.toStringAsFixed(1);
  }

  Widget _buildSetGoalsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.track_changes,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.9)
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'nutrition_goals.set_your_goals'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'nutrition_goals.banner_description'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NutritionGoalsScreen(),
                  ),
                );
                if (result == true) {
                  // Goals were saved, reload them
                  _loadGoals();
                }
              },
              icon: const Icon(Icons.settings),
              label: Text('nutrition_goals.set_goals_button'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If goals aren't set, show banner
    if (!_goalsSet) {
      return _buildSetGoalsBanner();
    }

    final nutrition = _calculateNutritionForDay(selectedDaysAgo);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor ?? Colors.transparent, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with dropdown
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: isDark 
                      ? Colors.white.withOpacity(0.9)
                      : Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: borderColor ?? Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDaysAgo,
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        dropdownColor: cardColor,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: subTextColor,
                          size: 20,
                        ),
                        items: _buildDropdownItems(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedDaysAgo = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NutritionGoalsScreen(),
                      ),
                    );
                    if (result == true) {
                      _loadGoals();
                    }
                  },
                  icon: Icon(
                    Icons.settings,
                    color: isDark 
                        ? Colors.white.withOpacity(0.9)
                        : Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  tooltip: 'nutrition_goals.edit_goals'.tr(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Nutrition cards with progress
            Row(
              children: [
                _buildNutritionCardWithProgress(
                  'nutrition.calories'.tr(),
                  nutrition['calories']!.toStringAsFixed(0),
                  'k',
                  Icons.local_fire_department,
                  Colors.red[400]!,
                  textColor,
                  subTextColor,
                  nutrition['calories']!,
                  _caloriesGoal,
                ),
                const SizedBox(width: 8),
                _buildNutritionCardWithImageAndProgress(
                  'nutrition.protein'.tr(),
                  _formatNutritionValue(nutrition['proteins']!),
                  'nutrition.grams'.tr(),
                  'images/meat.png',
                  Colors.blue[400]!,
                  textColor,
                  subTextColor,
                  nutrition['proteins']!,
                  _proteinGoal,
                ),
                const SizedBox(width: 8),
                _buildNutritionCardWithImageAndProgress(
                  'nutrition.carbs'.tr(),
                  _formatNutritionValue(nutrition['carbs']!),
                  'nutrition.grams'.tr(),
                  'images/carbs.png',
                  Colors.orange[400]!,
                  textColor,
                  subTextColor,
                  nutrition['carbs']!,
                  _carbsGoal,
                ),
                const SizedBox(width: 8),
                _buildNutritionCardWithImageAndProgress(
                  'nutrition.fats'.tr(),
                  _formatNutritionValue(nutrition['fats']!),
                  'nutrition.grams'.tr(),
                  'images/fats.png',
                  Colors.green[400]!,
                  textColor,
                  subTextColor,
                  nutrition['fats']!,
                  _fatsGoal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionCard(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
    Color textColor,
    Color? subTextColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 18,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionCardWithImage(
    String label,
    String value,
    String unit,
    String imagePath,
    Color color,
    Color textColor,
    Color? subTextColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Image.asset(
              imagePath,
              width: 18,
              height: 18,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionCardWithProgress(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
    Color textColor,
    Color? subTextColor,
    double currentValue,
    double goalValue,
  ) {
    final progress = (currentValue / goalValue).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isDark 
                  ? Colors.white.withOpacity(0.9)
                  : textColor,
              size: 18,
            ),
            const SizedBox(height: 8),
            // Progress bar with percentage inside
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 2,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value$unit',
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionCardWithImageAndProgress(
    String label,
    String value,
    String unit,
    String imagePath,
    Color color,
    Color textColor,
    Color? subTextColor,
    double currentValue,
    double goalValue,
  ) {
    final progress = (currentValue / goalValue).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Image.asset(
              imagePath,
              width: 18,
              height: 18,
            ),
            const SizedBox(height: 8),
            // Progress bar with percentage inside
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 2,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value$unit',
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: subTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 