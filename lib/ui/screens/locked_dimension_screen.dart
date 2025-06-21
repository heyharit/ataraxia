import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LockedDimensionScreen extends StatefulWidget {
  const LockedDimensionScreen({super.key});

  @override
  State<LockedDimensionScreen> createState() => _LockedDimensionScreenState();
}

class _LockedDimensionScreenState extends State<LockedDimensionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact(); // Thud on entry

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context); // Tap anywhere to leave
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Deep Eerie Background Glow
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                final pulse = Curves.easeInOutSine.transform(_pulseCtrl.value);
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0 + (pulse * 0.2),
                      colors: [
                        Colors.redAccent.withOpacity(0.05 + (pulse * 0.05)),
                        Colors.black,
                      ],
                    ),
                  ),
                );
              }
            ),

            // 2. The Glass Padlock & Message
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutQuart,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - val)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The Glowing Lock
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.1),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: isTablet ? 64 : 48,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // The Header
                    Text(
                      "DIMENSION SEALED",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: isTablet ? 14 : 11,
                        fontFamily: 'Courier',
                        letterSpacing: 6.0,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // The Poetic Rejection
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "The sun is too loud.\nReturn in darkness.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 36 : 24,
                          fontFamily: 'Times New Roman',
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Leave Hint
                    Text(
                      "TAP ANYWHERE TO RETREAT",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 9,
                        fontFamily: 'Courier',
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}