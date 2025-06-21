import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../data/models/moment.dart';
import '../../utils/wallpaper_helper.dart';
import '../../ritual/wallpaper_intent_sheet.dart';
import '../../ritual/streak_manager.dart';
import '../../ritual/seasonal_tint.dart';
import '../../data/identity_store.dart';
import '../screens/memory_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/dashboard_screen.dart';
import '../../ritual/daily_ritual_manager.dart';
import '../../supabase/supabase_service.dart';
import '../identity/identity_gate.dart';
import '../../utils/imagekit.dart';
import '../screens/explore_drawer_screen.dart';
import '../../settings/ambient_ritual_screen.dart';
import '../screens/categories_screen.dart';
import '../../utils/axiom_gate.dart';
import '../../utils/cinematic_toast.dart';
import '../../core/palette.dart';
import '../screens/onboarding_overlay.dart';

enum RitualHoldState { idle, holding, armed }

enum SwipeDirection { left, right, up, down }

enum GestureMode { none, swipe, hold }

enum _DialAction {
  cancel,
  memory,
  ambient,
  sanctuary,
  library,
  pure,
} // 🚀 New Dial Actions

class RitualScreen extends StatefulWidget {
  final Moment? overrideMoment;
  final ImageProvider? preloadedImage;
  final bool fromExplore;

  const RitualScreen({
    super.key,
    this.overrideMoment,
    this.preloadedImage,
    this.fromExplore = false,
  });

  @override
  State<RitualScreen> createState() => _RitualScreenState();
}

