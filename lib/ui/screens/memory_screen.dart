import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/models/identity.dart';
import '../../data/models/memory_bond.dart';
import '../../data/models/moment.dart';
import '../../data/identity_store.dart';
import '../identity/identity_gate.dart';
import '../../supabase/supabase_service.dart';
import '../../utils/imagekit.dart';
import '../identity/identity_export_sheet.dart';
import '../../features/identity/identity_qr_export.dart';
import '../identity/burn_identity_ritual.dart';
import '../screens/ritual_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import '../identity/identity_export_warning.dart';
import '../../utils/moment_action_handler.dart';
import '../../utils/moment_actions.dart';
import '../../utils/share_service.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with TickerProviderStateMixin {
  late final AnimationController pulse;
  late final AnimationController awakenController;
  late final AnimationController shimmerController;
  late final Animation<double> awaken;

  List<MemoryBond> _bonds = [];
  bool _initialized = false;
  int _currentPageIndex = 0;
  Identity? _identity;
  final Map<String, ImageProvider> _imageProviderCache = {};
  final ValueNotifier<double> _bgPage = ValueNotifier(0.0);

  ImageProvider _getImageProvider(String imageKey) {
    return _imageProviderCache.putIfAbsent(
      imageKey,
      () => NetworkImage(ImageKit.original(imageKey)),
    );
  }

  Future<void> _reloadIdentity() async {
    setState(() {
      _initialized = false;
      _bonds.clear();
      _identity = null;
    });

    final identity = await IdentityStore.active();
    if (!mounted) return;

    if (identity == null) {
      setState(() => _initialized = true);
      return;
    }

    setState(() => _identity = identity);
    await _initMemoryScreen(identity);
  }

  Future<void> _initMemoryScreen(Identity identity) async {
    final bonds = await SupabaseService.fetchMemoryBonds(identity.id);
    setState(() {
      _bonds = bonds;
      _initialized = true;
    });

    for (final bond in bonds.take(4)) {
      if (mounted) precacheImage(_getImageProvider(bond.imageKey), context);
    }
  }

  @override
  void initState() {
    super.initState();

    pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    awakenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // ✨ Rotating iridescent sheen
    shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    awaken = CurvedAnimation(
      parent: awakenController,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final identity = await IdentityStore.active();
      if (!mounted) return;

      if (identity == null) {
        setState(() {
          _identity = null;
          _initialized = true;
          _bonds = [];
        });
        return;
      }
      setState(() => _identity = identity);
      _initMemoryScreen(identity);
    });
  }

  @override
  void dispose() {
    pulse.dispose();
    awakenController.dispose();
    shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. The Background acts as the canvas for both states
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 2. The Content Switcher (Loads Carousel vs Void Pulse)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1200),
            switchInCurve: Curves.easeOutQuart,
            switchOutCurve: Curves.easeInQuad,
            child: !_initialized
                ? _RitualLoader(
                    pulse: pulse,
                    shimmer: shimmerController,
                    text: 'R E C A L L I N G', // Normal loading state
                  )
                : _bonds.isEmpty
                ? Stack(
                    key: const ValueKey('Empty'),
                    children: [
                      _RitualLoader(
                        pulse: pulse,
                        shimmer: shimmerController,
                        // Logic for what to show when empty
                        text: _identity == null
                            ? 'TAP ATARAXIA TO ENTER'
                            : 'NO MEMORIES YET',
                      ),
                      // Only show the paragraph text if they are actually logged in
                      if (_identity != null) const _EmptyMemory(),
                    ],
                  )
                : _buildCarouselContent(),
          ),

          // 3. The Identity Aura (Always present - anchors the user)
          Positioned(
            top: 33,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: _IdentityAura(identity: _identity, pulse: pulse),
            ),
          ),

          // 4. Cinematic Vignette (Always on top to blend everything)
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
                  stops: [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to keep the build method clean
  Widget _buildCarouselContent() {
    return Stack(
      key: const ValueKey('Carousel'),
      clipBehavior: Clip.none,
      children: [
        RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: _bgPage,
            builder: (_, page, __) {
              return _BackgroundCrossFade(
                bonds: _bonds,
                page: page,
                getImageProvider: _getImageProvider,
                awaken: awaken,
                pulse: pulse,
              );
            },
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: _FloatingMemoryCarousel(
                bonds: _bonds,
                pulse: pulse,
                awaken: awaken,
                shimmer: shimmerController,
                getImageProvider: _getImageProvider,
                pageListenable: _bgPage,
                onPageChanged: (page) {
                  _bgPage.value = page;
                  _currentPageIndex = page.round();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RitualLoader extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> shimmer;
  final String text;

  const _RitualLoader({
    required this.pulse,
    required this.shimmer,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Center(
      key: const ValueKey('Loader'),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. The Rotating Glyphs (Tuning)
          AnimatedBuilder(
            animation: shimmer,
            builder: (_, __) {
              return Transform.rotate(
                angle: shimmer.value * 2 * pi,
                child: Container(
                  width: isTablet ? 280 : 180,
                  height: isTablet ? 280 : 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.03),
                      width: 1,
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. The "Sonar" Pulse (Searching)
          CustomPaint(
            painter: _VoidPulsePainter(animation: pulse),
            size: isTablet ? const Size(450, 450) : const Size(300, 300),
          ),

          // 3. The Text (Manifesting)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: isTablet ? 180 : 120), // Push below center
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) {
                  return Opacity(
                    opacity: 0.3 + (pulse.value * 0.4),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 15 : 10,
                        letterSpacing: isTablet
                            ? 7.0 + (pulse.value * 3)
                            : 6.0 + (pulse.value * 2),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoidPulsePainter extends CustomPainter {
  final Animation<double> animation;

  _VoidPulsePainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw 3 rings that expand based on the pulse
    for (int i = 0; i < 3; i++) {
      // Stagger the rings so they don't all move at once
      final offset = i * 0.3;
      final progress = (animation.value + offset) % 1.0;

      // Radius expands from 20 to 80
      final radius = 20.0 + (progress * 60.0);

      // Opacity fades out as it gets larger
      final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.3;

      paint.color = Colors.white.withOpacity(opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_VoidPulsePainter oldDelegate) => true;
}

/* ───────────────────────────────────────────────────────────── */
/* FLOATING MEMORY CAROUSEL (ADAPTIVE MOTION ENGINE)             */
/* ───────────────────────────────────────────────────────────── */

class _FloatingMemoryCarousel extends StatefulWidget {
  final List<MemoryBond> bonds;
  final Animation<double> pulse;
  final Animation<double> awaken;
  final Animation<double> shimmer;
  final ValueChanged<double> onPageChanged;
  final ImageProvider Function(String imageKey) getImageProvider;
  final ValueListenable<double> pageListenable;

  const _FloatingMemoryCarousel({
    required this.bonds,
    required this.pulse,
    required this.awaken,
    required this.shimmer,
    required this.onPageChanged,
    required this.getImageProvider,
    required this.pageListenable,
  });

  @override
  State<_FloatingMemoryCarousel> createState() =>
      _FloatingMemoryCarouselState();
}

class _FloatingMemoryCarouselState extends State<_FloatingMemoryCarousel>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  PageController? _controller; // Made nullable for dynamic recreation
  double _viewportFraction = 0.75;

  StreamSubscription? _accelSub;
  int _lastHapticIndex = -1;
  late final Ticker _ticker;
  late final ValueNotifier<Offset> tilt;

  double _targetTiltX = 0, _targetTiltY = 0;
  double _currentTiltX = 0, _currentTiltY = 0;
  double _rawTiltX = 0.0, _rawTiltY = 0.0;
  double _tiltVelocityX = 0, _tiltVelocityY = 0;
  Duration? _last;

  static const double springStrength = 180;
  static const double damping = 22;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tilt = ValueNotifier(Offset.zero);

    _ticker = createTicker((elapsed) {
      final rawDt = _last == null
          ? 1 / 60
          : (elapsed - _last!).inMicroseconds / 1e6;
      final dt = rawDt.clamp(0.0, 1 / 30);
      _last = elapsed;

      _targetTiltX += (_rawTiltX - _targetTiltX) * 0.12;
      _targetTiltY += (_rawTiltY - _targetTiltY) * 0.12;

      _tiltVelocityX +=
          (springStrength * (_targetTiltX - _currentTiltX) -
              damping * _tiltVelocityX) *
          dt;
      _currentTiltX += _tiltVelocityX * dt;

      _tiltVelocityY +=
          (springStrength * (_targetTiltY - _currentTiltY) -
              damping * _tiltVelocityY) *
          dt;
      _currentTiltY += _tiltVelocityY * dt;

      tilt.value = Offset(_currentTiltX, _currentTiltY);
    })..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _accelSub = accelerometerEventStream().listen((event) {
          final x = (event.x / 9.8).clamp(-0.35, 0.35);
          final y = (event.y / 9.8).clamp(-0.35, 0.35);
          _rawTiltX = x.abs() < 0.02 ? 0.0 : x;
          _rawTiltY = y.abs() < 0.02 ? 0.0 : y;
        });
      });
    });
  }

  void _onScroll() {
    if (_controller == null) return;
    final page = _safePage(_controller!);
    widget.onPageChanged(page);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    // ─── PREMIUM ADAPTIVE MATH ───
    // Phones get 65% height, Tablets get 55% height to look like physical polaroids.
    // final targetHeight = size.height * (isTablet ? 0.61 : 0.65); // 3 in 1 tab
    final targetHeight = size.height * (isTablet ? 0.79 : 0.65);

    // Force a perfect 9:16 golden ratio based on the available height
    final targetWidth = targetHeight * (9 / 16);

    // Calculate exact viewport fraction needed to render that width (+24px for spacing)
    final newFraction = ((targetWidth + 24) / size.width).clamp(0.2, 0.85);

    // Rebuild controller only if screen size changes drastically (e.g., rotation)
    if (_controller == null || (_viewportFraction - newFraction).abs() > 0.01) {
      final initialPage = _controller?.page?.round() ?? 0;
      _controller?.removeListener(_onScroll);
      _controller?.dispose();

      _viewportFraction = newFraction;
      _controller = PageController(
        viewportFraction: _viewportFraction,
        initialPage: initialPage,
      );
      _controller!.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    tilt.dispose();
    _ticker.dispose();
    _controller?.dispose();
    _accelSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  double _safePage(PageController controller) =>
      controller.hasClients && controller.position.hasPixels
      ? controller.page ?? 0.0
      : 0.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    // Use the exact same math as dependencies to set the absolute box boundary
    final cardHeight = size.height * (isTablet ? 0.79 : 0.63); //card size

    return Column(
      mainAxisAlignment:
          MainAxisAlignment.center, // Keeps it tight to the center
      children: [
        SizedBox(height: isTablet ? 81 : 35),
        SizedBox(
          height: cardHeight, // DYNAMIC HEIGHT FIX
          child: AnimatedBuilder(
            animation: _controller!,
            builder: (_, __) {
              final page = _safePage(_controller!);
              return PageView.builder(
                controller: _controller,
                physics: const LiquidScrollPhysics(),
                clipBehavior: Clip.none,
                itemCount: widget.bonds.length,
                itemBuilder: (_, index) {
                  final bond = widget.bonds[index];
                  final delta = (page - index).clamp(-1.0, 1.0);
                  final depth = delta.abs();
                  final isActive = page.round() == index;

                  // Haptics
                  if (isActive &&
                      _lastHapticIndex != index &&
                      (page - index).abs() < 0.02) {
                    _lastHapticIndex = index;
                    HapticFeedback.lightImpact();
                  }

                  // Perspective Scale & Sway
                  final scale = widget.awaken.value * (1.0 - (depth * 0.25));
                  // final translationX = delta * (isTablet ? 30 : 13);
                  final translationX = delta * (isTablet ? 39 : 19);
                  final breathe = sin(widget.pulse.value * 2 * pi) * 2.5;

                  return ValueListenableBuilder<Offset>(
                    valueListenable: tilt,
                    builder: (_, t, __) {
                      final focus = (1.0 - depth).clamp(0.0, 1.0);
                      final rotationY = (delta * 0.08) + t.dx * focus;
                      final rotationX = (delta * 0.035) + t.dy * focus;

                      return Transform.translate(
                        offset: Offset(
                          translationX,
                          depth * 10 + breathe * focus,
                        ),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0016)
                            ..rotateX(rotationX)
                            ..rotateY(rotationY)
                            ..scale(scale),
                          child: RepaintBoundary(
                            child: _HolographicCard(
                              bond: bond,
                              imageProvider: widget.getImageProvider(
                                bond.imageKey,
                              ),
                              isActive: isActive,
                              tilt: t,
                              shimmer: widget.shimmer,
                              depth: depth,
                              isTablet: isTablet,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 32),
        ValueListenableBuilder<double>(
          valueListenable: widget.pageListenable,
          builder: (_, page, __) {
            final index = page.round();
            return Text(
              '${index + 1} / ${widget.bonds.length}',
              style: TextStyle(
                color: Colors.white38,
                fontSize: isTablet ? 14 : 12, // Slightly larger on tablet
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ],
    );
  }
}

/* ───────────────────────────────────────────────────────────── */
/* ✨ HOLOGRAPHIC IRIDESCENT CARD (UPGRADED TACTILE FEEDBACK)    */
/* ───────────────────────────────────────────────────────────── */

class _HolographicCard extends StatefulWidget {
  final MemoryBond bond;
  final ImageProvider imageProvider;
  final bool isActive;
  final Offset tilt;
  final Animation<double> shimmer;
  final double depth;
  final bool isTablet;

  const _HolographicCard({
    required this.bond,
    required this.imageProvider,
    required this.isActive,
    required this.tilt,
    required this.shimmer,
    required this.depth,
    required this.isTablet,
  });

  @override
  State<_HolographicCard> createState() => _HolographicCardState();
}

class _HolographicCardState extends State<_HolographicCard>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _burstCtrl;

  @override
  void initState() {
    super.initState();
    // Handles the physical push down feeling
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Fast press
      reverseDuration: const Duration(
        milliseconds: 500,
      ), // Satisfying, elastic release
    );

    // Handles the explosive light flare on release
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isActive) return;
    HapticFeedback.heavyImpact(); // Deep thud on press
    _pressCtrl.forward();
  }

  void _onTapCancel() {
    if (!widget.isActive) return;
    _pressCtrl.reverse();
  }

  void _onTapUp(TapUpDetails details) async {
    if (!widget.isActive) return;

    HapticFeedback.lightImpact(); // Crisp click on release

    // 1. Trigger the physical bounce-back
    _pressCtrl.reverse();
    // 2. Trigger the blinding holographic light sweep
    _burstCtrl.forward(from: 0.0);

    // Map the MemoryBond flawlessly into a Moment
    final recalledMoment = Moment(
      wallpaperId: widget.bond.wallpaperId,
      slug: slugFromImageKey(widget.bond.imageKey),
      id: widget.bond.wallpaperId,
      title: widget.bond.title,
      quote: widget.bond.quote,
      imageKey: widget.bond.imageKey,
      author: widget.bond.author,
      time: TimeOfDayMoment.morning,
      type: 'static',
      tags: [],
    );

    // 3. THE MAGIC FIX: Wait 400ms so the user actually sees the beautiful burst
    // before the screen fades away!
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) =>
            RitualScreen(overrideMoment: recalledMoment, fromExplore: true),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightSource = Alignment(-widget.tilt.dx * 3, -widget.tilt.dy * 3);
    final radius = BorderRadius.circular(widget.isTablet ? 56 : 32);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      // 🚀 NEW: The Long Press Trigger
      onLongPress: () async {
        HapticFeedback.heavyImpact();

        // 🚀 1. Trigger the explosive light flare to make the long-press feel incredibly powerful
        _burstCtrl.forward(from: 0.0);

        // 🚀 2. Instantly map the MemoryBond to a Moment format
        final momentToShare = Moment(
          wallpaperId: widget.bond.wallpaperId,
          slug: slugFromImageKey(widget.bond.imageKey),
          id: widget.bond.wallpaperId,
          title: widget.bond.title,
          quote: widget.bond.quote,
          imageKey: widget.bond.imageKey,
          author: widget.bond.author,
          time: TimeOfDayMoment.morning, // Default fallback
          type: 'static',
          tags: [],
        );

        // 🚀 3. Call the centralized cinematic handler!
        // This will instantly pop up your "EXTRACTING ECHO" heartbeat UI
        // and trigger the high-res off-screen ShareService rendering.
        if (context.mounted) {
          await handleMomentAction(
            context: context,
            moment: momentToShare,
            action: MomentAction.share,
            style: ShareStyle.memory,
          );
        }
      },
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) {
          // Compress by 5% on press for a very obvious, heavy tactile feel
          final scale = 1.0 - (_pressCtrl.value * 0.05);
          final shadowOpacity =
              0.6 * (1 - widget.depth) * (1.0 - (_pressCtrl.value * 0.3));

          return AspectRatio(
            aspectRatio: 9 / 16,
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        shadowOpacity.clamp(0.0, 1.0),
                      ),
                      blurRadius: widget.isTablet ? 60 : 30,
                      // Pushes shadow closer to the card when pressed to simulate depth
                      offset: Offset(
                        0,
                        widget.isTablet
                            ? (30 - (_pressCtrl.value * 15))
                            : (15 - (_pressCtrl.value * 8)),
                      ),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Image
                      Image(
                        image: widget.imageProvider,
                        fit: BoxFit.cover,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  _MemoryManifestation(
                                    shimmer: widget.shimmer,
                                    tilt: widget.tilt,
                                  ),
                                  AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeOutQuart,
                                    child: child,
                                  ),
                                ],
                              );
                            },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: Colors.white12,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),

                      // 2. Depth Dimmer
                      if (widget.depth > 0.01)
                        Container(
                          color: Colors.black.withOpacity(widget.depth * 0.4),
                        ),

                      // 3. Cinematic Vignette
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.6, 1.0],
                          ),
                        ),
                      ),

                      // 4. ✨ Iridescent Border
                      if (widget.isActive)
                        AnimatedBuilder(
                          animation: widget.shimmer,
                          builder: (_, __) => CustomPaint(
                            painter: _HolographicBorderPainter(
                              progress: widget.shimmer.value,
                              tilt: widget.tilt,
                              isTablet: widget.isTablet,
                            ),
                          ),
                        ),

                      // 5. ✨ Reactive Specular Glass
                      if (widget.isActive)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: lightSource,
                                end: Alignment(-lightSource.x, -lightSource.y),
                                colors: [
                                  Colors.white.withOpacity(
                                    widget.isTablet ? 0.25 : 0.12,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.4],
                              ),
                            ),
                          ),
                        ),

                      // 6. 🔥 THE ADDICTIVE LIGHT BURST (On Release)
                      if (widget.isActive)
                        AnimatedBuilder(
                          animation: _burstCtrl,
                          builder: (_, __) {
                            if (_burstCtrl.value == 0.0 ||
                                _burstCtrl.value == 1.0) {
                              return const SizedBox.shrink();
                            }
                            final v = Curves.easeOutQuart.transform(
                              _burstCtrl.value,
                            );
                            final sweep =
                                (v * 2.5) -
                                0.5; // Travels aggressively across screen
                            final fade = 1.0 - Curves.easeIn.transform(v);
                            final flashOpacity = (1.0 - (v * 4.0)).clamp(
                              0.0,
                              1.0,
                            );

                            return IgnorePointer(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // The Central Camera Flash (Blinds the card for a split second)
                                  if (flashOpacity > 0)
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.white.withOpacity(
                                              flashOpacity * 0.9,
                                            ),
                                            Colors.transparent,
                                          ],
                                          radius: 1.0 + (v * 3.0),
                                        ),
                                      ),
                                    ),
                                  // The Sweeping Glass Glare (Washes over the card)
                                  Opacity(
                                    opacity: fade,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withOpacity(0.8),
                                            Colors.cyanAccent.withOpacity(0.9),
                                            Colors.white.withOpacity(0.8),
                                            Colors.transparent,
                                          ],
                                          stops: [
                                            (sweep - 0.4).clamp(0.0, 1.0),
                                            (sweep - 0.1).clamp(0.0, 1.0),
                                            sweep.clamp(0.0, 1.0),
                                            (sweep + 0.1).clamp(0.0, 1.0),
                                            (sweep + 0.4).clamp(0.0, 1.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      // 7. Content Text
                      Positioned(
                        bottom: 30,
                        left: 24,
                        right: 24,
                        child: Column(
                          children: [
                            Text(
                              widget.bond.title,
                              textAlign: TextAlign.center,
                              maxLines: 4,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.isTablet ? 26 : 17,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.w600,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 10),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _RitualTag(
                              intensity: widget.bond.intensity,
                              isTablet: widget.isTablet,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemoryManifestation extends StatelessWidget {
  final Animation<double> shimmer;
  final Offset tilt;

  const _MemoryManifestation({required this.shimmer, required this.tilt});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        // We shift the gradient based on the tilt physics to give it depth
        final alignX = -tilt.dx * 2;
        final alignY = -tilt.dy * 2;

        return Container(
          decoration: BoxDecoration(
            color: Colors.black, // Base void
            gradient: LinearGradient(
              begin: Alignment(alignX - 1, alignY - 1),
              end: Alignment(alignX + 1, alignY + 1),
              // Dark, muted versions of your holographic colors
              colors: [
                Colors.black,
                Colors.cyan.withOpacity(0.05),
                Colors.purple.withOpacity(0.05),
                Colors.black,
              ],
              stops: [
                0.0,
                0.3 +
                    (shimmer.value *
                        0.2), // The gradient moves through the void
                0.7 - (shimmer.value * 0.2),
                1.0,
              ],
              transform: GradientRotation(shimmer.value * pi),
            ),
          ),
          child: Center(
            // A pulsing "core" indicating the memory is being recalled
            child: Opacity(
              opacity: 0.1 + (sin(shimmer.value * 2 * pi).abs() * 0.1),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Center(
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RitualTag extends StatelessWidget {
  final int intensity;
  final bool isTablet;
  const _RitualTag({required this.intensity, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: isTablet ? 18 : 12,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            'RITUALS $intensity',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isTablet ? 14 : 10,

              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HolographicBorderPainter extends CustomPainter {
  final double progress;
  final Offset tilt;
  final bool isTablet;
  _HolographicBorderPainter({
    required this.progress,
    required this.tilt,
    required this.isTablet,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isTablet ? 5.0 : 2.0;
    paint.shader = SweepGradient(
      center: Alignment(tilt.dx * 0.5, tilt.dy * 0.5),
      colors: [
        Colors.white.withOpacity(0),
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.6),
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0),
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      transform: GradientRotation(progress * pi * 2),
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1.0),
        Radius.circular(isTablet ? 56 : 32),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_HolographicBorderPainter old) => true;
}

/* ───────────────────────────────────────────────────────────── */
/* REMAINING UTILS (Background, Aura, Physics)                   */
/* ───────────────────────────────────────────────────────────── */

class LiquidScrollPhysics extends BouncingScrollPhysics {
  const LiquidScrollPhysics({super.parent});
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      offset * 0.65;
}

class _BackgroundCrossFade extends StatelessWidget {
  final List<MemoryBond> bonds;
  final double page;
  final Animation<double> awaken;
  final Animation<double> pulse;
  final ImageProvider Function(String) getImageProvider;

  const _BackgroundCrossFade({
    required this.bonds,
    required this.page,
    required this.awaken,
    required this.pulse,
    required this.getImageProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (bonds.isEmpty) return const SizedBox();
    final base = page.floor().clamp(0, bonds.length - 1);
    final next = (base + 1).clamp(0, bonds.length - 1);
    final t = (page - base).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 1.0 - t,
          child: Image(
            image: getImageProvider(bonds[base].imageKey),
            fit: BoxFit.cover,
          ),
        ),
        Opacity(
          opacity: t,
          child: Image(
            image: getImageProvider(bonds[next].imageKey),
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            // child: Container(color: Colors.black.withOpacity(0.4)),
            // child: Container(color: Colors.black.withOpacity(0.15)),
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) {
                // Opacity fluctuates between 0.1 and 0.25
                final dynamicOpacity = 0.1 + (pulse.value * 0.25);
                return Container(
                  color: Colors.black.withOpacity(dynamicOpacity),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _IdentityAura extends StatefulWidget {
  final Identity? identity;
  final Animation<double> pulse;

  const _IdentityAura({required this.identity, required this.pulse});

  @override
  State<_IdentityAura> createState() => _IdentityAuraState();
}

class _IdentityAuraState extends State<_IdentityAura>
    with SingleTickerProviderStateMixin {
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  // Particles
  final List<_Particle> _particles = [];
  final int _particleCount = 25;
  final Random _rand = Random();
  // Timer? _particleTimer;

  @override
  void initState() {
    super.initState();
    _scale = Tween(
      begin: 0.96,
      end: 1.05,
    ).animate(CurvedAnimation(parent: widget.pulse, curve: Curves.easeInOut));

    _opacity = Tween(
      begin: 0.06,
      end: 0.18,
    ).animate(CurvedAnimation(parent: widget.pulse, curve: Curves.easeInOut));

    // Initialize particles
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_Particle.random(_rand));
    }

    // Animate particles
    // _particleTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
    //   for (var p in _particles) {
    //     p.update();
    //   }
    //   // no setState
    // });
  }

  @override
  void dispose() {
    // _particleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return GestureDetector(
      onTap: () {
        if (widget.identity == null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => IdentityGate(
                // onAuthenticated: () {
                //   Navigator.pop(context);

                //   // force reload
                //   if (context.mounted) {
                //     final state = context
                //         .findAncestorStateOfType<_MemoryScreenState>();
                //     state?.setState(() {
                //       state._initialized = false;
                //     });
                //     state?.initState();
                //   }
                // },
                onAuthenticated: () async {
                  Navigator.pop(context);

                  final state = context
                      .findAncestorStateOfType<_MemoryScreenState>();

                  await state?._reloadIdentity();
                },
              ),
            ),
          );
        } else {
          _showIdentityActions(context, widget.identity!);
        }
      },

      child: AnimatedBuilder(
        animation: widget.pulse,
        builder: (_, __) {
          final emptyBoost = widget.identity == null ? 1.4 : 1.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // 🌌 Aura glow behind text
                  Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: isTablet ? 200 : 130,
                      height: isTablet ? 100 : 61,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(
                              (_opacity.value * emptyBoost).clamp(0.0, 0.35),
                            ),

                            Colors.transparent,
                          ],
                          radius: 0.9,
                        ),
                      ),
                    ),
                  ),

                  // ✨ Identity ID (anchor)
                  Text(
                    (widget.identity?.name ?? 'ATARAXIA').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 30 : 16,
                      letterSpacing: isTablet ? 8.0 : 5.0,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Courier',
                    ),
                  ),

                  // 🫧 Particles orbit the text
                  SizedBox(
                    width: isTablet ? 240 : 160,
                    height: isTablet ? 60 : 35,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _ParticlePainter(
                          _particles,
                          widget.pulse.value,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────── */
/* PARTICLE LOGIC                                                 */
/* ───────────────────────────────────────────────────────────── */

// class _Particle {
//   double x, y, size, speedX, speedY, alpha;
//   _Particle(Random r)
//     : x = r.nextDouble() * 120 - 60,
//       y = r.nextDouble() * 40 - 20,
//       size = r.nextDouble() * 2 + 1,
//       speedX = (r.nextDouble() - 0.5) * 0.4,
//       speedY = (r.nextDouble() - 0.5) * 0.4,
//       alpha = r.nextDouble() * 0.5 + 0.1;

//   factory _Particle.random(Random r) => _Particle(r);
// }

class _Particle {
  double x, y, size, speedX, speedY, alpha;

  _Particle(Random r)
    : x = (r.nextDouble() - 0.5) * 180, // Wider spread (was 120)
      y = (r.nextDouble() - 0.5) * 50, // Taller spread (was 40)
      size = r.nextDouble() * 1.5 + 0.5, // Smaller, finer dust (was 2+1)
      // Much faster chaotic movement
      speedX = (r.nextDouble() - 0.5) * 0.8,
      speedY = (r.nextDouble() - 0.5) * 0.8,
      // Brighter alpha
      alpha = r.nextDouble() * 0.6 + 0.2;

  factory _Particle.random(Random r) => _Particle(r);
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;

  _ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final t = animationValue * 2 * pi;

    for (var p in particles) {
      // Orbit math driven by pulse animation to avoid extra timer
      double dx = p.x + sin(t + p.x) * 5;
      double dy = p.y + cos(t + p.y) * 2;

      paint.color = Colors.white.withOpacity(p.alpha);
      canvas.drawCircle(
        Offset(size.width / 2 + dx, size.height / 2 + dy),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// void _showIdentityActions(BuildContext context, Identity identity) {
//   showModalBottomSheet(
//     context: context,
//     backgroundColor: Colors.black,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//     ),
//     isScrollControlled: true,
//     builder: (sheetContext) {
//       // builder: (_) { //check
//       return SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   identity.name,
//                   style: Theme.of(
//                     context,
//                   ).textTheme.headlineSmall?.copyWith(color: Colors.white),
//                 ),
//                 const SizedBox(height: 12),
//                 const Text(
//                   'This Ataraxia remembers through you.',
//                   style: TextStyle(color: Colors.white60),
//                 ),
//                 const SizedBox(height: 24),
//                 // ─── FILE EXPORT ───
//                 ListTile(
//                   leading: const Icon(Icons.upload_rounded),
//                   title: const Text('Export identity'),
//                   subtitle: const Text('Save your Ataraxia to a file'),
//                   textColor: Colors.white,
//                   iconColor: Colors.white70,
//                   onTap: () async {
//                     Navigator.pop(context); // Close the menu

//                     // 1. Open the universal Auth Sheet
//                     final validKey = await showModalBottomSheet<String>(
//                       context: context,
//                       isScrollControlled: true,
//                       backgroundColor: Colors.transparent,
//                       builder: (_) => IdentityExportSheet(identity: identity),
//                     );

//                     // 2. If they succeeded, route to the File Warning dialog
//                     if (validKey != null && context.mounted) {
//                       showDialog(
//                         context: context,
//                         barrierColor: Colors.black.withOpacity(0.8),
//                         builder: (_) => IdentityExportWarning(
//                           identity: identity,
//                           secretKey: validKey,
//                         ),
//                       );
//                     }
//                   },
//                 ),
//                 const SizedBox(height: 16),

//                 // ─── QR EXPORT ───
//                 ListTile(
//                   leading: const Icon(Icons.qr_code_rounded),
//                   title: const Text('Transfer via QR'),
//                   textColor: Colors.white,
//                   onTap: () async {
//                     Navigator.pop(context); // Close the menu

//                     // 1. Open the EXACT SAME universal Auth Sheet
//                     final validKey = await showModalBottomSheet<String>(
//                       context: context,
//                       isScrollControlled: true,
//                       backgroundColor: Colors.transparent,
//                       builder: (_) => IdentityExportSheet(identity: identity),
//                     );

//                     // 2. If they succeeded, route to the QR Export screen
//                     if (validKey != null && context.mounted) {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           fullscreenDialog: true,
//                           builder: (_) => IdentityQrExport(
//                             identity: identity,
//                             identityKey: validKey, // Pass the verified key!
//                           ),
//                         ),
//                       );
//                     }
//                   },
//                 ),
//                 const Divider(color: Colors.white24, height: 32),
//                 ListTile(
//                   leading: const Icon(Icons.local_fire_department_rounded),
//                   title: const Text('Burn identity'),
//                   subtitle: const Text('Erase this identity everywhere'),
//                   textColor: Colors.redAccent,
//                   iconColor: Colors.redAccent,
//                   onTap: () async {
//                     Navigator.pop(sheetContext);
//                     await Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         fullscreenDialog: true,
//                         builder: (_) => IdentityBurnRitual(identity: identity),
//                       ),
//                     );
//                   },
//                 ),
//                 const SizedBox(height: 24),
//                 ListTile(
//                   leading: const Icon(Icons.logout_rounded),
//                   title: const Text('Exit Ataraxia'),
//                   subtitle: const Text('This device will forget you'),
//                   textColor: Colors.redAccent,
//                   iconColor: Colors.redAccent,
//                   onTap: () async {
//                     await IdentityStore.logout();
//                     Navigator.of(
//                       context,
//                     ).pushNamedAndRemoveUntil('/', (_) => false);
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     },
//   );
// }

void _showIdentityActions(BuildContext context, Identity identity) {
  HapticFeedback.heavyImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _PremiumIdentityMenu(identity: identity),
  );
}

// ─── THE NEW CINEMATIC IDENTITY MENU ───
class _PremiumIdentityMenu extends StatefulWidget {
  final Identity identity;
  const _PremiumIdentityMenu({required this.identity});

  @override
  State<_PremiumIdentityMenu> createState() => _PremiumIdentityMenuState();
}

class _PremiumIdentityMenuState extends State<_PremiumIdentityMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          padding: EdgeInsets.fromLTRB(
            24,
            32,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 40),

              // 2. Identity Header with Glow
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.15),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        "ANCHORED IDENTITY",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                          fontFamily: 'Courier',
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.identity.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 48 : 36,
                          fontFamily: 'Times New Roman',
                          fontStyle: FontStyle.italic,
                          height: 1.0,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // 🚀 1. THE REVEAL CIPHER BUTTON
              // Only shows up if they actually have a cipher on this device
              if (widget.identity.recoveryPhrase != null)
                _buildMenuAction(
                  index: 0,
                  icon: Icons.visibility_rounded,
                  title: "REVEAL MASTER CIPHER",
                  subtitle: "View your 12-word recovery phrase",
                  color: Colors.cyanAccent,
                  onTap: () async {
                    final nav = Navigator.of(context);
                    nav.pop(); // Close the menu

                    // Ask for their password for security
                    final validKey = await showModalBottomSheet<String>(
                      context: nav.context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          IdentityExportSheet(identity: widget.identity),
                    );

                    // Show the glowing cipher box!
                    if (validKey != null && nav.context.mounted) {
                      showDialog(
                        context: nav.context,
                        barrierColor: Colors.black.withOpacity(0.8),
                        builder: (_) => IdentityExportWarning(
                          identity: widget.identity,
                          secretKey: validKey,
                          recoveryPhrase: widget.identity.recoveryPhrase,
                        ),
                      );
                    }
                  },
                ),

              // 3. Actions (Staggered Entrance)
              _buildMenuAction(
                index: 1,
                icon: Icons.upload_rounded,
                title: "EXPORT TO FILE",
                subtitle: "Save your Ataraxia encrypted",
                color: Colors.white,
                onTap: () async {
                  // 1. Capture the Navigator so it survives the pop
                  final nav = Navigator.of(context);

                  // 2. Pop the menu
                  nav.pop();

                  // 3. Use nav.context to launch the password sheet
                  final validKey = await showModalBottomSheet<String>(
                    context: nav.context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        IdentityExportSheet(identity: widget.identity),
                  );

                  // 4. Use nav.context to verify it's still safe to proceed
                  if (validKey != null && nav.context.mounted) {
                    showDialog(
                      context: nav.context,
                      barrierColor: Colors.black.withOpacity(0.8),
                      builder: (_) => IdentityExportWarning(
                        identity: widget.identity,
                        secretKey: validKey,
                      ),
                    );
                  }
                },
              ),

              _buildMenuAction(
                index: 2,
                icon: Icons.qr_code_rounded,
                title: "TRANSFER VIA QR",
                subtitle: "Beam identity to another device",
                color: Colors.white,
                onTap: () async {
                  // 1. Capture Navigator
                  final nav = Navigator.of(context);
                  nav.pop();

                  final validKey = await showModalBottomSheet<String>(
                    context: nav.context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) =>
                        IdentityExportSheet(identity: widget.identity),
                  );

                  if (validKey != null && nav.context.mounted) {
                    // 2. Push the QR screen using the safe nav instance
                    nav.push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => IdentityQrExport(
                          identity: widget.identity,
                          identityKey: validKey,
                        ),
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              const SizedBox(height: 16),

              _buildMenuAction(
                index: 3,
                icon: Icons.logout_rounded,
                title: "SEVER CONNECTION",
                subtitle: "Exit and lock this device",
                color: Colors.redAccent.withOpacity(0.8),
                onTap: () async {
                  await IdentityStore.logout();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (_) => false);
                  }
                },
              ),

              _buildMenuAction(
                index: 4,
                icon: Icons.local_fire_department_rounded,
                title: "BURN IDENTITY",
                subtitle: "Erase everything permanently",
                color: Colors.redAccent,
                isDestructive: true,
                onTap: () async {
                  // Fix this one too just in case!
                  final nav = Navigator.of(context);
                  nav.pop();

                  await nav.push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) =>
                          IdentityBurnRitual(identity: widget.identity),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuAction({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    // Calculate stagger delay
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _animCtrl,
      curve: Interval(start, end, curve: Curves.easeOutQuint),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - anim.value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.05)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.2),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMemory extends StatelessWidget {
  const _EmptyMemory();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 64 : 32),
        child: Text(
          // 'No memories yet.\n\nThis identity has not been marked by ritual.',
          '~( ˇωˇ )~',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white38,
            // Adaptive sizing: 18px for tablet, 14px for mobile (default)
            fontSize: isTablet ? 18 : 14,
            // Higher line height for a more "poetic" look on big screens
            height: isTablet ? 1.8 : 1.6,
            letterSpacing: isTablet ? 0.5 : 0.0,
          ),
        ),
      ),
    );
  }
}
