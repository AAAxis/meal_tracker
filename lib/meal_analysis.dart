import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/upload_service.dart';
import 'services/parsing_service.dart';
import 'services/openai_service.dart';

// Re-export the Meal model from models/meal_model.dart
export 'models/meal_model.dart';

// Import the Meal model
import 'models/meal_model.dart';

/// Main function to analyze an image file and update meals list
Future<void> analyzeImageFile({
  required File imageFile,
  required List<Meal> meals,
  required Function(List<Meal>) updateMeals,
  required BuildContext context,
  required ImageSource source,
}) async {
  try {
    print('🔍 Starting meal analysis...');
    
    final user = FirebaseAuth.instance.currentUser;
    
    // Create analyzing meal entry
    final analyzingMeal = Meal.analyzing(
      imageUrl: imageFile.path, // Use local path initially
      localImagePath: imageFile.path,
      userId: user?.uid,
    );
    
    print('🎬 Created analyzing meal with ID: ${analyzingMeal.id}');
    print('🎬 Analyzing meal isAnalyzing: ${analyzingMeal.isAnalyzing}');
    
    // Add analyzing meal to list
    final updatedMeals = [...meals, analyzingMeal];
    print('🎬 Updating meals list: ${meals.length} -> ${updatedMeals.length}');
    updateMeals(updatedMeals);
    
    // Small delay to ensure UI updates
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      // Step 1: Upload image to backend (for display purposes)
      print('📤 Uploading image...');
      final imageUrl = await UploadService.uploadImageWithRetry(imageFile);
      print('✅ Image uploaded: $imageUrl');
      
      // Step 2: Analyze with Firebase Functions (try base64 first, then URL)
      print('🔥 Analyzing with Firebase Functions...');
      final imageName = imageFile.path.split('/').last;
      
      Map<String, dynamic> analysisResult;
      try {
        // Try base64 analysis first (more reliable for large images)
        analysisResult = await OpenAIService.analyzeMealImageBase64WithRetry(
          imageFile: imageFile,
          imageName: imageName,
          maxRetries: 2,
        );
        print('✅ Base64 analysis completed successfully');
      } catch (base64Error) {
        print('❌ Base64 analysis failed: $base64Error');
        try {
          // Fallback to URL analysis
          print('🔄 Falling back to URL analysis...');
          analysisResult = await OpenAIService.analyzeMealImageWithRetry(
            imageUrl: imageUrl,
            imageName: imageName,
            imageFile: imageFile,
            maxRetries: 2,
          );
          print('✅ URL analysis completed successfully');
        } catch (urlError) {
          print('❌ Both base64 and URL analysis failed');
          throw Exception('Analysis failed: Base64 error: $base64Error, URL error: $urlError');
        }
      }
      
      // Step 3: The result is already parsed by OpenAIService._transformFirebaseResponse
      print('✅ Analysis result received and transformed');
      final parsedResult = analysisResult; // Already in the correct format
      
      if (!ParsingService.validateParsedResult(parsedResult)) {
        throw Exception('Analysis result validation failed');
      }
      print('✅ Results parsed and validated');
      
      // Step 4: Create final meal object
      final completedMeal = Meal.fromAnalysis(
        id: analyzingMeal.id,
        imageUrl: imageUrl,
        localImagePath: imageFile.path,
        analysisData: parsedResult,
        userId: user?.uid,
      );
      
      // Step 5: Save to appropriate storage
      if (user != null) {
        // Save to Firebase for authenticated users
        await _saveMealToFirebase(completedMeal);
        print('✅ Meal saved to Firebase');
      } else {
        // Save to local storage for non-authenticated users
        await Meal.addOrUpdateInLocalStorage(completedMeal);
        print('✅ Meal saved to local storage');
      }
      
      // Step 6: Update meals list
      final finalMeals = meals.where((m) => m.id != analyzingMeal.id).toList();
      finalMeals.add(completedMeal);
      updateMeals(finalMeals);
      
      print('✅ Meal analysis completed successfully');
      
    } catch (e) {
      print('❌ Error during analysis: $e');
      
      // Create failed meal
      final failedMeal = Meal.failed(
        id: analyzingMeal.id,
        imageUrl: imageFile.path,
        localImagePath: imageFile.path,
        userId: user?.uid,
      );
      
      // Update meals list with failed meal
      final failedMeals = meals.where((m) => m.id != analyzingMeal.id).toList();
      failedMeals.add(failedMeal);
      updateMeals(failedMeals);
      
      // Show error to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
  } catch (e) {
    print('❌ Critical error in meal analysis: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start analysis: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Function to pick and analyze image from camera/gallery
Future<void> pickAndAnalyzeImage({
  required ImagePicker picker,
  required List<Meal> meals,
  required Function(List<Meal>) updateMeals,
  required BuildContext context,
  required ImageSource source,
  Meal? retryMeal,
}) async {
  try {
    final XFile? image = await picker.pickImage(source: source);
    
    if (image != null) {
      await analyzeImageFile(
        imageFile: File(image.path),
        meals: meals,
        updateMeals: updateMeals,
        context: context,
        source: source,
      );
    }
  } catch (e) {
    print('❌ Error picking/analyzing image: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Function specifically for camera capture (used by camera service)
Future<void> pickAndAnalyzeImageFromCamera({
  required ImagePicker picker,
  required List<Meal> meals,
  required Function(List<Meal>) updateMeals,
  required BuildContext context,
}) async {
  await pickAndAnalyzeImage(
    picker: picker,
    meals: meals,
    updateMeals: updateMeals,
    context: context,
    source: ImageSource.camera,
  );
}

/// Function specifically for gallery selection
Future<void> pickAndAnalyzeImageFromGallery({
  required ImagePicker picker,
  required List<Meal> meals,
  required Function(List<Meal>) updateMeals,
  required BuildContext context,
}) async {
  await pickAndAnalyzeImage(
    picker: picker,
    meals: meals,
    updateMeals: updateMeals,
    context: context,
    source: ImageSource.gallery,
  );
}

/// Save meal to Firebase
Future<void> _saveMealToFirebase(Meal meal) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    final mealData = meal.toJson();
    
    // Convert DateTime to Timestamp for Firestore
    if (mealData['timestamp'] is String) {
      mealData['timestamp'] = Timestamp.fromDate(meal.timestamp);
    }
    
    // Ensure userId is set
    mealData['userId'] = user.uid;
    
    await FirebaseFirestore.instance
        .collection('analyzed_meals')
        .doc(meal.id)
        .set(mealData);
        
    print('✅ Meal saved to Firebase: ${meal.id}');
  } catch (e) {
    print('❌ Error saving meal to Firebase: $e');
    rethrow;
  }
}

/// Load meals from Firebase for authenticated users
Future<List<Meal>> loadMealsFromFirebase() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('🔍 No authenticated user, loading from local storage');
      return await Meal.loadFromLocalStorage();
    }
    
    print('🔥 Loading meals from Firebase for user: ${user.uid}');
    
    final snapshot = await FirebaseFirestore.instance
        .collection('analyzed_meals')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();
    
    final meals = snapshot.docs.map((doc) {
      final data = doc.data();
      
      // Convert Firestore Timestamp to DateTime string
      if (data['timestamp'] is Timestamp) {
        data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
      }
      
      return Meal.fromJson(data);
    }).toList();
    
    print('✅ Loaded ${meals.length} meals from Firebase');
    return meals;
    
  } catch (e) {
    print('❌ Error loading meals from Firebase: $e');
    // Fallback to local storage
    return await Meal.loadFromLocalStorage();
  }
}

/// Delete meal from Firebase
Future<void> deleteMealFromFirebase(String mealId) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await Meal.deleteFromLocalStorage(mealId);
      return;
    }
    
    await FirebaseFirestore.instance
        .collection('analyzed_meals')
        .doc(mealId)
        .delete();
        
    print('✅ Meal deleted from Firebase: $mealId');
  } catch (e) {
    print('❌ Error deleting meal from Firebase: $e');
    rethrow;
  }
}

/// Update meal in Firebase
Future<void> updateMealInFirebase(String mealId, Map<String, dynamic> updates) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    
    await FirebaseFirestore.instance
        .collection('analyzed_meals')
        .doc(mealId)
        .update(updates);
        
    print('✅ Meal updated in Firebase: $mealId');
  } catch (e) {
    print('❌ Error updating meal in Firebase: $e');
    rethrow;
  }
}

/// Retry analysis for failed meal
Future<void> retryMealAnalysis({
  required Meal failedMeal,
  required List<Meal> meals,
  required Function(List<Meal>) updateMeals,
  required BuildContext context,
}) async {
  if (failedMeal.localImagePath != null) {
    final imageFile = File(failedMeal.localImagePath!);
    if (imageFile.existsSync()) {
      // Remove the failed meal from the list
      final updatedMeals = meals.where((m) => m.id != failedMeal.id).toList();
      updateMeals(updatedMeals);
      
      // Retry analysis
      await analyzeImageFile(
        imageFile: imageFile,
        meals: updatedMeals,
        updateMeals: updateMeals,
        context: context,
        source: ImageSource.camera,
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Original image file not found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 