import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/models/identity.dart';
import 'identity_qr_payload.dart';
import 'identity_qr_confirm.dart';

class IdentityQrImport extends StatefulWidget {
  const IdentityQrImport({super.key});

  @override
  State<IdentityQrImport> createState() => _IdentityQrImportState();
}

class _IdentityQrImportState extends State<IdentityQrImport>
    with SingleTickerProviderStateMixin {
  bool _handled = false;
  late final MobileScannerController _scannerController;
  late final AnimationController _scanLineCtrl;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanLineCtrl.dispose();
    super.dispose();
  }

  // 🚀 FIX: Made this async so we can await the confirmation screen
  void _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    try {
      final json = IdentityQrPayload.decode(code);
      final identity = Identity.fromJson(json['identity']);
      final key = json['key'];

      setState(() => _handled = true); // Stop processing multiple frames
      HapticFeedback.heavyImpact();

      // 🚀 FIX: Await the push instead of replacing, so we capture the result!
      final result = await Navigator.push<bool>(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) =>
              IdentityQrConfirm(identity: identity, identityKey: key),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );

      // 🚀 FIX: Cascade the success signal back to the Identity Gate
      if (result == true && mounted) {
        Navigator.pop(context, true);
      } else {
        // If they cancelled or went back, let them scan again
        if (mounted) setState(() => _handled = false);
      }
    } catch (_) {
      if (mounted) setState(() => _handled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    final scanWindowWidth = isTablet ? 400.0 : size.width * 0.75;
    final scanWindowHeight = scanWindowWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),

          CustomPaint(
            painter: _ScannerOverlayPainter(
              windowSize: Size(scanWindowWidth, scanWindowHeight),
            ),
          ),

          Center(
            child: SizedBox(
              width: scanWindowWidth,
              height: scanWindowHeight,
              child: AnimatedBuilder(
                animation: _scanLineCtrl,
                builder: (context, child) {
                  final alignY = (_scanLineCtrl.value * 2) - 1.0;
                  return Align(
                    alignment: Alignment(0, alignY),
                    child: Container(
                      height: 3,
                      width: scanWindowWidth * 0.9,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.cyanAccent.withOpacity(0.0),
                            Colors.cyanAccent,
                            Colors.purpleAccent,
                            Colors.purpleAccent.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.6),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.flashlight_on_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => _scannerController.toggleTorch(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: size.height * 0.15,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(
                  Icons.center_focus_weak_rounded,
                  color: Colors.white54,
                  size: 32,
                ),
                const SizedBox(height: 16),
                Text(
                  "AWAITING ARTIFACT",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Courier',
                    fontSize: isTablet ? 18 : 14,
                    letterSpacing: 6.0,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.cyanAccent.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Align the QR code within the frame to decrypt.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: isTablet ? 14 : 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Size windowSize;
  _ScannerOverlayPainter({required this.windowSize});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.85);
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final windowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: windowSize.width,
      height: windowSize.height,
    );
    final windowRRect = RRect.fromRectAndRadius(
      windowRect,
      const Radius.circular(24),
    );

    final bgPath = Path()..addRect(bgRect);
    final windowPath = Path()..addRRect(windowRRect);
    final finalPath = Path.combine(
      PathOperation.difference,
      bgPath,
      windowPath,
    );

    canvas.drawPath(finalPath, bgPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    const cornerLength = 40.0;

    void drawCorner(Offset start, Offset end, Offset middle, Color color) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(middle.dx, middle.dy)
        ..lineTo(end.dx, end.dy);
      glowPaint.color = color.withOpacity(0.5);
      canvas.drawPath(path, glowPaint);
      borderPaint.color = color;
      canvas.drawPath(path, borderPaint);
    }

    final top = windowRect.top;
    final bottom = windowRect.bottom;
    final left = windowRect.left;
    final right = windowRect.right;

    drawCorner(
      Offset(left, top + cornerLength),
      Offset(left + cornerLength, top),
      Offset(left, top),
      Colors.cyanAccent,
    );
    drawCorner(
      Offset(right - cornerLength, top),
      Offset(right, top + cornerLength),
      Offset(right, top),
      Colors.purpleAccent,
    );
    drawCorner(
      Offset(left, bottom - cornerLength),
      Offset(left + cornerLength, bottom),
      Offset(left, bottom),
      Colors.purpleAccent,
    );
    drawCorner(
      Offset(right - cornerLength, bottom),
      Offset(right, bottom - cornerLength),
      Offset(right, bottom),
      Colors.cyanAccent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
