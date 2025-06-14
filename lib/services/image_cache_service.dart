import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Memory cache for quick access
  static final Map<String, Uint8List> _memoryCache = {};
  
  // Cache settings
  static const int maxMemoryCacheSize = 50;
  static const int maxDiskCacheSize = 100;
  static const Duration cacheDuration = Duration(days: 7);
  
  // Directory for cached images
  static Directory? _cacheDirectory;
  
  /// Initialize the cache service
  static Future<void> initialize() async {
    try {
      final directory = await getApplicationCacheDirectory();
      _cacheDirectory = Directory(path.join(directory.path, 'image_cache'));
      
      if (!await _cacheDirectory!.exists()) {
        await _cacheDirectory!.create(recursive: true);
        print('📁 Created image cache directory: ${_cacheDirectory!.path}');
      } else {
        print('📁 Image cache directory exists: ${_cacheDirectory!.path}');
      }
      
      await _cleanupOldCacheFiles();
      print('✅ Image cache service initialized successfully');
      print('💾 Cache directory: ${_cacheDirectory!.path}');
    } catch (e) {
      print('❌ Error initializing image cache service: $e');
    }
  }
  
  /// Generate a cache key from URL
  static String _generateCacheKey(String source) {
    return md5.convert(utf8.encode(source)).toString();
  }
  
  /// Get cached file path
  static String _getCacheFilePath(String cacheKey) {
    return path.join(_cacheDirectory!.path, '$cacheKey.jpg');
  }
  
  /// Check if image exists in disk cache and is valid
  static Future<bool> isInDiskCache(String source) async {
    if (_cacheDirectory == null) return false;
    
    try {
      final cacheKey = _generateCacheKey(source);
      final cachedFile = File(_getCacheFilePath(cacheKey));
      
      if (!await cachedFile.exists()) return false;
      
      final stat = await cachedFile.stat();
      final age = DateTime.now().difference(stat.modified);
      
      if (age > cacheDuration) {
        await cachedFile.delete();
        return false;
      }
      
      return true;
    } catch (e) {
      print('❌ Error checking disk cache: $e');
      return false;
    }
  }
  
  /// Get image data from memory cache
  static Uint8List? getFromMemoryCache(String source) {
    final cacheKey = _generateCacheKey(source);
    return _memoryCache[cacheKey];
  }
  
  /// Get image data from disk cache
  static Future<Uint8List?> getFromDiskCache(String source) async {
    if (!await isInDiskCache(source)) return null;
    
    try {
      final cacheKey = _generateCacheKey(source);
      final cachedFile = File(_getCacheFilePath(cacheKey));
      return await cachedFile.readAsBytes();
    } catch (e) {
      print('❌ Error reading from disk cache: $e');
      return null;
    }
  }
  
  /// Store image data in memory cache
  static void storeInMemoryCache(String source, Uint8List data) {
    try {
      final cacheKey = _generateCacheKey(source);
      
      if (_memoryCache.length >= maxMemoryCacheSize) {
        final firstKey = _memoryCache.keys.first;
        _memoryCache.remove(firstKey);
      }
      
      _memoryCache[cacheKey] = data;
    } catch (e) {
      print('❌ Error storing in memory cache: $e');
    }
  }
  
  /// Store image data in disk cache
  static Future<void> storeInDiskCache(String source, Uint8List data) async {
    if (_cacheDirectory == null) return;
    
    try {
      final cacheKey = _generateCacheKey(source);
      final cachedFile = File(_getCacheFilePath(cacheKey));
      await cachedFile.writeAsBytes(data);
      await _updateCacheMetadata(cacheKey);
      await _cleanupDiskCache();
    } catch (e) {
      print('❌ Error storing in disk cache: $e');
    }
  }
  
  /// Download and cache network image
  static Future<Uint8List?> _downloadAndCacheImage(String imageUrl) async {
    try {
      print('📥 Downloading image: $imageUrl');
      
      final uri = Uri.parse(imageUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        print('❌ Invalid URL scheme: ${uri.scheme}');
        return null;
      }
      
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'KaliAI/1.0',
          'Accept': 'image/*',
        },
      ).timeout(Duration(seconds: 30));
      
      print('📡 HTTP Response: ${response.statusCode} for $imageUrl');
      
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final data = response.bodyBytes;
        print('📦 Downloaded ${data.length} bytes');
        
        // Store in memory cache first
        storeInMemoryCache(imageUrl, data);
        print('💾 Stored in memory cache');
        
        // Then store in disk cache
        await storeInDiskCache(imageUrl, data);
        print('💿 Stored in disk cache');
        
        print('✅ Image downloaded and cached successfully: ${data.length} bytes');
        return data;
      } else {
        print('❌ Failed to download image: HTTP ${response.statusCode}, body length: ${response.bodyBytes.length}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading image: $e');
      return null;
    }
  }
  
  /// Get cached image widget with automatic caching
  static Widget getCachedImage(
    String source, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (source.isEmpty) {
      return errorWidget ?? _buildErrorWidget(width, height);
    }

    final isNetworkImage = source.startsWith('http://') || source.startsWith('https://');
    
    if (isNetworkImage) {
      return _buildNetworkCachedImage(
        source,
        fit: fit,
        width: width,
        height: height,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    } else {
      return _buildLocalCachedImage(
        source,
        fit: fit,
        width: width,
        height: height,
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }
  }
  
  /// Build network cached image widget
  static Widget _buildNetworkCachedImage(
    String imageUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return FutureBuilder<Uint8List?>(
      future: _getNetworkImageData(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? _buildLoadingPlaceholder(width, height);
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return errorWidget ?? _buildErrorWidget(width, height);
        }
        
        return Image.memory(
          snapshot.data!,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _buildErrorWidget(width, height);
          },
        );
      },
    );
  }
  
  /// Build local cached image widget
  static Widget _buildLocalCachedImage(
    String filePath, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return FutureBuilder<Uint8List?>(
      future: _getLocalImageData(filePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? _buildLoadingPlaceholder(width, height);
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return errorWidget ?? _buildErrorWidget(width, height);
        }
        
        return Image.memory(
          snapshot.data!,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _buildErrorWidget(width, height);
          },
        );
      },
    );
  }
  
  /// Get network image data with caching
  static Future<Uint8List?> _getNetworkImageData(String imageUrl) async {
    print('🔍 Looking for image: $imageUrl');
    
    // Check memory cache first
    final memoryData = getFromMemoryCache(imageUrl);
    if (memoryData != null) {
      print('📦 Image loaded from memory cache: ${memoryData.length} bytes');
      return memoryData;
    }
    print('❌ Not found in memory cache');
    
    // Check disk cache
    final diskData = await getFromDiskCache(imageUrl);
    if (diskData != null) {
      print('💾 Image loaded from disk cache: ${diskData.length} bytes');
      storeInMemoryCache(imageUrl, diskData);
      print('📦 Stored in memory cache for future use');
      return diskData;
    }
    print('❌ Not found in disk cache');
    
    // Download and cache
    print('🌐 Downloading from network...');
    return await _downloadAndCacheImage(imageUrl);
  }
  
  /// Get local image data with caching
  static Future<Uint8List?> _getLocalImageData(String filePath) async {
    try {
      // Check memory cache first
      final memoryData = getFromMemoryCache(filePath);
      if (memoryData != null) {
        print('📦 Local image loaded from memory cache');
        return memoryData;
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ Local file does not exist: $filePath');
        return null;
      }
      
      final data = await file.readAsBytes();
      storeInMemoryCache(filePath, data);
      print('📱 Local image loaded from file');
      return data;
    } catch (e) {
      print('❌ Error loading local image: $e');
      return null;
    }
  }
  
  /// Build loading placeholder
  static Widget _buildLoadingPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
    );
  }
  
  /// Build error widget
  static Widget _buildErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: 32,
      ),
    );
  }
  
  /// Update cache metadata for cleanup
  static Future<void> _updateCacheMetadata(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = prefs.getStringList('image_cache_metadata') ?? [];
      
      metadata.removeWhere((entry) => entry.startsWith('$cacheKey:'));
      metadata.add('$cacheKey:${DateTime.now().millisecondsSinceEpoch}');
      
      await prefs.setStringList('image_cache_metadata', metadata);
    } catch (e) {
      print('❌ Error updating cache metadata: $e');
    }
  }
  
  /// Clean up old cache files
  static Future<void> _cleanupOldCacheFiles() async {
    if (_cacheDirectory == null) return;
    
    try {
      final now = DateTime.now();
      final files = await _cacheDirectory!.list().toList();
      
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);
          
          if (age > cacheDuration) {
            await file.delete();
            print('🗑️ Deleted expired cache file: ${path.basename(file.path)}');
          }
        }
      }
    } catch (e) {
      print('❌ Error cleaning up old cache files: $e');
    }
  }
  
  /// Clean up disk cache when it gets too large
  static Future<void> _cleanupDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = prefs.getStringList('image_cache_metadata') ?? [];
      
      if (metadata.length <= maxDiskCacheSize) return;
      
      metadata.sort((a, b) {
        final timestampA = int.parse(a.split(':')[1]);
        final timestampB = int.parse(b.split(':')[1]);
        return timestampA.compareTo(timestampB);
      });
      
      final filesToRemove = metadata.take(metadata.length - maxDiskCacheSize);
      for (final entry in filesToRemove) {
        final cacheKey = entry.split(':')[0];
        final filePath = _getCacheFilePath(cacheKey);
        final file = File(filePath);
        
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted old cache file: $cacheKey');
        }
      }
      
      final remainingMetadata = metadata.skip(metadata.length - maxDiskCacheSize).toList();
      await prefs.setStringList('image_cache_metadata', remainingMetadata);
      
    } catch (e) {
      print('❌ Error cleaning up disk cache: $e');
    }
  }
  
  /// Clear all caches
  static Future<void> clearAllCaches() async {
    try {
      _memoryCache.clear();
      
      if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
        final files = await _cacheDirectory!.list().toList();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('image_cache_metadata');
      
      print('✅ All image caches cleared');
    } catch (e) {
      print('❌ Error clearing caches: $e');
    }
  }
} 