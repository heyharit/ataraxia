import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/palette.dart';

const String _kOnboardingKey = 'ataraxia_onboarded_v1';

/// Shows the onboarding overlay the very first time the user opens the app.
/// Returns immediately if already seen. Call from RitualScreen's initState.
Future<void> showOnboardingIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool(_kOnboardingKey) ?? false;
  if (seen) return;

  if (!context.mounted) return;

  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => const _OnboardingOverlay(),
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      );
    },
  );

  await prefs.setBool(_kOnboardingKey, true);
}

/// Forces the onboarding to show again (for settings/help access).
Future<void> showOnboardingForced(BuildContext context) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (_, __, ___) => const _OnboardingOverlay(),
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _OnboardingOverlay extends StatefulWidget {
  const _OnboardingOverlay();

  @override
  State<_OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<_OnboardingOverlay>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  static const int _totalPages = 5;

  late final AnimationController _ambientCtrl;
  late final AnimationController _pageTransCtrl;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _pageTransCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _ambientCtrl.dispose();
    _pageTransCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
    }
  }

  void _skip() {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── FROSTED GLASS BACKDROP ───
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                color: AtaraxiaPalette.voidDeep.withOpacity(0.92),
              ),
            ),
          ),

          // ─── AMBIENT ORBS ───
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (_, __) {
              final v = _ambientCtrl.value;
              return Stack(
                children: [
                  // Top-right indigo orb
                  Positioned(
                    top: -size.height * 0.1 - (v * 30),
                    right: -80 + (v * 20),
                    child: Container(
                      width: size.width * 0.8,
                      height: size.width * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AtaraxiaPalette.cosmicIndigo.withOpacity(
                              0.18 + v * 0.07,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom-left violet orb
                  Positioned(
                    bottom: -size.height * 0.1 + (v * 20),
                    left: -60 - (v * 15),
                    child: Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AtaraxiaPalette.auroraViolet.withOpacity(
                              0.14 + v * 0.06,
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

          // ─── PAGE CONTENT ───
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 20, 0),
                    child: GestureDetector(
                      onTap: _skip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Text(
                          'SKIP',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _page = i);
                    },
                    children: [
                      _WelcomePage(isTablet: isTablet),
                      _HoldPage(isTablet: isTablet),
                      _TapDialPage(isTablet: isTablet),
                      _SwipePage(isTablet: isTablet),
                      _ExplorePage(isTablet: isTablet),
                    ],
                  ),
                ),

                // ─── DOTS + BUTTON ───
                Padding(
                  padding: EdgeInsets.only(
                    bottom: isTablet ? 56 : 40,
                    left: 32,
                    right: 32,
                    top: 24,
                  ),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_totalPages, (i) {
                          final isActive = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: isActive
                                  ? AtaraxiaPalette.progressGradient
                                  : null,
                              color: isActive
                                  ? null
                                  : Colors.white.withOpacity(0.2),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AtaraxiaPalette.glacialTeal
                                            .withOpacity(0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 28),

                      // CTA button
                      GestureDetector(
                        onTap: _next,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            gradient: LinearGradient(
                              colors: _page == _totalPages - 1
                                  ? [
                                      AtaraxiaPalette.cosmicIndigo,
                                      AtaraxiaPalette.glacialTeal,
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.12),
                                      Colors.white.withOpacity(0.08),
                                    ],
                            ),
                            border: Border.all(
                              color: _page == _totalPages - 1
                                  ? AtaraxiaPalette.glacialTeal.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.15),
                              width: 1.5,
                            ),
                            boxShadow: _page == _totalPages - 1
                                ? [
                                    BoxShadow(
                                      color: AtaraxiaPalette.glacialTeal
                                          .withOpacity(0.3),
                                      blurRadius: 24,
                                      spreadRadius: -4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            _page == _totalPages - 1
                                ? 'ENTER THE VOID'
                                : 'NEXT',
                            style: TextStyle(
                              color: _page == _totalPages - 1
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────
// PAGE 1: WELCOME
// ─────────────────────────────────────────────────────────────────
class _WelcomePage extends StatefulWidget {
  final bool isTablet;
  const _WelcomePage({required this.isTablet});
  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isTablet ? 80 : 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated logo orb
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Container(
                width: widget.isTablet ? 180 : 130,
                height: widget.isTablet ? 180 : 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AtaraxiaPalette.cosmicIndigo.withOpacity(
                        0.15 + _ctrl.value * 0.1,
                      ),
                      AtaraxiaPalette.auroraViolet.withOpacity(
                        0.08 + _ctrl.value * 0.06,
                      ),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: AtaraxiaPalette.glassEdgeBright,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AtaraxiaPalette.cosmicIndigo.withOpacity(
                        0.2 + _ctrl.value * 0.15,
                      ),
                      blurRadius: 40 + (_ctrl.value * 20),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/app_icon_foreground.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: widget.isTablet ? 56 : 40),

          Text(
            'ATARAXIA',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: widget.isTablet ? 28 : 20,
              letterSpacing: 10,
              fontWeight: FontWeight.w300,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Your wallpaper sanctuary.\nBuilt for those who feel deeply.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: widget.isTablet ? 18 : 14,
              height: 1.6,
              fontFamily: 'Times New Roman',
              fontStyle: FontStyle.italic,
            ),
          ),

          SizedBox(height: widget.isTablet ? 40 : 28),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AtaraxiaPalette.cosmicIndigo.withOpacity(0.1),
              border: Border.all(
                color: AtaraxiaPalette.cosmicIndigo.withOpacity(0.25),
              ),
            ),
            child: Text(
              'Swipe through to learn the gestures →',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: widget.isTablet ? 12 : 10,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PAGE 2: HOLD TO SET
// ─────────────────────────────────────────────────────────────────
class _HoldPage extends StatefulWidget {
  final bool isTablet;
  const _HoldPage({required this.isTablet});
  @override
  State<_HoldPage> createState() => _HoldPageState();
}

class _HoldPageState extends State<_HoldPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isTablet ? 80 : 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated hold visualisation
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              // Phase 0→0.4: finger presses, rings bloom
              // Phase 0.4→0.7: hold charged
              // Phase 0.7→1.0: release / reset
              final phase = _ctrl.value;
              final charge = phase < 0.4
                  ? (phase / 0.4).clamp(0.0, 1.0)
                  : (phase < 0.7 ? 1.0 : ((1.0 - phase) / 0.3).clamp(0.0, 1.0));

              return SizedBox(
                width: widget.isTablet ? 200 : 160,
                height: widget.isTablet ? 200 : 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse ring
                    Container(
                      width:
                          (widget.isTablet ? 160 : 120) +
                          (charge * (widget.isTablet ? 40 : 30)),
                      height:
                          (widget.isTablet ? 160 : 120) +
                          (charge * (widget.isTablet ? 40 : 30)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Color.lerp(
                            Colors.white.withOpacity(0.1),
                            AtaraxiaPalette.auroraViolet.withOpacity(0.6),
                            charge,
                          )!,
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Inner charge circle
                    Container(
                      width: widget.isTablet ? 100 : 80,
                      height: widget.isTablet ? 100 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.transparent,
                            AtaraxiaPalette.cosmicIndigo.withOpacity(
                              charge * 0.9,
                            ),
                            AtaraxiaPalette.auroraViolet.withOpacity(
                              charge * 0.9,
                            ),
                            Colors.transparent,
                          ],
                          stops: [
                            0.0,
                            (0.3 * charge).clamp(0.001, 0.3),
                            (0.7 * charge).clamp(0.001, 0.7),
                            1.0,
                          ],
                          startAngle: 0,
                          endAngle: math.pi * 2,
                        ),
                        border: Border.all(
                          color: Color.lerp(
                            Colors.white.withOpacity(0.2),
                            AtaraxiaPalette.glacialTeal.withOpacity(0.8),
                            charge,
                          )!,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AtaraxiaPalette.auroraViolet.withOpacity(
                              charge * 0.4,
                            ),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    ),
                    // Finger icon
                    Icon(
                      phase < 0.4
                          ? Icons.touch_app_rounded
                          : (charge > 0.5
                                ? Icons.radio_button_checked_rounded
                                : Icons.fingerprint_rounded),
                      color: Color.lerp(
                        Colors.white.withOpacity(0.5),
                        AtaraxiaPalette.glacialTeal,
                        charge,
                      ),
                      size: widget.isTablet ? 40 : 30,
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: widget.isTablet ? 48 : 36),

          Text(
            'HOLD TO CHARGE',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isTablet ? 22 : 16,
              letterSpacing: 6,
              fontWeight: FontWeight.w300,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Press and hold anywhere on the wallpaper.\nFeel the haptic pulse as it charges.\nRelease when it arms — a sheet appears\nto choose where to set the wallpaper.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: widget.isTablet ? 15 : 12,
              height: 1.7,
            ),
          ),

          SizedBox(height: widget.isTablet ? 32 : 20),

          _GestureChip(
            icon: Icons.touch_app_rounded,
            text: 'Long Press anywhere',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PAGE 3: TAP → ROTARY DIAL
// ─────────────────────────────────────────────────────────────────
class _TapDialPage extends StatefulWidget {
  final bool isTablet;
  const _TapDialPage({required this.isTablet});
  @override
  State<_TapDialPage> createState() => _TapDialPageState();
}

class _TapDialPageState extends State<_TapDialPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialR = widget.isTablet ? 75.0 : 55.0;
    final orbitR = dialR * 0.65;
    final dotItems = [
      (Icons.close_rounded, 'DISMISS'),
      (Icons.history, 'MEMORY'),
      (Icons.waves, 'RITUAL'),
      (Icons.tune_rounded, 'SANCTUARY'),
      (Icons.grid_view, 'LIBRARY'),
      (Icons.visibility_off, 'HIDE'),
    ];
    const n = 6;
    final startAngle = -math.pi * 7 / 6;
    final endAngle = math.pi * 1 / 6;
    final step = (endAngle - startAngle) / (n - 1);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isTablet ? 80 : 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated dial preview
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              // Slow rotation
              final rotation = _ctrl.value * math.pi * 0.6 - math.pi * 0.3;

              return SizedBox(
                width: dialR * 2 + 40,
                height: dialR * 2 + 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Wheel
                    Transform.rotate(
                      angle: rotation,
                      child: Container(
                        width: dialR * 2,
                        height: dialR * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              AtaraxiaPalette.cosmicIndigo.withOpacity(0.15),
                              AtaraxiaPalette.glacialTeal.withOpacity(0.15),
                              AtaraxiaPalette.auroraViolet.withOpacity(0.15),
                              AtaraxiaPalette.cosmicIndigo.withOpacity(0.15),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: List.generate(n, (i) {
                            final angle = startAngle + step * i;
                            final dx = orbitR * math.cos(angle);
                            final dy = orbitR * math.sin(angle);
                            double absAngle = angle + rotation;
                            double norm = absAngle % (2 * math.pi);
                            if (norm > math.pi) norm -= 2 * math.pi;
                            if (norm < -math.pi) norm += 2 * math.pi;
                            final distToTop = (norm - (-math.pi / 2)).abs();
                            final focus = Curves.easeOutQuart.transform(
                              (1.0 - (distToTop / 0.4)).clamp(0.0, 1.0),
                            );

                            return Transform.translate(
                              offset: Offset(dx, dy),
                              child: Transform.rotate(
                                angle: -rotation,
                                child: Container(
                                  width: 28 + (focus * 12),
                                  height: 28 + (focus * 12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                    border: Border.all(
                                      color: Color.lerp(
                                        Colors.white.withOpacity(0.15),
                                        AtaraxiaPalette.glacialTeal,
                                        focus,
                                      )!,
                                      width: 1 + focus,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AtaraxiaPalette.glacialTeal
                                            .withOpacity(0.4 * focus),
                                        blurRadius: 10 * focus,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    dotItems[i].$1,
                                    color: Color.lerp(
                                      Colors.white38,
                                      AtaraxiaPalette.glacialTeal,
                                      focus,
                                    ),
                                    size: 12 + (4 * focus),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    // Central hub
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(
                        Icons.blur_circular,
                        color: Colors.white24,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: widget.isTablet ? 40 : 28),

          Text(
            'TAP → THE DIAL',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isTablet ? 22 : 16,
              letterSpacing: 6,
              fontWeight: FontWeight.w300,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Tap once anywhere to summon the Rotary Dial.\nSpin it to select an action.\nRelease when the top reader glows.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: widget.isTablet ? 15 : 12,
              height: 1.7,
            ),
          ),

          SizedBox(height: widget.isTablet ? 24 : 16),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _MiniChip('Memory'),
              _MiniChip('Library'),
              _MiniChip('Sanctuary'),
              _MiniChip('Ritual'),
              _MiniChip('Hide Text'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PAGE 4: SWIPE NAVIGATION — all 4 directions shown simultaneously
// ─────────────────────────────────────────────────────────────────
class _SwipePage extends StatefulWidget {
  final bool isTablet;
  const _SwipePage({required this.isTablet});
  @override
  State<_SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<_SwipePage> with TickerProviderStateMixin {
  Timer? _cycleTimer;
  int _autoIdx = 0;
  int? _manualIdx;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (mounted) setState(() => _autoIdx = (_autoIdx + 1) % 4);
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  int get _activeIdx {
    if (_manualIdx != null) return _manualIdx!;
    return _autoIdx;
  }

  void _onTileTap(int idx) {
    _cycleTimer?.cancel();
    setState(() {
      _manualIdx = idx;
      _autoIdx = idx; // sync auto cycle
    });
    // Resume auto-cycle after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _manualIdx = null);
        _startTimer();
      }
    });
  }

  static const _directions = [
    (
      Icons.arrow_back_rounded,
      '← LEFT',
      'SWIPE LEFT',
      'Sanctuary\n(Your profile & settings)',
    ),
    (
      Icons.arrow_forward_rounded,
      '→ RIGHT',
      'SWIPE RIGHT',
      'Memory\n(Saved wallpapers)',
    ),
    (
      Icons.arrow_upward_rounded,
      '↑ UP',
      'SWIPE UP',
      'Explore Void\n(Left half = Drawer, Right = Feed)',
    ),
    (
      Icons.arrow_downward_rounded,
      '↓ DOWN',
      'SWIPE DOWN',
      'Dimensions\n(Browse by category)',
    ),
  ];

  static const _tileColors = [
    Color(0xFF00BCD4), // glacialTeal approx
    Color(0xFF9B59FF), // auroraViolet approx
    Color(0xFF9B7FFF),
    Color(0xFFD4A843), // sacredGold approx
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.isTablet;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s ? 80 : 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Phone mockup — reactive to active direction ──
          _PhoneMockup(activeIdx: _activeIdx, isTablet: s),

          SizedBox(height: s ? 8 : 6),

          // ── Live direction label — updates with active tile ──
          Builder(
            builder: (_) {
              final idx = _activeIdx;
              final dir = _directions[idx];
              final color = _tileColors[idx];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        ),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(idx),
                  children: [
                    Text(
                      dir.$3,
                      style: TextStyle(
                        color: color,
                        fontSize: s ? 13 : 10,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dir.$4,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: s ? 13 : 11,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: s ? 20 : 14),

          // ── 4 direction tiles — tappable ──
          Builder(
            builder: (_) {
              final activeIdx = _activeIdx;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(4, (i) {
                  final dir = _directions[i];
                  final color = _tileColors[i];
                  return GestureDetector(
                    onTap: () => _onTileTap(i),
                    child: _SwipeTile(
                      icon: dir.$1,
                      direction: dir.$2,
                      label: dir.$3,
                      color: color,
                      isActive: activeIdx == i,
                      isTablet: s,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Swipe tile with active highlight
class _SwipeTile extends StatelessWidget {
  final IconData icon;
  final String direction;
  final String label;
  final Color color;
  final bool isActive;
  final bool isTablet;
  const _SwipeTile({
    required this.icon,
    required this.direction,
    required this.label,
    required this.color,
    required this.isActive,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isActive
            ? color.withOpacity(0.12)
            : Colors.white.withOpacity(0.03),
        border: Border.all(
          color: isActive
              ? color.withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? color : Colors.white30, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                direction,
                style: TextStyle(
                  color: isActive
                      ? color.withOpacity(0.8)
                      : Colors.white.withOpacity(0.3),
                  fontSize: 8,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white.withOpacity(0.9)
                      : Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PAGE 5: EXPLORE FEED
// ─────────────────────────────────────────────────────────────────
class _ExplorePage extends StatefulWidget {
  final bool isTablet;
  const _ExplorePage({required this.isTablet});
  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isTablet ? 80 : 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated vertical scroll visualisation
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return SizedBox(
                width: widget.isTablet ? 150 : 110,
                height: widget.isTablet ? 200 : 160,
                child: Stack(
                  children: [
                    // Card stack
                    ...List.generate(3, (i) {
                      final offset = (i * 0.33 - _ctrl.value + 1.0) % 1.0;
                      final y = offset * (widget.isTablet ? 200 : 160);
                      final scale = 0.85 + (0.15 * (1.0 - offset));
                      return Positioned(
                        top: y - (widget.isTablet ? 100 : 80),
                        left: 0,
                        right: 0,
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            height: widget.isTablet ? 120 : 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  [
                                    AtaraxiaPalette.cosmicIndigo,
                                    AtaraxiaPalette.auroraViolet,
                                  ],
                                  [
                                    AtaraxiaPalette.auroraViolet,
                                    AtaraxiaPalette.glacialTeal,
                                  ],
                                  [
                                    AtaraxiaPalette.glacialTeal,
                                    AtaraxiaPalette.cosmicIndigo,
                                  ],
                                ][i].map((c) => c.withOpacity(0.3)).toList(),
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Scroll indicator
                    Positioned(
                      right: 4,
                      top: (_ctrl.value * (widget.isTablet ? 160 : 120)).clamp(
                        0,
                        widget.isTablet ? 160.0 : 120.0,
                      ),
                      child: Container(
                        width: 3,
                        height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: AtaraxiaPalette.glacialTeal.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: widget.isTablet ? 40 : 28),

          Text(
            'THE VOID FEED',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isTablet ? 22 : 16,
              letterSpacing: 6,
              fontWeight: FontWeight.w300,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Swipe UP on the right side of the screen\nto enter an infinite vertical wallpaper feed.\n\nDouble-tap to save. Long-press to\nreveal share, download & more options.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: widget.isTablet ? 15 : 12,
              height: 1.7,
            ),
          ),

          SizedBox(height: widget.isTablet ? 32 : 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GestureChip(
                icon: Icons.favorite_rounded,
                text: 'Double-tap to save',
                color: AtaraxiaPalette.auroraViolet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED MINI COMPONENTS
// ─────────────────────────────────────────────────────────────────
class _GestureChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _GestureChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AtaraxiaPalette.glacialTeal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: c.withOpacity(0.08),
        border: Border.all(color: c.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: c.withOpacity(0.9),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 9,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _PhoneMockup extends StatefulWidget {
  final int activeIdx;
  final bool isTablet;
  const _PhoneMockup({required this.activeIdx, required this.isTablet});

  @override
  State<_PhoneMockup> createState() => _PhoneMockupState();
}

class _PhoneMockupState extends State<_PhoneMockup>
    with TickerProviderStateMixin {
  late AnimationController _swipeCtrl;
  late AnimationController _loopCtrl;

  int _swipePhase = 0;
  int _runToken = 0; // incremented on each new direction to cancel old loops

  @override
  void initState() {
    super.initState();
    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _startLoop();
  }

  @override
  void didUpdateWidget(_PhoneMockup old) {
    super.didUpdateWidget(old);
    if (old.activeIdx != widget.activeIdx) {
      _startLoop(); // cancels old loop via token, starts fresh
    }
  }

  void _startLoop() {
    _runToken++; // invalidates any pending callbacks from previous direction
    _swipePhase = 0;
    _swipeCtrl.stop();
    _runOnce(_runToken);
  }

  void _runOnce(int token) {
    if (!mounted || token != _runToken) return;
    _swipeCtrl.forward(from: 0).then((_) {
      if (!mounted || token != _runToken) return;

      if (widget.activeIdx == 2 && _swipePhase == 0) {
        // For UP: pause, flip phase to 1, run again (once)
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted || token != _runToken) return;
          setState(() {
            _swipePhase = 1;
          });
          _runOnce(token);
        });
      }
      // No else block: we do NOT loop endlessly.
      // Other directions play once and stop. UP plays phase 0 then phase 1 and stops.
    });
  }

  @override
  void dispose() {
    _runToken++; // stop any pending Future.delayed callbacks
    _swipeCtrl.dispose();
    _loopCtrl.dispose();
    super.dispose();
  }

  static const _tileColors = [
    Color(0xFF00BCD4),
    Color(0xFF9B59FF),
    Color(0xFF9B7FFF),
    Color(0xFFD4A843),
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.isTablet;
    final phoneW = s ? 180.0 : 140.0;
    final phoneH = s ? 240.0 : 190.0;
    final idx = widget.activeIdx;
    final color = _tileColors[idx];

    return SizedBox(
      width: phoneW + 60,
      height: phoneH + 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── PHONE SHELL ──
          Container(
            width: phoneW,
            height: phoneH,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.01),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // Wallpaper bg
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        colors: [
                          color.withOpacity(0.08),
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),

                  // ── CONTENT per direction ──
                  AnimatedBuilder(
                    animation: _swipeCtrl,
                    builder: (_, __) {
                      final t = Curves.easeOutCubic.transform(_swipeCtrl.value);
                      return _buildScreenContent(
                        idx,
                        t,
                        phoneW,
                        phoneH,
                        color,
                        s,
                      );
                    },
                  ),

                  // ── SWIPE FINGER TRAIL ──
                  AnimatedBuilder(
                    animation: _swipeCtrl,
                    builder: (_, __) {
                      return _buildFingerTrail(
                        idx,
                        _swipeCtrl.value,
                        phoneW,
                        phoneH,
                        color,
                      );
                    },
                  ),

                  // Notch
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── OUTSIDE ARROW — shows swipe origin ──
          AnimatedBuilder(
            animation: _swipeCtrl,
            builder: (_, __) {
              return _buildOutsideArrow(
                idx,
                _swipeCtrl.value,
                phoneW,
                phoneH,
                color,
                s,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScreenContent(
    int idx,
    double t,
    double phoneW,
    double phoneH,
    Color color,
    bool s,
  ) {
    switch (idx) {
      case 0: // SWIPE LEFT → Sanctuary panel
        return Positioned(
          right: (1.0 - t) * -phoneW * 0.65,
          top: 0,
          bottom: 0,
          width: phoneW * 0.65,
          child: Transform.translate(
            offset: Offset(phoneW * 0.65 * (1.0 - t), 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.12),
                border: Border(
                  left: BorderSide(
                    color: const Color(0xFF00BCD4).withOpacity(0.3),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 28, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SANCTUARY',
                      style: TextStyle(
                        color: const Color(0xFF00BCD4).withOpacity(0.9),
                        fontSize: s ? 7 : 5.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Header Row (Avatar + Name)
                    Row(
                      children: [
                        Container(
                          width: s ? 14 : 10,
                          height: s ? 14 : 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: s ? 30 : 20,
                          height: s ? 4 : 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Vibe Selector (Pills)
                    Row(
                      children: List.generate(
                        3,
                        (i) => Container(
                          margin: const EdgeInsets.only(right: 3),
                          width: s ? 16 : 12,
                          height: s ? 6 : 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4)
                                .withOpacity(0.2 - (i * 0.05)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Streak Card
                    Container(
                      height: s ? 36 : 28,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A843).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFD4A843).withOpacity(0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Premium Card
                    Container(
                      height: s ? 24 : 18,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFD4A843).withOpacity(0.3),
                            const Color(0xFFD4A843).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFD4A843).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case 1: // SWIPE RIGHT → Memory panel
        return Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: phoneW * 0.65,
          child: Transform.translate(
            offset: Offset(-phoneW * 0.65 * (1.0 - t), 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF9B59FF).withOpacity(0.12),
                border: Border(
                  right: BorderSide(
                    color: const Color(0xFF9B59FF).withOpacity(0.3),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 28, 6, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEMORY',
                      style: TextStyle(
                        color: const Color(0xFF9B59FF).withOpacity(0.9),
                        fontSize: s ? 7 : 5.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Simulated FloatingMemoryCarousel (Stacked fan)
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: List.generate(3, (i) {
                          final double angle = (i - 1) * 0.2;
                          final double scale = 1.0 - (i == 1 ? 0.0 : 0.1);
                          final double yOffset = (i == 1) ? 0.0 : 10.0;
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..translate(0.0, yOffset, 0.0)
                              ..rotateZ(angle)
                              ..scale(scale),
                            child: Container(
                              width: s ? 50 : 36,
                              height: s ? 80 : 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF9B59FF).withOpacity(0.4),
                                    const Color(0xFF9B59FF).withOpacity(0.1),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF9B59FF).withOpacity(0.5),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9B59FF).withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).reversed.toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case 2: // SWIPE UP → Drawer (left) & Feed (right)
        final isRightPhase = _swipePhase == 1; // phase 0 = left drawer first
        final t2 = Curves.easeOutCubic.transform(_swipeCtrl.value);

        return Stack(
          children: [
            // Divider line
            Positioned(
              left: phoneW / 2 - 0.5,
              top: 0,
              bottom: 0,
              width: 1,
              child: Container(color: Colors.white.withOpacity(0.1)),
            ),

            // Left half: DRAWER — slides up from bottom
            Positioned(
              left: 0,
              width: phoneW / 2,
              top: 0,
              bottom: 0,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionalTranslation(
                    translation: Offset(0, isRightPhase ? 1.0 : (1.0 - t2)),
                    child: Container(
                      height: phoneH * 0.7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9B7FFF).withOpacity(0.14),
                        border: Border(
                          top: BorderSide(
                            color: const Color(0xFF9B7FFF).withOpacity(0.5),
                          ),
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DRAWER',
                              style: TextStyle(
                                color: const Color(0xFF9B7FFF).withOpacity(0.8),
                                fontSize: s ? 6 : 5,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Masonry grid simulation
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const NeverScrollableScrollPhysics(),
                                      child: Column(
                                        children: [
                                          _miniBlock(phoneH, 0.25, const Color(0xFF9B7FFF)),
                                          _miniBlock(phoneH, 0.4, const Color(0xFF9B7FFF)),
                                          _miniBlock(phoneH, 0.2, const Color(0xFF9B7FFF)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const NeverScrollableScrollPhysics(),
                                      child: Column(
                                        children: [
                                          _miniBlock(phoneH, 0.35, const Color(0xFF9B7FFF)),
                                          _miniBlock(phoneH, 0.25, const Color(0xFF9B7FFF)),
                                          _miniBlock(phoneH, 0.3, const Color(0xFF9B7FFF)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right half: FEED — full-page vertical cinematic scroll
            Positioned(
              right: 0,
              width: phoneW / 2,
              top: 0,
              bottom: 0,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _swipeCtrl,
                  builder: (_, __) {
                    final scrollFrac = isRightPhase ? t2 : 1.0;
                    // Scroll exactly one full page height
                    final scroll = scrollFrac * phoneH;
                    return Transform.translate(
                      offset: Offset(0, -scroll),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            3,
                            (i) => Container(
                              height: phoneH, // full page height
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF9B7FFF).withOpacity(0.15 + (i % 2) * 0.08),
                                    const Color(0xFF00BCD4).withOpacity(0.10 + (i % 3) * 0.05),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.07),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Fake social buttons
                                  Positioned(
                                    right: 4,
                                    bottom: 12,
                                    child: Column(
                                      children: [
                                        Icon(Icons.favorite_border, size: s ? 10 : 8, color: Colors.white.withOpacity(0.4)),
                                        const SizedBox(height: 6),
                                        Icon(Icons.bookmark_border, size: s ? 10 : 8, color: Colors.white.withOpacity(0.4)),
                                        const SizedBox(height: 6),
                                        Icon(Icons.share, size: s ? 10 : 8, color: Colors.white.withOpacity(0.4)),
                                      ],
                                    ),
                                  ),
                                  // Fake text
                                  Positioned(
                                    left: 6,
                                    bottom: 12,
                                    child: Container(
                                      width: s ? 24 : 16,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );

      case 3: // SWIPE DOWN → Dimensions category browser
        final slideY = (1.0 - t) * -phoneH * 0.55;
        return Positioned(
          left: 0,
          right: 0,
          top: slideY,
          height: phoneH * 0.65,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD4A843).withOpacity(0.08),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFD4A843).withOpacity(0.3),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 26, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIMENSIONS',
                    style: TextStyle(
                      color: const Color(0xFFD4A843).withOpacity(0.9),
                      fontSize: s ? 7 : 5.5,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Grid of category blocks
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(4, (i) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: const Color(0xFFD4A843).withOpacity(0.1 + i * 0.03),
                            border: Border.all(
                              color: const Color(0xFFD4A843).withOpacity(0.2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // Helper for masonry grid mini blocks
  Widget _miniBlock(double phoneH, double heightFactor, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      height: phoneH * heightFactor * 0.5,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildFingerTrail(
    int idx,
    double t,
    double phoneW,
    double phoneH,
    Color color,
  ) {
    // Trail fades in fast then fades out
    final opacity = t < 0.3
        ? t / 0.3
        : t < 0.7
        ? 1.0
        : (1 - t) / 0.3;

    Offset start, end;
    switch (idx) {
      case 0: // SWIPE LEFT: finger moves right→left, BUT panel comes from right
        // finger still goes right to left (that's the actual swipe gesture)
        start = Offset(phoneW * 0.75, phoneH * 0.5);
        end = Offset(phoneW * 0.15, phoneH * 0.5);
        break;
      case 1: // SWIPE RIGHT: finger moves left→right
        start = Offset(phoneW * 0.25, phoneH * 0.5);
        end = Offset(phoneW * 0.85, phoneH * 0.5);
        break;
      case 2:
        if (_swipePhase == 0) {
          // Phase 0: LEFT half first (drawer)
          start = Offset(phoneW * 0.25, phoneH * 0.78);
          end = Offset(phoneW * 0.25, phoneH * 0.22);
        } else {
          // Phase 1: RIGHT half (feed)
          start = Offset(phoneW * 0.75, phoneH * 0.78);
          end = Offset(phoneW * 0.75, phoneH * 0.22);
        }
        break;
      case 3: // Swipe down: top to bottom
        start = Offset(phoneW * 0.5, phoneH * 0.2);
        end = Offset(phoneW * 0.5, phoneH * 0.75);
        break;
      default:
        return const SizedBox.shrink();
    }

    final current = Offset.lerp(start, end, Curves.easeInOut.transform(t))!;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: CustomPaint(
        painter: _TrailPainter(
          start: start,
          current: current,
          color: color,
          progress: t,
        ),
        size: Size(phoneW, phoneH),
      ),
    );
  }

  Widget _buildOutsideArrow(
    int idx,
    double t,
    double phoneW,
    double phoneH,
    Color color,
    bool s,
  ) {
    // Pulses: arrow bounces toward phone
    final pulse = math.sin(t * math.pi) * 8;
    final iconSize = s ? 26.0 : 20.0;

    IconData icon;
    Offset position;

    switch (idx) {
      case 0: // swipe LEFT: arrow on right side pointing left
        icon = Icons.arrow_back_rounded;
        position = Offset(phoneW / 2 + 16 - pulse, 0);
        break;
      case 1: // swipe RIGHT: arrow on left side pointing right
        icon = Icons.arrow_forward_rounded;
        position = Offset(-phoneW / 2 - 16 + pulse, 0);
        break;
      case 2:
        icon = Icons.arrow_upward_rounded;
        // Arrow shifts left/right depending on which half is being demonstrated
        final xOffset = _swipePhase == 0 ? -phoneW * 0.25 : phoneW * 0.25;
        position = Offset(xOffset, phoneH / 2 + 16 - pulse);
        break;
      case 3: // swipe DOWN: arrow above pointing down
        icon = Icons.arrow_downward_rounded;
        position = Offset(0, -phoneH / 2 - 16 + pulse);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Transform.translate(
      offset: position,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.8), blurRadius: 16),
            BoxShadow(color: color.withOpacity(0.4), blurRadius: 32),
          ],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  final Offset start;
  final Offset current;
  final Color color;
  final double progress;

  const _TrailPainter({
    required this.start,
    required this.current,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trailPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw trail line
    canvas.drawLine(start, current, trailPaint);

    // Draw glowing dot at finger tip
    final dotPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(current, 5, dotPaint);

    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(current, 10, glowPaint);
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.current != current || old.progress != progress;
}
