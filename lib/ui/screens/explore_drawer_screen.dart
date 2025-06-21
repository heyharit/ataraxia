import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/physics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/moment_action_handler.dart';
import '../../utils/moment_actions.dart';
import '../screens/explore_screen.dart';
import '../../data/models/moment.dart';
import '../../data/models/custom_collection.dart';
import '../../utils/imagekit.dart';
import '../../supabase/supabase_service.dart';
import '../../utils/cinematic_toast.dart';
import '../../data/identity_store.dart';
import '../../utils/void_signal.dart';
import '../../utils/cosmic_loader.dart';

// ─── ROUTING ARCHITECTURE ───
enum DrawerMode { ritual, archive, category }

class _DrawerTab {
  final String id;
  final String title;
  final bool isCollection;
  final bool isCategory;
  final List<Moment>? preloadedMoments;

  _DrawerTab({
    required this.id,
    required this.title,
    required this.isCollection,
    required this.isCategory,
    this.preloadedMoments,
  });
}

// ─── MAIN SCREEN ───
class ExploreDrawerScreen extends StatefulWidget {
  final List<Moment> moments;
  final bool autoFocusSearch;
  final String? customTitle;
  final String? collectionId;
  final List<CustomCollection>? userCollections;
  final List<Map<String, dynamic>>? categoriesData;

  const ExploreDrawerScreen({
    super.key,
    required this.moments,
    this.autoFocusSearch = false,
    this.customTitle,
    this.collectionId,
    this.userCollections,
    this.categoriesData,
  });

  @override
  State<ExploreDrawerScreen> createState() => _ExploreDrawerScreenState();
}

