import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../data/models/moment.dart';
import '../utils/imagekit.dart';

class WallpaperHelper {
  // ─── Channel ───────────────────────────────────────────────────────────────
  static const MethodChannel _channel = MethodChannel('com.ataraxia/wallpaper');

  // ─── Location flags ────────────────────────────────────────────────────────
  static const int FLAG_SYSTEM = 1;
  static const int FLAG_LOCK = 2;
  static const int FLAG_BOTH = 3;

  // ═══════════════════════════════════════════════════════════════════════════
  // FILE → WALLPAPER (STATIC)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sets a static wallpaper from a local [filePath].
  /// Falls back to the native write-intent picker for the lock screen if the
  /// silent set fails (required on some Android versions).
  static Future<void> setWallpaperFromFile(
    String filePath, {
    int location = FLAG_SYSTEM,
  }) async {
    if (!await File(filePath).exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final String mode = switch (location) {
      FLAG_SYSTEM => 'home',
      FLAG_LOCK => 'lock',
      _ => 'both',
    };

    try {
      final bool success = await _channel.invokeMethod('setWallpaper', {
        'path': filePath,
        'mode': mode,
      });
      if (!success) throw Exception('Native setWallpaper returned false');
    } catch (e) {
      debugPrint('Silent wallpaper set failed: $e');
      // Fallback: open native picker for lock screen if silent set fails.
      if (location == FLAG_LOCK || location == FLAG_BOTH) {
        await _channel.invokeMethod('openWriteIntent', {'path': filePath});
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SACRED WALLPAPER  (360° sphere or parallax engine)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Main entry point. Chooses the correct engine based on [m.type] / [m.is360]:
  ///   • panorama / is360  → OpenGL 360° sphere
  ///   • parallax          → 4D parallax engine (foreground + background layers)
  ///   • fallback          → static wallpaper
  static Future<void> setSacredWallpaper(Moment m) async {
    try {
      // ── 360° Sphere route ─────────────────────────────────────────────────
      if (m.type == 'panorama' || m.is360) {
        final File file = await _streamDownloadImage(
          ImageKit.original(m.imageKey),
          '${m.id}_360',
        );

        final bool success = await _channel.invokeMethod('set360Wallpaper', {
          'image': file.path,
        });

        if (!success) throw Exception('Native 360 engine returned false.');
        return;
      }

      // ── Parallax / 4D route ───────────────────────────────────────────────
      final String? foreKey = m.foreLayerKey;
      if (foreKey == null || foreKey.isEmpty) {
        throw Exception(
          'Cannot launch parallax engine: foreLayerKey is missing for moment ${m.id}.',
        );
      }

      final List<File> downloads = await Future.wait([
        _streamDownloadImage(ImageKit.original(m.imageKey), '${m.id}_bg'),
        _streamDownloadImage(ImageKit.original(foreKey), '${m.id}_fore'),
      ]);

      final String bgPath = downloads[0].path;
      final String forePath = downloads[1].path;

      // MainActivity.kt must save 'bg_path' and 'fore_path' to SharedPreferences
      // so the WallpaperService can read them after a reboot.
      final bool liveSuccess = await _channel.invokeMethod(
        'setParallaxWallpaper',
        {'bg': bgPath, 'fore': forePath},
      );

      if (!liveSuccess) {
        // Parallax engine failed — fall back to the static background layer.
        debugPrint('Parallax engine failed, falling back to static wallpaper.');
        await _channel.invokeMethod('setWallpaper', {
          'path': bgPath,
          'mode': 'both',
        });
      }
    } catch (e) {
      debugPrint('setSacredWallpaper failed: $e');
      // Last resort: set the raw image as a static wallpaper so the user
      // always sees something rather than their old wallpaper or a crash.
      await setWallpaperFromFile(ImageKit.original(m.imageKey));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAMING DOWNLOADER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Downloads [url] and streams bytes directly to disk at [fileName].
  ///
  /// Streaming avoids loading the entire image (often 10–30 MB for 360°
  /// panoramas) into RAM as a Uint8List, which eliminates the download-lag
  /// jank on mid-range devices.
  ///
  /// The file extension is inferred from the URL so that PNG foreground
  /// layers (which carry transparency) are never accidentally saved as JPEG.
  static Future<File> _streamDownloadImage(String url, String fileName) async {
    final http.Client client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Download failed for $fileName — HTTP ${response.statusCode}',
        );
      }

      // Infer the correct extension from the URL.
      // IMPORTANT: PNG files carry alpha channels (transparent foreground
      // layers). Saving them as .jpg would destroy the transparency.
      final String ext = _extensionFromUrl(url);

      final Directory docDir = await getApplicationDocumentsDirectory();
      final File file = File('${docDir.path}/$fileName.$ext');

      final IOSink sink = file.openWrite();
      await response.stream.pipe(sink);
      await sink.flush();
      await sink.close();

      return file;
    } catch (e) {
      debugPrint('Download error ($fileName): $e');
      rethrow;
    } finally {
      // FIX: Always close the client to avoid exhausting the connection pool.
      client.close();
    }
  }

  /// Returns 'png', 'webp', or 'jpg' based on the file extension in [url].
  static String _extensionFromUrl(String url) {
    final String lower = url.toLowerCase();
    if (lower.contains('.png')) return 'png';
    if (lower.contains('.webp')) return 'webp';
    return 'jpg';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKWARD COMPATIBILITY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Kept for any existing call sites that use the old [downloadImage] name.
  static Future<File> downloadImage(String url, String fileName) =>
      _streamDownloadImage(url, fileName);
}
