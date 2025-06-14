import 'dart:convert';
import 'package:flutter/foundation.dart';

class ParsingService {
  /// Parse and validate OpenAI analysis results
  static Map<String, dynamic> parseAnalysisResult(Map<String, dynamic> rawResult) {
    try {
      print('🔍 Parsing analysis result...');
      
      // Create a standardized result structure
      final Map<String, dynamic> parsedResult = {};
      
      // Parse meal name
      parsedResult['mealName'] = _parseMealName(rawResult['mealName']);
      
      // Parse calories
      parsedResult['calories'] = _parseCalories(rawResult['calories']);
      
      // Parse macros
      parsedResult['macros'] = _parseMacros(rawResult['macros']);
      
      // Parse ingredients
      parsedResult['ingredients'] = _parseIngredients(rawResult['ingredients']);
      
      // Parse nutrients
      parsedResult['nutrients'] = _parseNutrients(rawResult['nutrients']);
      
      // Parse healthiness
      parsedResult['healthiness'] = _parseHealthiness(rawResult['healthiness']);
      parsedResult['healthiness_explanation'] = _parseHealthinessExplanation(rawResult['healthiness_explanation']);
      
      // Parse additional fields
      parsedResult['portion_size'] = _parsePortionSize(rawResult['portion_size']);
      parsedResult['meal_type'] = _parseMealType(rawResult['meal_type']);
      parsedResult['cooking_method'] = _parseCookingMethod(rawResult['cooking_method']);
      parsedResult['allergens'] = _parseAllergens(rawResult['allergens']);
      parsedResult['dietary_tags'] = _parseDietaryTags(rawResult['dietary_tags']);
      
      print('✅ Analysis result parsed successfully');
      return parsedResult;
      
    } catch (e) {
      print('❌ Error parsing analysis result: $e');
      rethrow;
    }
  }
  
  /// Parse meal name with multilingual support
  static Map<String, dynamic> _parseMealName(dynamic mealName) {
    if (mealName is Map) {
      return Map<String, dynamic>.from(mealName);
    } else if (mealName is String) {
      // If it's just a string, use it as English
      return {'en': mealName, 'es': mealName, 'fr': mealName};
    }
    return {'en': 'Unknown Meal', 'es': 'Comida Desconocida', 'fr': 'Repas Inconnu'};
  }
  
  /// Parse calories with validation
  static double _parseCalories(dynamic calories) {
    if (calories is num) {
      final caloriesValue = calories.toDouble();
      // Validate reasonable calorie range (0-3000) - allow 0 for unknown
      if (caloriesValue >= 0 && caloriesValue <= 3000) {
        // If calories is 0, provide a reasonable default
        if (caloriesValue == 0) {
          print('⚠️ Calories is 0, using default 200');
          return 200.0;
        }
        return caloriesValue;
      }
    }
    print('⚠️ Invalid calories value: $calories, using default 200');
    return 200.0; // Default reasonable value
  }
  
  /// Parse macros with validation
  static Map<String, double> _parseMacros(dynamic macros) {
    final Map<String, double> result = {
      'proteins': 0.0,
      'carbs': 0.0,
      'fats': 0.0,
    };
    
    if (macros is Map) {
      final macrosMap = Map<String, dynamic>.from(macros);
      
      // Parse proteins
      if (macrosMap['proteins'] is num) {
        final proteins = macrosMap['proteins'].toDouble();
        if (proteins >= 0 && proteins <= 200) {
          result['proteins'] = proteins;
        }
      }
      
      // Parse carbs
      if (macrosMap['carbs'] is num) {
        final carbs = macrosMap['carbs'].toDouble();
        if (carbs >= 0 && carbs <= 300) {
          result['carbs'] = carbs;
        }
      }
      
      // Parse fats
      if (macrosMap['fats'] is num) {
        final fats = macrosMap['fats'].toDouble();
        if (fats >= 0 && fats <= 150) {
          result['fats'] = fats;
        }
      }
    }
    
    return result;
  }
  
  /// Parse ingredients with multilingual support
  static Map<String, dynamic> _parseIngredients(dynamic ingredients) {
    if (ingredients is Map) {
      final Map<String, dynamic> result = {};
      final ingredientsMap = Map<String, dynamic>.from(ingredients);
      
      for (final entry in ingredientsMap.entries) {
        if (entry.value is List) {
          result[entry.key] = List<String>.from(entry.value);
        }
      }
      
      return result;
    } else if (ingredients is List) {
      // If it's just a list, use it for all languages
      final ingredientsList = List<String>.from(ingredients);
      return {
        'en': ingredientsList,
        'es': ingredientsList,
        'fr': ingredientsList,
      };
    }
    
    return {
      'en': [],
      'es': [],
      'fr': [],
    };
  }
  
