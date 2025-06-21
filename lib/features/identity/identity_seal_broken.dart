// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class IdentitySealBroken extends StatefulWidget {
//   const IdentitySealBroken({super.key});

//   @override
//   State<IdentitySealBroken> createState() => _IdentitySealBrokenState();
// }

// class _IdentitySealBrokenState extends State<IdentitySealBroken>
//     with TickerProviderStateMixin {
//   late AnimationController _ctrl;

//   // Entrance
//   late Animation<double> _iconScale;
//   late Animation<double> _iconOpacity;

//   // Shockwaves
//   late Animation<double> _wave1Scale;
//   late Animation<double> _wave1Opacity;
//   late Animation<double> _wave2Scale;
//   late Animation<double> _wave2Opacity;

//   // Text
//   late Animation<double> _textOpacity;
//   late Animation<double> _textTracking; // Expands letter spacing over time

//   // The final fade to black before popping
//   late Animation<double> _sceneFadeOut;

//   late Animation<double> _bgGlow;

//   @override
//   void initState() {
//     super.initState();

//     // Expanded duration to 3.2 seconds for a complete, unhurried cinematic sequence
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 3200),
//     );

//     // 1. Icon strikes the screen
//     _iconScale = Tween(begin: 0.3, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _ctrl,
//         curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
//       ),
//     );
//     _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _ctrl,
//         curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
//       ),
//     );

//     // 2. Primary Shockwave
//     _wave1Scale = Tween(begin: 1.0, end: 4.5).animate(
//       CurvedAnimation(
//         parent: _ctrl,
//         curve: const Interval(0.15, 0.6, curve: Curves.easeOutCubic),
//       ),
//     );
//     _wave1Opacity = TweenSequence(
//       [
//         TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 10),
//         TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 90),
//       ],
//     ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.7)));

//     // 3. Secondary Aftershock (Slightly delayed, softer)
//     _wave2Scale = Tween(begin: 1.0, end: 3.5).animate(
//       CurvedAnimation(
//         parent: _ctrl,
//         curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic),
//       ),
//     );
//     _wave2Opacity = TweenSequence(
//       [
//         TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.4), weight: 10),
//         TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.0), weight: 90),
//       ],
//     ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.9)));

//     // 4. Text fades in and slowly spreads out
//     _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _ctrl,
//         curve: const Interval(0.3, 0.5, curve: Curves.easeOut),
//       ),
//     );
//     _textTracking = Tween(begin: 4.0, end: 12.0).animate(
//       CurvedAnimation(
//         parent: _ctrl,
//         curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
//       ),
//     );

//     // 5. Background Bloom
//     _bgGlow = TweenSequence([
//       TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.2), weight: 30),
//       TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.2), weight: 40),
//       TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.0), weight: 30),
//     ]).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 1.0)));

//     // 6. THE SCENE EXIT (Fades everything smoothly to absolute black before popping)
//     _sceneFadeOut = Tween(begin: 1.0, end: 0.0).animate(
//       CurvedAnimation(
//         parent: _ctrl,
//         curve: const Interval(0.8, 1.0, curve: Curves.easeInOut),
//       ),
//     );

//     // Instead of a random timer, we listen for the exact moment the animation finishes
//     _ctrl.addStatusListener((status) {
//       if (status == AnimationStatus.completed) {
//         if (mounted) Navigator.pop(context, true);
//       }
//     });

//     _ctrl.forward();

//     // Perfectly timed cinematic haptics
//     Future.delayed(
//       const Duration(milliseconds: 100),
//       () => HapticFeedback.mediumImpact(),
//     );
//     Future.delayed(
//       const Duration(milliseconds: 400),
//       () => HapticFeedback.heavyImpact(),
//     ); // Primary wave
//     Future.delayed(
//       const Duration(milliseconds: 650),
//       () => HapticFeedback.lightImpact(),
//     ); // Secondary wave
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       // Wrap everything in the fade-out so it disappears before popping
//       body: FadeTransition(
//         opacity: _sceneFadeOut,
//         child: AnimatedBuilder(
//           animation: _ctrl,
//           builder: (_, __) {
//             // A continuous slow zoom on the whole stack to feel alive
//             final continuousZoom = 1.0 + (_ctrl.value * 0.05);

