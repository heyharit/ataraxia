import 'dart:math';
import 'package:flutter/material.dart';

class AshDissolvePainter extends CustomPainter {
  final double progress;

  AshDissolvePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Fade out smoothly as the burn finishes
    final paint = Paint()
      ..color = Colors.white.withOpacity(
        ((1.0 - progress) * 0.8).clamp(0.0, 1.0),
      )
      ..style = PaintingStyle.fill;

    final particleCount = 200; // Increased count for a better visual effect

    // Seed the RNG exactly the same way every frame so trajectories are deterministic
    final rng = Random(42);

    for (int i = 0; i < particleCount; i++) {
      // 1. We MUST consume the exact same number of randoms per particle every frame.
      // Do this BEFORE the `continue` statement so the sequence doesn't shift.
      final startX = rng.nextDouble();
      final startY = rng.nextDouble();
      final speedY = rng.nextDouble();
      final radius = 1.0 + rng.nextDouble() * 2.0;
      final swayOffset = rng.nextDouble() * pi * 2; // For organic drifting

      // The "burn line": earlier particles disappear as progress increases
      final particleLife = i / particleCount;
      if (particleLife < progress) continue;

      // 2. Add organic sway to the X axis so it drifts like real smoke/ash
      final dx =
          (size.width * startX) + sin((progress * pi * 4) + swayOffset) * 15;

      // 3. Move upwards. Progress acts as the engine driving the Y value.
      final dy =
          (size.height * startY) - (progress * size.height * (1.0 + speedY));

      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AshDissolvePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}


// import 'dart:math';
// import 'package:flutter/material.dart';

// class AshDissolvePainter extends CustomPainter {
//   final double progress;
//   final Random _rng = Random(42);

//   AshDissolvePainter({required this.progress});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.white.withOpacity((1 - progress) * 0.25)
//       ..style = PaintingStyle.fill;

//     final particleCount = 140;

//     for (int i = 0; i < particleCount; i++) {
//       final t = (i / particleCount);
//       if (t < progress) continue;

//       final dx = size.width * _rng.nextDouble();
//       final dy = size.height * (_rng.nextDouble() - progress);
//       final r = 1.2 + _rng.nextDouble() * 2;

//       canvas.drawCircle(Offset(dx, dy), r, paint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant AshDissolvePainter oldDelegate) {
//     return oldDelegate.progress != progress;
//   }
// }
