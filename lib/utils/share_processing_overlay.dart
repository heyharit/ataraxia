import 'dart:ui';
import 'package:flutter/material.dart';

class ShareProcessingOverlay extends StatefulWidget {
  const ShareProcessingOverlay({super.key});

  @override
  State<ShareProcessingOverlay> createState() => _ShareProcessingOverlayState();
}

class _ShareProcessingOverlayState extends State<ShareProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final blurSigma = screenWidth > 400
        ? 6.0
        : 3.5; // adaptive blur for low-end devices

    return Material(
      type: MaterialType.transparency,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, val, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurSigma * val,
              sigmaY: blurSigma * val,
            ),
            child: Container(
              color: Colors.black.withOpacity(0.7 * val),
              child: Opacity(opacity: val, child: child),
            ),
          );
        },
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final pulse = Curves.elasticOut.transform(_pulseCtrl.value);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Pulsing Rings
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 1; i <= 3; i++)
                        Container(
                          width: 80.0 * i * pulse,
                          height: 80.0 * i * pulse,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.15 / i),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.05),
                                blurRadius: 20 * i * pulse,
                                spreadRadius: 8 * i * pulse,
                              ),
                            ],
                          ),
                        ),
                      // Rotating central icon
                      Transform.rotate(
                        angle: 0.05 * pulse,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.cyanAccent.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.25),
                                blurRadius: 30 * pulse,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Shimmering Text
                  ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        colors: [
                          Colors.white70,
                          Colors.cyanAccent,
                          Colors.white70,
                        ],
                        stops: [0.0, 0.5, 1.0],
                        begin: Alignment(-1 - pulse, 0),
                        end: Alignment(1 + pulse, 0),
                      ).createShader(rect);
                    },
                    child: Text(
                      "EXTRACTING ECHO",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Courier',
                        letterSpacing: 6,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.cyanAccent.withOpacity(0.3),
                            blurRadius: 8,
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
      ),
    );
  }
}