//             return Stack(
//               fit: StackFit.expand,
//               children: [
//                 // 1. Background Bloom
//                 Container(
//                   decoration: BoxDecoration(
//                     gradient: RadialGradient(
//                       center: Alignment.center,
//                       radius: 1.5,
//                       colors: [
//                         Colors.cyanAccent.withOpacity(_bgGlow.value),
//                         Colors.black,
//                       ],
//                       stops: const [0.0, 1.0],
//                     ),
//                   ),
//                 ),

//                 Center(
//                   child: Transform.scale(
//                     scale: continuousZoom,
//                     child: Stack(
//                       alignment: Alignment.center,
//                       children: [
//                         // 2. Primary Shockwave
//                         Transform.scale(
//                           scale: _wave1Scale.value,
//                           child: Opacity(
//                             opacity: _wave1Opacity.value,
//                             child: Container(
//                               width: 120,
//                               height: 120,
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                   color: Colors.cyanAccent,
//                                   width: 3.0,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),

//                         // 3. Secondary Aftershock
//                         Transform.scale(
//                           scale: _wave2Scale.value,
//                           child: Opacity(
//                             opacity: _wave2Opacity.value,
//                             child: Container(
//                               width: 120,
//                               height: 120,
//                               decoration: BoxDecoration(
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                   color: Colors.white,
//                                   width: 1.0,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),

//                         // 4. The Main Lock Artifact
//                         Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Transform.scale(
//                               scale: _iconScale.value,
//                               child: Opacity(
//                                 opacity: _iconOpacity.value,
//                                 child: Container(
//                                   width: 140,
//                                   height: 140,
//                                   decoration: BoxDecoration(
//                                     shape: BoxShape.circle,
//                                     color: Colors.white.withOpacity(0.03),
//                                     border: Border.all(
//                                       color: Colors.white.withOpacity(0.5),
//                                       width: 1.5,
//                                     ),
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: Colors.cyanAccent.withOpacity(
//                                           0.15,
//                                         ),
//                                         blurRadius: 50,
//                                         spreadRadius: 10,
//                                       ),
//                                     ],
//                                   ),
//                                   child: const Center(
//                                     child: Icon(
//                                       Icons.lock_open_rounded,
//                                       color: Colors.white,
//                                       size: 56,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(height: 40),

//                             // 5. Cinematic Text
//                             Opacity(
//                               opacity: _textOpacity.value,
//                               child: Text(
//                                 'SEAL BROKEN',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontFamily: 'Courier',
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w900,
//                                   letterSpacing: _textTracking.value,
//                                   shadows: [
//                                     Shadow(
//                                       color: Colors.cyanAccent.withOpacity(0.5),
//                                       blurRadius: 10,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IdentitySealBroken extends StatefulWidget {
  const IdentitySealBroken({super.key});

  @override
  State<IdentitySealBroken> createState() => _IdentitySealBrokenState();
}

