// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import '../../ritual/daily_ritual_manager.dart';
// import '../../ritual/ambient/ambient_manager.dart';
// import 'ritual_screen.dart';

// class AtaraxiaSplashScreen extends StatefulWidget {
//   const AtaraxiaSplashScreen({super.key});

//   @override
//   State<AtaraxiaSplashScreen> createState() => _AtaraxiaSplashScreenState();
// }

// class _AtaraxiaSplashScreenState extends State<AtaraxiaSplashScreen> {
//   bool _initialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _startBootSequence();
//   }

//   Future<void> _startBootSequence() async {
//     // 1. Parallel initialization of all core services
//     await Future.wait([
//       Supabase.initialize(
//         url: 'https://thczyvmcihuuycbccpty.supabase.co',
//         anonKey:
//             'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoY3p5dm1jaWh1dXljYmNjcHR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgyNzE0NTIsImV4cCI6MjA4Mzg0NzQ1Mn0.l-wdh1qk3pJ8rQvrnfNkoTd_JiDFEIRWlN-ehPr9me4',
//       ),
//       AmbientManager.initialize(),
//       DailyRitualManager.loadTodayMoment(),
//       Future.delayed(
//         const Duration(milliseconds: 2500),
//       ), // Minimum "breath" time
//     ]);

//     if (!mounted) return;
//     setState(() => _initialized = true);

//     // 2. Transition to the main experience
//     Navigator.of(context).pushReplacement(
//       PageRouteBuilder(
//         transitionDuration: const Duration(milliseconds: 1200),
//         pageBuilder: (_, __, ___) => const RitualScreen(),
//         transitionsBuilder: (_, anim, __, child) =>
//             FadeTransition(opacity: anim, child: child),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // AnnotatedRegion ensures the OS doesn't tint the status/nav bars grey
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: SystemUiOverlayStyle.light.copyWith(
//         statusBarColor: Colors.transparent,
//         systemNavigationBarColor: Colors.transparent,
//         systemNavigationBarDividerColor: Colors.transparent,
//       ),
//       child: Scaffold(
//         backgroundColor: Colors.black, // Forced pure black
//         body: Center(
//           child: TweenAnimationBuilder<double>(
//             tween: Tween(begin: 0.0, end: 1.0),
//             duration: const Duration(seconds: 2),
//             builder: (context, value, child) {
//               return Opacity(
//                 opacity: value,
//                 child: Transform.scale(
//                   scale: 0.98 + (0.02 * value),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         "A T A R A X I A",
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.7),
//                           letterSpacing: 12 + (8 * value),
//                           fontWeight: FontWeight.w200,
//                           fontSize: 16,
//                         ),
//                       ),
//                       const SizedBox(height: 48),
//                       // Ritualistic progress bar
//                       Stack(
//                         alignment: Alignment.center,
//                         children: [
//                           Container(
//                             width: 40,
//                             height: 0.5,
//                             color: Colors.white.withOpacity(0.1),
//                           ),
//                           AnimatedContainer(
//                             duration: const Duration(milliseconds: 2000),
//                             curve: Curves.easeInOutCubic,
//                             width: _initialized ? 40 : 0,
//                             height: 0.5,
//                             color: Colors.white.withOpacity(0.8),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ritual/ambient/ambient_manager.dart';
import '../../ritual/daily_ritual_manager.dart';
import '../../core/palette.dart';
import 'ritual_screen.dart';

class AtaraxiaSplashScreen extends StatefulWidget {
  const AtaraxiaSplashScreen({super.key});

  @override
  State<AtaraxiaSplashScreen> createState() => _AtaraxiaSplashScreenState();
}

class _AtaraxiaSplashScreenState extends State<AtaraxiaSplashScreen>
    with SingleTickerProviderStateMixin {
  bool _dataReady = false;
  bool _textFinished = false;
  bool _progressStarted = false;

  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _boot();
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      await Future.wait([
        AmbientManager.initialize(),
        DailyRitualManager.loadTodayMoment(),
      ]);
    } catch (e) {
      debugPrint('Boot error: $e');
    } finally {
      if (mounted) {
        setState(() => _dataReady = true);
        _tryAdvance();
      }
    }
  }

  void _onTextDone() {
    if (mounted) {
      setState(() => _textFinished = true);
      _tryAdvance();
    }
  }

  void _tryAdvance() {
    if (_dataReady && _textFinished && !_progressStarted) {
      setState(() => _progressStarted = true);

      // Let the progress bar physically complete
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1200),
            pageBuilder: (_, __, ___) => const RitualScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AtaraxiaPalette.voidDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ─── BREATHING AMBIENT GLOW ───
            AnimatedBuilder(
              animation: _breathCtrl,
              builder: (_, __) {
                final v = _breathCtrl.value;
                return Stack(
                  children: [
                    // Central violet glow
                    Center(
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AtaraxiaPalette.auroraViolet.withOpacity(
                                0.12 + v * 0.08,
                              ),
                              AtaraxiaPalette.cosmicIndigo.withOpacity(
                                0.06 + v * 0.04,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top-right indigo accent
                    Positioned(
                      top: -80,
                      right: -60,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AtaraxiaPalette.cosmicIndigo.withOpacity(
                                0.10 + v * 0.06,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ─── MAIN CONTENT ───
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                onEnd: _onTextDone,
                builder: (_, value, __) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.96 + (0.04 * value),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) =>
                                AtaraxiaPalette.progressGradient.createShader(
                              Rect.fromLTWH(
                                0,
                                0,
                                bounds.width,
                                bounds.height,
                              ),
                            ),
                            child: Text(
                              'A T A R A X I A',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w200,
                                letterSpacing: 10 + (8 * value),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            'your wallpaper sanctuary',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.2 * value),
                              fontSize: 10,
                              letterSpacing: 4,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'Times New Roman',
                            ),
                          ),

                          const SizedBox(height: 52),

                          // Gradient progress bar
                          SizedBox(
                            width: 60,
                            child: Stack(
                              children: [
                                Container(
                                  height: 1.5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 1500),
                                  curve: Curves.easeInOutCubic,
                                  height: 1.5,
                                  width: _progressStarted ? 60 : 0,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient:
                                        AtaraxiaPalette.progressGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AtaraxiaPalette.glacialTeal
                                            .withOpacity(0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

