import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/identity.dart';
import '../../data/models/custom_collection.dart';
import '../../supabase/supabase_service.dart';
import '../../utils/cinematic_toast.dart';
import 'explore_drawer_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/imagekit.dart';
import 'collage_forge_screen.dart';
import '../../ui/modals/exchange_modal.dart';

class PersonalArchivesScreen extends StatefulWidget {
  final Identity identity;

  const PersonalArchivesScreen({super.key, required this.identity});

  @override
  State<PersonalArchivesScreen> createState() => _PersonalArchivesScreenState();
}

class _PersonalArchivesScreenState extends State<PersonalArchivesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;

  List<CustomCollection> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final data = await SupabaseService.fetchUserCollections(
        widget.identity.id,
      );
      if (mounted) {
        setState(() {
          _collections = data;
          _isLoading = false;
        });
        _entranceCtrl.forward();
      }
    } catch (e) {
      debugPrint("Failed to load collections: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _triggerCreateArchive() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CreateArchiveModal(
        userId: widget.identity.id,
        onCreated: (newCollection) async {
          setState(() => _isLoading = true);
          await _loadCollections();

          if (mounted) {
            _entranceCtrl.reset();
            _entranceCtrl.forward();
            showCinematicToast(context, "DIMENSION FORGED");
          }
        },
      ),
    );
  }

  void _deleteCollection(CustomCollection c) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _collections.removeWhere((col) => col.id == c.id);
    });
    try {
      await SupabaseService.deleteCollection(c.id);
      if (mounted) showCinematicToast(context, "DIMENSION DESTROYED");
    } catch (e) {
      // Handle error visually if desired
    }
  }

  void _openExchange() {
    HapticFeedback.selectionClick();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Exchange",
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, _, __) => ExchangeModal(identity: widget.identity),
      transitionBuilder: (context, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 30 * anim.value,
              sigmaY: 30 * anim.value,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _triggerRenameArchive(CustomCollection c) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RenameArchiveModal(
        collection: c,
        onRenamed: (newName) {
          setState(() {
            final index = _collections.indexWhere((col) => col.id == c.id);
            if (index != -1) {
              _collections[index] = CustomCollection(
                id: c.id,
                userId: c.userId,
                name: newName,
                createdAt: c.createdAt,
                itemCount: c.itemCount, // Preserve count
              );
            }
          });
          showCinematicToast(context, "DIMENSION RENAMED");
        },
      ),
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  int _getCrossAxisCount(double width) {
    if (width > 1000) return 4;
    if (width > 650) return 3;
    if (width > 450) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),

          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 1.5,
                ),
              ),
            )
          else
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      screenWidth > 600 ? 48 : 28,
                      120,
                      screenWidth > 600 ? 48 : 28,
                      40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FadeIn(
                          ctrl: _entranceCtrl,
                          interval: const Interval(0.0, 0.5),
                          child: Text(
                            "CURATED\nDIMENSIONS",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth > 600 ? 64 : 48,
                              fontFamily: 'Times New Roman',
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _FadeIn(
                          ctrl: _entranceCtrl,
                          interval: const Interval(0.1, 0.6),
                          child: Text(
                            "Your personal sanctuaries. Bound together.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: screenWidth > 600 ? 16 : 14,
                              fontFamily: 'Serif',
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_collections.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: _FadeIn(
                        ctrl: _entranceCtrl,
                        interval: const Interval(0.2, 0.8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.all_inclusive_rounded,
                              color: Colors.white.withOpacity(0.05),
                              size: 64,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "NO ARCHIVES FORMED",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.2),
                                fontSize: 10,
                                letterSpacing: 6,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      screenWidth > 600 ? 48 : 20,
                      0,
                      screenWidth > 600 ? 48 : 20,
                      140,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final collection = _collections[index];
                        final start = (0.2 + (index * 0.05)).clamp(0.0, 1.0);
                        final end = (start + 0.4).clamp(0.0, 1.0);

                        return _FadeIn(
                          ctrl: _entranceCtrl,
                          interval: Interval(start, end),
                          child: _ResponsiveCollectionCard(
                            collection: collection,
                            index: index,
                            allCollections: _collections,
                            onRename: () => _triggerRenameArchive(collection),
                            onDelete: () => _deleteCollection(collection),
                          ),
                        );
                      }, childCount: _collections.length),
                    ),
                  ),
              ],
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white54,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            "PERSONAL ARCHIVES",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 10,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w900,
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

          // ─── LIMIT LOGIC APPLIED TO BUTTON ───
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _FadeIn(
              ctrl: _entranceCtrl,
              interval: const Interval(0.6, 1.0),
              child: Center(
                // 🚀 THE FIX: Check Premium & Archives status!
                child:
                    (!widget.identity.isPremium &&
                        !widget.identity.hasInfiniteArchives &&
                        _collections.length >= 3)
                    ? GestureDetector(
                        onTap: _openExchange, // Takes them to the store!
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: const Color(
                                0xFFB38728,
                              ).withOpacity(0.5), // Subtle gold hint
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFFB38728),
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "CAPACITY REACHED - UNLOCK ARCHIVES",
                                style: TextStyle(
                                  color: const Color(
                                    0xFFFCF6BA,
                                  ).withOpacity(0.8),
                                  fontSize: 10,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _triggerCreateArchive,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "FORGE ARCHIVE",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
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
          ),
        ],
      ),
    );
  }
}

