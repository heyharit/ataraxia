import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/physics.dart';
import '../../supabase/supabase_service.dart';
import '../../utils/imagekit.dart';
import '../../data/models/moment.dart';
import '../screens/ritual_screen.dart';
import '../../utils/moment_actions.dart';
import '../../utils/moment_action_handler.dart';
import '../../data/identity_store.dart';
import '../../utils/void_signal.dart';
import '../../core/palette.dart';

class ExploreScreen extends StatefulWidget {
  final List<Moment>? preloadedMoments;

  const ExploreScreen({super.key, this.preloadedMoments});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with VoidListener {
  late final PageController _controller;
  final List<Moment> _moments = [];

  bool _isLoading = true;
  bool _isScrollLocked = false;

  // ─── INFINITE SCROLL STATE ───
  bool _isFetchingMore = false;
  int _currentOffset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1.0);
    _initializeData();
  }

  @override
  void onVoidReconnect() {
    if (widget.preloadedMoments == null || widget.preloadedMoments!.isEmpty) {
      setState(() {
        _hasMore = true;
        if (_moments.isEmpty) _isLoading = true;
      });
      _fetchNextBatch();
    }
  }

  Future<void> _initializeData() async {
    if (widget.preloadedMoments != null &&
        widget.preloadedMoments!.isNotEmpty) {
      _moments.addAll(widget.preloadedMoments!);
      _currentOffset = widget.preloadedMoments!.length;

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        _precacheImages(0);
      }
    } else {
      await _fetchNextBatch();
    }
  }

  Future<void> _fetchNextBatch() async {
    if (_isFetchingMore || !_hasMore) return;

    if (mounted) {
      setState(() {
        _isFetchingMore = true;
        if (_moments.isEmpty) _isLoading = true;
      });
    }

    try {
      final identity = await IdentityStore.active();
      List<dynamic> res;
      final bool isFirstFetch = _currentOffset == 0;

      if (identity != null) {
        res = await SupabaseService.fetchVoidFeed(
          identity.id,
          limit: 20,
          offset: _currentOffset,
        );
      } else {
        res = await SupabaseService.fetchWallpapers(
          timeOfDay: 'any',
          limit: 20,
          offset: _currentOffset,
        );
      }

      if (mounted) {
        if (res.isEmpty) {
          setState(() {
            _hasMore = false;
            _isFetchingMore = false;
            _isLoading = false;
          });
          return;
        }

        final newMoments = res.map((e) => Moment.fromJson(e)).toList();
        int addedCount = 0;

        setState(() {
          for (var newMoment in newMoments) {
            if (!_moments.any((existing) => existing.id == newMoment.id)) {
              _moments.add(newMoment);
              addedCount++;
            }
          }

          _currentOffset += res.length;
          _isLoading = false;
          _isFetchingMore = false;
        });

        if (addedCount == 0 && _hasMore) {
          _fetchNextBatch();
        } else if (isFirstFetch && addedCount > 0) {
          _precacheImages(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  void _precacheImages(int currentIndex) {
    if (_moments.isEmpty || !mounted) return;

    if (currentIndex >= _moments.length - 5 && !_isFetchingMore) {
      _fetchNextBatch();
    }

    final window = [
      math.max(0, currentIndex - 1),
      currentIndex,
      math.min(_moments.length - 1, currentIndex + 1),
      math.min(_moments.length - 1, currentIndex + 2),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (int idx in window.toSet()) {
        final url = ImageKit.original(_moments[idx].imageKey);
        precacheImage(CachedNetworkImageProvider(url), context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _PremiumExploreLoader();

    return Scaffold(
      backgroundColor: Colors.black,
      body: _moments.isEmpty
          ? const Center(
              child: Text(
                "VOID",
                style: TextStyle(
                  color: Colors.white24,
                  letterSpacing: 10,
                  fontSize: 12,
                ),
              ),
            )
          : PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              physics: _isScrollLocked
                  ? const NeverScrollableScrollPhysics()
                  : const _SnappingBouncingScrollPhysics(),
              itemCount: _moments.length + (_hasMore ? 1 : 0),
              onPageChanged: (idx) {
                HapticFeedback.selectionClick();
                if (idx < _moments.length) {
                  _precacheImages(idx);
                }
              },
              itemBuilder: (context, index) {
                if (index == _moments.length) {
                  if (!_isFetchingMore) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _fetchNextBatch(),
                    );
                  }
                  return const Scaffold(
                    backgroundColor: Colors.black,
                    body: _PremiumExploreLoader(),
                  );
                }

                final moment = _moments[index];
                return _CinematicPage(
                  controller: _controller,
                  index: index,
                  moment: moment,
                  onExit: () => Navigator.pop(context),
                  onScrollLock: (locked) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _isScrollLocked != locked) {
                        setState(() => _isScrollLocked = locked);
                      }
                    });
                  },
                );
              },
            ),
    );
  }
}

