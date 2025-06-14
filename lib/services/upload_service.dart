import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class UploadService {
  /// Upload an image file to Firebase Storage
  static Future<String> uploadImage(File imageFile) async {
    try {
      print('📤 Starting Firebase Storage upload...');
      
      final user = FirebaseAuth.instance.currentUser;
      final uuid = const Uuid().v4();
      final fileName = 'meal_images/${user?.uid ?? 'anonymous'}/$uuid.jpg';
      
      // Create a reference to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child(fileName);
      
      // Upload the file
      final uploadTask = ref.putFile(imageFile);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📤 Upload progress: ${progress.toStringAsFixed(1)}%');
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Image uploaded to Firebase Storage: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('❌ Error uploading to Firebase Storage: $e');
      // Return local path as fallback if Firebase Storage fails
      print('🔄 Using local file path as fallback');
      return imageFile.path;
    }
  }
  
  /// Upload image with retry logic
  static Future<String> uploadImageWithRetry(File imageFile, {int maxRetries = 3}) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await uploadImage(imageFile);
      } catch (e) {
        attempts++;
        print('❌ Upload attempt $attempts failed: $e');
        
        if (attempts >= maxRetries) {
          print('❌ Max upload retries exceeded');
          // Return local path as final fallback
          print('🔄 Using local file path as final fallback');
          return imageFile.path;
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    
    // This should never be reached due to the fallback above
    return imageFile.path;
  }
} 