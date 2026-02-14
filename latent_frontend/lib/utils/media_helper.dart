import 'dart:io';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class MediaHelper {
  /// Compresses an image file to a target quality and size.
  static Future<File?> compressImage(File file) async {
    final filePath = file.absolute.path;
    
    // Create output path
    final lastIndex = filePath.lastIndexOf(RegExp(r'.png|.jpg|.jpeg'));
    final splitted = filePath.substring(0, (lastIndex));
    final outPath = "${splitted}_compressed.jpg";

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, 
      outPath,
      quality: 70,
    );

    return result != null ? File(result.path) : null;
  }

  /// Compresses a video file to 720p or medium quality.
  static Future<File?> compressVideo(File file) async {
    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false, // Keep the original for safety
        includeAudio: true,
      );

      return mediaInfo != null ? mediaInfo.file : null;
    } catch (e) {
      return null;
    }
  }

  /// Clears the compression cache to save device space.
  static Future<void> clearCache() async {
    await VideoCompress.deleteAllCache();
  }
}