class _SnappingBouncingScrollPhysics extends BouncingScrollPhysics {
  const _SnappingBouncingScrollPhysics({super.parent});

  @override
  _SnappingBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnappingBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 0.8, stiffness: 450, damping: 32);
}

class _CinematicPage extends StatefulWidget {
  final PageController controller;
  final int index;
  final Moment moment;
  final VoidCallback onExit;
  final ValueChanged<bool> onScrollLock;

  const _CinematicPage({
    required this.controller,
    required this.index,
    required this.moment,
    required this.onExit,
    required this.onScrollLock,
  });

  @override
  State<_CinematicPage> createState() => _CinematicPageState();
}

class _CinematicPageState extends State<_CinematicPage>
    with TickerProviderStateMixin {
  late final AnimationController _focusCtrl;
  late final AnimationController _breathingCtrl;
  late final AnimationController _dialTransitionCtrl;

  // 🚀 2D MATRIX HORIZONTAL STATE
  late final PageController _hController;
  List<Moment> _relatedMoments = [];
  bool _isFetchingRelated = false;
  bool _hasFetchedRelated = false;
  int _currentHIndex = 0;

  late double _screenHeight;
  late double _screenWidth;
  late double _devicePixelRatio;

  static const bool ENABLE_HORIZONTAL = false;

  bool _saved = false;
  bool _showHeart = false;
  bool _isActive = false;
  bool _inDialMode = false;
  bool _isHolding = false;
  Timer? _dwellTimer;
  bool _hasTrackedView = false;
  String? _activeUserId;

  Offset? _doubleTapPos;
  Offset _startDragPos = Offset.zero;
  Offset _fingerPos = Offset.zero;
  final ValueNotifier<double> _dragNotifier = ValueNotifier(0.0);
  int? _hoveredMenuIndex;

  Moment get _currentMoment =>
      _currentHIndex == 0 ? widget.moment : _relatedMoments[_currentHIndex - 1];

  @override
  void initState() {
    super.initState();
    if (ENABLE_HORIZONTAL) {
      _hController = PageController();
    }

    _focusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 600),
    );

    _breathingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _dialTransitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    IdentityStore.active().then((id) {
      if (mounted && id != null) setState(() => _activeUserId = id.id);
    });

    widget.controller.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!mounted || !widget.controller.position.haveDimensions) return;
    final page = widget.controller.page ?? 0;
    final isCurrentlyActive = (page.round() == widget.index);

    if (_isActive != isCurrentlyActive) {
      setState(() => _isActive = isCurrentlyActive);

      if (_isActive) {
        if (ENABLE_HORIZONTAL) {
          _fetchRelatedWallpapers();
        }
        _startDwellTimer();
      } else {
        _dwellTimer?.cancel();
        _hasTrackedView = false;
        if (_inDialMode) _setDialMode(false);
      }
    }
  }

  Future<void> _fetchRelatedWallpapers() async {
    if (_isFetchingRelated || _hasFetchedRelated) return;
    _isFetchingRelated = true;

    final tags = widget.moment.tags.toList();
    if (tags.isEmpty) {
      if (mounted) setState(() => _hasFetchedRelated = true);
      return;
    }

    final res = await SupabaseService.fetchRelatedWallpapers(
      widget.moment.wallpaperId,
      tags,
    );

    if (mounted) {
      setState(() {
        _relatedMoments = res.map((e) => Moment.fromJson(e)).toList();
        _hasFetchedRelated = true;
        _isFetchingRelated = false;
      });
    }
  }

  void _startDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted && !_hasTrackedView && _activeUserId != null) {
        HapticFeedback.selectionClick();
        SupabaseService.trackVoidEcho(
          _activeUserId!,
          _currentMoment.wallpaperId,
          'view',
        );
        _hasTrackedView = true;
      }
    });
  }

  void _setDialMode(bool active) {
    if (_inDialMode == active) return;
    setState(() => _inDialMode = active);
    widget.onScrollLock(active);
    if (active) {
      _dialTransitionCtrl.forward();
    } else {
      _dialTransitionCtrl.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    _screenHeight = mq.size.height;
    _screenWidth = mq.size.width;
    _devicePixelRatio = mq.devicePixelRatio;
    _isActive = (widget.controller.initialPage == widget.index);
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    widget.controller.removeListener(_scrollListener);
    if (ENABLE_HORIZONTAL) {
      _hController.dispose();
    }
    _focusCtrl.dispose();
    _breathingCtrl.dispose();
    _dialTransitionCtrl.dispose();
    _dragNotifier.dispose();
    super.dispose();
  }

  void _saveAndRitual() {
    if (_saved) return;
    HapticFeedback.heavyImpact();
    _focusCtrl.reverse();
    _setDialMode(false);

    if (_activeUserId != null) {
      SupabaseService.trackVoidEcho(
        _activeUserId!,
        _currentMoment.wallpaperId,
        'ritual',
      );
    }

    setState(() {
      _saved = true;
      _showHeart = true;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showHeart = false);
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) =>
              RitualScreen(overrideMoment: _currentMoment, fromExplore: true),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ).then((_) {
        if (mounted) setState(() => _saved = false);
      });
    });
  }

  // 🚀 OPTIMIZATION 2: Pre-build the typography chunk and wrap in RepaintBoundary
  Widget _buildStaticTextContent(Moment m, bool isTablet) {
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            m.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 40 : 26,
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              height: 1.3,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 20)],
            ),
          ),
          SizedBox(height: isTablet ? 32 : 24),
          if (m.author != null)
            Text(
              m.author!.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: isTablet ? 12 : 10,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
              ),
            ),
          SizedBox(height: isTablet ? 60 : 40),
          const _HoldHint(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final totalHorizontalPages = 1 + _relatedMoments.length;

    // 🚀 OPTIMIZATION 3: Clamp memory cache to prevent OutOfMemory crashes
    final safeMemCache = math.min(
      (_screenHeight * _devicePixelRatio).toInt(),
      1200,
    );

    return PopScope(
      canPop: !_inDialMode,
      onPopInvoked: (didPop) {
        if (!didPop && _inDialMode) {
          HapticFeedback.lightImpact();
          _setDialMode(false);
        }
      },
      child: VisibilityDetector(
        key: Key('void_page_${widget.moment.id}'),
        onVisibilityChanged: (info) {
          if (!mounted) return;
          if (info.visibleFraction == 0.0) {
            if (_breathingCtrl.isAnimating) _breathingCtrl.stop();
          } else {
            if (!_breathingCtrl.isAnimating)
              _breathingCtrl.repeat(reverse: true);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            if (_inDialMode) return;
            HapticFeedback.heavyImpact();
            _focusCtrl.forward();
            _startDragPos = details.globalPosition;
            _fingerPos = details.globalPosition;
            _dragNotifier.value = 0.0;
            setState(() => _isHolding = true);
            widget.onScrollLock(true);
          },
          onLongPressMoveUpdate: (details) {
            if (_inDialMode) return;
            _fingerPos = details.globalPosition;
            _dragNotifier.value = math.max(
              0.0,
              _fingerPos.dy - _startDragPos.dy,
            );
            _checkHover(_fingerPos, _screenWidth, _screenHeight);
          },
          onLongPressCancel: () {
            if (_inDialMode) return;
            _focusCtrl.reverse();
            setState(() {
              _isHolding = false;
              _hoveredMenuIndex = null;
            });
            widget.onScrollLock(false);
            _dragNotifier.value = 0.0;
          },
          onLongPressEnd: (details) {
            if (_inDialMode) return;
            _focusCtrl.reverse();

            final enteringDial = _hoveredMenuIndex == 2;
            if (enteringDial) {
              HapticFeedback.selectionClick();
              _setDialMode(true);
            } else {
              widget.onScrollLock(false);
            }

            if (_hoveredMenuIndex == 0) {
              handleMomentAction(
                context: context,
                moment: _currentMoment,
                action: MomentAction.share,
              );
            }
            if (_hoveredMenuIndex == 1) {
              handleMomentAction(
                context: context,
                moment: _currentMoment,
                action: MomentAction.save,
              );
            }

            setState(() {
              _isHolding = false;
              _hoveredMenuIndex = null;
            });
            _dragNotifier.value = 0.0;
          },
          onDoubleTapDown: (details) => _doubleTapPos = details.localPosition,
          onDoubleTap: _saveAndRitual,

          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([
                  widget.controller,
                  _focusCtrl,
                  _breathingCtrl,
                  _dragNotifier,
                  _dialTransitionCtrl,
                ]),
                builder: (_, child) {
                  double page = widget.index.toDouble();
                  if (widget.controller.position.haveDimensions) {
                    page = widget.controller.page ?? widget.index.toDouble();
                  }

                  final delta = (widget.index - page);
                  double translateY = 0.0;
                  double scrollScale = 1.0;
                  double perspectiveTilt = 0.0;

                  if (delta < 0) {
                    translateY = delta * (_screenHeight * 0.4);
                    scrollScale = (1.0 + (delta * 0.15)).clamp(0.7, 1.0);
                    perspectiveTilt = delta * 0.25;
                  } else {
                    translateY = delta * _screenHeight;
                    scrollScale = (1.0 - (delta * 0.05)).clamp(0.9, 1.0);
                    perspectiveTilt = delta * 0.15;
                  }

                  final holdCurve = Curves.easeOutCubic.transform(
                    _focusCtrl.value,
                  );
                  final dialCurve = Curves.easeInOutCubic.transform(
                    _dialTransitionCtrl.value,
                  );

                  final pushUp =
                      math.min(_dragNotifier.value * 0.4, 60.0) * holdCurve;
                  final dialTranslateY = lerpDouble(
                    0,
                    -(_screenHeight * 0.16),
                    dialCurve,
                  )!;
                  final breatheScale = lerpDouble(
                    1.0,
                    1.04,
                    Curves.easeInOutSine.transform(_breathingCtrl.value),
                  )!;
                  final holdShrink = lerpDouble(1.0, 0.85, holdCurve)!;
                  final dialShrink = lerpDouble(
                    1.0,
                    0.59,
                    dialCurve,
                  )!; //52 check
                  final finalScale =
                      scrollScale * breatheScale * holdShrink * dialShrink;
                  final holdRadius = lerpDouble(
                    0.0,
                    isTablet ? 64.0 : 40.0,
                    math.max(holdCurve, dialCurve),
                  )!;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..translate(
                        0.0,
                        translateY - pushUp + dialTranslateY,
                        0.0,
                      )
                      ..rotateX(perspectiveTilt)
                      ..scale(finalScale),
                    child: RepaintBoundary(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(holdRadius),
                          boxShadow: [
                            if (holdCurve > 0.01 || dialCurve > 0.01)
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  math.max(holdCurve, dialCurve) * 0.9,
                                ),
                                blurRadius: 60 * math.max(holdCurve, dialCurve),
                                offset: Offset(
                                  0,
                                  30 * math.max(holdCurve, dialCurve),
                                ),
                              ),
                          ],
                        ),
                        // 🚀 OPTIMIZATION 1: The PageView is injected here via `child`, preventing full rebuilds
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(holdRadius),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                // 🚀 THE STATIC CHILD: This entire inner carousel only builds ONCE!
                child: ENABLE_HORIZONTAL
                    ? PageView.builder(
                        controller: _hController,
                        scrollDirection: Axis.horizontal,
                        physics: (_inDialMode || _isHolding)
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        itemCount: totalHorizontalPages,
                        onPageChanged: (idx) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _currentHIndex = idx;
                            _hasTrackedView = false;
                          });
                          _startDwellTimer();
                        },
                        itemBuilder: (context, hIndex) {
                          final m = hIndex == 0
                              ? widget.moment
                              : _relatedMoments[hIndex - 1];

                          final Widget staticImage = CachedNetworkImage(
                            imageUrl: ImageKit.original(m.imageKey),
                            fit: BoxFit.cover,
                            memCacheHeight: safeMemCache,
                            placeholder: (_, __) =>
                                const _PremiumImagePlaceholder(),
                            fadeInDuration: const Duration(milliseconds: 800),
                          );

                          final Widget staticText = _buildStaticTextContent(
                            m,
                            isTablet,
                          );

                          return _buildHorizontalCard(
                            staticImage,
                            staticText,
                            hIndex,
                          );
                        },
                      )
                    : Builder(
                        builder: (context) {
                          final m = widget.moment;

                          // 🚀 NEW: Calculate the parallax delta
                          double page = widget.index.toDouble();
                          if (widget.controller.position.haveDimensions) {
                            page =
                                widget.controller.page ??
                                widget.index.toDouble();
                          }
                          final delta = (widget.index - page);

                          // 🚀 NEW: Apply parallax alignment
                          final Widget staticImage = CachedNetworkImage(
                            imageUrl: ImageKit.original(m.imageKey),
                            fit: BoxFit.cover,
                            // Moves the image slightly opposite to the scroll direction
                            alignment: Alignment(0, delta * 0.4),
                            memCacheHeight: safeMemCache,
                            placeholder: (_, __) =>
                                const _PremiumImagePlaceholder(),
                            fadeInDuration: const Duration(milliseconds: 800),
                          );

                          final Widget staticText = _buildStaticTextContent(
                            m,
                            isTablet,
                          );

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              staticImage,

                              // 🚀 THE FIX: Group the atmospheric layers and text, then fade them out on hold
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutQuart,
                                opacity: _isHolding ? 0.0 : 1.0,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Cinematic Film Grain
                                    Container(
                                      color: Colors.black.withOpacity(0.05),
                                      child: BackdropFilter(
                                        filter: ImageFilter.matrix(
                                          Matrix4.identity().storage,
                                        ),
                                        blendMode: BlendMode.overlay,
                                        child: Container(
                                          color: Colors.white.withOpacity(0.02),
                                        ),
                                      ),
                                    ),

                                    const _CinematicScrim(),

                                    SafeArea(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 700,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              isTablet ? 48 : 32,
                                              0,
                                              isTablet ? 48 : 32,
                                              isTablet ? 60 : 40,
                                            ),
                                            child: staticText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              if (!_inDialMode) _buildBottomMenu(),

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
                      height: _screenHeight * 0.55,
                      child: Opacity(
                        opacity: _dialTransitionCtrl.value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, 100 * (1 - curve)),
                          child: Transform.scale(
                            scale: 0.8 + (0.2 * curve),
                            child: _RotaryDial(
                              onActionTriggered: (action) {
                                if (action == _DialAction.cancel) {
                                  HapticFeedback.lightImpact();
                                  _setDialMode(false);
                                } else if (action == _DialAction.ritual) {
                                  _saveAndRitual();
                                } else if (action == _DialAction.save) {
                                  _setDialMode(false);
                                  handleMomentAction(
                                    context: context,
                                    moment: _currentMoment,
                                    action: MomentAction.save,
                                  );
                                } else if (action == _DialAction.share) {
                                  _setDialMode(false);
                                  handleMomentAction(
                                    context: context,
                                    moment: _currentMoment,
                                    action: MomentAction.share,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (ENABLE_HORIZONTAL &&
                  _relatedMoments.isNotEmpty &&
                  !_inDialMode)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 26,
                  right: isTablet ? 32 : 24,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isHolding ? 0.0 : 1.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(totalHorizontalPages, (i) {
                        final isActive = i == _currentHIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 4,
                          width: isActive ? 16 : 4,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.cyanAccent
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withOpacity(0.5),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                        );
                      }),
                    ),
                  ),
                ),

              if (_showHeart && _doubleTapPos != null)
                Positioned(
                  left: _doubleTapPos!.dx - 100,
                  top: _doubleTapPos!.dy - 100,
                  child: const _EtherealBurst(),
                ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: isTablet ? 24 : 10,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isActive && !_inDialMode ? 1.0 : 0.0,
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withOpacity(0.5),
                      size: isTablet ? 36 : 28,
                    ),
                    onPressed: widget.onExit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkHover(Offset globalPos, double screenWidth, double screenHeight) {
    if (_dragNotifier.value < 20) {
      if (_hoveredMenuIndex != null) setState(() => _hoveredMenuIndex = null);
      return;
    }

    final shareCenter = Offset(screenWidth * 0.25, screenHeight - 120);
    final saveCenter = Offset(screenWidth * 0.50, screenHeight - 120);
    final moreCenter = Offset(screenWidth * 0.75, screenHeight - 120);

    int? closest;
    if ((globalPos - shareCenter).distance < 80) {
      closest = 0;
    } else if ((globalPos - saveCenter).distance < 80) {
      closest = 1;
    } else if ((globalPos - moreCenter).distance < 80) {
      closest = 2;
    }

    if (_hoveredMenuIndex != closest) {
      setState(() => _hoveredMenuIndex = closest);
      if (closest != null) HapticFeedback.heavyImpact();
    }
  }

  Widget _buildBottomMenu() {
    return ValueListenableBuilder<double>(
      valueListenable: _dragNotifier,
      builder: (context, dragVal, child) {
        return AnimatedBuilder(
          animation: _focusCtrl,
          builder: (context, _) {
            if (_focusCtrl.value == 0) return const SizedBox.shrink();

            final size = MediaQuery.of(context).size;
            final shareCenter = Offset(size.width * 0.25, size.height - 120);
            final saveCenter = Offset(size.width * 0.50, size.height - 120);
            final moreCenter = Offset(size.width * 0.75, size.height - 120);

            final shareReveal = ((dragVal - 10) / 60).clamp(0.0, 1.0);
            final saveReveal = ((dragVal - 15) / 60).clamp(0.0, 1.0);
            final moreReveal = ((dragVal - 20) / 60).clamp(0.0, 1.0);
            final fadeMultiplier = _focusCtrl.value;

            return Stack(
              children: [
                _buildMenuItem(
                  0,
                  Icons.ios_share_rounded,
                  "SHARE",
                  shareCenter,
                  Curves.easeOutBack.transform(shareReveal) * fadeMultiplier,
                ),
                _buildMenuItem(
                  1,
                  Icons.bookmark_add_rounded,
                  "SAVE",
                  saveCenter,
                  Curves.easeOutBack.transform(saveReveal) * fadeMultiplier,
                ),
                _buildMenuItem(
                  2,
                  Icons.more_horiz_rounded,
                  "MORE",
                  moreCenter,
                  Curves.easeOutBack.transform(moreReveal) * fadeMultiplier,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMenuItem(
    int index,
    IconData icon,
    String label,
    Offset center,
    double revealProgress,
  ) {
    if (revealProgress <= 0) return const SizedBox.shrink();

    final isHovered = _hoveredMenuIndex == index;
    Offset magneticOffset = Offset.zero;

    if (isHovered) {
      magneticOffset = Offset(
        (_fingerPos.dx - center.dx) * 0.20,
        (_fingerPos.dy - center.dy) * 0.20,
      );
    }

    final slideUpOffset = 60 * (1 - revealProgress);

    return Positioned(
      left: center.dx - 60,
      top: center.dy - 60,
      width: 120,
      child: Opacity(
        opacity: revealProgress.clamp(0.0, 1.0),
        child: TweenAnimationBuilder<Offset>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          tween: Tween<Offset>(begin: Offset.zero, end: magneticOffset),
          builder: (context, magOffset, child) {
            return Transform.translate(
              offset: Offset(magOffset.dx, slideUpOffset + magOffset.dy),
              child: Transform.scale(
                scale: isHovered ? 1.15 : (0.8 + (0.2 * revealProgress)),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isHovered
                          ? Colors.white
                          : Colors.white.withOpacity(0.08),
                      border: Border.all(
                        color: isHovered
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (isHovered)
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: isHovered ? Colors.black : Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutQuint,
                style: TextStyle(
                  color: Colors.white.withOpacity(isHovered ? 1.0 : 0.5),
                  fontSize: 10,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w900,
                  letterSpacing: isHovered ? 6.0 : 2.0,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCard(Widget image, Widget text, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        image,

        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
          opacity: _isHolding ? 0.0 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Film Grain
              Container(
                color: Colors.black.withOpacity(0.05),
                child: BackdropFilter(
                  filter: ImageFilter.matrix(Matrix4.identity().storage),
                  blendMode: BlendMode.overlay,
                  child: Container(color: Colors.white.withOpacity(0.02)),
                ),
              ),
              const _CinematicScrim(),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                      child: text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _DialAction { ritual, share, cancel, save }

class _RotaryDial extends StatefulWidget {
  final ValueChanged<_DialAction> onActionTriggered;
  const _RotaryDial({required this.onActionTriggered});
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

  final List<Map<String, dynamic>> _slots = [
    {
      'action': _DialAction.cancel,
      'icon': Icons.close_rounded,
      'label': 'CANCEL',
      'angle': -math.pi / 2.8,
    },
    {
      'action': _DialAction.ritual,
      'icon': Icons.auto_awesome,
      'label': 'RITUAL',
      'angle': -math.pi / 9,
    },
    {
      'action': _DialAction.save,
      'icon': Icons.bookmark_add_rounded,
      'label': 'SAVE',
      'angle': math.pi / 9,
    },
    {
      'action': _DialAction.share,
      'icon': Icons.ios_share_rounded,
      'label': 'SHARE',
      'angle': math.pi / 2.8,
    },
  ];

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
    const readerAngle = -math.pi / 2;
    const lockThreshold = 0.2;

    _DialAction? foundLock;
    int foundIndex = -1;

    for (int i = 0; i < _slots.length; i++) {
      double absoluteSlotAngle =
          _slots[i]['angle'] + _currentRotation - (math.pi / 2);
      absoluteSlotAngle = absoluteSlotAngle % (2 * math.pi);
      if (absoluteSlotAngle > math.pi) absoluteSlotAngle -= 2 * math.pi;

      if ((absoluteSlotAngle - readerAngle).abs() < lockThreshold) {
        foundLock = _slots[i]['action'];
        foundIndex = i;
        break;
      }
    }

    if (foundLock != _lockedAction) {
      _lockedAction = foundLock;
      if (_lockedAction != null && _lastHapticId != foundIndex) {
        HapticFeedback.heavyImpact();
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
    const readerSize = 72.0;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _currentRotation,
              child: Container(
                width: dialRadius * 2,
                height: dialRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AtaraxiaPalette.cosmicIndigo.withOpacity(0.20),
                      AtaraxiaPalette.glacialTeal.withOpacity(0.20),
                      AtaraxiaPalette.auroraViolet.withOpacity(0.20),
                      AtaraxiaPalette.cosmicIndigo.withOpacity(0.20),
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
                      final topAlignedAngle = angle - (math.pi / 2);
                      final dx = orbitRadius * math.cos(topAlignedAngle);
                      final dy = orbitRadius * math.sin(topAlignedAngle);

                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Container(
                          width: slotSize,
                          height: slotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Colors.black,
                                Colors.black87,
                                Color(0xFF111111),
                              ],
                              stops: [0.5, 0.8, 1.0],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            slot['icon'] as IconData,
                            color: Colors.white54,
                            size: 24,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
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

class _HoldHint extends StatefulWidget {
  const _HoldHint();
  @override
  State<_HoldHint> createState() => _HoldHintState();
}

class _HoldHintState extends State<_HoldHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final opacity = 0.25 + (_pulseCtrl.value * 0.45);
        return Column(
          children: [
            Container(
              height: 24,
              width: 1.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AtaraxiaPalette.glacialTeal.withOpacity(opacity),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "HOLD TO INSPECT",
              style: TextStyle(
                color: Colors.white.withOpacity(opacity),
                fontSize: 9,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: AtaraxiaPalette.glacialTeal.withOpacity(
                      opacity * 0.5,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CinematicScrim extends StatelessWidget {
  const _CinematicScrim();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.45),
              Colors.transparent,
              Colors.transparent,
              AtaraxiaPalette.voidDeep.withOpacity(0.75),
              AtaraxiaPalette.voidDeep.withOpacity(0.96),
            ],
            stops: const [0.0, 0.2, 0.5, 0.82, 1.0],
          ),
        ),
      ),
    );
  }
}

class _EtherealBurst extends StatelessWidget {
  const _EtherealBurst();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutBack,
      builder: (_, v, __) {
        final fadeOut = (1.0 - v).clamp(0.0, 1.0);
        final scaleOut = 0.5 + (v * 0.7);
        return Transform.translate(
          offset: Offset(0, -v * 60),
          child: Transform.scale(
            scale: scaleOut,
            child: Opacity(
              opacity: fadeOut,
              child: Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.15 * fadeOut),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 100,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent.withOpacity(0.8 * fadeOut),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumExploreLoader extends StatefulWidget {
  const _PremiumExploreLoader();
  @override
  State<_PremiumExploreLoader> createState() => _PremiumExploreLoaderState();
}

class _PremiumExploreLoaderState extends State<_PremiumExploreLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.3 + (_ctrl.value * 0.5),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AtaraxiaPalette.cosmicIndigo.withOpacity(
                        0.4 + _ctrl.value * 0.3,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AtaraxiaPalette.cosmicIndigo.withOpacity(
                          0.15 + _ctrl.value * 0.15,
                        ),
                        blurRadius: 30 * _ctrl.value,
                        spreadRadius: 4 * _ctrl.value,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Opacity(
                opacity: 0.3 + (_ctrl.value * 0.5),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) =>
                      AtaraxiaPalette.progressGradient.createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  ),
                  child: const Text(
                    "MANIFESTING VOID",
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PremiumImagePlaceholder extends StatelessWidget {
  const _PremiumImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141414), // Dark void grey
            Color(0xFF050505), // Pitch black
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.blur_on_rounded,
          color: Colors.white.withOpacity(0.05),
          size: 32,
        ),
      ),
    );
  }
}
