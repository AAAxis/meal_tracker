import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({Key? key}) : super(key: key);

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  double _caloriesGoal = 2000;
  double _proteinGoal = 150;
  double _carbsGoal = 250;
  double _fatsGoal = 65;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _caloriesGoal = prefs.getDouble('nutrition_goal_calories') ?? 2000;
        _proteinGoal = prefs.getDouble('nutrition_goal_protein') ?? 150;
        _carbsGoal = prefs.getDouble('nutrition_goal_carbs') ?? 250;
        _fatsGoal = prefs.getDouble('nutrition_goal_fats') ?? 65;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading nutrition goals: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('nutrition_goal_calories', _caloriesGoal);
      await prefs.setDouble('nutrition_goal_protein', _proteinGoal);
      await prefs.setDouble('nutrition_goal_carbs', _carbsGoal);
      await prefs.setDouble('nutrition_goal_fats', _fatsGoal);
      await prefs.setBool('nutrition_goals_set', true);
    } catch (e) {
      print('Error saving nutrition goals: $e');
    }
  }

  @override
  void dispose() {
    // Auto-save when leaving the screen
    _saveGoals();
    super.dispose();
  }

  Widget _buildGoalSlider({
    required String title,
    required String unit,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String imagePath,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                imagePath,
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.round()}$unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.3),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              valueIndicatorColor: color,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.round()}$unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '${max.round()}$unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSliderWithIcon({
    required String title,
    required String unit,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.round()}$unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.3),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              valueIndicatorColor: color,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.round()}$unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '${max.round()}$unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('nutrition_goals.title'.tr()),
        ),
        body: const SizedBox.shrink(), // Minimal loading state
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Auto-save when back button is pressed
        await _saveGoals();
        Navigator.pop(context, true); // Return true to indicate goals were saved
        return false; // We handle the navigation ourselves
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('nutrition_goals.title'.tr()),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // Auto-save when back arrow is pressed
              await _saveGoals();
              Navigator.pop(context, true); // Return true to indicate goals were saved
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGoalSliderWithIcon(
                title: 'nutrition_goals.daily_calories'.tr(),
                unit: 'k',
                value: _caloriesGoal,
                min: 1200,
                max: 4000,
                onChanged: (value) => setState(() => _caloriesGoal = value),
                icon: Icons.local_fire_department,
                color: Colors.red[400]!,
              ),
              _buildGoalSlider(
                title: 'nutrition_goals.daily_protein'.tr(),
                unit: 'g',
                value: _proteinGoal,
                min: 50,
                max: 300,
                onChanged: (value) => setState(() => _proteinGoal = value),
                imagePath: 'images/meat.png',
                color: Colors.blue[400]!,
              ),
              _buildGoalSlider(
                title: 'nutrition_goals.daily_carbs'.tr(),
                unit: 'g',
                value: _carbsGoal,
                min: 100,
                max: 500,
                onChanged: (value) => setState(() => _carbsGoal = value),
                imagePath: 'images/carbs.png',
                color: Colors.orange[400]!,
              ),
              _buildGoalSlider(
                title: 'nutrition_goals.daily_fats'.tr(),
                unit: 'g',
                value: _fatsGoal,
                min: 30,
                max: 150,
                onChanged: (value) => setState(() => _fatsGoal = value),
                imagePath: 'images/fats.png',
                color: Colors.green[400]!,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
} 