class _RitualScreenState extends State<RitualScreen>
    with TickerProviderStateMixin {
  // --- Animation Controllers ---
  late final AnimationController _entryController;
  late final AnimationController _breathController;
  late final AnimationController _exhaleController;
  late final AnimationController _swipeController;
  late final AnimationController _idleDriftController;
  late final AnimationController _gateController;
  late final AnimationController _dialTransitionCtrl; // 🚀 New Dial Controller

  // --- Animations ---
  late final Animation<double> _textFadeAnim;
  late final Animation<double> _exhaleScaleAnim;
  late final Animation<double> _gateLetterSpacing;
  late final Animation<double> _gateOpacity;

  // --- State Notifiers ---
  final ValueNotifier<Offset> _gyroNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<Offset> _panNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<Offset> _holdOffsetNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _breathValue = ValueNotifier(0.0);

  StreamSubscription? _gyroSubscription;

  // --- Logic State ---
  bool _isApplying = false;
  Moment? moment;
  ImageProvider? _wallpaperProvider;
  bool _autoArmed = false;
  bool _cancelled = false;
  bool _confirmed = false;
  bool _isStreakActive = false;
  bool _pureMode = false;
  bool _wallpaperSet = false;
  bool _showGate = true;
  bool _inDialMode = false; // 🚀 Replaces _showOverlayActions

  List<Moment> _wallpapers = [];
  RitualHoldState _holdState = RitualHoldState.idle;

  // --- Gesture Physics ---
  Offset? _longPressOrigin;
  Offset _panStart = Offset.zero;
  SwipeDirection? _lockedDirection;
  double _panAxisValue = 0.0;
  double _springStart = 0.0;
  GestureMode _gestureMode = GestureMode.none;

  bool get _gyroActive =>
      _gestureMode != GestureMode.swipe && !_isApplying && !_inDialMode;

  @override
  void initState() {
    super.initState();
    _showGate = widget.overrideMoment == null;
    if (_showGate) _initializeGateAnimations();
    _initializeData();
    _initializeAnimations();
    _setupGyroscope();
  }

  void _setupGyroscope() {
    try {
      _gyroSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
        if (!mounted || !_gyroActive) return;

        final current = _gyroNotifier.value;
        double newX = ((current.dx * 0.85) + (event.y * 0.15)) * 0.98;
        double newY = ((current.dy * 0.85) + (event.x * 0.15)) * 0.98;

        if ((newX - current.dx).abs() > 0.002 ||
            (newY - current.dy).abs() > 0.002) {
          _gyroNotifier.value = Offset(
            newX.clamp(-2.0, 2.0),
            newY.clamp(-2.0, 2.0),
          );
        }
      });
    } catch (e) {
      _gyroNotifier.value = Offset.zero;
    }
  }

  void _initializeGateAnimations() {
    _gateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _gateLetterSpacing = Tween<double>(begin: 2.0, end: 12.0).animate(
      CurvedAnimation(parent: _gateController, curve: Curves.easeOutQuart),
    );
    _gateOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_gateController);
    _gateController.forward();
  }

  void _initializeData() {
    if (widget.overrideMoment != null) {
      moment = widget.overrideMoment;
      _autoArmed = widget.fromExplore;
      _preloadImage(moment!);
    } else {
      DailyRitualManager.loadTodayMoment().then((m) {
        if (!mounted) return;
        setState(() => moment = m);
        _preloadImage(m);
      });
    }
    _loadBackgroundData();
  }

  void _loadBackgroundData() async {
    StreakManager.isContinuingStreak().then((v) {
      if (mounted) setState(() => _isStreakActive = v);
    });

    final identity = await IdentityStore.active();
    List<Map<String, dynamic>> res;

    if (identity != null) {
      res = await SupabaseService.fetchVoidFeed(identity.id, limit: 50);
    } else {
      res = await SupabaseService.fetchWallpapers(timeOfDay: 'any');
    }

    if (!mounted) return;
    final list = res.map((e) => Moment.fromJson(e)).toList();
    if (list.isNotEmpty) {
      precacheImage(
        CachedNetworkImageProvider(ImageKit.original(list[0].imageKey)),
        context,
      );
    }
    setState(() => _wallpapers = list);
  }

  void _preloadImage(Moment m) {
    final provider = ResizeImage(
      CachedNetworkImageProvider(ImageKit.original(m.imageKey)),
      width: 1080,
      policy: ResizeImagePolicy.fit,
    );
    provider
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((info, _) {
            if (mounted) setState(() => _wallpaperProvider = provider);
          }),
        );
  }

  void _initializeAnimations() {
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _exhaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _idleDriftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    // 🚀 NEW: The controller for the dial bloom
    _dialTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textFadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _exhaleScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_exhaleController);

    _setupAnimationListeners();
    _entryController.forward();

    // 🌟 Show onboarding on very first launch (after entry animation settles)
    if (widget.overrideMoment == null) {
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted) showOnboardingIfNeeded(context);
      });
    }
  }

  void _setupAnimationListeners() {
    _breathController.addListener(() {
      _breathValue.value = holdCharge;

      if (_holdState != RitualHoldState.holding || _cancelled) return;

      final current = _breathController.value;
      if ((current * 100).toInt() % 15 == 0 && current < 0.2) {
        HapticFeedback.selectionClick();
      }
      if (current >= 0.25 && _holdState != RitualHoldState.armed) {
        setState(() => _holdState = RitualHoldState.armed);
        HapticFeedback.mediumImpact();
      }
    });

    _swipeController.addListener(() {
      if (_lockedDirection == null) return;
      final value = _swipeController.value * _springStart;
      double dx = 0, dy = 0;

      if (_lockedDirection == SwipeDirection.left ||
          _lockedDirection == SwipeDirection.right) {
        dx = value;
      } else {
        dy = value;
      }
      _panNotifier.value = Offset(dx, dy);

      if (_swipeController.isCompleted || _swipeController.value == 0.0) {
        _resetGesture();
      }
    });
  }

  @override
  void dispose() {
    _gyroSubscription?.cancel();
    _gyroNotifier.dispose();
    _panNotifier.dispose();
    _holdOffsetNotifier.dispose();
    _breathValue.dispose();
    if (_showGate) _gateController.dispose();
    _entryController.dispose();
    _swipeController.dispose();
    _breathController.dispose();
    _exhaleController.dispose();
    _idleDriftController.dispose();
    _dialTransitionCtrl.dispose(); // 🚀 Dispose the new dial
    super.dispose();
  }

  double get holdCharge => _holdState == RitualHoldState.armed
      ? 1.0
      : (_holdState != RitualHoldState.holding
            ? 0.0
            : Curves.easeOutCubic.transform(
                (_breathController.value * 1.5).clamp(0.0, 1.0),
              ));

  // 🚀 TOGGLES THE ROTARY ENGINE
  void _setDialMode(bool active) {
    if (_inDialMode == active) return;
    HapticFeedback.selectionClick();
    setState(() => _inDialMode = active);
    if (active) {
      _dialTransitionCtrl.forward();
    } else {
      _dialTransitionCtrl.reverse();
    }
  }

  // --- GESTURE & NAVIGATION ---
  void _onPanStart(DragStartDetails d) {
    if (_inDialMode) return; // 🚀 Block swipes if dial is open
    if (_holdState == RitualHoldState.idle) {
      _gestureMode = GestureMode.swipe;
      _swipeController.stop();
      _panStart = d.globalPosition;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_gestureMode != GestureMode.swipe || _inDialMode) return;
    final delta = d.globalPosition - _panStart;

    if (_lockedDirection == null &&
        (delta.dx.abs() > 5 || delta.dy.abs() > 5)) {
      if (delta.dx.abs() > delta.dy.abs()) {
        _lockedDirection = delta.dx > 0
            ? SwipeDirection.right
            : SwipeDirection.left;
      } else {
        _lockedDirection = delta.dy > 0
            ? SwipeDirection.down
            : SwipeDirection.up;
      }
    }

    if (_lockedDirection == null) return;

    double rawVal =
        (_lockedDirection == SwipeDirection.left ||
            _lockedDirection == SwipeDirection.right)
        ? delta.dx
        : delta.dy;

    _panAxisValue = _resistance(rawVal);
    _panNotifier.value =
        (_lockedDirection == SwipeDirection.left ||
            _lockedDirection == SwipeDirection.right)
        ? Offset(_panAxisValue, 0)
        : Offset(0, _panAxisValue);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_inDialMode || _lockedDirection == null) {
      _resetGesture();
      return;
    }

    double velocity =
        (_lockedDirection == SwipeDirection.left ||
            _lockedDirection == SwipeDirection.right)
        ? d.velocity.pixelsPerSecond.dx
        : d.velocity.pixelsPerSecond.dy;

    final screenSize = MediaQuery.of(context).size;
    final dimension =
        (_lockedDirection == SwipeDirection.left ||
            _lockedDirection == SwipeDirection.right)
        ? screenSize.width
        : screenSize.height;

    double projection = _panAxisValue + (velocity * 0.35);

    if (velocity.abs() > 600 || projection.abs() > (dimension * 0.20)) {
      _commitSwipe();
    } else {
      _springBack(velocity, dimension);
    }
  }

  void _springBack(double velocity, double dimension) {
    _springStart = _panAxisValue;
    _swipeController.stop();
    _swipeController.value = 1.0;

    _swipeController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1.2, stiffness: 600, damping: 42),
        1.0,
        0.0,
        (velocity / dimension).clamp(-15.0, 15.0),
      ),
    );
  }

  double _resistance(double v) {
    const double limit = 120.0;
    if (v.abs() <= limit) return v;
    return v.sign * (limit + (60 * math.log(1 + ((v.abs() - limit) / 60))));
  }

  void _commitSwipe() {
    if (_lockedDirection == SwipeDirection.left) {
      _openDashboard();
    } else if (_lockedDirection == SwipeDirection.right) {
      _openMemories();
    } else if (_lockedDirection == SwipeDirection.up) {
      final screenWidth = MediaQuery.of(context).size.width;
      if (_panStart.dx < screenWidth / 2) {
        _openExploreDrawer();
      } else {
        _openExploreScreen();
      }
    } else if (_lockedDirection == SwipeDirection.down) {
      _openCategories();
    }
    _resetGesture();
  }

  void _resetGesture() {
    _gestureMode = GestureMode.none;
    _lockedDirection = null;
    _panNotifier.value = Offset.zero;
    _panAxisValue = 0.0;
    _holdOffsetNotifier.value = Offset.zero;
  }

  void _forceStopSwipe() {
    _swipeController.stop();
    _resetGesture();
  }

  // --- NAVIGATION ---
  void _openDashboard() => Navigator.push(
    context,
    _createRoute(const DashboardScreen(), true, true),
  );
  void _openExploreDrawer({bool autoFocusSearch = false}) {
    Navigator.of(context).push(
      _createVerticalRoute(
        ExploreDrawerScreen(
          moments: _wallpapers,
          autoFocusSearch: autoFocusSearch,
        ),
        fromBottom: true,
        opaque: false,
      ),
    );
  }

  void _openCategories() {
    Navigator.of(context).push(
      _createVerticalRoute(
        CategoriesScreen(moments: _wallpapers),
        fromBottom: false,
        opaque: true,
      ),
    );
  }

  void _openExploreScreen() => Navigator.push(
    context,
    _createDiagonalRoute(
      ExploreScreen(
        preloadedMoments: _wallpapers.isNotEmpty ? _wallpapers : null,
      ),
      const Offset(1.0, 1.0), // from bottom-right
    ),
  );
  void _openMemories() =>
      Navigator.push(context, _createRoute(const MemoryScreen(), false, true));
  void _openAmbientRitual() => Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const AmbientRitualScreen(),
    ),
  );

  Route _createDiagonalRoute(Widget page, Offset beginOffset) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 550),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slideAnim = Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutExpo));
        final scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
        );
        final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );
        return SlideTransition(
          position: slideAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: FadeTransition(opacity: fadeAnim, child: child),
          ),
        );
      },
    );
  }

  Route _createRoute(Widget page, bool fromRight, bool horizontal) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 550),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slideAnim =
            Tween<Offset>(
              begin: horizontal
                  ? Offset(fromRight ? 1.0 : -1.0, 0.0)
                  : Offset(0.0, fromRight ? 1.0 : -1.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
            );
        final scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
        );
        final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );
        return SlideTransition(
          position: slideAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: FadeTransition(opacity: fadeAnim, child: child),
          ),
        );
      },
    );
  }

  Route _createVerticalRoute(
    Widget page, {
    required bool fromBottom,
    bool opaque = true,
  }) {
    return PageRouteBuilder(
      opaque: opaque,
      transitionDuration: const Duration(milliseconds: 550),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final slideAnim =
            Tween<Offset>(
              begin: Offset(0.0, fromBottom ? 1.0 : -1.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
            );
        final scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutExpo),
        );
        final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );
        return SlideTransition(
          position: slideAnim,
          child: ScaleTransition(
            scale: scaleAnim,
            child: FadeTransition(opacity: fadeAnim, child: child),
          ),
        );
      },
    );
  }

  // --- RITUAL LOGIC (Long Press) ---
  void _onLongPressStart(LongPressStartDetails d) {
    if (_inDialMode) return; // 🚀 Block holds if dial is open
    _forceStopSwipe();
    _gestureMode = GestureMode.hold;
    _wallpaperSet = false;
    _cancelled = false;
    _longPressOrigin = d.globalPosition;
    _holdOffsetNotifier.value = d.globalPosition;

    setState(() => _holdState = RitualHoldState.holding);
    HapticFeedback.lightImpact();
    _breathController.repeat(reverse: true);
  }

  Future<void> _onLongPressEnd(LongPressEndDetails _) async {
    if (_gestureMode != GestureMode.hold || _cancelled) {
      _resetToIdle();
      return;
    }
    _breathController.stop();
    _breathController.reset();

    if (!(_holdState == RitualHoldState.armed ||
        (_autoArmed && !_wallpaperSet))) {
      HapticFeedback.selectionClick();
      _resetToIdle();
      return;
    }

    HapticFeedback.heavyImpact();

    final result = await showModalBottomSheet<WallpaperConfig>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WallpaperIntentSheet(moment: moment!),
    );

    if (result == null) {
      _resetToIdle();
      return;
    }
    await _executeRitual(result);
    _resetGesture();
  }

  Future<void> _executeRitual(WallpaperConfig result) async {
    final m = moment!;
    final identity = await IdentityStore.active();

    // 🚀 GHOST PROTOCOL (Not Logged In)
    if (identity == null) {
      final ghostAppliesLeft = await IdentityStore.getGhostApplies();

      if (ghostAppliesLeft <= 0) {
        // 🚀 THE FIX: Summon the gorgeous Ad-or-Login wall
        if (mounted) {
          _resetToIdle();
          AxiomGate.showGhostWall(context);
        }
        return;
      }

      // It's a free ghost apply, just decrement
      await IdentityStore.decrementGhostApplies();
      if (mounted) {
        showCinematicToast(
          context,
          "GHOST ESSENCE: ${ghostAppliesLeft - 1} REMAINING",
        );
      }
    } else {
      // 🚀 AXIOM PROTOCOL (Logged In)
      final isInMemory = await SupabaseService.isMomentInMemory(
        identity.id,
        m.wallpaperId,
      );

      if (!isInMemory) {
        final cost = (m.isParallax || m.is360) ? 8 : 3;
        final confirmed = await AxiomGate.requestToll(
          context: context,
          title: "APPLY FREQUENCY",
          description:
              "Anchor this frequency to your device and permanently etch it into your Memory.",
          cost: cost,
          actionLabel: "ANCHOR",
        );
        if (!confirmed) {
          _resetToIdle();
          return;
        }
      } else {
        if (mounted) showCinematicToast(context, "RECALLED FROM MEMORY");
      }
    }

    // ─── If they pass the gates, proceed with the actual application! ───
    try {
      await _shieldAndFreeze();
      await _applyWallpaperFlow(m, result);

      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await _handleIdentityAndStreak(m);

      SupabaseService.emitRitualEcho();
      _exhaleController.forward(from: 0.0);
    } finally {
      if (mounted) setState(() => _isApplying = false);
      _setupGyroscope();

      if (mounted) setState(() => _confirmed = true);

      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => _confirmed = false);
    }
  }

  Future<void> _shieldAndFreeze() async {
    if (mounted) {
      setState(() {
        _isApplying = true;
        _holdState = RitualHoldState.idle;
        _autoArmed = false;
      });
    }
    await _gyroSubscription?.cancel();
    _gyroSubscription = null;
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _applyWallpaperFlow(Moment m, WallpaperConfig result) async {
    if ((m.isParallax || m.is360) &&
        result.variant == WallpaperVariant.immersive) {
      await WallpaperHelper.setSacredWallpaper(m);
    } else {
      final size = MediaQuery.of(context).size;
      String imageUrl = result.variant == WallpaperVariant.immersive
          ? ImageKit.original(m.imageKey)
          : ImageKit.cropped(
              path: m.imageKey,
              width: size.width,
              height: size.height,
            );

      final file = await WallpaperHelper.downloadImage(
        imageUrl,
        "${m.id}_static",
      );

      int flag = (result.location == WallpaperLocation.lock)
          ? WallpaperHelper.FLAG_LOCK
          : (result.location == WallpaperLocation.both
                ? WallpaperHelper.FLAG_BOTH
                : WallpaperHelper.FLAG_SYSTEM);

      await WallpaperHelper.setWallpaperFromFile(file.path, location: flag);
    }
  }

  Future<void> _handleIdentityAndStreak(Moment m) async {
    var identity = await IdentityStore.active();
    if (identity == null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              IdentityGate(onAuthenticated: () => Navigator.pop(context)),
        ),
      );
    }
    identity = await IdentityStore.active();
    if (identity != null) {
      SupabaseService.recordMemoryEvent(
        userId: identity.id,
        wallpaperId: m.wallpaperId,
        ritualDate: DateTime.now(),
      );
      StreakManager.markCompletedToday(identity.id);
    }
  }

  void _resetToIdle() {
    if (mounted) {
      setState(() {
        _holdState = RitualHoldState.idle;
        _autoArmed = false;
      });
    }
    _resetGesture();
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_inDialMode) {
          HapticFeedback.lightImpact();
          _setDialMode(false);
          return false; // Close dial instead of popping route
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AtaraxiaPalette.voidDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (!_isApplying)
              _showGate
                  ? AnimatedBuilder(
                      animation: _gateController,
                      builder: (_, __) => _buildGateStack(),
                    )
                  : _buildMainContent(),
            if (_isApplying) _buildApplyingOverlay(),
            if (_confirmed) _buildConfirmedOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildGateStack() {
    final bool gateVisible = _gateController.value < 0.95;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: (_wallpaperProvider != null && moment != null) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 2500),
          curve: Curves.easeOutCubic,
          child: _buildMainContent(),
        ),
        if (gateVisible)
          IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(_gateOpacity.value),
              alignment: Alignment.center,
              child: Opacity(
                opacity: _gateOpacity.value,
                child: Text(
                  "A T A R A X I A",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 32 : 14,
                    fontWeight: FontWeight.w200,
                    letterSpacing: isTablet
                        ? _gateLetterSpacing.value * 2.5
                        : _gateLetterSpacing.value,
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 20 + (_gateController.value * 40),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMainContent() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 🚀 THE SINGLE TAP TRIGGER
        if (_inDialMode) {
          _setDialMode(false);
        } else {
          _setDialMode(true);
        }
      },
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _forceStopSwipe,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressMoveUpdate: (details) {
        _holdOffsetNotifier.value = details.globalPosition;
        if (_longPressOrigin != null &&
            (details.globalPosition - _longPressOrigin!).distance > 80 &&
            !_cancelled) {
          _cancelled = true;
          _breathController.reset();
          setState(() => _holdState = RitualHoldState.idle);
          HapticFeedback.heavyImpact();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. WALLPAPER STACK (UPGRADED 3D GESTURE PHYSICS + DIAL COMPRESSION)
          ValueListenableBuilder<Offset>(
            valueListenable: _panNotifier,
            builder: (context, panOffset, child) {
              if (panOffset == Offset.zero && !_inDialMode) return child!;

              final screen = MediaQuery.of(context).size;
              final dragPercent = (panOffset.distance / screen.width).clamp(
                0.0,
                1.0,
              );

              // Base pushback from swipe
              final scale = 1.0 - (dragPercent * 0.20);
              final rotationX = (-panOffset.dy * 0.0012).clamp(-0.35, 0.35);
              final rotationY = (panOffset.dx * 0.0012).clamp(-0.35, 0.35);

              // 🚀 If the Dial is open, compress the image backward smoothly
              return AnimatedBuilder(
                animation: _dialTransitionCtrl,
                builder: (context, _) {
                  final dialCurve = Curves.easeInOutCubic.transform(
                    _dialTransitionCtrl.value,
                  );
                  final dialShrink = lerpDouble(1.0, 0.8, dialCurve)!;
                  final dialTranslateY = lerpDouble(
                    0,
                    -(screen.height * 0.18),
                    dialCurve,
                  )!;

                  final finalScale = scale * dialShrink;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..translate(panOffset.dx, panOffset.dy + dialTranslateY)
                      ..rotateX(rotationX)
                      ..rotateY(rotationY)
                      ..scale(finalScale),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        (dragPercent * 60) + (dialCurve * 40),
                      ),
                      child: child,
                    ),
                  );
                },
              );
            },
            child: _buildParallaxStack(),
          ),

          // 2. OVERLAYS & VIGNETTES
          if (!_pureMode) ...[
            if (_isStreakActive)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: 0.08,
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Colors.white, Colors.transparent],
                        radius: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.black45,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            if (!_pureMode)
              ValueListenableBuilder<double>(
                valueListenable: _breathValue,
                builder: (_, charge, __) => _RitualVignette(charge),
              ),
          ],

          // 3. TEXT CONTENT (Fades out when dial opens)
          if (!_pureMode && moment != null)
            AnimatedBuilder(
              animation: _dialTransitionCtrl,
              builder: (context, child) {
                final fade = 1.0 - _dialTransitionCtrl.value;
                return Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -40 * _dialTransitionCtrl.value),
                    child: child,
                  ),
                );
              },
              child: ValueListenableBuilder<Offset>(
                valueListenable: _panNotifier,
                builder: (context, pan, child) =>
                    Transform.translate(offset: pan, child: child),
                child: RepaintBoundary(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FadeTransition(
                      opacity: _textFadeAnim,
                      child: _buildQuoteBlock(),
                    ),
                  ),
                ),
              ),
            ),

          // 🚀 4. THE ROTARY ENGINE
          if (_inDialMode)
            AnimatedBuilder(
              animation: _dialTransitionCtrl,
              builder: (context, child) {
                final curve = Curves.easeOutBack.transform(
                  _dialTransitionCtrl.value,
                );
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: Opacity(
                    opacity: _dialTransitionCtrl.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 100 * (1 - curve)),
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * curve),
                        child: _RotaryDial(
                          isPureMode: _pureMode,
                          onActionTriggered: (action) {
                            _setDialMode(false);
                            if (action == _DialAction.cancel) {
                              // Handled by _setDialMode
                            } else if (action == _DialAction.sanctuary) {
                              _openDashboard();
                            } else if (action == _DialAction.library) {
                              _openExploreDrawer();
                            } else if (action == _DialAction.memory) {
                              _openMemories();
                            } else if (action == _DialAction.pure) {
                              setState(() => _pureMode = !_pureMode);
                            } else if (action == _DialAction.ambient) {
                              _openAmbientRitual();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildParallaxStack() {
    if (moment == null) return const SizedBox.shrink();
    final m = moment!;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _exhaleController,
        _breathValue,
        _idleDriftController,
      ]),
      builder: (context, child) {
        double scale = _exhaleController.isAnimating
            ? _exhaleScaleAnim.value
            : (_holdState == RitualHoldState.holding
                  ? lerpDouble(1.0, 1.15, _breathValue.value)!
                  : 1.05);

        return Transform.scale(
          scale: scale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ParallaxLayer(
                imageKey: m.imageKey,
                depth: 0.2,
                momentId: m.id,
                gyroNotifier: _gyroNotifier,
                idleAnim: _idleDriftController,
                isHeroBaseLayer: true,
              ),
              if (m.isParallax && m.midLayerKey != null)
                _ParallaxLayer(
                  imageKey: m.midLayerKey!,
                  depth: 0.6,
                  momentId: m.id,
                  gyroNotifier: _gyroNotifier,
                  idleAnim: _idleDriftController,
                ),
              if (m.isParallax && m.foreLayerKey != null)
                _ParallaxLayer(
                  imageKey: m.foreLayerKey!,
                  depth: 1.2,
                  momentId: m.id,
                  gyroNotifier: _gyroNotifier,
                  idleAnim: _idleDriftController,
                ),
              if (!_pureMode)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColorFiltered(
                      colorFilter: SeasonalTint.filter(),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuoteBlock() {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isTablet ? 180 : 120,
        left: isTablet ? size.width * 0.15 : 30,
        right: isTablet ? size.width * 0.15 : 30,
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: _breathValue,
        builder: (context, charge, child) {
          return ValueListenableBuilder<Offset>(
            valueListenable: _holdOffsetNotifier,
            builder: (context, holdPos, child) {
              final scalePull = 1.0 - (0.05 * charge);
              Offset pull = holdPos == Offset.zero
                  ? Offset.zero
                  : Offset(
                      (holdPos.dx - MediaQuery.of(context).size.width / 2) *
                          0.02 *
                          charge,
                      (holdPos.dy - MediaQuery.of(context).size.height / 2) *
                          0.02 *
                          charge,
                    );
              return Transform.translate(
                offset: pull,
                child: Transform.scale(scale: scalePull, child: child),
              );
            },
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (moment!.isParallax || moment!.is360)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
                child: Text(
                  moment!.is360 ? "PORTAL / 360" : "SACRED / 3D",
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 8,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              moment!.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Times New Roman',
                fontStyle: FontStyle.italic,
                fontSize: isTablet ? 56 : 32,
                height: 1.05,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
            if (moment!.author != null) ...[
              const SizedBox(height: 15),
              Text(
                "— ${moment!.author!.toUpperCase()} —",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isTablet ? 14 : 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(height: isTablet ? 60 : 40),
            _buildHoldHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldHint() {
    String text = (_holdState == RitualHoldState.idle)
        ? (widget.fromExplore ? 'HOLD TO SET' : 'HOLD TO FOCUS')
        : (_autoArmed
              ? 'RELEASE'
              : (_holdState == RitualHoldState.holding
                    ? 'BREATHE'
                    : 'RELEASE'));

    final bool isIdle = _holdState == RitualHoldState.idle;
    final bool isArmed = _holdState == RitualHoldState.armed;

    return AnimatedOpacity(
      opacity: isIdle ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isArmed
              ? LinearGradient(
                  colors: [
                    AtaraxiaPalette.auroraViolet.withOpacity(0.25),
                    AtaraxiaPalette.glacialTeal.withOpacity(0.15),
                  ],
                )
              : null,
          color: isArmed ? null : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: isArmed
                ? AtaraxiaPalette.glacialTeal.withOpacity(0.5)
                : Colors.white.withOpacity(isIdle ? 0.08 : 0.2),
            width: 1,
          ),
          boxShadow: isArmed
              ? [
                  BoxShadow(
                    color: AtaraxiaPalette.glacialTeal.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isArmed ? AtaraxiaPalette.glacialTeal : Colors.white,
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.bold,
            shadows: isArmed
                ? [
                    Shadow(
                      color: AtaraxiaPalette.glacialTeal.withOpacity(0.6),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildApplyingOverlay() => Container(
    color: Colors.black,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white24, strokeWidth: 1),
        const SizedBox(height: 20),
        const Text(
          "TRANSCENDING",
          style: TextStyle(
            color: Colors.white30,
            fontSize: 10,
            letterSpacing: 5,
          ),
        ),
      ],
    ),
  );

  Widget _buildConfirmedOverlay() => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2000),
      builder: (_, val, __) {
        double opacity = val < 0.2
            ? (val * 5)
            : (val > 0.8 ? ((1 - val) * 5) : 1.0);
        return Container(
          color: Colors.black.withOpacity(opacity * 0.4),
          alignment: Alignment.center,
          child: Opacity(
            opacity: opacity,
            child: const Text(
              "IT IS DONE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 14,
                fontWeight: FontWeight.w400,
                shadows: [Shadow(color: Colors.white54, blurRadius: 24)],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ─── THE ROTARY ENGINE ───
class _RotaryDial extends StatefulWidget {
  final bool isPureMode;
  final ValueChanged<_DialAction> onActionTriggered;

  const _RotaryDial({
    required this.isPureMode,
    required this.onActionTriggered,
  });

  @override
  State<_RotaryDial> createState() => _RotaryDialState();
}

class _RotaryDialState extends State<_RotaryDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _springCtrl;

  double _currentRotation = 0.0;
  double _dragStartAngle = 0.0;
  double _rotationOffsetAtStart = 0.0;

  _DialAction? _lockedAction;
  int _lastHapticId = -1;

  // 🚀 THE MATH FIX: Perfectly spread 6 items across 240 degrees over the top
  List<Map<String, dynamic>> get _slots {
    final actions = [
      _DialAction.cancel,
      _DialAction.memory,
      _DialAction.ambient,
      _DialAction.sanctuary,
      _DialAction.library,
      _DialAction.pure,
    ];

    final icons = [
      Icons.close_rounded,
      Icons.history,
      Icons.waves,
      Icons.tune_rounded,
      Icons.grid_view,
      widget.isPureMode ? Icons.visibility : Icons.visibility_off,
    ];

    final labels = [
      'DISMISS',
      'MEMORY',
      'RITUAL',
      'SANCTUARY',
      'LIBRARY',
      widget.isPureMode ? 'SHOW' : 'HIDE',
    ];

    const int n = 6;
    // -210 degrees (left side) to +30 degrees (right side).
    // The top center of the circle is exactly -90 degrees (-math.pi / 2).
    final double startAngle = -math.pi * 7 / 6;
    final double endAngle = math.pi * 1 / 6;
    final double step = (endAngle - startAngle) / (n - 1);

    return List.generate(n, (i) {
      return {
        'action': actions[i],
        'icon': icons[i],
        'label': labels[i],
        'angle': startAngle + (step * i),
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController(vsync: this);
    _springCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentRotation = _springCtrl.value;
        _checkLocks();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkLocks();
    });
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _springCtrl.stop();
    final box = context.findRenderObject() as RenderBox;
    final center = box.size.center(Offset.zero);
    final localPos = box.globalToLocal(details.globalPosition);

    _dragStartAngle = math.atan2(
      localPos.dy - center.dy,
      localPos.dx - center.dx,
    );
    _rotationOffsetAtStart = _currentRotation;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final center = box.size.center(Offset.zero);
    final localPos = box.globalToLocal(details.globalPosition);

    final currentAngle = math.atan2(
      localPos.dy - center.dy,
      localPos.dx - center.dx,
    );
    double delta = currentAngle - _dragStartAngle;

    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;

    setState(() {
      _currentRotation = _rotationOffsetAtStart + delta;
      _checkLocks();
    });
  }

  void _checkLocks() {
    if (!mounted) return;
    const readerAngle = -math.pi / 2; // Top center is always -90 degrees
    const lockThreshold = 0.25; // Radians to trigger the snap (~14 degrees)

    _DialAction? foundLock;
    int foundIndex = -1;
    final currentSlots = _slots;

    for (int i = 0; i < currentSlots.length; i++) {
      // Find the slot's absolute position on screen right now
      double absoluteAngle = currentSlots[i]['angle'] + _currentRotation;
      double normAngle = absoluteAngle % (2 * math.pi);
      if (normAngle > math.pi) normAngle -= 2 * math.pi;
      if (normAngle < -math.pi) normAngle += 2 * math.pi;

      if ((normAngle - readerAngle).abs() < lockThreshold) {
        foundLock = currentSlots[i]['action'];
        foundIndex = i;
        break;
      }
    }

    if (foundLock != _lockedAction) {
      _lockedAction = foundLock;
      if (_lockedAction != null && _lastHapticId != foundIndex) {
        HapticFeedback.heavyImpact(); // Deep click when locked in
        _lastHapticId = foundIndex;
      }
    }

    if (_lockedAction == null) _lastHapticId = -1;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_lockedAction != null) {
      HapticFeedback.selectionClick();
      widget.onActionTriggered(_lockedAction!);
    }

    final spring = SpringDescription(mass: 1, stiffness: 200, damping: 15);
    final sim = SpringSimulation(
      spring,
      _currentRotation,
      0.0,
      details.velocity.pixelsPerSecond.dx * 0.01,
    );
    _springCtrl.animateWith(sim);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    final dialRadius = isTablet ? 180.0 : 130.0;
    final orbitRadius = dialRadius * 0.65;
    final blur = _lockedAction != null ? 1.0 : 0.0;
    const slotSize = 60.0;
    const readerSize = 70.0;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. THE ROTARY WHEEL BASE
            Transform.rotate(
              angle: _currentRotation,
              child: Container(
                width: dialRadius * 2,
                height: dialRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AtaraxiaPalette.cosmicIndigo.withOpacity(0.12),
                      AtaraxiaPalette.glacialTeal.withOpacity(0.15),
                      AtaraxiaPalette.auroraViolet.withOpacity(0.12),
                      AtaraxiaPalette.cosmicIndigo.withOpacity(0.12),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 40),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(dialRadius * 2, dialRadius * 2),
                      painter: _DialTickPainter(),
                    ),
                    ..._slots.map((slot) {
                      final angle = slot['angle'] as double;

                      // Base placement
                      final dx = orbitRadius * math.cos(angle);
                      final dy = orbitRadius * math.sin(angle);

                      // 🚀 PROXIMITY BLOOMING MATH
                      // Calculate how close this icon is to the top reader
                      double absoluteAngle = angle + _currentRotation;
                      double normAngle = absoluteAngle % (2 * math.pi);
                      if (normAngle > math.pi) normAngle -= 2 * math.pi;
                      if (normAngle < -math.pi) normAngle += 2 * math.pi;

                      double distToTop = (normAngle - (-math.pi / 2)).abs();
                      // Creates a smoothly scaling value from 0.0 (far away) to 1.0 (dead center)
                      double focusFactor = Curves.easeOutQuart.transform(
                        (1.0 - (distToTop / 0.35)).clamp(0.0, 1.0),
                      );

                      final double dynamicScale =
                          (isTablet ? 1.1 : 0.9) + (0.35 * focusFactor);
                      final double finalSize = slotSize * dynamicScale;

                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          // 🚀 COUNTER-ROTATION: Keeps the icons standing perfectly vertical while spinning
                          angle: -_currentRotation,
                          child: Container(
                            width: finalSize,
                            height: finalSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.lerp(
                                const Color(0xFF111111),
                                Colors.black,
                                focusFactor,
                              ),
                              border: Border.all(
                                color: Color.lerp(
                                  Colors.white.withOpacity(0.1),
                                  Colors.cyanAccent.withOpacity(0.8),
                                  focusFactor,
                                )!,
                                width: 1 + (1.5 * focusFactor),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(
                                    0.4 * focusFactor,
                                  ),
                                  blurRadius: 20 * focusFactor,
                                  spreadRadius: 2 * focusFactor,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 4,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              slot['icon'] as IconData,
                              color: Color.lerp(
                                Colors.white54,
                                Colors.cyanAccent,
                                focusFactor,
                              ),
                              size: 24 + (4 * focusFactor),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // 2. THE TOP INPUT READER
            Transform.translate(
              offset: Offset(0, -orbitRadius),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: readerSize,
                    height: readerSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _lockedAction != null
                          ? Colors.white.withOpacity(0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color: _lockedAction != null
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        width: _lockedAction != null ? 3 : 1.5,
                      ),
                      boxShadow: [
                        if (_lockedAction != null)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. CENTRAL HUB LABEL
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: Colors.white10, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, blurRadius: 20),
                ],
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _lockedAction == null ? 1.0 : 0.0,
                    child: const Icon(
                      Icons.blur_circular,
                      color: Colors.white24,
                      size: 30,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _lockedAction != null ? 1.0 : 0.0,
                    child: _lockedAction != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _slots.firstWhere(
                                  (s) => s['action'] == _lockedAction,
                                )['label'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "RELEASE",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 8,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final thickPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final angle = (i * 2 * math.pi) / 60;
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;
      final innerRadius = radius - 4 - tickLength;
      final outerRadius = radius - 4;

      final p1 = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, isMajor ? thickPaint : paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- OPTIMIZED SUB-COMPONENTS ---
class _RitualVignette extends StatelessWidget {
  final double charge;
  const _RitualVignette(this.charge);

  @override
  Widget build(BuildContext context) {
    if (charge == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: Opacity(
          opacity: charge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Violet inner glow
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.6,
                    colors: [
                      AtaraxiaPalette.auroraViolet.withOpacity(
                        0.15 * charge,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // White rim
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      Colors.transparent,
                      AtaraxiaPalette.glacialTeal.withOpacity(
                        0.06 * charge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParallaxLayer extends StatelessWidget {
  final String imageKey;
  final double depth;
  final String momentId;
  final ValueNotifier<Offset> gyroNotifier;
  final AnimationController idleAnim;
  final bool isHeroBaseLayer;

  const _ParallaxLayer({
    required this.imageKey,
    required this.depth,
    required this.momentId,
    required this.gyroNotifier,
    required this.idleAnim,
    this.isHeroBaseLayer = false,
  });

  @override
  Widget build(BuildContext context) {
    final double bleedScale = 1.0 + (depth * 0.08);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([gyroNotifier, idleAnim]),
        builder: (context, child) {
          final gyro = gyroNotifier.value;
          final double driftX =
              math.sin(idleAnim.value * math.pi * 2) * 5 * depth;
          final double driftY =
              math.cos(idleAnim.value * math.pi * 4) * 3 * depth;
          final double dx = (gyro.dx * 26 * depth) + driftX;
          final double dy = (gyro.dy * 26 * depth) + driftY;

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(scale: bleedScale, child: child),
          );
        },
        child: _buildImage(context),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cacheHeight = isHeroBaseLayer
        ? (mq.size.height * mq.devicePixelRatio).toInt()
        : (mq.size.height * mq.devicePixelRatio * 0.5).toInt();

    Widget img = CachedNetworkImage(
      imageUrl: ImageKit.original(imageKey),
      fit: BoxFit.cover,
      memCacheHeight: cacheHeight,
      placeholder: (_, __) => isHeroBaseLayer
          ? Container(color: Colors.black)
          : const SizedBox.shrink(),
      fadeInDuration: const Duration(milliseconds: 1200),
    );

    if (isHeroBaseLayer) {
      return Hero(
        tag: 'moment_hero_$momentId',
        flightShuttleBuilder:
            (flightContext, animation, direction, fromContext, toContext) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(
                    24 * (1 - animation.value),
                  ),
                  child: img,
                ),
              );
            },
        child: img,
      );
    }
    return img;
  }
}
