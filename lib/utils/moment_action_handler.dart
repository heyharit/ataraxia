import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'cinematic_toast.dart';
import '../data/models/moment.dart';
import '../data/models/custom_collection.dart';
import '../data/identity_store.dart';
import '../supabase/supabase_service.dart';
import '../ui/screens/ritual_screen.dart';
import '../utils/moment_actions.dart';
import 'share_service.dart';
import 'share_processing_overlay.dart';

Future<void> handleMomentAction({
  required BuildContext context,
  required Moment moment,
  required MomentAction action,
  ShareStyle style = ShareStyle.explore,
  String? excludedCollectionId, // 🚀 ADD THIS
}) async {
  try {
    final identity = await IdentityStore.active();
    if (identity != null) {
      String actionStr = '';
      if (action == MomentAction.ritual)
        actionStr = 'ritual';
      else if (action == MomentAction.save)
        actionStr = 'save';
      else if (action == MomentAction.share)
        actionStr = 'share';

      if (actionStr.isNotEmpty) {
        SupabaseService.trackVoidEcho(
          identity.id,
          moment.wallpaperId,
          actionStr,
        );
      }
    }
  } catch (e) {
    debugPrint("Silent telemetry ignored: $e");
  }

  // ─── 2. UI EXECUTION ───
  switch (action) {
    case MomentAction.ritual:
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) =>
              RitualScreen(overrideMoment: moment, fromExplore: true),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
      break;

    case MomentAction.save:
      HapticFeedback.lightImpact();
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _SaveToArchiveSheet(
          moment: moment,
          excludedCollectionId: excludedCollectionId, // 🚀 PASS IT DOWN HERE
        ),
      );
      break;

    case MomentAction.share:
      // 🚀 CAPTURE THE NAVIGATOR IMMEDIATELY
      // This prevents the PageView rebuild bug from destroying our context
      final rootNav = Navigator.of(context, rootNavigator: true);

      // Create a deterministic route for the overlay
      final dialogRoute = DialogRoute(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        useSafeArea: false,
        builder: (_) => const ShareProcessingOverlay(),
      );

      // Push the overlay
      rootNav.push(dialogRoute);

      try {
        final shareFile = await ShareService.prepareShareFile(
          moment,
          style: style,
        );

        // 🚀 KEEP OVERLAY ALIVE HERE
        await ShareService.invokeNativeShare(shareFile, moment);
      } catch (e) {
        final url = 'https://theataraxia.web.app/${moment.slug}';
        await Share.share("Check this out: $url");
      } finally {
        // ✅ REMOVE ONLY AFTER USER RETURNS
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (rootNav.mounted && dialogRoute.isActive) {
            try {
              rootNav.removeRoute(dialogRoute);
            } catch (_) {}
          }
        });
      }
      break;

    case MomentAction.remove:
      break;

    case MomentAction.cancel:
      // Intentionally empty — cancel is a UI concern
      break;
  }
}

// ─── THE EXQUISITE SAVE SHEET ───
class _SaveToArchiveSheet extends StatefulWidget {
  final Moment moment;
  final String? excludedCollectionId; // 🚀 ADD THIS

  const _SaveToArchiveSheet({
    required this.moment,
    this.excludedCollectionId, // 🚀 ADD THIS
  });

  @override
  State<_SaveToArchiveSheet> createState() => _SaveToArchiveSheetState();
}