// ─── RESPONSIVE COLLECTION CARD COMPONENT ───
class _ResponsiveCollectionCard extends StatefulWidget {
  final CustomCollection collection;
  final int index;
  final List<CustomCollection> allCollections; // 🚀 NEW
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ResponsiveCollectionCard({
    required this.collection,
    required this.index,
    required this.allCollections, // 🚀 NEW
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ResponsiveCollectionCard> createState() =>
      _ResponsiveCollectionCardState();
}

class _ResponsiveCollectionCardState extends State<_ResponsiveCollectionCard>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _breathCtrl;

  bool _isFetching = false;
  String? _coverImageKey;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _fetchCoverImage();
  }

  Future<void> _fetchCoverImage() async {
    try {
      final moments = await SupabaseService.fetchMomentsInCollection(
        widget.collection.id,
      );
      if (moments.isNotEmpty && mounted) {
        setState(() {
          _coverImageKey = moments.first.imageKey;
        });
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _breathCtrl.dispose();
    super.dispose();
  }

  void _openArchive() async {
    HapticFeedback.mediumImpact();
    setState(() => _isFetching = true);

    try {
      final moments = await SupabaseService.fetchMomentsInCollection(
        widget.collection.id,
      );
      if (!mounted) return;

      setState(() => _isFetching = false);
      if (moments.isEmpty) {
        showCinematicToast(context, "DIMENSION IS EMPTY");
        return;
      }

      final validCollections = widget.allCollections
          .where((c) => c.itemCount > 0)
          .toList();

      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => ExploreDrawerScreen(
            moments: moments,
            customTitle: widget.collection.name,
            collectionId: widget.collection.id,
            userCollections: validCollections,
          ),
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutQuart)).animate(anim),
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
        showCinematicToast(context, "FAILED TO OPEN DIMENSION");
      }
    }
  }

  void _openCollageForge() async {
    HapticFeedback.heavyImpact();
    setState(() => _isFetching = true);

    try {
      final moments = await SupabaseService.fetchMomentsInCollection(
        widget.collection.id,
      );
      if (!mounted) return;
      setState(() => _isFetching = false);

      if (moments.isEmpty) {
        showCinematicToast(context, "DIMENSION IS EMPTY");
        return;
      }

      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => CollageForgeScreen(
            moments: moments,
            archiveName: widget.collection.name,
          ),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _openManageSheet() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
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
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.collection.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'Serif',
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 32),

                // 🚀 1. THE NEW FORGE TRIGGER
                ListTile(
                  leading: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: Colors.cyanAccent,
                  ),
                  title: const Text(
                    "FORGE COLLAGE WALLPAPER",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close the sheet
                    _openCollageForge(); // Open the new dimension!
                  },
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.white),
                  title: const Text(
                    "RENAME DIMENSION",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onRename();
                  },
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "SEVER / DESTROY",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final hues = [
      Colors.cyanAccent.withOpacity(0.05),
      Colors.deepPurpleAccent.withOpacity(0.05),
      Colors.indigoAccent.withOpacity(0.05),
      Colors.tealAccent.withOpacity(0.05),
    ];
    final glowColor = hues[widget.index % hues.length];

    final mq = MediaQuery.of(context);
    final cacheWidth = (mq.size.width * mq.devicePixelRatio).toInt();

    return AnimatedBuilder(
      animation: _scaleCtrl,
      builder: (context, child) {
        final scale = 1.0 - (_scaleCtrl.value * 0.04);
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapCancel: () => _scaleCtrl.reverse(),
        onTapUp: (_) {
          _scaleCtrl.reverse();
          if (!_isFetching) _openArchive();
        },
        onLongPress: _openManageSheet,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF080808),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.1), // Slightly brighter border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. THE COVER IMAGE
              if (_coverImageKey != null) ...[
                AnimatedBuilder(
                  animation: _breathCtrl,
                  builder: (context, child) {
                    final breathe =
                        1.0 +
                        (Curves.easeInOutSine.transform(_breathCtrl.value) *
                            0.12);
                    return Transform.scale(scale: breathe, child: child);
                  },
                  child: CachedNetworkImage(
                    imageUrl: ImageKit.constrainedWidth(
                      path: _coverImageKey!,
                      width: 600,
                    ),
                    fit: BoxFit.cover,
                    memCacheWidth: cacheWidth > 1200 ? 1200 : cacheWidth,
                    fadeInDuration: const Duration(milliseconds: 800),
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFF080808)),
                  ),
                ),

                // 🚀 2. THE FIX: Subtle shadow overlay just for the very top menu dots
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // EMPTY STATE GLOW
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 80,
                          spreadRadius: 40,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // TOP ICONS (Loader / Menu)
              Positioned(
                top: 24,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: _isFetching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(
                                color: Colors.white54,
                                strokeWidth: 1.5,
                              ),
                            )
                          : const Icon(
                              Icons.blur_on_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // 🚀 3. THE NEW FROSTED GLASS FOOTER
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  // Ensure blur doesn't bleed out of the bottom corners
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 15,
                      sigmaY: 15,
                    ), // Elegant glass blur
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(
                              0.2,
                            ), // Barely visible at top
                            Colors.black.withOpacity(
                              0.8,
                            ), // Solid at bottom for text contrast
                          ],
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ), // Beautiful glass reflection line
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.collection.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontFamily: 'Serif',
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.1,
                              ), // Brighter badge
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              "${widget.collection.itemCount} VISIONS",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 9,
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ─── CREATE ARCHIVE MODAL BOTTOM SHEET ───
// ─── CREATE ARCHIVE MODAL BOTTOM SHEET ───
class _CreateArchiveModal extends StatefulWidget {
  final String userId;
  final ValueChanged<CustomCollection> onCreated;

