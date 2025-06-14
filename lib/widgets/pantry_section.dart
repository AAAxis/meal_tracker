import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../meal_analysis.dart';
import '../dashboard/details_screen.dart';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';

class PantrySection extends StatefulWidget {
  final List<Meal> meals;
  final Function(String) onDelete;
  final Future<void> Function() onRefresh;
  final Function(List<Meal>) updateMeals;

  const PantrySection({
    Key? key,
    required this.meals,
    required this.onDelete,
    required this.onRefresh,
    required this.updateMeals,
  }) : super(key: key);

  @override
  State<PantrySection> createState() => _PantrySectionState();
}

class _PantrySectionState extends State<PantrySection> with TickerProviderStateMixin {
  Map<String, AnimationController> _animationControllers = {};
  Map<String, Animation<double>> _caloriesAnimations = {};
  Map<String, Animation<double>> _proteinsAnimations = {};
  Map<String, Animation<double>> _carbsAnimations = {};
  Map<String, Animation<double>> _fatsAnimations = {};
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  @override
  void didUpdateWidget(PantrySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Clean up old controllers
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    _animationControllers.clear();
    _caloriesAnimations.clear();
    _proteinsAnimations.clear();
    _carbsAnimations.clear();
    _fatsAnimations.clear();

    // Create animations for analyzing meals
    for (var meal in widget.meals) {
      if (meal.isAnalyzing) {
        final controller = AnimationController(
          duration: const Duration(seconds: 10),
          vsync: this,
        );

        final caloriesAnimation = Tween<double>(
          begin: 30 + _random.nextDouble() * 50,
          end: 250 + _random.nextDouble() * 50,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOutSine,
        ));

        final proteinsAnimation = Tween<double>(
          begin: 1 + _random.nextDouble() * 3,
          end: 8 + _random.nextDouble() * 2,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOutSine,
        ));

        final carbsAnimation = Tween<double>(
          begin: 10 + _random.nextDouble() * 5,
          end: 25 + _random.nextDouble() * 5,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOutSine,
        ));

        final fatsAnimation = Tween<double>(
          begin: 20 + _random.nextDouble() * 5,
          end: 28 + _random.nextDouble() * 2,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOutSine,
        ));

        _animationControllers[meal.id] = controller;
        _caloriesAnimations[meal.id] = caloriesAnimation;
        _proteinsAnimations[meal.id] = proteinsAnimation;
        _carbsAnimations[meal.id] = carbsAnimation;
        _fatsAnimations[meal.id] = fatsAnimation;

        controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date'),
        content: SizedBox(
          width: 300,
          height: 350,
          child: CalendarDatePicker(
            initialDate: DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now(),
            onDateChanged: (date) {
              Navigator.of(context).pop();
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  List<Meal> get _filteredMeals {
    List<Meal> mealsList = List<Meal>.from(widget.meals);
    mealsList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mealsList.length > 5) {
      mealsList = mealsList.take(5).toList();
    }
    return mealsList;
  }

  Widget _buildMealImage(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[100],
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          return Container(
            color: Theme.of(context).colorScheme.surface,
            child: Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              size: 32,
            ),
          );
        },
        cacheKey: imageUrl.hashCode.toString(), // Use URL hash as cache key
        memCacheHeight: 200,
        memCacheWidth: 200,
      );
    } else {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: Icon(
                Icons.broken_image,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                size: 32,
              ),
            );
          },
        );
      } else {
        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: Icon(
            Icons.photo,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            size: 32,
          ),
        );
      }
    }
  }

  Widget _buildAnalyzingMealCard(Meal meal) {
    final controller = _animationControllers[meal.id];
    if (controller == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final calories = _caloriesAnimations[meal.id]?.value ?? 0;
        final proteins = _proteinsAnimations[meal.id]?.value ?? 0;
        final carbs = _carbsAnimations[meal.id]?.value ?? 0;
        final fats = _fatsAnimations[meal.id]?.value ?? 0;

        return Container(
          margin: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 0,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          height: 122,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.maxHeight;
                          return SizedBox(
                            width: size,
                            height: size,
                            child: _buildMealImage(meal.imageUrl!),
                          );
                        },
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.maxHeight;
                          return Container(
                            width: size,
                            height: size,
                            color: Theme.of(context).colorScheme.surface,
                            child: Icon(
                              Icons.photo,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              size: 32,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'dashboard.analyzing'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontSize: 17),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.inverseSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                DateFormat('HH:mm').format(meal.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onInverseSurface,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${calories.toStringAsFixed(0)} ${'common.calories'.tr()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Image.asset(
                            'images/meat.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${proteins.toStringAsFixed(0)}g',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Image.asset(
                            'images/carbs.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${carbs.toStringAsFixed(0)}g',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Image.asset(
                            'images/fats.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${fats.toStringAsFixed(0)}g',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '📦 ${'dashboard.your_pantry'.tr()}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        
            ],
          ),
          const SizedBox(height: 10),
          
          // Pantry content
          if (_filteredMeals.isEmpty)
            Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'dashboard.no_meals'.tr(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: _filteredMeals.length,
              itemBuilder: (context, index) {
                final meal = _filteredMeals[index];
                
                // Show animated card for analyzing meals
                if (meal.isAnalyzing) {
                  return _buildAnalyzingMealCard(meal);
                }
                
                final macros = meal.macros;
                
                return Dismissible(
                  key: Key(meal.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('dashboard.delete_analysis'.tr()),
                        content: Text('dashboard.delete_confirm'.tr()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('dashboard.cancel'.tr()),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('dashboard.delete'.tr()),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    widget.onDelete(meal.id);
                  },
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnalysisDetailsScreen(
                            analysisId: meal.id,
                          ),
                        ),
                      );
                      // After returning, refresh meals via callback
                      await widget.onRefresh();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 0,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      height: 122,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                                ? LayoutBuilder(
                                    builder: (context, constraints) {
                                      final size = constraints.maxHeight;
                                      return SizedBox(
                                        width: size,
                                        height: size,
                                        child: _buildMealImage(meal.imageUrl!),
                                      );
                                    },
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final size = constraints.maxHeight;
                                      return Container(
                                        width: size,
                                        height: size,
                                        color: Theme.of(context).colorScheme.surface,
                                        child: Icon(
                                          Icons.photo,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                          size: 32,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          meal.getMealName(Localizations.localeOf(context).languageCode),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontSize: 17),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.inverseSurface,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            DateFormat('HH:mm').format(meal.timestamp),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.onInverseSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${meal.calories.toStringAsFixed(0)} ${'common.calories'.tr()}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Image.asset(
                                        'images/meat.png',
                                        width: 18,
                                        height: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${macros['proteins']?.toStringAsFixed(0) ?? 0}g',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Image.asset(
                                        'images/carbs.png',
                                        width: 18,
                                        height: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${macros['carbs']?.toStringAsFixed(0) ?? 0}g',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Image.asset(
                                        'images/fats.png',
                                        width: 18,
                                        height: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${macros['fats']?.toStringAsFixed(0) ?? 0}g',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
} 