  /// Parse nutrients with validation
  static Map<String, dynamic> _parseNutrients(dynamic nutrients) {
    final Map<String, dynamic> result = {
      'fiber': 0.0,
      'sugar': 0.0,
      'sodium': 0.0,
      'potassium': 0.0,
      'vitamin_c': 0.0,
      'calcium': 0.0,
      'iron': 0.0,
    };
    
    if (nutrients is Map) {
      final nutrientsMap = Map<String, dynamic>.from(nutrients);
      
      for (final entry in nutrientsMap.entries) {
        if (entry.value is num) {
          final value = entry.value.toDouble();
          // Basic validation - ensure non-negative
          if (value >= 0) {
            result[entry.key] = value;
          }
        }
      }
    }
    
    return result;
  }
  
  /// Parse healthiness with validation
  static String _parseHealthiness(dynamic healthiness) {
    if (healthiness is String) {
      final normalized = healthiness.toLowerCase().trim();
      if (['healthy', 'medium', 'unhealthy'].contains(normalized)) {
        return normalized;
      }
    }
    return 'medium'; // Default value
  }
  
  /// Parse healthiness explanation with multilingual support
  static Map<String, dynamic> _parseHealthinessExplanation(dynamic explanation) {
    if (explanation is Map) {
      return Map<String, dynamic>.from(explanation);
    } else if (explanation is String) {
      // If it's just a string, use it for all languages
      return {'en': explanation, 'es': explanation, 'fr': explanation};
    }
    return {'en': '', 'es': '', 'fr': ''};
  }
  
  /// Parse portion size with validation
  static String _parsePortionSize(dynamic portionSize) {
    if (portionSize is String) {
      final normalized = portionSize.toLowerCase().trim();
      if (['small', 'medium', 'large'].contains(normalized)) {
        return normalized;
      }
    }
    return 'medium'; // Default value
  }
  
  /// Parse meal type with validation
  static String _parseMealType(dynamic mealType) {
    if (mealType is String) {
      final normalized = mealType.toLowerCase().trim();
      if (['breakfast', 'lunch', 'dinner', 'snack'].contains(normalized)) {
        return normalized;
      }
    }
    return 'snack'; // Default value
  }
  
  /// Parse cooking method
  static String _parseCookingMethod(dynamic cookingMethod) {
    if (cookingMethod is String) {
      return cookingMethod.toLowerCase().trim();
    }
    return 'unknown';
  }
  
  /// Parse allergens
  static List<String> _parseAllergens(dynamic allergens) {
    if (allergens is List) {
      return List<String>.from(allergens);
    }
    return [];
  }
  
  /// Parse dietary tags
  static List<String> _parseDietaryTags(dynamic dietaryTags) {
    if (dietaryTags is List) {
      return List<String>.from(dietaryTags);
    }
    return [];
  }
  
  /// Validate parsed result for completeness
  static bool validateParsedResult(Map<String, dynamic> parsedResult) {
    try {
      // Check required fields
      if (parsedResult['mealName'] == null ||
          parsedResult['calories'] == null ||
          parsedResult['macros'] == null) {
        print('❌ Missing required fields in parsed result');
        return false;
      }
      
      // Check calorie range - allow reasonable values including defaults
      final calories = parsedResult['calories'] as double;
      if (calories < 0 || calories > 5000) {
        print('❌ Calories out of reasonable range: $calories');
        return false;
      }
      
      // Check macros
      final macros = parsedResult['macros'] as Map<String, double>;
      if (!macros.containsKey('proteins') ||
          !macros.containsKey('carbs') ||
          !macros.containsKey('fats')) {
        print('❌ Missing macro nutrients');
        return false;
      }
      
      print('✅ Parsed result validation passed');
      return true;
      
    } catch (e) {
      print('❌ Error validating parsed result: $e');
      return false;
    }
  }
  
  /// Create fallback result in case of parsing errors
  static Map<String, dynamic> createFallbackResult() {
    return {
      'mealName': {
        'en': 'Unknown Meal',
        'es': 'Comida Desconocida',
        'fr': 'Repas Inconnu',
      },
      'calories': 200.0,
      'macros': {
        'proteins': 10.0,
        'carbs': 25.0,
        'fats': 8.0,
      },
      'ingredients': {
        'en': ['Unknown ingredients'],
        'es': ['Ingredientes desconocidos'],
        'fr': ['Ingrédients inconnus'],
      },
      'nutrients': {
        'fiber': 2.0,
        'sugar': 5.0,
        'sodium': 300.0,
        'potassium': 200.0,
        'vitamin_c': 10.0,
        'calcium': 50.0,
        'iron': 2.0,
      },
      'healthiness': 'medium',
      'healthiness_explanation': {
        'en': 'Unable to analyze meal healthiness',
        'es': 'No se pudo analizar la salubridad de la comida',
        'fr': 'Impossible d\'analyser la salubrité du repas',
      },
      'portion_size': 'medium',
      'meal_type': 'snack',
      'cooking_method': 'unknown',
      'allergens': [],
      'dietary_tags': [],
    };
  }
} 