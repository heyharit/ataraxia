import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../utils/imagekit.dart';
import '../../data/models/moment.dart';
import 'explore_drawer_screen.dart';
import '../../supabase/supabase_service.dart';
import 'package:flutter/rendering.dart';
import 'locked_dimension_screen.dart';
import '../../utils/void_signal.dart';
import '../../utils/cosmic_loader.dart';

class CategoriesScreen extends StatefulWidget {
  final List<Moment> moments;

  const CategoriesScreen({super.key, required this.moments});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin, VoidListener {
  // ⬅️ CHANGED to TickerProvider
  // ─── ANIMATION & SCROLL ───
  late final AnimationController _headerCtrl;
  late final AnimationController _listCtrl;
  late List<NormalizedMoment> _normalizedMoments;
  final ScrollController _scrollController = ScrollController();

  // ─── SEARCH CONTROLLERS ───
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  // ─── DYNAMIC DATA ───
  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _displayedCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // 1. Header animates instantly as soon as screen opens (Fast 800ms)
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // 2. List waits for data, then animates in
    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _normalizedMoments = widget.moments
        .map((m) => NormalizedMoment(m))
        .toList();

    // Setup Listeners
    _searchCtrl.addListener(_onSearchChanged);
    _searchFocus.addListener(() => setState(() {}));
    _scrollController.addListener(_hideKeyboardOnScroll);

    _initializeCategories();
  }

  @override
  void onVoidReconnect() {
    setState(() => _isLoading = true);

    _initializeCategories();
  }

  void _hideKeyboardOnScroll() {
    if (_scrollController.position.userScrollDirection !=
            ScrollDirection.idle &&
        _searchFocus.hasFocus) {
      _searchFocus.unfocus();
    }
  }

