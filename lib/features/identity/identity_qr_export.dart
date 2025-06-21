import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/models/identity.dart';
import 'identity_qr_payload.dart';
import 'identity_glyph.dart';

class IdentityQrExport extends StatefulWidget {
  final Identity identity;
  final String identityKey;

  const IdentityQrExport({
    super.key,
    required this.identity,
    required this.identityKey,
  });

  @override
  State<IdentityQrExport> createState() => _IdentityQrExportState();
}

class _IdentityQrExportState extends State<IdentityQrExport>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _scanCtrl; // Controls the sweeping laser

  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _blur;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();

    // 1. Entrance Animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scale = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));

    _blur = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutQuart),
    );

    // 2. Active Scanner Animation
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = IdentityQrPayload.encode(
      identity: widget.identity,
      key: widget.identityKey,
    );

    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    // Calculate the perfect size for the QR containment field
    final qrSize = isTablet ? 340.0 : 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Deep Cyber Grid Background
          const Positioned.fill(child: _CyberGridBackground()),

          // 2. Ambient Core Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [Colors.cyanAccent.withOpacity(0.05), Colors.black],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // 3. Main Holographic Content
          SafeArea(
            child: AnimatedBuilder(
              animation: _entranceCtrl,
              builder: (context, child) {
                Widget animatedChild = child!;

                // 🚀 PERFORMANCE ENGINE:
                // Only inject the heavy ImageFiltered widget if the blur is actually visible.
                // The moment the entrance animation finishes, this drops the filter entirely,
                // freeing up massive GPU resources and preventing idle lag.
                if (_blur.value > 0.01) {
                  animatedChild = ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: _blur.value,
                      sigmaY: _blur.value,
                    ),
                    child: animatedChild,
                  );
                }

                return Opacity(
                  opacity: _fade.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: animatedChild,
                  ),
                );
              },
              // 🚀 PERFORMANCE ENGINE:
              // RepaintBoundary forces Flutter to take a static "screenshot" of the heavy QR code.
              // Now, it animates a flattened image instead of recalculating the QR math every frame.
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),

                            IdentityGlyph(identity: widget.identity),
                            const SizedBox(height: 16),

                            Text(
                              widget.identity.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTablet ? 36 : 28,
                                fontFamily: 'Serif',
                                fontStyle: FontStyle.italic,
                                letterSpacing: 2.0,
                                shadows: const [
                                  Shadow(
                                    color: Colors.cyanAccent,
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 48),

                            // ─── THE CONTAINMENT FIELD (QR CODE) ───
                            SizedBox(
                              width: qrSize + 40, // Padding for HUD corners
                              height: qrSize + 40,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer Glow
                                  Container(
                                    width: qrSize,
                                    height: qrSize,
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.cyanAccent.withOpacity(
                                            0.15,
                                          ),
                                          blurRadius: 50,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Tactical HUD Corners
                                  CustomPaint(
                                    size: Size(qrSize + 40, qrSize + 40),
                                    painter: _HUDCornersPainter(),
                                  ),

                                  // The Glassmorphic Plate
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        width: qrSize,
                                        height: qrSize,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // White Backing for Scanner Readability
                                            Container(
                                              width: qrSize - 32,
                                              height: qrSize - 32,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: QrImageView(
                                                  data: payload,
                                                  // Premium rounded styling
                                                  eyeStyle: const QrEyeStyle(
                                                    eyeShape: QrEyeShape.square,
                                                    color: Colors.black87,
                                                  ),
                                                  dataModuleStyle:
                                                      const QrDataModuleStyle(
                                                        dataModuleShape:
                                                            QrDataModuleShape
                                                                .circle,
                                                        color: Colors.black87,
                                                      ),
                                                  backgroundColor:
                                                      Colors.transparent,
                                                ),
                                              ),
                                            ),

                                            // Active Scanning Laser Overlay
                                            AnimatedBuilder(
                                              animation: _scanCtrl,
                                              builder: (context, child) {
                                                // Curves.easeInOut creates a smooth sweep up and down
                                                final sweep = Curves.easeInOut
                                                    .transform(_scanCtrl.value);
                                                final topOffset =
                                                    16.0 +
                                                    (sweep * (qrSize - 36));

                                                return Positioned(
                                                  top: topOffset,
                                                  left: 16,
                                                  right: 16,
                                                  child: Container(
                                                    height: 3,
                                                    decoration: BoxDecoration(
                                                      color: Colors.cyanAccent,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors
                                                              .cyanAccent
                                                              .withOpacity(0.8),
                                                          blurRadius: 10,
                                                          spreadRadius: 2,
                                                        ),
                                                        BoxShadow(
                                                          color: Colors.white
                                                              .withOpacity(0.8),
                                                          blurRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 54),

                            Text(
                              'TRANSMISSION READY',
                              style: TextStyle(
                                color: Colors.cyanAccent.withOpacity(0.8),
                                fontSize: 12,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 5.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Align scanner with the containment field\nto extract consciousness.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                height: 1.6,
                                fontSize: 13,
                              ),
                            ),

                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 20,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CYBER GRID BACKGROUND ───
class _CyberGridBackground extends StatefulWidget {
  const _CyberGridBackground();

  @override
  State<_CyberGridBackground> createState() => _CyberGridBackgroundState();
}

class _CyberGridBackgroundState extends State<_CyberGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gridCtrl;

  @override
  void initState() {
    super.initState();
    _gridCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _gridCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _gridCtrl,
      builder: (context, _) {
        return CustomPaint(painter: _GridPainter(progress: _gridCtrl.value));
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    const gridSize = 40.0;
    final offsetY = progress * gridSize;

    // Horizontal Lines moving downwards
    for (double y = -gridSize; y < size.height + gridSize; y += gridSize) {
      canvas.drawLine(
        Offset(0, y + offsetY),
        Offset(size.width, y + offsetY),
        paint,
      );
    }

    // Vertical Lines (Static)
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── TACTICAL HUD CORNERS ───
class _HUDCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const double length = 24.0; // Length of the bracket arms
    final double w = size.width;
    final double h = size.height;

    // Top Left
    final Path path = Path()
      ..moveTo(0, length)
      ..lineTo(0, 0)
      ..lineTo(length, 0);

    // Top Right
    path.moveTo(w - length, 0);
    path.lineTo(w, 0);
    path.lineTo(w, length);

    // Bottom Right
    path.moveTo(w, h - length);
    path.lineTo(w, h);
    path.lineTo(w - length, h);

    // Bottom Left
    path.moveTo(length, h);
    path.lineTo(0, h);
    path.lineTo(0, h - length);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