  const _CreateArchiveModal({required this.userId, required this.onCreated});

  @override
  State<_CreateArchiveModal> createState() => _CreateArchiveModalState();
}

// 1. Add the Observer
class _CreateArchiveModalState extends State<_CreateArchiveModal>
    with WidgetsBindingObserver {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to raw engine
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final newCollection = await SupabaseService.createCollection(
        widget.userId,
        name,
      );
      HapticFeedback.selectionClick();
      widget.onCreated(newCollection);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up
    _nameCtrl.dispose();
    super.dispose();
  }

  // 2. Trigger rebuild on keyboard pop
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 3. Bypass the Scaffold trap
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    // 4. Animate the padding and wrap in SingleChildScrollView to prevent overflow
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: SingleChildScrollView(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Colors.black.withOpacity(0.85),
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NAME YOUR DIMENSION",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontFamily: 'Courier',
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    maxLength: 9,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontFamily: 'Times New Roman',
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: 'e.g. Midnight',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontFamily: 'Times New Roman',
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              "MANIFEST",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900,
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
        ),
      ),
    );
  }
}

// ─── RENAME ARCHIVE MODAL BOTTOM SHEET ───
// ─── RENAME ARCHIVE MODAL BOTTOM SHEET ───
class _RenameArchiveModal extends StatefulWidget {
  final CustomCollection collection;
  final ValueChanged<String> onRenamed;

  const _RenameArchiveModal({
    required this.collection,
    required this.onRenamed,
  });

  @override
  State<_RenameArchiveModal> createState() => _RenameArchiveModalState();
}

// 1. Add the Observer
class _RenameArchiveModalState extends State<_RenameArchiveModal>
    with WidgetsBindingObserver {
  late final TextEditingController _nameCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to raw engine
    _nameCtrl = TextEditingController(text: widget.collection.name);
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name == widget.collection.name) return;

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      await SupabaseService.renameCollection(widget.collection.id, name);
      HapticFeedback.selectionClick();
      widget.onRenamed(name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up
    _nameCtrl.dispose();
    super.dispose();
  }

  // 2. Trigger rebuild on keyboard pop
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 3. Bypass the Scaffold trap
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    // 4. Animate the padding and wrap in SingleChildScrollView to prevent overflow
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: SingleChildScrollView(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Colors.black.withOpacity(0.85),
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "RENAME DIMENSION",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontFamily: 'Courier',
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    maxLength: 9,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontFamily: 'Times New Roman',
                    ),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      counterText: "",
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              "UPDATE",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900,
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
        ),
      ),
    );
  }
}

// ─── UTILITIES ───
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.5),
          radius: 1.5,
          colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
        ),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  final AnimationController ctrl;
  final Interval interval;
  final Widget child;
  const _FadeIn({
    required this.ctrl,
    required this.interval,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final anim = CurvedAnimation(parent: ctrl, curve: interval);
        final opacity = Curves.easeOut.transform(anim.value);
        final slide = Curves.easeOutQuart.transform(anim.value);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - slide)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