  void _onSearchChanged() {
    // 1. Cancel the previous timer if the user is still typing
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 2. Start a new 300ms countdown
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchCtrl.text.toLowerCase();

      // 3. Only update state if the widget is still on screen
      if (mounted) {
        setState(() {
          _displayedCategories = _allCategories.where((c) {
            final title = c['title'].toString().toLowerCase();
            final subtitle = c['subtitle'].toString().toLowerCase();
            // 🚀 Combine all tags into one searchable string
            final tagsString = (c['tags'] as List<String>).join(' ');

            return query.isEmpty ||
                title.contains(query) ||
                subtitle.contains(query) ||
                tagsString.contains(query);
          }).toList();
        });
      }
    });
  }

  Future<void> _initializeCategories() async {
    try {
      // 1. Fetch your exact categories from your Supabase database
      final archetypes = await SupabaseService.fetchActiveArchetypes();

      // 🚀 THE FIX: THE PAGINATION TRAP
      // widget.moments only contains the wallpapers CURRENTLY loaded in the Explore feed.
      // If the user hasn't scrolled, it only has 20 items! We must fetch the COMPLETE
      // catalog from the database here so our category counts are 100% accurate.
      final res = await SupabaseService.fetchWallpapers(
        timeOfDay: 'any',
        limit: 1000, // Fetch up to 1000 to ensure we have the whole database
      );

      final allMoments = res.map((e) => Moment.fromJson(e)).toList();
      _normalizedMoments = allMoments.map((m) => NormalizedMoment(m)).toList();

      // 3. Build the categories using the full database
      _buildDynamicCategories(archetypes);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // 4. CRITICAL: Reset the animation so the cards slide up beautifully
        _listCtrl.reset();
        _listCtrl.forward();
      }
    } catch (e) {
      debugPrint("Failed to load archetypes: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildDynamicCategories(List<Map<String, dynamic>> archetypes) {
    final List<Map<String, dynamic>> compiledList = [];
    int index = 1;

    for (final arch in archetypes) {
      final targetTags = List<String>.from(
        arch['tags'] ?? [],
      ).map((t) => t.toLowerCase()).toList();

      if (targetTags.isEmpty) continue;

      // 🚀 THE MAGIC: Grab the flag from the database
      final bool matchAll = arch['match_all'] ?? false;
      final targetSet = targetTags.toSet();

      // final matchingMoments = widget.moments.where((m) {
      //   if (matchAll) {
      //     // 🔥 STRICT 'AND' LOGIC: The moment MUST satisfy EVERY tag in the array
      //     return targetTags.every((target) {
      //       return m.time.name.toLowerCase() == target ||
      //           m.type.toLowerCase() == target ||
      //           m.tags.any((tag) => tag.toLowerCase() == target);
      //     });
      //   } else {
      //     // 🌊 FLEXIBLE 'OR' LOGIC: The moment just needs ONE match (Your old logic)
      //     final timeMatch = targetTags.contains(m.time.name.toLowerCase());
      //     final typeMatch = targetTags.contains(m.type.toLowerCase());
      //     final tagMatch = m.tags.any(
      //       (tag) => targetTags.contains(tag.toLowerCase()),
      //     );

      //     return timeMatch || tagMatch || typeMatch;
      //   }
      // }).toList();

      final matchingMoments = _normalizedMoments
          .where((m) {
            if (matchAll) {
              return targetSet.every((target) {
                return m.time == target ||
                    m.type == target ||
                    m.tags.contains(target);
              });
            } else {
              return targetSet.contains(m.time) ||
                  targetSet.contains(m.type) ||
                  m.tags.any(targetSet.contains);
            }
          })
          .map((m) => m.original)
          .toList();

      if (matchingMoments.isEmpty) continue;

      matchingMoments.shuffle();
      final coverImageKey = matchingMoments.first.imageKey;

      compiledList.add({
        'id': index.toString().padLeft(2, '0'),
        'title': arch['title'],
        'tags': targetTags,
        'subtitle': arch['subtitle'],
        'count': matchingMoments.length.toString(),
        'imageKey': coverImageKey,
        'matchingMoments': matchingMoments,
      });

      index++;
    }

    _allCategories = compiledList;
    _displayedCategories = List.from(_allCategories);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _headerCtrl.dispose();
    _listCtrl.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─── SEARCH WIDGET ───
  Widget _buildOmniSearch() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _searchFocus.hasFocus
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                hintText: 'Search collections...',
                hintStyle: TextStyle(
                  color: Colors.white24,
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                _searchFocus.unfocus();
              },
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withOpacity(0.4),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),

          // ⬅️ NO LONGER BLOCKED BY IF (_ISLOADING)
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // ─── HEADER (RENDERS INSTANTLY) ───
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isTablet ? 0 : 28,
                          60,
                          isTablet ? 0 : 28,
                          30,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _GlassBackButton(
                                  onTap: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 24),
                                Container(
                                  width: 30,
                                  height: 1,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedBuilder(
                                    animation: _headerCtrl,
                                    builder: (context, child) {
                                      return Opacity(
                                        opacity: _headerCtrl.value,
                                        child: child,
                                      );
                                    },
                                    child: Text(
                                      "ARCHETYPE COLLECTIONS",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 3.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            AnimatedBuilder(
                              animation: _headerCtrl,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: Curves.easeIn.transform(
                                    _headerCtrl.value,
                                  ),
                                  child: Transform.translate(
                                    offset: Offset(
                                      0,
                                      20 * (1 - _headerCtrl.value),
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                "Choose your\nfrequency.",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Serif',
                                  fontSize: isTablet ? 72 : 52,
                                  height: 0.95,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -2.0,
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // SEARCH BAR
                            AnimatedBuilder(
                              animation: _headerCtrl,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _headerCtrl.value,
                                  child: child,
                                );
                              },
                              child: _buildOmniSearch(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── THE LOADING/LIST STATE ───
                    if (_isLoading)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CosmicLoaderWidget(),
                              const SizedBox(height: 30),
                              Text(
                                "CALIBRATING ARCHETYPES",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 10,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_displayedCategories.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            "NO FREQUENCIES FOUND",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 11,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final data = _displayedCategories[index];

                            final start = (index * 0.1).clamp(0.0, 1.0);
                            final end = (start + 0.4).clamp(0.0, 1.0);
                            final itemAnim = CurvedAnimation(
                              parent: _listCtrl, // ⬅️ NOW USES LIST CONTROLLER
                              curve: Interval(
                                start,
                                end,
                                curve: Curves.easeOutQuint,
                              ),
                            );

                            return RepaintBoundary(
                              child: _SlideInItem(
                                animation: itemAnim,
                                child: _InteractiveCategoryCard(
                                  key: ValueKey(data['id']),
                                  data: data,
                                  moments: widget.moments,
                                  isTablet: isTablet,
                                  allCategories: _displayedCategories,
                                ),
                              ),
                            );
                          }, childCount: _displayedCategories.length),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── COMPONENT: THE INTERACTIVE CARD (UPGRADED PHYSICS) ───

class _InteractiveCategoryCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<Moment> moments;
  final bool isTablet;
  final List<Map<String, dynamic>> allCategories;

  const _InteractiveCategoryCard({
    super.key,
    required this.data,
    required this.moments,
    required this.isTablet,
    required this.allCategories,
  });

  @override
  State<_InteractiveCategoryCard> createState() =>
      _InteractiveCategoryCardState();
}

class _InteractiveCategoryCardState extends State<_InteractiveCategoryCard>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();

    // 1. Tactile Push Down
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 400),
    );

    // 2. Light Sweep Flare
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 3. Ambient Continuous Breathing (Ken Burns)
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _burstCtrl.dispose();
    _breathCtrl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.heavyImpact();
    _scaleCtrl.forward();
  }

  void _handleTapCancel() {
    _scaleCtrl.reverse();
  }

  void _handleTapUp(TapUpDetails details) async {
    HapticFeedback.lightImpact();
    _scaleCtrl.reverse();
    _burstCtrl.forward(from: 0.0);

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    // 🚀 THE GATEKEEPER: Time-Locked Logic
    final title = widget.data['title'].toString().toUpperCase();

    if (title == "THE WITCHING HOUR") {
      final int currentHour = DateTime.now().hour;

      // DateTime.hour returns military time (0 to 23).
      // 0 = 12:00 AM, 1 = 1:00 AM, 2 = 2:00 AM.
      // If it is 3 or higher, the dimension is locked.
      if (currentHour >= 3 && currentHour < 24) {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, __, ___) => const LockedDimensionScreen(),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutCubic,
                ),
                child: child,
              );
            },
          ),
        );
        return; // 🛑 ABORT NAVIGATION TO THE ARCHIVE
      }
    }

    // If it's a normal collection, OR if it's the Witching Hour and the time is right:
    // Proceed normally into the dimension.
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => ExploreDrawerScreen(
          moments: widget.data['matchingMoments'],
          customTitle: widget.data['title'],
          categoriesData: widget.allCategories,
        ),
        transitionsBuilder: (_, anim, __, child) {
          const curve = Curves.easeOutQuart;
          var tween = Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(position: anim.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cacheWidth = (mq.size.width * mq.devicePixelRatio).toInt();

    return VisibilityDetector(
      key: Key('category_${widget.data['id']}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;

        if (info.visibleFraction == 0.0) {
          // 🛑 OFF-SCREEN: Stop the heavy breathing animation to save RAM
          if (_breathCtrl.isAnimating) _breathCtrl.stop();
        } else {
          // ▶️ ON-SCREEN: Resume the animation if it was stopped
          if (!_breathCtrl.isAnimating) _breathCtrl.repeat(reverse: true);
        }
      },

      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) {
          // Compress deeply on tap
          final scale = 1.0 - (_scaleCtrl.value * 0.04);
          // Pull shadow tight when compressed
          final shadowBlur = widget.isTablet ? 50.0 : 30.0;
          final shadowOffset = widget.isTablet ? 20.0 : 15.0;

          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: Container(
                height: widget.isTablet ? 420 : 340,
                margin: EdgeInsets.symmetric(
                  horizontal: widget.isTablet ? 0 : 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: const Color(0xFF111111),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        0.6 - (_scaleCtrl.value * 0.3),
                      ),
                      blurRadius: shadowBlur - (_scaleCtrl.value * 15),
                      offset: Offset(0, shadowOffset - (_scaleCtrl.value * 10)),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. BREATHING IMAGE (OPTIMIZED RAM)
                    AnimatedBuilder(
                      animation: _breathCtrl,
                      builder: (_, child) {
                        final breathe =
                            1.0 +
                            (Curves.easeInOutSine.transform(_breathCtrl.value) *
                                0.12);
                        return Transform.scale(scale: breathe, child: child);
                      },
                      child: CachedNetworkImage(
                        imageUrl: ImageKit.constrainedWidth(
                          path: widget.data['imageKey'],
                          width: 800,
                        ),
                        fit: BoxFit.cover,
                        memCacheWidth: cacheWidth > 2000 ? 2000 : cacheWidth,
                        fadeInDuration: const Duration(milliseconds: 800),
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFF1A1A1A)),
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFF1A1A1A)),
                      ),
                    ),

                    // 2. CINEMATIC GRADIENT
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black54,
                            Colors.black,
                          ],
                          stops: [0.0, 0.4, 0.75, 1.0],
                        ),
                      ),
                    ),

                    // 3. THE LIGHT BURST FLARE (On Release)
                    AnimatedBuilder(
                      animation: _burstCtrl,
                      builder: (_, __) {
                        if (_burstCtrl.value == 0 || _burstCtrl.value == 1)
                          return const SizedBox.shrink();

                        final v = Curves.easeOutQuart.transform(
                          _burstCtrl.value,
                        );
                        final sweep = (v * 2.5) - 0.5;
                        final fade = 1.0 - Curves.easeIn.transform(v);

                        return Opacity(
                          opacity: fade,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.6),
                                  Colors.cyanAccent.withOpacity(0.7),
                                  Colors.white.withOpacity(0.6),
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
                        );
                      },
                    ),

                    // 4. TEXT CONTENT & LAYOUT
                    Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOP ROW: ID and Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.data['id'],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Courier',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              _GlassBadge(count: widget.data['count']),
                            ],
                          ),

                          // BOTTOM CONTENT
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.data['title'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.isTablet ? 56 : 42,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  height: 1.0,
                                  shadows: const [
                                    Shadow(color: Colors.black, blurRadius: 20),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    width: 2,
                                    height: widget.isTablet ? 46 : 38,
                                    color: Colors.cyanAccent.withOpacity(
                                      0.8,
                                    ), // Premium highlight
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      widget.data['subtitle'],
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontFamily: 'Serif',
                                        fontSize: widget.isTablet ? 20 : 16,
                                        fontStyle: FontStyle.italic,
                                        height: 1.25,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black87,
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── PREMIUM UI ASSETS ───

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.6),
          radius: 1.6,
          colors: [Color(0xFF1F1F1F), Color(0xFF000000)],
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final String count;
  const _GlassBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Text(
            "$count VOLS",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GlassBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(
              Icons
                  .arrow_upward_rounded, // Replaced with semantic backward arrow below if desired, but kept original design
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── HIGH PERFORMANCE ENTRY ANIMATION ───
// Centralized controller prevents the "Future.delayed memory leak" issue.

class _SlideInItem extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _SlideInItem({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(
              0,
              80 * (1 - animation.value),
            ), // Dramatic cinematic sweep up
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class NormalizedMoment {
  final Moment original;
  final String time;
  final String type;
  final Set<String> tags;

  NormalizedMoment(this.original)
    : time = original.time.name.toLowerCase(),
      type = original.type.toLowerCase(),
      tags = original.tags.map((t) => t.toLowerCase()).toSet();
}
