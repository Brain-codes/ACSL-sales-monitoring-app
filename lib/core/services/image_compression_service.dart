import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCompressionService {
  static final Logger _logger = Logger();

  /// Compresses an image file and returns the compressed file
  ///
  /// Parameters:
  /// - [file]: The original image file to compress
  /// - [quality]: Compression quality (0-100), default is 70
  /// - [minWidth]: Minimum width in pixels, default is 300
  /// - [minHeight]: Minimum height in pixels, default is 300
  ///
  /// Returns compressed File or null if compression fails
  static Future<File?> compressImage(
    File file, {
    int quality = 70,
    int minWidth = 300,
    int minHeight = 300,
  }) async {
    try {
      _logger.d('Starting image compression for: ${file.path}');

      // Get file info
      final originalSize = await file.length();
      _logger.d(
          'Original file size: ${(originalSize / 1024).toStringAsFixed(2)} KB');

      // Get temporary directory for output
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basenameWithoutExtension(file.path);
      final fileExtension = path.extension(file.path);
      final outputPath = path.join(
        tempDir.path,
        '${fileName}_compressed$fileExtension',
      );

      // Compress the image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outputPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: _getCompressFormat(fileExtension),
        keepExif: false, // Remove EXIF data to reduce size
      );

      if (compressedFile != null) {
        final compressedSize = await compressedFile.length();
        final compressionRatio =
            ((originalSize - compressedSize) / originalSize * 100);

        _logger.d(
            'Compressed file size: ${(compressedSize / 1024).toStringAsFixed(2)} KB');
        _logger.d('Compression ratio: ${compressionRatio.toStringAsFixed(1)}%');

        return File(compressedFile.path);
      } else {
        _logger.e('Image compression failed - returned null');
        return file; // Return original file if compression fails
      }
    } catch (e) {
      _logger.e('Error during image compression: $e');
      return file; // Return original file if compression fails
    }
  }

  /// Compresses image from Uint8List (useful for camera captures)
  ///
  /// Parameters:
  /// - [bytes]: The original image bytes to compress
  /// - [quality]: Compression quality (0-100), default is 70
  /// - [minWidth]: Minimum width in pixels, default is 300
  /// - [minHeight]: Minimum height in pixels, default is 300
  ///
  /// Returns compressed Uint8List or original bytes if compression fails
  static Future<Uint8List?> compressImageFromBytes(
    Uint8List bytes, {
    int quality = 70,
    int minWidth = 300,
    int minHeight = 300,
  }) async {
    try {
      _logger.d('Starting image compression from bytes');
      _logger.d(
          'Original bytes size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');

      // Create a temporary file from bytes
      final tempDir = await getTemporaryDirectory();
      final tempInputPath = path.join(
        tempDir.path,
        'temp_input_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final tempOutputPath = path.join(
        tempDir.path,
        'temp_output_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Write bytes to temporary file
      final tempInputFile = File(tempInputPath);
      await tempInputFile.writeAsBytes(bytes);

      // Compress the temporary file with available parameters
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        tempInputFile.absolute.path,
        tempOutputPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (compressedFile != null) {
        // Read compressed file back to bytes
        final compressedBytes = await File(compressedFile.path).readAsBytes();

        final compressionRatio =
            ((bytes.length - compressedBytes.length) / bytes.length * 100);
        _logger.d(
            'Compressed bytes size: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
        _logger.d('Compression ratio: ${compressionRatio.toStringAsFixed(1)}%');

        // Clean up temporary files
        try {
          await tempInputFile.delete();
          await File(compressedFile.path).delete();
        } catch (e) {
          _logger.w('Failed to clean up temporary files: $e');
        }

        return compressedBytes;
      } else {
        _logger.e('Image compression failed - returned null');

        // Clean up input file
        try {
          await tempInputFile.delete();
        } catch (e) {
          _logger.w('Failed to clean up temporary input file: $e');
        }

        return bytes; // Return original bytes if compression fails
      }
    } catch (e) {
      _logger.e('Error during bytes compression: $e');
      return bytes; // Return original bytes if compression fails
    }
  }

  /// Determines the compression format based on file extension
  static CompressFormat _getCompressFormat(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return CompressFormat.png;
      case '.webp':
        return CompressFormat.webp;
      case '.heic':
        return CompressFormat.heic;
      default:
        return CompressFormat.jpeg;
    }
  }

  /// Gets the optimal compression settings based on file size
  static Map<String, int> getOptimalSettings(int fileSizeBytes) {
    // For files larger than 5MB, use more aggressive compression
    if (fileSizeBytes > 5 * 1024 * 1024) {
      return {
        'quality': 60,
        'minWidth': 200,
        'minHeight': 200,
      };
    }
    // For files larger than 2MB, use moderate compression
    else if (fileSizeBytes > 2 * 1024 * 1024) {
      return {
        'quality': 70,
        'minWidth': 300,
        'minHeight': 300,
      };
    }
    // For smaller files, use light compression
    else {
      return {
        'quality': 80,
        'minWidth': 400,
        'minHeight': 400,
      };
    }
  }
}