class _SaveToArchiveSheetState extends State<_SaveToArchiveSheet> {
  List<CustomCollection> _collections = [];
  Set<String> _existingCollectionIds = {};
  bool _isLoading = true;
  bool _isAuthenticated = true;
  bool _isPremium = false;
  bool _hasInfiniteArchives = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    final identity = await IdentityStore.active();
    if (identity == null) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
      return;
    }

    _userId = identity.id;
    _isPremium = identity.isPremium;
    _hasInfiniteArchives = identity.hasInfiniteArchives;

    try {
      final collections = await SupabaseService.fetchUserCollections(
        identity.id,
      );

      final existingColIds = await SupabaseService.fetchCollectionsWithMoment(
        widget.moment.wallpaperId,
      );

      collections.removeWhere((c) => c.id == widget.excludedCollectionId);

      collections.sort((a, b) {
        final aSaved = existingColIds.contains(a.id);
        final bSaved = existingColIds.contains(b.id);

        // 1. Push saved items to the bottom
        if (aSaved && !bSaved) return 1;
        if (!aSaved && bSaved) return -1;

        // 2. If they are the same status, sort them alphabetically
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _collections = collections;
          _existingCollectionIds = existingColIds.toSet();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToCollection(CustomCollection collection) async {
    HapticFeedback.heavyImpact();
    try {
      await SupabaseService.addMomentToCollection(
        collection.id,
        widget.moment.wallpaperId,
      );
      if (mounted) {
        Navigator.pop(context); // Close sheet
        showCinematicToast(
          context,
          "ANCHORED TO ${collection.name.toUpperCase()}",
        ); // SHOW VISUAL FEEDBACK
      }
    } catch (e) {
      debugPrint("Failed to save: $e");
    }
  }

  void _openQuickForge() {
    if (_userId == null) return;
    HapticFeedback.selectionClick();

    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _QuickForgeSheet(userId: _userId!, momentToSave: widget.moment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withOpacity(0.85),
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SELECT DIMENSION",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontFamily: 'Courier',
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white24,
                      strokeWidth: 1.5,
                    ),
                  ),
                )
              else if (!_isAuthenticated)
                _buildEmptyState("UNANCHORED. LOG IN TO SAVE.")
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ─── LIMIT CREATION TO 3 (UNLESS ASCENDED) ───
                    if (!_isPremium &&
                        !_hasInfiniteArchives &&
                        _collections.length >= 3)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            "DIMENSION CAPACITY REACHED (3/3)",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 10,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _openQuickForge,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                color: Colors.cyanAccent.withOpacity(0.8),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "FORGE NEW DIMENSION",
                                style: TextStyle(
                                  color: Colors.cyanAccent.withOpacity(0.8),
                                  fontSize: 10,
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_collections.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.35,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _collections.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final c = _collections[index];
                            // 🚀 Check if the moment is already in this collection
                            final isAlreadySaved = _existingCollectionIds
                                .contains(c.id);

                            return GestureDetector(
                              // Disable the tap if it's already saved
                              onTap: isAlreadySaved
                                  ? null
                                  : () => _saveToCollection(c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  // Dim the background if it's already saved
                                  color: Colors.white.withOpacity(
                                    isAlreadySaved ? 0.01 : 0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    // Dim the border if it's already saved
                                    color: Colors.white.withOpacity(
                                      isAlreadySaved ? 0.03 : 0.1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: TextStyle(
                                              // Dim the text if it's already saved
                                              color: Colors.white.withOpacity(
                                                isAlreadySaved ? 0.4 : 1.0,
                                              ),
                                              fontSize: 18,
                                              fontFamily: 'Serif',
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          // 🚀 NEW: Add a premium sub-label if it's already anchored here
                                          if (isAlreadySaved) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "ALREADY ANCHORED",
                                              style: TextStyle(
                                                color: Colors.cyanAccent
                                                    .withOpacity(0.4),
                                                fontSize: 8,
                                                fontFamily: 'Courier',
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      // 🚀 Change the icon to a checkmark if saved
                                      isAlreadySaved
                                          ? Icons.bookmark_added_rounded
                                          : Icons.bookmark_add_rounded,
                                      color: isAlreadySaved
                                          ? Colors.cyanAccent.withOpacity(0.4)
                                          : Colors.white.withOpacity(0.3),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    // ... keep existing empty state UI ...
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            fontFamily: 'Courier',
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─── QUICK FORGE (ON-THE-FLY CREATION) ───
class _QuickForgeSheet extends StatefulWidget {
  final String userId;
  final Moment momentToSave;
  const _QuickForgeSheet({required this.userId, required this.momentToSave});
  @override
  State<_QuickForgeSheet> createState() => _QuickForgeSheetState();
}

// 1. Add the Observer
class _QuickForgeSheetState extends State<_QuickForgeSheet>
    with WidgetsBindingObserver {
  final TextEditingController _nameCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to raw engine
  }

  void _createAndSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final newCollection = await SupabaseService.createCollection(
        widget.userId,
        name,
      );
      await SupabaseService.addMomentToCollection(
        newCollection.id,
        widget.momentToSave.wallpaperId,
      );

      if (mounted) {
        Navigator.pop(context);
        showCinematicToast(
          context,
          "FORGED & ANCHORED",
        ); // SHOW VISUAL FEEDBACK
      }
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
    // 3. Bypass the Scaffold trap to get the real keyboard height
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    // 4. Animate the padding and wrap in SingleChildScrollView
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Colors.black.withOpacity(0.9),
              // 5. Clean up the padding hack. We just use static 40 here now!
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
                    cursorColor: Colors.cyanAccent,
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
                    onSubmitted: (_) => _createAndSave(),
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
                            color: Colors.cyanAccent,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _createAndSave,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              "CREATE & SAVE",
                              style: TextStyle(
                                color: Colors.cyanAccent.withOpacity(0.9),
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
