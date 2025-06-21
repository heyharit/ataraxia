import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ImageComposer {
  static Future<File> composeLockScreen({
    required String imageUrl,
    required String quote,
    required String author,
  }) async {
    // 1. Download the raw image
    final response = await http.get(Uri.parse(imageUrl));
    final bytes = response.bodyBytes;

    // 2. Decode using Flutter's high-speed C++ engine
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final width = image.width.toDouble();
    final height = image.height.toDouble();

    // 3. Setup the Canvas
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // 4. Draw the base image (Untouched, full brightness!)
    canvas.drawImage(image, Offset.zero, Paint());

    // 5. THE MAGIC: Cinematic Scrim
    // Paints a smooth shadow that fades up from the bottom so text is readable
    // but the rest of the artwork remains pristine.
    final gradient = ui.Gradient.linear(
      Offset(width / 2, height * 0.45), // Starts fading 45% down
      Offset(width / 2, height), // Fully dark at the bottom edge
      [
        Colors.transparent,
        Colors.black.withOpacity(0.6),
        Colors.black.withOpacity(0.95),
      ],
      [0.0, 0.5, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, height * 0.45, width, height * 0.55),
      Paint()..shader = gradient,
    );

    // 6. PREMIUM TYPOGRAPHY SETUP
    final quoteStyle = ui.TextStyle(
      color: Colors.white.withOpacity(0.85),
      fontSize: width * 0.035, // Scales perfectly with any image resolution
      fontFamily: 'serif', // Safe default for background isolates
      fontStyle: ui.FontStyle.italic,
      height: 1.25,
      shadows: [
        ui.Shadow(
          color: Colors.black.withOpacity(0.9),
          blurRadius: 13,
          offset: const Offset(0, 5),
        ),
      ],
    );

    final authorStyle = ui.TextStyle(
      color: Colors.white.withOpacity(0.65),
      fontSize: width * 0.016,
      letterSpacing: width * 0.007, // Wide, elegant tracking
      fontWeight: FontWeight.w500,
    );

    // 7. Layout the Quote
    final quoteBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, maxLines: 6),
          )
          ..pushStyle(quoteStyle)
          ..addText(quote);

    final quoteParagraph = quoteBuilder.build()
      ..layout(
        ui.ParagraphConstraints(width: width * 0.8),
      ); // 10% padding on sides

    // 8. Layout the Author
    final authorBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, maxLines: 1),
          )
          ..pushStyle(authorStyle)
          ..addText("— ${author.toUpperCase()} —");

    final authorParagraph = authorBuilder.build()
      ..layout(ui.ParagraphConstraints(width: width * 0.8));

    // 9. Calculate Positioning (Anchored to the bottom)
    final bottomPadding = height * 0.19;
    final authorY = height - bottomPadding - authorParagraph.height;
    final quoteY = authorY - quoteParagraph.height - (height * 0.02);

    // 10. Paint Text to Canvas
    canvas.drawParagraph(quoteParagraph, Offset(width * 0.1, quoteY));
    canvas.drawParagraph(authorParagraph, Offset(width * 0.1, authorY));

    // 11. Export to high-quality PNG
    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    // 12. Save & Cleanup (Using your exact logic)
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/ambient_$timestamp.png');

    // Clean up old files
    final directory = Directory(tempDir.path);
    if (directory.existsSync()) {
      for (var entity in directory.listSync()) {
        if (entity is File && entity.path.contains('ambient_')) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    }

    await file.writeAsBytes(byteData!.buffer.asUint8List());
    return file;
  }
}
