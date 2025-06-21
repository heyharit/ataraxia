import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ImageCropper {
  static Future<File> cropToScreen({
    required String assetPath,
    required double screenWidth,
    required double screenHeight,
  }) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final imageRatio = image.width / image.height;
    final screenRatio = screenWidth / screenHeight;

    late Rect src;

    if (imageRatio > screenRatio) {
      // wider image → crop sides
      final newWidth = image.height * screenRatio;
      final x = (image.width - newWidth) / 2;
      src = Rect.fromLTWH(x, 0, newWidth, image.height.toDouble());
    } else {
      // taller image → crop top/bottom
      final newHeight = image.width / screenRatio;
      final y = (image.height - newHeight) / 2;
      src = Rect.fromLTWH(0, y, image.width.toDouble(), newHeight);
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();

    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, screenWidth, screenHeight),
      paint,
    );

    final picture = recorder.endRecording();
    final cropped = await picture.toImage(
      screenWidth.toInt(),
      screenHeight.toInt(),
    );
    final pngBytes = (await cropped.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ataraxia_still.png');
    await file.writeAsBytes(pngBytes);

    return file;
  }
}
