import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/moment.dart';
import '../utils/imagekit.dart';

// 🚀 NEW: The enum that defines the visual vibe of the exported image
enum ShareStyle { explore, memory }

class ShareService {
  static const int _maxCacheFiles = 10;

  // 🔥 cap resolution (VERY IMPORTANT for low-end devices)
  static const int _maxDimension = 1080;

  static Uint8List? _cachedLogoBytes;

  static Future<Uint8List> _getLogoBytes() async {
    if (_cachedLogoBytes != null) return _cachedLogoBytes!;
    final data = await rootBundle.load('assets/app_icon_foreground.png');
    _cachedLogoBytes = data.buffer.asUint8List();
    return _cachedLogoBytes!;
  }

  // ─────────────────────────────────────────────
  // 🧠 PUBLIC API
  // ─────────────────────────────────────────────

  // 🚀 1. Just generates and returns the file (Used while overlay is loading)
  static Future<File> prepareShareFile(
    Moment moment, {
    ShareStyle style = ShareStyle.explore,
  }) async {
    final file = await _getCachedFile(moment, style);

    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
      return file;
    }

    final bytes = await _generateImage(moment, style);
    await file.writeAsBytes(bytes);
    await _evictIfNeeded();

    return file;
  }

  // 🚀 2. Triggers the OS Share Sheet (Called AFTER overlay closes)
  static Future<void> invokeNativeShare(File file, Moment moment) async {
    final finalUrl = 'https://theataraxia.web.app/${moment.slug}';
    final text =
        "\"${moment.title}\"\n— ${moment.author ?? 'Unknown'}\n\nEnter the void: $finalUrl";

    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      subject: 'An Echo from Ataraxia',
    );
  }

  static Future<void> preCacheMoment(
    Moment moment, {
    ShareStyle style = ShareStyle.explore,
  }) async {
    final file = await _getCachedFile(moment, style);

    if (await file.exists()) return;

    try {
      final bytes = await _generateImage(moment, style);
      await file.writeAsBytes(bytes);
      await _evictIfNeeded();
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // ⚙️ CORE PIPELINE
  // ─────────────────────────────────────────────

  static Future<Uint8List> _generateImage(
    Moment moment,
    ShareStyle style,
  ) async {
    final url = ImageKit.original(moment.imageKey);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to download image');
    }

    final logoBytes = await _getLogoBytes();
    final bytes = response.bodyBytes;

    // 🔥 smart isolate trigger
    final bool useIsolate = bytes.length > 500000; // ~500KB+

    if (useIsolate) {
      try {
        return await compute(_watermarkWorker, {
          'image': bytes,
          'logo': logoBytes,
          'quote': moment.title,
          'author': moment.author ?? 'Unknown',
          'style': style.index, // Pass the enum index to the isolate
        });
      } catch (_) {}
    }

    // Fallback if isolate fails or image is small enough
    return await _applyPremiumWatermark(
      bytes,
      logoBytes,
      moment.title,
      moment.author ?? 'Unknown',
      style,
    );
  }

  // ─────────────────────────────────────────────
  // 🖼️ CORE WATERMARK (CINEMATIC ENGINE)
  // ─────────────────────────────────────────────

  static Future<Uint8List> _applyPremiumWatermark(
    Uint8List imageBytes,
    Uint8List logoBytes,
    String quote,
    String author,
    ShareStyle style,
  ) async {
    if (style == ShareStyle.explore) {
      return _applyMinimalWatermark(imageBytes, logoBytes);
    }
    // 🔥 Downscale during decode (BIGGEST WIN for memory)
    final ui.Codec bgCodec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: _maxDimension,
    );

    final ui.Image bgImage = (await bgCodec.getNextFrame()).image;

    final int targetLogoWidth = (bgImage.width * 0.16).toInt(); // size

    final ui.Codec logoCodec = await ui.instantiateImageCodec(
      logoBytes,
      targetWidth: targetLogoWidth,
    );

    final ui.Image logoImage = (await logoCodec.getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(
      0,
      0,
      bgImage.width.toDouble(),
      bgImage.height.toDouble(),
    );

    // 1. Draw the beautiful background image
    canvas.drawImage(bgImage, Offset.zero, Paint());

    // 2. Draw Cinematic Bottom Gradient (So the white text is always readable)
    final gradient = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, bgImage.height * 0.55), // Starts slightly lower than halfway
        Offset(0, bgImage.height.toDouble()),
        [
          const Color(0x00000000),
          const Color(0xCC000000),
        ], // Transparent to 80% Black
      );
    canvas.drawRect(rect, gradient);

    // 3. ✨ THE MEMORY TINT: If it's a memory, wash the whole thing in a moody 13% shadow
    if (style == ShareStyle.memory) {
      canvas.drawRect(rect, Paint()..color = const Color(0x22000000));
    }

    // 4. Build Quote
    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.center,
      maxLines: 4,
    );

    final textStyle = ui.TextStyle(
      color: const Color(0xFFFFFFFF),
      fontSize: bgImage.width * 0.055,
      fontStyle: FontStyle.italic,
      fontFamily: 'Times New Roman',
      height: 1.3,
    );

    final paragraph =
        (ui.ParagraphBuilder(paragraphStyle)
              ..pushStyle(textStyle)
              ..addText('"$quote"'))
            .build();

    paragraph.layout(ui.ParagraphConstraints(width: bgImage.width * 0.8));

    // 5. Build Author
    final authorParagraph =
        (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
              ..pushStyle(
                ui.TextStyle(
                  color: const Color(0xB3FFFFFF),
                  fontSize: bgImage.width * 0.03,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Courier',
                ),
              )
              ..addText('— ${author.toUpperCase()}'))
            .build();

    authorParagraph.layout(ui.ParagraphConstraints(width: bgImage.width * 0.8));

    // 6. Logo position (ANCHOR)
    final double padding = bgImage.width * 0.04;
    final double logoX = (bgImage.width - logoImage.width) / 2;
    final double logoY = bgImage.height - logoImage.height - padding;

    // 7. Spacing (tweak here 🎯)
    final double authorToLogoGap = bgImage.height * 0.055;
    final double quoteToAuthorGap = bgImage.height * 0.02;

    // 8. Position Author (above logo)
    final double authorY = logoY - authorParagraph.height - authorToLogoGap;

    // 9. Position Quote (above author)
    double quoteY = authorY - paragraph.height - quoteToAuthorGap;

    // 10. Safety clamp (prevents going too high)
    final double minQuoteY = bgImage.height * 0.58;
    if (quoteY < minQuoteY) quoteY = minQuoteY;

    double adjustedAuthorY = authorY;
    double adjustedQuoteY = quoteY;

    final double minAuthorY = minQuoteY + paragraph.height + quoteToAuthorGap;

    if (adjustedAuthorY < minAuthorY) {
      final shift = minAuthorY - adjustedAuthorY;

      adjustedAuthorY += shift;
      adjustedQuoteY += shift;
    }

    // 11. Draw Quote & Author
    canvas.drawParagraph(
      paragraph,
      Offset(bgImage.width * 0.1, adjustedQuoteY),
    );

    canvas.drawParagraph(
      authorParagraph,
      Offset(bgImage.width * 0.1, adjustedAuthorY),
    );

    // Subtle glow behind the logo
    final Rect shadowRect = Rect.fromLTWH(
      logoX - padding,
      logoY - padding,
      logoImage.width + padding * 2,
      logoImage.height + padding * 2,
    );

    final shadowPaint = Paint()
      ..shader = ui.Gradient.radial(shadowRect.center, shadowRect.width * 0.5, [
        const Color(0x66000000),
        const Color(0x00000000),
      ]);

    canvas.drawRect(shadowRect, shadowPaint);

    final logoPaint = Paint()..color = const Color(0xD9FFFFFF); // 85% opacity
    canvas.drawImage(logoImage, Offset(logoX, logoY), logoPaint);

    // 7. Render out the final masterpiece
    final finalImage = await recorder.endRecording().toImage(
      bgImage.width,
      bgImage.height,
    );

    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  static Future<Uint8List> _applyMinimalWatermark(
    Uint8List imageBytes,
    Uint8List logoBytes,
  ) async {
    // Decode background
    final ui.Codec bgCodec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: _maxDimension,
    );

    final ui.Image bgImage = (await bgCodec.getNextFrame()).image;

    // Smaller logo = premium feel
    final int targetLogoWidth = (bgImage.width * 0.12).toInt();

    final ui.Codec logoCodec = await ui.instantiateImageCodec(
      logoBytes,
      targetWidth: targetLogoWidth,
    );

    final ui.Image logoImage = (await logoCodec.getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Draw background
    canvas.drawImage(bgImage, Offset.zero, Paint());

    final double padding = bgImage.width * 0.035;

    final double logoX = bgImage.width - logoImage.width - padding;
    final double logoY = bgImage.height - logoImage.height - padding;

    // 2. Premium soft glow (clean, not muddy)
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..color = const Color(0x33000000);

    canvas.drawCircle(
      Offset(logoX + logoImage.width / 2, logoY + logoImage.height / 2),
      logoImage.width * 0.8,
      glowPaint,
    );

    // 3. Draw logo (slightly sharper than before)
    final logoPaint = Paint()..color = const Color(0xE6FFFFFF);

    canvas.drawImage(logoImage, Offset(logoX, logoY), logoPaint);

    // 4. Export image
    final finalImage = await recorder.endRecording().toImage(
      bgImage.width,
      bgImage.height,
    );

    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  // ─────────────────────────────────────────────
  // 💾 CACHE (LRU)
  // ─────────────────────────────────────────────

  static Future<File> _getCachedFile(Moment moment, ShareStyle style) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/moment_${moment.id}_${style.name}.png');
  }

  static Future<List<File>> _getAllCacheFiles() async {
    final dir = await getTemporaryDirectory();

    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('moment_'))
        .toList();
  }

  static Future<void> _evictIfNeeded() async {
    final files = await _getAllCacheFiles();

    if (files.length <= _maxCacheFiles) return;

    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    for (final file in files.take(files.length - _maxCacheFiles)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}

// ─────────────────────────────────────────────
// 🚀 ISOLATE WORKER (THIN WRAPPER)
// ─────────────────────────────────────────────

Future<Uint8List> _watermarkWorker(Map<String, dynamic> data) async {
  return ShareService._applyPremiumWatermark(
    data['image'] as Uint8List,
    data['logo'] as Uint8List,
    data['quote'] as String,
    data['author'] as String,
    ShareStyle.values[data['style'] as int], // Reconstruct enum from index
  );
}
