import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class NutritionEditScreen extends StatefulWidget {
  final double initialCalories;
  final double initialProteins;
  final double initialCarbs;
  final double initialFats;

  const NutritionEditScreen({
    Key? key,
    required this.initialCalories,
    required this.initialProteins,
    required this.initialCarbs,
    required this.initialFats,
  }) : super(key: key);

  @override
  State<NutritionEditScreen> createState() => _NutritionEditScreenState();
}

class _NutritionEditScreenState extends State<NutritionEditScreen> {
  late double calories;
  late double proteins;
  late double carbs;
  late double fats;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    calories = widget.initialCalories;
    proteins = widget.initialProteins;
    carbs = widget.initialCarbs;
    fats = widget.initialFats;
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Color color,
    ValueChanged<double> onChanged, {
    String? unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text(
              '${value.round()}${unit != null ? ' ${unit.tr()}' : ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.3),
            thumbColor: color,
            overlayColor: color.withOpacity(0.1),
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 1).round(),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isSaving) {
          setState(() => _isSaving = true);
          Navigator.pop(context, {
            'calories': calories,
            'proteins': proteins,
            'carbs': carbs,
            'fats': fats,
          });
        }
        return false; // Prevent default pop, we handle it
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('nutrition_edit.title'.tr()),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (!_isSaving) {
                setState(() => _isSaving = true);
                Navigator.pop(context, {
                  'calories': calories,
                  'proteins': proteins,
                  'carbs': carbs,
                  'fats': fats,
                });
              }
            },
          ),
        ),
        body: _isSaving
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSlider(
                      'nutrition_edit.calories',
                      calories,
                      0,
                      2000,
                      Colors.green,
                      (v) => setState(() => calories = v),
                      unit: 'nutrition_edit.kcal',
                    ),
                    _buildSlider(
                      'nutrition_edit.protein',
                      proteins,
                      0,
                      100,
                      Colors.red[400]!,
                      (v) => setState(() => proteins = v),
                      unit: 'nutrition_edit.grams',
                    ),
                    _buildSlider(
                      'nutrition_edit.carbs',
                      carbs,
                      0,
                      200,
                      Colors.orange[400]!,
                      (v) => setState(() => carbs = v),
                      unit: 'nutrition_edit.grams',
                    ),
                    _buildSlider(
                      'nutrition_edit.fats',
                      fats,
                      0,
                      100,
                      Colors.blue[400]!,
                      (v) => setState(() => fats = v),
                      unit: 'nutrition_edit.grams',
                    ),
                    const SizedBox(height: 32),
                      ],
                    ),
                ),
              ),
    );
  }
}