class _ExploreDrawerScreenState extends State<ExploreDrawerScreen>
    with VoidListener {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late PageController _pageController;

  // 🚀 HIGH-PERFORMANCE DECOUPLED STATE
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier("");
  final ValueNotifier<bool> _isHeaderHidden = ValueNotifier<bool>(false);
  final ValueNotifier<List<Moment>> _activeMomentsNotifier = ValueNotifier([]);
  final Map<int, List<Moment>> _tabMomentsCache = {};

  late DrawerMode _mode;
  List<_DrawerTab> _tabs = [];
  int _currentIndex = 0;
  int _crossAxisCount = 2;
  late List<GlobalKey> _pillKeys;

  @override
  void initState() {
    super.initState();
    _loadLayoutPreference();
    _determineModeAndBuildTabs();
    _setupControllers();
  }

  @override
  void onVoidReconnect() {
    // If the internet dropped before we could load the user's archives, fetch them now!
    if (_mode == DrawerMode.ritual && _tabs.length <= 1) {
      _fetchCollectionsForExplore();
    }
  }

  void _determineModeAndBuildTabs() {
    // 1. CATEGORY MODE (Filters out Witching Hour if it's locked)
    if (widget.categoriesData != null && widget.categoriesData!.isNotEmpty) {
      _mode = DrawerMode.category;
      final int currentHour = DateTime.now().hour;
      final bool isWitchingHourLocked = currentHour >= 3 && currentHour < 24;

      final visibleCategories = widget.categoriesData!.where((c) {
        final title = c['title'].toString().toUpperCase();
        if (title == "THE WITCHING HOUR" && isWitchingHourLocked) return false;
        return true;
      }).toList();

      _tabs = visibleCategories
          .map(
            (c) => _DrawerTab(
              id: c['title'],
              title: c['title'],
              isCollection: false,
              isCategory: true,
              preloadedMoments: c['matchingMoments'],
            ),
          )
          .toList();
      _currentIndex = _tabs.indexWhere(
        (t) => t.title.toLowerCase() == widget.customTitle?.toLowerCase(),
      );
    }
    // 2. ARCHIVE MODE (Viewing Personal Collections)
    else if (widget.userCollections != null &&
        widget.userCollections!.isNotEmpty) {
      _mode = DrawerMode.archive;
      _tabs = widget.userCollections!
          .map(
            (c) => _DrawerTab(
              id: c.id,
              title: c.name,
              isCollection: true,
              isCategory: false,
            ),
          )
          .toList();
      _currentIndex = _tabs.indexWhere((t) => t.id == widget.collectionId);
    }
    // 3. RITUAL MODE (The default "All" view + Archives)
    else {
      _mode = DrawerMode.ritual;
      _tabs = [
        _DrawerTab(
          id: 'All',
          title: 'All',
          isCollection: false,
          isCategory: false,
        ),
      ];
      _currentIndex = 0;
      _fetchCollectionsForExplore();
    }

    if (_currentIndex == -1) _currentIndex = 0;
    _pillKeys = List.generate(_tabs.length, (_) => GlobalKey());
  }

  void _setupControllers() {
    _pageController = PageController(initialPage: _currentIndex);
    _searchCtrl.addListener(
      () => _searchQueryNotifier.value = _searchCtrl.text,
    );

    if (widget.autoFocusSearch) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _searchFocus.requestFocus();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToActivePill(_currentIndex),
    );
  }

  Future<void> _fetchCollectionsForExplore() async {
    try {
      final identity = await IdentityStore.active();
      if (identity == null) return;
      final collections = await SupabaseService.fetchUserCollections(
        identity.id,
      );

      if (collections.isNotEmpty && mounted) {
        setState(() {
          _tabs.addAll(
            collections.map(
              (c) => _DrawerTab(
                id: c.id,
                title: c.name,
                isCollection: true,
                isCategory: false,
              ),
            ),
          );
          _pillKeys = List.generate(_tabs.length, (_) => GlobalKey());
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLayoutPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => _crossAxisCount = prefs.getInt('explore_columns') ?? 2);
  }

  Future<void> _toggleLayout() async {
    HapticFeedback.lightImpact();
    setState(() => _crossAxisCount = _crossAxisCount == 2 ? 3 : 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('explore_columns', _crossAxisCount);
  }

  void _scrollToActivePill(int index) {
    if (index < 0 || index >= _pillKeys.length) return;
    final context = _pillKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _pageController.dispose();
    _isHeaderHidden.dispose();
    _searchQueryNotifier.dispose();
    _activeMomentsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is UserScrollNotification &&
              notification.metrics.axis == Axis.vertical) {
            final direction = notification.direction;
            if (direction == ScrollDirection.reverse &&
                !_isHeaderHidden.value) {
              _isHeaderHidden.value = true;
              if (_searchFocus.hasFocus) _searchFocus.unfocus();
            } else if (direction == ScrollDirection.forward &&
                _isHeaderHidden.value) {
              _isHeaderHidden.value = false;
            }
          }
          return false;
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  _isHeaderHidden.value = false;
                  HapticFeedback.lightImpact();
                  setState(() => _currentIndex = index);
                  _scrollToActivePill(index);

                  // Update Play Button
                  if (_tabMomentsCache.containsKey(index)) {
                    _activeMomentsNotifier.value = _tabMomentsCache[index]!;
                  }
                },
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  return _MasonryTabview(
                    tab: _tabs[index],
                    baseMoments: widget.moments,
                    searchNotifier: _searchQueryNotifier,
                    crossAxisCount: _crossAxisCount,
                    isActive: _currentIndex == index,
                    onMomentsFiltered: (moments) {
                      _tabMomentsCache[index] = moments;
                      if (_currentIndex == index && mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _activeMomentsNotifier.value = moments;
                        });
                      }
                    },
                  );
                },
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isHeaderHidden,
                builder: (context, isHidden, child) {
                  return AnimatedSlide(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    offset: isHidden ? const Offset(0, -1) : Offset.zero,
                    child: child,
                  );
                },
                child: _buildFloatingHeader(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHeader() {
    String titleText = _tabs.isNotEmpty
        ? _tabs[_currentIndex].title.toUpperCase()
        : "EXPLORE";
    if (_mode == DrawerMode.archive) titleText = "ARCHIVE";

    return Container(
      // 🚀 THE FIX: A pure, heavy gradient fade instead of a GPU-heavy BackdropFilter.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 0.8, 1.0],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 24, // Added padding to smooth the fade transition
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF111111,
                ), // Solid dark background for the pill
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _searchFocus.hasFocus
                      ? Colors.cyanAccent.withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  // Subtle premium drop shadow behind the search bar
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                      cursorColor: Colors.cyanAccent,
                      decoration: InputDecoration(
                        hintText: 'SEARCH $titleText...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                    ),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  GestureDetector(
                    onTap: _toggleLayout,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.transparent,
                      child: Icon(
                        _crossAxisCount == 2
                            ? Icons.grid_view_rounded
                            : Icons.grid_on_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<List<Moment>>(
                    valueListenable: _activeMomentsNotifier,
                    builder: (context, moments, child) {
                      if (moments.isEmpty) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 1,
                            height: 20,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: const Duration(
                                    milliseconds: 700,
                                  ),
                                  pageBuilder: (_, __, ___) =>
                                      ExploreScreen(preloadedMoments: moments),
                                  transitionsBuilder: (_, anim, __, child) =>
                                      FadeTransition(
                                        opacity: CurvedAnimation(
                                          parent: anim,
                                          curve: Curves.easeOut,
                                        ),
                                        child: child,
                                      ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 6, right: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.12),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_tabs.length > 1) ...[
            const SizedBox(height: 16),
            _buildMoodSelector(),
          ] else ...[
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        cacheExtent: 2000,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          return _MoodPill(
            key: _pillKeys[i],
            label: _tabs[i].title,
            isSelected: _currentIndex == i,
            onTap: () {
              if (_currentIndex != i) {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ─── DECOUPLED TAB VIEW (Fixes Swipe Lag) ───
class _MasonryTabview extends StatefulWidget {
  final _DrawerTab tab;
  final List<Moment> baseMoments;
  final ValueNotifier<String> searchNotifier;
  final int crossAxisCount;
  final bool isActive;
  final ValueChanged<List<Moment>> onMomentsFiltered;

  const _MasonryTabview({
    required this.tab,
    required this.baseMoments,
    required this.searchNotifier,
    required this.crossAxisCount,
    required this.isActive,
    required this.onMomentsFiltered,
  });

  @override
  State<_MasonryTabview> createState() => _MasonryTabviewState();
}

class _MasonryTabviewState extends State<_MasonryTabview>
    with AutomaticKeepAliveClientMixin, VoidListener {
  List<Moment> _rawMoments = [];
  List<Moment> _filteredMoments = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  int _currentOffset = 0;
  final int _limit = 40;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void onVoidReconnect() {
    if (_rawMoments.isEmpty) {
      _initData();
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      // 🚀 CLEANED UP: The scroll listener NOW ONLY cares about infinite scrolling.
      // No more messy negative pixel math!
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        _fetchMoreData();
      }
    });
    _initData();

    widget.searchNotifier.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _applySearch();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    widget.searchNotifier.removeListener(_onSearchChanged);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MasonryTabview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive && widget.tab.isCollection) {
      _silentRefresh();
    }
  }

  Future<void> _fetchMoreData() async {
    if (_isFetchingMore ||
        !_hasMore ||
        widget.tab.isCollection ||
        widget.tab.isCategory)
      return;

    setState(() => _isFetchingMore = true);

    try {
      final identity = await IdentityStore.active();
      List<dynamic> res;

      if (identity != null) {
        res = await SupabaseService.fetchVoidFeed(
          identity.id,
          limit: _limit,
          offset: _currentOffset,
        );
      } else {
        res = await SupabaseService.fetchWallpapers(
          timeOfDay: 'any',
          limit: _limit,
          offset: _currentOffset,
        );
      }

      if (mounted) {
        if (res.isEmpty) {
          setState(() {
            _hasMore = false;
            _isFetchingMore = false;
          });
          return;
        }

        final newMoments = res.map((e) => Moment.fromJson(e)).toList();
        int addedCount = 0;

        setState(() {
          for (var newMoment in newMoments) {
            if (!_rawMoments.any((existing) => existing.id == newMoment.id)) {
              _rawMoments.add(newMoment);
              addedCount++;
            }
          }
          _currentOffset += res.length;

          if (res.length < _limit) _hasMore = false;
          _isFetchingMore = false;
        });

        _applySearch();

        if (addedCount == 0 && _hasMore) {
          _fetchMoreData();
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch more of the Void: $e");
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final res = await SupabaseService.fetchMomentsInCollection(widget.tab.id);
      if (mounted && res.length != _rawMoments.length) {
        setState(() {
          _rawMoments = res;
          _applySearch();
        });
      }
    } catch (_) {}
  }

  Future<void> _initData({bool forceRefresh = false}) async {
    if (_rawMoments.isNotEmpty && !forceRefresh) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 🚀 FIXED: Actually clear the old data so it doesn't duplicate on refresh!
    if (forceRefresh) {
      _rawMoments.clear();
      _filteredMoments.clear();
    }

    try {
      if (widget.tab.isCollection) {
        _rawMoments = await SupabaseService.fetchMomentsInCollection(
          widget.tab.id,
        );
      } else if (widget.tab.isCategory && widget.tab.preloadedMoments != null) {
        _rawMoments = List.from(widget.tab.preloadedMoments!);
      } else {
        final identity = await IdentityStore.active();
        List<dynamic> res;

        _currentOffset = 0;
        _hasMore = true;

        if (identity != null) {
          res = await SupabaseService.fetchVoidFeed(
            identity.id,
            limit: _limit,
            offset: _currentOffset,
          );
        } else {
          res = await SupabaseService.fetchWallpapers(
            timeOfDay: 'any',
            limit: _limit,
            offset: _currentOffset,
          );
        }
        _rawMoments = res.map((e) => Moment.fromJson(e)).toList();

        _currentOffset = res.length;
        if (res.length < _limit) _hasMore = false;
      }
    } catch (e) {
      debugPrint("Fetch failed: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _applySearch();
    }
  }

  void _applySearch() {
    final query = widget.searchNotifier.value.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMoments = List.from(_rawMoments);
      } else {
        _filteredMoments = _rawMoments
            .where(
              (m) =>
                  m.title.toLowerCase().contains(query) ||
                  m.quote.toLowerCase().contains(query) ||
                  (m.author?.toLowerCase().contains(query) ?? false) ||
                  m.tags.any((t) => t.toLowerCase().contains(query)),
            )
            .toList();
      }
    });
    widget.onMomentsFiltered(_filteredMoments);
  }

  void _removeMomentFromArchive(Moment m) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _filteredMoments.removeWhere((item) => item.id == m.id);
      _rawMoments.removeWhere((item) => item.id == m.id);
    });
    widget.onMomentsFiltered(_filteredMoments);

    try {
      await SupabaseService.removeMomentFromCollection(
        widget.tab.id,
        m.wallpaperId,
      );
      if (mounted) showCinematicToast(context, "SEVERED FROM DIMENSION");
    } catch (e) {
      debugPrint("Failed to remove: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading && _rawMoments.isEmpty) {
      return const CosmicLoaderWidget();
    }

    if (_filteredMoments.isEmpty) return _buildFadeInEmptyState();

    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // This dynamically scales the grid for tablets (2->3, 3->4)
    final currentColumns = isTablet
        ? (widget.crossAxisCount + 1)
        : widget.crossAxisCount;

    final isDense = widget.crossAxisCount > 2;

    return MasonryGridView.count(
      controller: _scrollController,
      key: PageStorageKey('grid_${widget.tab.id}_$currentColumns'),
      crossAxisCount: currentColumns,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top + 130,
        8,
        MediaQuery.of(context).padding.bottom + 40,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredMoments.length + (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredMoments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.cyanAccent,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        final m = _filteredMoments[index];
        return HeroMode(
          enabled: widget.isActive,
          // 🚀 THE FIX: Removed RepaintBoundary. Let the framework breathe.
          child: _LibraryCard(
            key: ValueKey('card_${widget.tab.id}_${m.id}'),
            moment: m,
            collectionId: widget.tab.isCollection ? widget.tab.id : null,
            onRemove: widget.tab.isCollection
                ? () => _removeMomentFromArchive(m)
                : null,
            isDense: isDense,
          ),
        );
      },
    );
  }

  Widget _buildFadeInEmptyState() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wind_power_outlined,
                    color: Colors.white.withOpacity(0.05),
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "THE VOID IS SILENT",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.15),
                      letterSpacing: 8,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── MICRO COMPONENTS ───
class _MoodPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontFamily: 'Courier',
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                letterSpacing: 2.0,
                shadows: isSelected
                    ? [
                        Shadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 4,
              width: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.8),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryCard extends StatefulWidget {
  final Moment moment;
  final String? collectionId;
  final VoidCallback? onRemove;
  final bool isDense;

  const _LibraryCard({
    super.key,
    required this.moment,
    this.collectionId,
    this.onRemove,
    this.isDense = false,
  });

  @override
  State<_LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<_LibraryCard> {
  DragMenuController? _dragController;

  @override
  Widget build(BuildContext context) {
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final int cacheWidth = (200 * pixelRatio).round();

    return _SpringScaleButton(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (context.mounted)
          handleMomentAction(
            context: context,
            moment: widget.moment,
            action: MomentAction.ritual,
          );
      },
      onLongPressStart: (details) {
        HapticFeedback.heavyImpact();
        final renderBox = context.findRenderObject() as RenderBox;
        final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
        _dragController = DragMenuController(
          context: context,
          moment: widget.moment,
          collectionId: widget.collectionId,
          onRemove: widget.onRemove,
          sourceRect: rect,
        );
        _dragController?.show(details.globalPosition);
      },
      onLongPressMoveUpdate: (details) =>
          _dragController?.updateFinger(details.globalPosition),
      onLongPressEnd: (details) {
        _dragController?.release();
        _dragController = null;
      },
      onLongPressCancel: () {
        _dragController?.cancel();
        _dragController = null;
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.isDense ? 12 : 18),
          color: const Color(0xFF080808),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Hero(
              tag: 'moment_hero_${widget.moment.id}',
              child: CachedNetworkImage(
                imageUrl: ImageKit.constrainedWidth(
                  path: widget.moment.imageKey,
                  width: widget.isDense ? 300 : 500,
                ),
                memCacheWidth: cacheWidth,
                width: double.infinity,
                fit: BoxFit.cover,
                // 🚀 UPGRADED: Now uses the cinematic pulsating placeholder instead of a flat black box
                placeholder: (_, __) => SizedBox(
                  width: double.infinity,
                  height: widget.isDense ? 150 : 250,
                  child: const _PremiumImagePlaceholder(),
                ),
                fadeInDuration: const Duration(milliseconds: 500),
              ),
            ),
            if (!widget.isDense) ...[
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                      stops: [0.6, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Text(
                  widget.moment.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12,
                    fontFamily: 'Times New Roman',
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpringScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final VoidCallback? onLongPressCancel;

  const _SpringScaleButton({
    required this.child,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.onLongPressCancel,
  });

  @override
  State<_SpringScaleButton> createState() => _SpringScaleButtonState();
}

class _SpringScaleButtonState extends State<_SpringScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _bounceBack() => _controller.animateWith(
    SpringSimulation(
      const SpringDescription(mass: 0.6, stiffness: 500, damping: 20),
      _controller.value,
      1.0,
      0.0,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.animateTo(0.94, curve: Curves.easeOutCubic),
      onTapUp: (_) {
        _bounceBack();
        widget.onTap();
      },
      onTapCancel: () => _controller.animateTo(1.0),
      onLongPressStart: (details) {
        _controller.animateTo(0.94, curve: Curves.easeOutCubic);
        widget.onLongPressStart?.call(details);
      },
      onLongPressMoveUpdate: widget.onLongPressMoveUpdate,
      onLongPressEnd: (details) {
        _bounceBack();
        widget.onLongPressEnd?.call(details);
      },
      onLongPressCancel: () {
        _bounceBack();
        widget.onLongPressCancel?.call();
      },
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}

class DragMenuController {
  final BuildContext context;
  final Moment moment;
  final String? collectionId;
  final VoidCallback? onRemove;
  final Rect sourceRect;
  OverlayEntry? _overlayEntry;
  final ValueNotifier<Offset> _fingerPos = ValueNotifier(Offset.zero);

  DragMenuController({
    required this.context,
    required this.moment,
    this.collectionId,
    this.onRemove,
    required this.sourceRect,
  });

  void show(Offset initialTouch) {
    _fingerPos.value = initialTouch;
    _overlayEntry = OverlayEntry(
      builder: (ctx) => _DragMenuOverlay(
        moment: moment,
        collectionId: collectionId,
        onRemove: onRemove,
        sourceRect: sourceRect,
        fingerNotifier: _fingerPos,
        parentContext: context,
        onClose: cancel,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void updateFinger(Offset position) => _fingerPos.value = position;
  void release() => _fingerPos.value = const Offset(-1, -1);
  void cancel() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _DragMenuOverlay extends StatefulWidget {
  final Moment moment;
  final String? collectionId;
  final VoidCallback? onRemove;
  final Rect sourceRect;
  final ValueNotifier<Offset> fingerNotifier;
  final BuildContext parentContext;
  final VoidCallback onClose;

  const _DragMenuOverlay({
    required this.moment,
    this.collectionId,
    this.onRemove,
    required this.sourceRect,
    required this.fingerNotifier,
    required this.parentContext,
    required this.onClose,
  });

  @override
  State<_DragMenuOverlay> createState() => _DragMenuOverlayState();
}

class _DragMenuOverlayState extends State<_DragMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  MomentAction? _hoveredAction;
  late List<MomentActionSpec> _actions;
  final double _buttonSize = 64.0;
  final double _spacing = 16.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _actions = [
      const MomentActionSpec(
        action: MomentAction.ritual,
        icon: Icons.auto_awesome,
        label: 'RITUAL',
      ),
      if (widget.collectionId != null)
        const MomentActionSpec(
          action: MomentAction.remove,
          icon: Icons.bookmark_remove_rounded,
          label: 'REMOVE',
        ),
      const MomentActionSpec(
        action: MomentAction.save,
        icon: Icons.bookmark_add_rounded,
        label: 'SAVE',
      ),
      const MomentActionSpec(
        action: MomentAction.share,
        icon: Icons.ios_share_rounded,
        label: 'SHARE',
      ),
    ];

    widget.fingerNotifier.addListener(_onFingerMoved);
  }

  @override
  void dispose() {
    widget.fingerNotifier.removeListener(_onFingerMoved);
    _animCtrl.dispose();
    super.dispose();
  }

  void _onFingerMoved() {
    final pos = widget.fingerNotifier.value;
    if (pos == const Offset(-1, -1)) return _executeDrop();

    final screenWidth = MediaQuery.of(context).size.width;
    final totalWidth =
        (_buttonSize * _actions.length) + (_spacing * (_actions.length - 1));
    final startX = (screenWidth - totalWidth) / 2;
    final yPos = _getButtonsY();

    MomentAction? currentHover;
    for (int i = 0; i < _actions.length; i++) {
      final center = Offset(
        startX + i * (_buttonSize + _spacing) + _buttonSize / 2,
        yPos + _buttonSize / 2,
      );
      if ((pos - center).distance < 45) {
        currentHover = _actions[i].action;
        if (_hoveredAction != currentHover) HapticFeedback.selectionClick();
        break;
      }
    }
    if (currentHover != _hoveredAction)
      setState(() => _hoveredAction = currentHover);
  }

  void _executeDrop() {
    if (_hoveredAction != null) {
      HapticFeedback.heavyImpact();
      if (_hoveredAction == MomentAction.remove && widget.onRemove != null) {
        widget.onRemove!();
      } else {
        // 🚀 EXCLUDES THE ACTIVE COLLECTION SO IT DOESN'T SHOW IN THE SAVE SHEET
        handleMomentAction(
          context: widget.parentContext,
          moment: widget.moment,
          action: _hoveredAction!,
          excludedCollectionId: widget.collectionId,
        );
      }
    }
    widget.onClose();
  }

  double _getButtonsY() => widget.sourceRect.top < 150
      ? widget.sourceRect.bottom + 20
      : widget.sourceRect.top - (_buttonSize + 40);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final totalWidth =
        (_buttonSize * _actions.length) + (_spacing * (_actions.length - 1));
    final startX = (screenWidth - totalWidth) / 2;
    final yPos = _getButtonsY();
    final alignX = (widget.sourceRect.center.dx / screenWidth) * 2 - 1;
    final alignY = (widget.sourceRect.center.dy / screenHeight) * 2 - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, child) => FadeTransition(
              opacity: _animCtrl, // Hardware accelerated!
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 11, sigmaY: 11), // Static blur
                child: Container(color: Colors.black.withOpacity(0.6)),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, child) {
              final scale = 1.0 + (0.15 * _animCtrl.value);
              return Positioned(
                top: widget.sourceRect.top,
                left: widget.sourceRect.left,
                width: widget.sourceRect.width,
                height: widget.sourceRect.height,
                child: Transform.translate(
                  offset: Offset(0, -15.0 * _animCtrl.value),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment(alignX, alignY),
                    child: Opacity(
                      opacity: _animCtrl.value,
                      child: _buildPoppedCard(),
                    ),
                  ),
                ),
              );
            },
          ),
          ...List.generate(_actions.length, (index) {
            final spec = _actions[index];
            final isHovered = _hoveredAction == spec.action;
            return Positioned(
              left: startX + index * (_buttonSize + _spacing),
              top: yPos,
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 20 * (1 - _animCtrl.value)),
                  child: Opacity(opacity: _animCtrl.value, child: child),
                ),
                child: AnimatedScale(
                  scale: isHovered ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: _buttonSize,
                        height: _buttonSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isHovered
                              ? Colors.white
                              : Colors.white.withOpacity(0.1),
                          boxShadow: isHovered
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.4),
                                    blurRadius: 20,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          spec.icon,
                          color: isHovered ? Colors.black : Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        opacity: isHovered ? 1.0 : 0.6,
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          spec.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: isHovered
                                ? FontWeight.w900
                                : FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPoppedCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 40,
            spreadRadius: 10,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: ImageKit.constrainedWidth(
              path: widget.moment.imageKey,
              width: 400,
            ),
            memCacheWidth: (400 * MediaQuery.of(context).devicePixelRatio)
                .round(),
            fit: BoxFit.cover,
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.moment.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 11,
                    fontFamily: 'Times New Roman',
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
                if (widget.moment.author != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.moment.author!.toUpperCase(),
                    style: TextStyle(
                      color: Colors.cyanAccent.withOpacity(0.9),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 🚀 THE FIX: Changed to StatelessWidget. No Tickers, No State, 0% CPU cost.
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
            Color(0xFF141414), // Dark grey
            Color(0xFF050505), // Pitch black
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.blur_on_rounded, // Subtle cosmic icon while it loads
          color: Colors.white.withOpacity(0.05),
          size: 32,
        ),
      ),
    );
  }
}
