import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/identity.dart';
import 'identity_checksum.dart';

class IdentityGlyph extends StatelessWidget {
  final Identity identity;
  final double size;

  const IdentityGlyph({
    super.key,
    required this.identity,
    this.size = 56, // 👈 small but powerful
  });

  @override
  Widget build(BuildContext context) {
    final bytes = IdentityChecksum.bytesFor(identity);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SigilPainter(bytes)),
    );
  }
}

class _SigilPainter extends CustomPainter {
  final List<int> bytes;
  _SigilPainter(this.bytes);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width * 0.38;

    final path = Path();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _primaryColor()
      ..isAntiAlias = true;

    final steps = bytes.length;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final angle = t * 2 * pi;

      // identity-driven distortion (subtle!)
      final variance = (bytes[i] - 128) / 128;
      final radius = baseRadius * (0.92 + variance * 0.12);

      final point = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  Color _primaryColor() {
    // pick one stable color from identity
    final b = bytes.first;
    return IdentityChecksum.colorFrom(b).withOpacity(0.85);
  }

  @override
  bool shouldRepaint(_) => false;
}
