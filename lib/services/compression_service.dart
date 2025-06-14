import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CompressionService {
  /// Compress an image file for API upload
  /// Returns a compressed File that's suitable for base64 encoding
  static Future<File> compressImageForAPI({
    required File originalFile,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 80,
    String? targetPath,
  }) async {
    try {
      print('🗜️ Starting image compression...');
      print('📏 Original file size: ${await originalFile.length()} bytes');
      
      // Get target path for compressed image
      String compressedPath;
      if (targetPath != null) {
        compressedPath = targetPath;
      } else {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basenameWithoutExtension(originalFile.path);
        compressedPath = path.join(
          tempDir.path, 
          '${fileName}_compressed.jpg'
        );
      }
      
      // Compress the image
      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        compressedPath,
        quality: quality,
        format: CompressFormat.jpeg, // Always use JPEG for better compression
      );
      
      if (compressedXFile == null) {
        print('❌ Compression failed, using original file');
        return originalFile;
      }
      
      // Convert XFile to File
      final compressedFile = File(compressedXFile.path);
      final compressedSize = await compressedFile.length();
      
      print('✅ Compression complete!');
      print('📏 Original size: ${await originalFile.length()} bytes');
      print('📏 Compressed size: $compressedSize bytes');
      print('📊 Compression ratio: ${((1 - (compressedSize / await originalFile.length())) * 100).toStringAsFixed(1)}%');
      
      return compressedFile;
      
    } catch (e) {
      print('❌ Error during compression: $e');
      print('🔄 Falling back to original file');
      return originalFile;
    }
  }
  
  /// Compress image with different quality levels until it's under target size
  static Future<File> compressToTargetSize({
    required File originalFile,
    int targetSizeKB = 500, // Target 500KB by default
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) async {
    try {
      print('🎯 Compressing to target size: ${targetSizeKB}KB');
      
      final originalSize = await originalFile.length();
      final targetSizeBytes = targetSizeKB * 1024;
      
      if (originalSize <= targetSizeBytes) {
        print('✅ Original file already under target size');
        return originalFile;
      }
      
      // Try different quality levels
      final qualityLevels = [80, 60, 40, 30, 20, 15, 10];
      
      for (final quality in qualityLevels) {
        print('🔧 Trying quality level: $quality%');
        
        final compressedFile = await compressImageForAPI(
          originalFile: originalFile,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: quality,
        );
        
        final compressedSize = await compressedFile.length();
        
        if (compressedSize <= targetSizeBytes) {
          print('✅ Target size achieved with quality $quality%');
          return compressedFile;
        }
        
        print('📏 Still too large: ${compressedSize} bytes (target: $targetSizeBytes bytes)');
      }
      
      // If still too large, try reducing dimensions
      print('🔧 Reducing image dimensions...');
      
      final dimensionSizes = [
        [800, 800],
        [640, 640],
        [512, 512],
        [400, 400],
        [320, 320],
      ];
      
      for (final dimensions in dimensionSizes) {
        print('🔧 Trying dimensions: ${dimensions[0]}x${dimensions[1]}');
        
        final compressedFile = await compressImageForAPI(
          originalFile: originalFile,
          maxWidth: dimensions[0],
          maxHeight: dimensions[1],
          quality: 15, // Use lowest quality for smallest size
        );
        
        final compressedSize = await compressedFile.length();
        
        if (compressedSize <= targetSizeBytes) {
          print('✅ Target size achieved with dimensions ${dimensions[0]}x${dimensions[1]}');
          return compressedFile;
        }
      }
      
      print('⚠️ Could not achieve target size, returning best compression');
      return await compressImageForAPI(
        originalFile: originalFile,
        maxWidth: 320,
        maxHeight: 320,
        quality: 10,
      );
      
    } catch (e) {
      print('❌ Error during target size compression: $e');
      return originalFile;
    }
  }
  
  /// Quick compression for immediate use
  static Future<File> quickCompress(File originalFile) async {
    return await compressImageForAPI(
      originalFile: originalFile,
      maxWidth: 800,
      maxHeight: 800,
      quality: 70,
    );
  }
  
  /// Aggressive compression for API limits
  static Future<File> aggressiveCompress(File originalFile) async {
    return await compressToTargetSize(
      originalFile: originalFile,
      targetSizeKB: 300, // Very small target
      maxWidth: 640,
      maxHeight: 640,
    );
  }
  
  /// Get estimated base64 size (base64 is ~33% larger than binary)
  static Future<int> getEstimatedBase64Size(File file) async {
    final fileSize = await file.length();
    return (fileSize * 1.33).round(); // Base64 encoding increases size by ~33%
  }
  
  /// Check if file is suitable for base64 encoding (under specific limit)
  static Future<bool> isSuitableForBase64(File file, {int maxSizeKB = 500}) async {
    final estimatedBase64Size = await getEstimatedBase64Size(file);
    return estimatedBase64Size <= (maxSizeKB * 1024);
  }
  
  /// Clean up temporary compressed files
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync();
      
      for (final file in tempFiles) {
        if (file is File && file.path.contains('_compressed')) {
          try {
            await file.delete();
          } catch (e) {
            // Ignore errors when deleting temp files
          }
        }
      }
      
      print('🧹 Temporary compressed files cleaned up');
    } catch (e) {
      print('⚠️ Error cleaning up temp files: $e');
    }
  }
} 