class _IdentitySealBrokenState extends State<IdentitySealBroken>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;

  // Entrance
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;

  // Shockwaves
  late Animation<double> _wave1Scale;
  late Animation<double> _wave1Opacity;
  late Animation<double> _wave2Scale;
  late Animation<double> _wave2Opacity;

  // Text
  late Animation<double> _textOpacity;
  late Animation<double> _textTracking;

  // Final Scene
  late Animation<double> _sceneFadeOut;
  late Animation<double> _bgGlow;

  // Particle System
  final List<_Particle> _particles = [];
  final int _particleCount = 60;

  @override
  void initState() {
    super.initState();

    final rand = math.Random();
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_Particle.random(rand));
    }

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // 1. Icon strikes the screen
    _iconScale = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
      ),
    );
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
      ),
    );

    // 2. Primary Shockwave (Cyan)
    _wave1Scale = Tween(begin: 1.0, end: 4.5).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.15, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _wave1Opacity = TweenSequence(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 10),
        TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 90),
      ],
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.7)));

    // 3. Secondary Aftershock (Purple)
    _wave2Scale = Tween(begin: 1.0, end: 3.5).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _wave2Opacity = TweenSequence(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.4), weight: 10),
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.0), weight: 90),
      ],
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.9)));

    // 4. Text
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.5, curve: Curves.easeOut),
      ),
    );
    _textTracking = Tween(begin: 4.0, end: 14.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Background Bloom
    _bgGlow = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.25), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.1, 1.0)));

    // 6. SCENE EXIT
    _sceneFadeOut = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.8, 1.0, curve: Curves.easeInOut),
      ),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) Navigator.pop(context, true);
      }
    });

    _ctrl.forward();

    // The Orchestrated Rumble
    Future.delayed(
      const Duration(milliseconds: 100),
      () => HapticFeedback.mediumImpact(),
    );
    Future.delayed(
      const Duration(milliseconds: 400),
      () => HapticFeedback.heavyImpact(),
    ); // Primary wave + Particles
    Future.delayed(
      const Duration(milliseconds: 650),
      () => HapticFeedback.lightImpact(),
    ); // Secondary wave
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _sceneFadeOut,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final continuousZoom = 1.0 + (_ctrl.value * 0.08);

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Ambient Background Bloom
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.5,
                      colors: [
                        Colors.cyanAccent.withOpacity(_bgGlow.value),
                        Colors.black,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),

                Center(
                  child: Transform.scale(
                    scale: continuousZoom,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 2. ✨ THE PARTICLE EXPLOSION
                        SizedBox(
                          width: 300,
                          height: 300,
                          child: CustomPaint(
                            painter: _ExplosionPainter(
                              particles: _particles,
                              // Particles explode outwards during the middle of the animation
                              progress: Curves.easeOutQuint.transform(
                                ((_ctrl.value - 0.15) / 0.7).clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                        ),

                        // 3. Primary Cyan Shockwave
                        Transform.scale(
                          scale: _wave1Scale.value,
                          child: Opacity(
                            opacity: _wave1Opacity.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyanAccent,
                                  width: 4.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 4. Secondary Purple Aftershock
                        Transform.scale(
                          scale: _wave2Scale.value,
                          child: Opacity(
                            opacity: _wave2Opacity.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.purpleAccent,
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purpleAccent.withOpacity(0.5),
                                    blurRadius: 30,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 5. The Main Holographic Lock Artifact
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: _iconScale.value,
                              child: Opacity(
                                opacity: _iconOpacity.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(
                                          0.2,
                                        ),
                                        blurRadius: 40,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                            colors: [
                                              Colors.cyanAccent,
                                              Colors.purpleAccent,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                      child: const Icon(
                                        Icons.lock_open_rounded,
                                        color: Colors.white,
                                        size: 56,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // 6. Cinematic Iridescent Typography
                            Opacity(
                              opacity: _textOpacity.value,
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Colors.white,
                                        Colors.cyanAccent,
                                        Colors.white,
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ).createShader(bounds),
                                child: Text(
                                  'SEAL BROKEN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Courier',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: _textTracking.value,
                                    shadows: [
                                      Shadow(
                                        color: Colors.cyanAccent.withOpacity(
                                          0.8,
                                        ),
                                        blurRadius: 15,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── PARTICLE EXPLOSION SYSTEM ───

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  _Particle(this.angle, this.distance, this.size, this.color);

  factory _Particle.random(math.Random rand) {
    // Particles explode in a full 360 circle
    final angle = rand.nextDouble() * 2 * math.pi;
    // Distance they will travel (between 50 and 250 pixels outwards)
    final distance = rand.nextDouble() * 200 + 50;
    // Varying sizes of stardust
    final size = rand.nextDouble() * 3 + 1;
    // Alternating Ataraxia colors
    final color = rand.nextBool() ? Colors.cyanAccent : Colors.purpleAccent;

    return _Particle(angle, distance, size, color);
  }
}

class _ExplosionPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ExplosionPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // Fade out as they reach the edge of their explosion
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      // Calculate current position based on the progress of the explosion
      final currentDistance = p.distance * progress;
      final dx = center.dx + math.cos(p.angle) * currentDistance;
      final dy = center.dy + math.sin(p.angle) * currentDistance;

      paint.color = p.color.withOpacity(opacity);

      // Draw a glowing aura around the particle
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawCircle(Offset(dx, dy), p.size * 2, paint);

      // Draw the sharp bright core of the particle
      paint.maskFilter = null;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter oldDelegate) => true;
}
