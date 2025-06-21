import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../utils/update_manager.dart';
import '../../utils/cinematic_toast.dart';
import '../../utils/cosmic_loader.dart';
import '../identity/identity_gate.dart';
import '../../data/identity_store.dart';
import '../../data/models/identity.dart';
import '../../supabase/supabase_service.dart';
import '../identity/burn_identity_ritual.dart';
import '../../settings/ambient_ritual_screen.dart';
import '../screens/personal_archives_screen.dart';
import '../screens/collective_visions_screen.dart';
import '../screens/constellation_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ui/modals/exchange_modal.dart';
import '../../core/palette.dart';
import '../screens/onboarding_overlay.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  Identity? _identity;
  int _memoryCount = 0;
  int _streakCount = 0;
  int _archiveCount = 0;
  bool _isLoading = true;

  late final AnimationController _breathCtrl;
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadSanctuaryData();
  }

  Future<void> _loadSanctuaryData({bool isLogin = false}) async {
    _entranceCtrl.reset();

    // 🚀 1. If it's a fresh login, FORCE the loader to appear
    if (isLogin && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    var identity = await IdentityStore.active();

    if (identity == null) {
      if (mounted) {
        setState(() {
          _identity = null;
          _isLoading = false;
        });
        _entranceCtrl.forward();
      }
      return;
    }

    // ✅ 2. INSTANT UI (We skip this ONLY during a fresh login so the loader stays visible)
    if (mounted && !isLogin) {
      setState(() {
        _identity = identity;
        _isLoading = false;
      });
      _entranceCtrl.forward();
    }

    try {
      // 3. Synchronize frequencies with the Void
      final results = await Future.wait([
        SupabaseService.fetchMemoryBonds(identity.id),
        SupabaseService.fetchStreak(identity.id),
        SupabaseService.fetchUserCollections(identity.id),
      ]);

      await SupabaseService.claimDailyAxioms(identity.id);
      await IdentityStore.syncFromNetwork();
      final freshIdentity = await IdentityStore.active();

      if (mounted && freshIdentity != null) {
        setState(() {
          _identity = freshIdentity;
          _memoryCount = (results[0] as List).length;
          _streakCount = results[1] as int;
          _archiveCount = (results[2] as List).length;

          // 🚀 4. Turn off the loader ONLY after all data is fetched!
          if (isLogin) _isLoading = false;
        });

        // 🚀 5. Trigger the smooth fade-in entrance
        if (isLogin) {
          _entranceCtrl.forward();
        }
      }
    } catch (e) {
      debugPrint("Sanctuary sync failed: $e");
      if (mounted && isLogin) {
        setState(() => _isLoading = false);
        _entranceCtrl.forward();
      }
    }
  }

  void _triggerGate() {
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IdentityGate(
          onAuthenticated: () async {
            Navigator.pop(context);
            _loadSanctuaryData(isLogin: true);
          },
        ),
      ),
    );
  }

  void _openExchange() {
    HapticFeedback.selectionClick();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Exchange",
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, _, __) => ExchangeModal(identity: _identity!),
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
    ).then((_) async {
      // 🚀 When they close the store, refresh the UI in case they bought something!
      final updated = await IdentityStore.active();
      if (mounted && updated != null) {
        setState(() => _identity = updated);
      }
    });
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  // ─── SEQUENCES & NAVIGATION ───
  void _triggerBurnSequence() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IdentityBurnRitual(identity: _identity!),
      ),
    );
  }

  void _openArchives() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalArchivesScreen(identity: _identity!),
      ),
    );
  }

  void _openCollective() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectiveVisionsScreen(identity: _identity!),
      ),
    );
  }

  void _openAmbientRitual() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AmbientRitualScreen(),
      ),
    );
  }

  void _openFrequencies() {
    HapticFeedback.selectionClick();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Frequencies",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, _, __) => _FrequenciesModal(userId: _identity!.id),
      transitionBuilder: (context, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20 * anim.value,
              sigmaY: 20 * anim.value,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _triggerNetworkSequence() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (_, __, ___) =>
            const ConstellationScreen(), // 🚀 Launch the Map!
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  void _triggerAtaraxiaSequence() {
    HapticFeedback.selectionClick();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Network",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, _, __) => const _CommunityModal(),
      transitionBuilder: (context, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 20 * anim.value,
              sigmaY: 20 * anim.value,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _triggerRenameSequence() {
    HapticFeedback.selectionClick();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Rename",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, _, __) => _RenameModal(
        identity: _identity!,
        onNameUpdated: (newName) {
          setState(() {
            _identity = Identity(
              id: _identity!.id,
              name: newName,
              keyHash: _identity!.keyHash,
              createdAt: _identity!.createdAt,
            );
          });
        },
      ),
      transitionBuilder: (context, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10 * anim.value,
              sigmaY: 10 * anim.value,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _triggerSupportSequence() {
    HapticFeedback.selectionClick();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Signal",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, _, __) => SupportModal(identity: _identity),
      transitionBuilder: (context, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 10 * anim.value,
              sigmaY: 10 * anim.value,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _triggerSeverSequence() async {
    HapticFeedback.mediumImpact();
    await IdentityStore.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  void _triggerUpdateCheck() async {
    HapticFeedback.mediumImpact();
    showCinematicToast(context, "SCANNING FREQUENCIES...");

    final updateInfo = await UpdateManager.checkForUpdates();

    if (!mounted) return;

    if (updateInfo != null) {
      HapticFeedback.heavyImpact();
      final bool isForced = updateInfo['isForced'] == true;

      showGeneralDialog(
        context: context,
        barrierDismissible: !isForced, // 🚀 Lock out taps if forced
        barrierLabel: "Update",
        barrierColor: Colors.black.withOpacity(isForced ? 0.9 : 0.8),
        transitionDuration: const Duration(milliseconds: 500),
        // 🚀 Disable Android Back Button if forced
        pageBuilder: (context, _, __) => WillPopScope(
          onWillPop: () async => !isForced,
          child: _UpdateModal(
            newVersion: updateInfo['version']!,
            updateUrl: updateInfo['url']!,
            isForced: isForced,
          ),
        ),
        transitionBuilder: (context, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
      );
    } else {
      HapticFeedback.selectionClick();
      showCinematicToast(context, "YOU ARE IN SYNC");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: AtaraxiaPalette.voidDeep,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Ambient Breathing Void — dual-orb cosmic lighting
          AnimatedBuilder(
            animation: _breathCtrl,
            builder: (context, _) {
              final val = _breathCtrl.value;
              final baseSize = isTablet ? 700.0 : 380.0;

              return Stack(
                children: [
                  // Top-right cosmic indigo orb
                  Positioned(
                    top: (isTablet ? -260.0 : -130.0) - (val * 20),
                    right: (isTablet ? -180.0 : -90.0) - (val * 15),
                    child: Container(
                      width: baseSize + (val * 40),
                      height: baseSize + (val * 40),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AtaraxiaPalette.cosmicIndigo.withOpacity(
                              0.14 + (val * 0.08),
                            ),
                            AtaraxiaPalette.cosmicIndigo.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Bottom-left aurora violet orb
                  Positioned(
                    bottom: (isTablet ? -200.0 : -100.0) + (val * 20),
                    left: (isTablet ? -160.0 : -80.0) - (val * 10),
                    child: Container(
                      width: baseSize * 0.75 + (val * 30),
                      height: baseSize * 0.75 + (val * 30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AtaraxiaPalette.auroraViolet.withOpacity(
                              0.10 + (val * 0.06),
                            ),
                            AtaraxiaPalette.auroraViolet.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CosmicLoaderWidget(),
                  const SizedBox(height: 40),
                  _FadeIn(
                    ctrl: _entranceCtrl,
                    interval: const Interval(0.0, 1.0),
                    child: Text(
                      "SYNCHRONIZING FREQUENCIES",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: isTablet ? 12 : 9,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_identity == null)
            _buildUnanchoredState(isTablet)
          else
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 🚀 FIXED TOP SECTION
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _FadeIn(
                              ctrl: _entranceCtrl,
                              interval: const Interval(0.0, 0.3),
                              child: Text(
                                "YOUR SANCTUARY",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: isTablet ? 12 : 9,
                                  letterSpacing: 6,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),

                            // Right-side controls — flex so they never overflow
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _FadeIn(
                                    ctrl: _entranceCtrl,
                                    interval: const Interval(0.1, 0.4),
                                    child: GestureDetector(
                                      onTap: _openExchange,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AtaraxiaPalette.glacialTeal
                                                  .withOpacity(0.12),
                                              AtaraxiaPalette.cosmicIndigo
                                                  .withOpacity(0.08),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          border: Border.all(
                                            color: AtaraxiaPalette.glacialTeal
                                                .withOpacity(0.4),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AtaraxiaPalette.glacialTeal
                                                  .withOpacity(0.2),
                                              blurRadius: 18,
                                              spreadRadius: -2,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.change_history_rounded,
                                              color:
                                                  AtaraxiaPalette.glacialTeal,
                                              size: 13,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "${_identity?.axioms ?? 0}",
                                              style: TextStyle(
                                                color:
                                                    AtaraxiaPalette.glacialTeal,
                                                fontFamily: 'Courier',
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pop(context);
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white54,
                                      size: isTablet ? 28 : 22,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 40 : 32),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 48.0 : 32.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FadeIn(
                              ctrl: _entranceCtrl,
                              interval: const Interval(0.1, 0.4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // ─── DICEBEAR AVATAR ───
                                  GestureDetector(
                                    onTap: _triggerRenameSequence,
                                    child: Container(
                                      width: isTablet ? 79 : 59,
                                      height: isTablet ? 79 : 59,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        // No border for premium — pure glow only
                                        border: Border.all(
                                          color: _identity?.isPremium == true
                                              ? Colors.transparent
                                              : Colors.white.withOpacity(0.12),
                                          width: 1.5,
                                        ),
                                        boxShadow: _identity?.isPremium == true
                                            ? [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF7B2FFF,
                                                  ).withOpacity(0.35),
                                                  blurRadius: 24,
                                                  spreadRadius: 1,
                                                ),
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF00E5FF,
                                                  ).withOpacity(0.20),
                                                  blurRadius: 40,
                                                  spreadRadius: -4,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(0.5),
                                        child: ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                _identity?.isPremium == true
                                                ? 'https://api.dicebear.com/10.x/thumbs/png?borderRadius=5&backgroundColor=0a5b83,1c799f,69d2e7,f1f4dc,f88c49,8c00ff,c886fe,ffea00,000000&shapeColor=0a5b83,1c799f,69d2e7,f1f4dc,f88c49,8a00e6,d08aff,2bff00,000000&seed=${Uri.encodeComponent(_identity?.name ?? 'wanderer')}&size=256&backgroundColor=080910'
                                                : 'https://api.dicebear.com/10.x/glyphs/png?scale=1,1.38&borderRadius=6&glyphColor=76a7ff,525fa3,8c8c8c,75c675,ffaa64,ff4d6f,af61f2,00bfff,000000&glyphColorAngle=90&glyphColorFill=linear&seed=${Uri.encodeComponent(_identity?.name ?? 'wanderer')}&size=256&backgroundColor=080910',
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => Container(
                                              color:
                                                  AtaraxiaPalette.cardSurface,
                                              child: Icon(
                                                Icons.person_outline_rounded,
                                                color: Colors.white24,
                                                size: isTablet ? 32 : 24,
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                                  color: AtaraxiaPalette
                                                      .cardSurface,
                                                  child: Center(
                                                    child: Text(
                                                      (_identity?.name ?? 'W')
                                                          .substring(0, 1)
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withOpacity(0.6),
                                                        fontSize: isTablet
                                                            ? 28
                                                            : 20,
                                                        fontFamily:
                                                            'Times New Roman',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 20 : 14),
                                  // ─── NAME + EDIT ───
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: _triggerRenameSequence,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              _identity?.isPremium == true
                                                  ? AscendedIdentityText(
                                                      text:
                                                          (_identity?.name ??
                                                                  "WANDERER")
                                                              .toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: isTablet
                                                            ? 84
                                                            : 48,
                                                        fontFamily:
                                                            'Times New Roman',
                                                        height: 1.0,
                                                        letterSpacing: -1.5,
                                                      ),
                                                    )
                                                  : Text(
                                                      (_identity?.name ??
                                                              "WANDERER")
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: isTablet
                                                            ? 84
                                                            : 48,
                                                        fontFamily:
                                                            'Times New Roman',
                                                        height: 1.0,
                                                        letterSpacing: -1.5,
                                                      ),
                                                    ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                Icons.edit_rounded,
                                                color: Colors.white.withOpacity(
                                                  0.15,
                                                ),
                                                size: isTablet ? 28 : 18,
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
                            SizedBox(height: isTablet ? 20 : 12),
                            _FadeIn(
                              ctrl: _entranceCtrl,
                              interval: const Interval(0.2, 0.5),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 12 : 8,
                                      vertical: isTablet ? 6 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _identity?.id
                                              .split('-')
                                              .first
                                              .toUpperCase() ??
                                          "00000000",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: isTablet ? 12 : 10,
                                        fontFamily: 'Courier',
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    "ANCHORED ${_identity?.createdAt.year ?? DateTime.now().year}",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: isTablet ? 12 : 10,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 40 : 32),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 48.0 : 32.0,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _FadeIn(
                                ctrl: _entranceCtrl,
                                interval: const Interval(0.3, 0.6),
                                child: _buildPoeticStat(
                                  "RESONANCE",
                                  "$_streakCount",
                                  "DAYS",
                                  isTablet,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: isTablet ? 60 : 40,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 24.0),
                                child: _FadeIn(
                                  ctrl: _entranceCtrl,
                                  interval: const Interval(0.4, 0.7),
                                  child: _buildPoeticStat(
                                    "ECHOES",
                                    "$_memoryCount",
                                    "SAVED",
                                    isTablet,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 40 : 32),

                      // Expanded(
                      //   child: SingleChildScrollView(
                      //     physics: const BouncingScrollPhysics(),
                      //     padding:
                      //         EdgeInsets.symmetric(
                      //           horizontal: isTablet ? 48.0 : 32.0,
                      //         ).copyWith(
                      //           bottom: 40.0,
                      //         ), // Padding at the bottom for scroll clearance
                      //     child: Column(
                      //       crossAxisAlignment: CrossAxisAlignment.start,
                      //       children: [
                      //         _FadeIn(
                      //           ctrl: _entranceCtrl,
                      //           interval: const Interval(0.5, 0.8),
                      //           child: Row(
                      //             children: [
                      //               Expanded(
                      //                 child: _PortalCard(
                      //                   title: "Archives",
                      //                   subtitle: "Curated dimensions",
                      //                   icon: Icons.all_inclusive_rounded,
                      //                   height: 248, // 🚀 Fixed ratio
                      //                   onTap: _openArchives,
                      //                 ),
                      //               ),
                      //               const SizedBox(width: 16),
                      //               Expanded(
                      //                 child: Column(
                      //                   children: [
                      //                     _PortalCard(
                      //                       title: "The Collective",
                      //                       subtitle: "Manifest visions",
                      //                       icon: Icons.auto_awesome,
                      //                       height: 116, // 🚀 Fixed ratio
                      //                       isAccent: true,
                      //                       onTap: _openCollective,
                      //                     ),
                      //                     const SizedBox(height: 16),
                      //                     _PortalCard(
                      //                       title: "Frequencies",
                      //                       subtitle: "Psych profile",
                      //                       icon: Icons.blur_on_rounded,
                      //                       height: 116, // 🚀 Fixed ratio
                      //                       onTap: _openFrequencies,
                      //                     ),
                      //                   ],
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //         const SizedBox(height: 16),
                      //         _FadeIn(
                      //           ctrl: _entranceCtrl,
                      //           interval: const Interval(0.6, 0.9),
                      //           child: _PortalCard(
                      //             title: "Auto Sync & Update",
                      //             subtitle: "Ambient widget experience",
                      //             icon: Icons.sync_rounded,
                      //             height: 80, // 🚀 Fixed height
                      //             isWide: true,
                      //             onTap: _openAmbientRitual,
                      //           ),
                      //         ),
                      //         const SizedBox(height: 16),
                      //         _FadeIn(
                      //           ctrl: _entranceCtrl,
                      //           interval: const Interval(0.7, 1.0),
                      //           child: _PortalCard(
                      //             title: "The Network",
                      //             subtitle: "Community & Socials",
                      //             icon: Icons.language_rounded,
                      //             height: 80,
                      //             isWide: true,
                      //             onTap: _triggerNetworkSequence,
                      //           ),
                      //         ),
                      //         const SizedBox(height: 16),
                      //         _FadeIn(
                      //           ctrl: _entranceCtrl,
                      //           interval: const Interval(0.75, 1.0),
                      //           child: _PortalCard(
                      //             title: "System Protocol",
                      //             subtitle: "Check for new frequencies",
                      //             icon: Icons.radar_rounded,
                      //             height: 80,
                      //             isWide: true,
                      //             onTap: _triggerUpdateCheck,
                      //           ),
                      //         ),

                      //         const SizedBox(height: 32),

                      //         // Footer Links
                      //         _FadeIn(
                      //           ctrl: _entranceCtrl,
                      //           interval: const Interval(0.8, 1.0),
                      //           child: Row(
                      //             mainAxisAlignment: MainAxisAlignment.center,
                      //             children: [
                      //               _buildFooterLink(
                      //                 "SEVER",
                      //                 onTap: _triggerSeverSequence,
                      //               ),
                      //               _buildFooterDot(),
                      //               _buildFooterLink(
                      //                 "ERASE",
                      //                 isDestructive: true,
                      //                 onTap: _triggerBurnSequence,
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),

                      // 🚀 SCROLLABLE BENTO GRID SECTION
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 48.0 : 32.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _FadeIn(
                                      ctrl: _entranceCtrl,
                                      interval: const Interval(0.5, 0.8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _PortalCard(
                                              title: "Archives",
                                              subtitle:
                                                  "$_archiveCount FORGED DIMENSIONS",
                                              icon: Icons.all_inclusive_rounded,
                                              height: 248,
                                              onTap: _openArchives,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              children: [
                                                _PortalCard(
                                                  title: "The Collective",
                                                  subtitle: "Manifest visions",
                                                  icon: Icons.auto_awesome,
                                                  height: 116, // 🚀 Fixed ratio
                                                  isAccent: true,
                                                  onTap: _openCollective,
                                                ),
                                                const SizedBox(height: 16),
                                                _PortalCard(
                                                  title: "Frequencies",
                                                  subtitle: "Psych profile",
                                                  icon: Icons.blur_on_rounded,
                                                  height: 116, // 🚀 Fixed ratio
                                                  onTap: _openFrequencies,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _FadeIn(
                                      ctrl: _entranceCtrl,
                                      interval: const Interval(0.6, 0.9),
                                      child: _PortalCard(
                                        title: "Auto Sync & Update",
                                        subtitle: "Ambient widget experience",
                                        icon: Icons.sync_rounded,
                                        height: 80, // 🚀 Fixed height
                                        isWide: true,
                                        onTap: _openAmbientRitual,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _FadeIn(
                                      ctrl: _entranceCtrl,
                                      interval: const Interval(0.7, 1.0),
                                      child: _PortalCard(
                                        title: "The Network",
                                        subtitle: "ATARAXIANS",
                                        icon: Icons.language_rounded,
                                        height: 80,
                                        isWide: true,
                                        onTap: _triggerNetworkSequence,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _FadeIn(
                                      ctrl: _entranceCtrl,
                                      interval: const Interval(0.7, 1.0),
                                      child: _PortalCard(
                                        title: "The Ataraxia",
                                        subtitle: "Community & Socials",
                                        icon: Icons.language_rounded,
                                        height: 80,
                                        isWide: true,
                                        onTap: _triggerAtaraxiaSequence,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _FadeIn(
                                      ctrl: _entranceCtrl,
                                      interval: const Interval(0.75, 1.0),
                                      child: _PortalCard(
                                        title: "System Protocol",
                                        subtitle: "Check for new frequencies",
                                        icon: Icons.radar_rounded,
                                        height: 80,
                                        isWide: true,
                                        onTap: _triggerUpdateCheck,
                                      ),
                                    ),

                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),

                            // 🔥 STICKY FOOTER
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 16,
                                top: 8,
                              ),
                              child: _FadeIn(
                                ctrl: _entranceCtrl,
                                interval: const Interval(0.8, 1.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildFooterLink(
                                      "GUIDE",
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        showOnboardingForced(context);
                                      },
                                    ),
                                    _buildFooterDot(),
                                    _buildFooterLink(
                                      "TRANSMIT",
                                      onTap: _triggerSupportSequence,
                                    ),
                                    _buildFooterDot(),
                                    _buildFooterLink(
                                      "SEVER",
                                      onTap: _triggerSeverSequence,
                                    ),
                                    _buildFooterDot(),
                                    _buildFooterLink(
                                      "ERASE",
                                      isDestructive: true,
                                      onTap: _triggerBurnSequence,
                                    ),
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
        ],
      ),
    );
  }

  Widget _buildFooterLink(
    String text, {
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: isDestructive
                ? Colors.redAccent.withOpacity(0.8)
                : Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterDot() {
    return Text(
      "•",
      style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10),
    );
  }

  Widget _buildPoeticStat(
    String title,
    String value,
    String unit,
    bool isTablet,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: isTablet ? 12 : 8,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: isTablet ? 12 : 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            AnimatedCount(
              value: int.tryParse(value) ?? 0,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 64 : 36,
                fontFamily: 'Times New Roman',
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
                shadows: [
                  Shadow(
                    color: AtaraxiaPalette.cosmicIndigo.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              unit,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: isTablet ? 14 : 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnanchoredState(bool isTablet) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FadeIn(
              ctrl: _entranceCtrl,
              interval: const Interval(0.1, 0.6),
              child: Text(
                "UNANCHORED",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 48 : 32,
                  fontFamily: 'Times New Roman',
                  letterSpacing: 8.0,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _FadeIn(
              ctrl: _entranceCtrl,
              interval: const Interval(0.3, 0.8),
              child: Text(
                "To remember, you must first exist.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: isTablet ? 18 : 14,
                  fontFamily: 'Serif',
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: isTablet ? 80 : 60),
            _FadeIn(
              ctrl: _entranceCtrl,
              interval: const Interval(0.5, 1.0),
              child: AnimatedBuilder(
                animation: _breathCtrl,
                builder: (context, _) {
                  final glow = 0.2 + (_breathCtrl.value * 0.3);
                  final scale = 1.0 + (_breathCtrl.value * 0.05);

                  return GestureDetector(
                    onTap: _triggerGate,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 48 : 36,
                          vertical: isTablet ? 20 : 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.white.withOpacity(glow),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(glow * 0.2),
                              blurRadius: 20 * _breathCtrl.value,
                              spreadRadius: 5 * _breathCtrl.value,
                            ),
                          ],
                        ),
                        child: Text(
                          "AWAKEN IDENTITY",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: isTablet ? 14 : 11,
                            fontFamily: 'Courier',
                            letterSpacing: 4.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            _FadeIn(
              ctrl: _entranceCtrl,
              interval: const Interval(0.7, 1.0),
              child: GestureDetector(
                onTap: _triggerNetworkSequence,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    "THE NETWORK",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: isTablet ? 12 : 9,
                      fontFamily: 'Courier',
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _FadeIn(
              ctrl: _entranceCtrl,
              interval: const Interval(0.7, 1.0),
              child: GestureDetector(
                onTap: _triggerAtaraxiaSequence,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    "THE ATARAXIA",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: isTablet ? 12 : 9,
                      fontFamily: 'Courier',
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 🚀 THE NEW BENTO PORTAL CARD COMPONENT ───
class _PortalCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final double height;
  final bool isAccent;
  final bool isDestructive;
  final bool isWide;
  final VoidCallback onTap;

  const _PortalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.height,
    this.isAccent = false,
    this.isDestructive = false,
    this.isWide = false,
    required this.onTap,
  });

  @override
  State<_PortalCard> createState() => _PortalCardState();
}

class _PortalCardState extends State<_PortalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color baseColor = Colors.white;
    if (widget.isAccent) baseColor = Colors.cyanAccent;
    if (widget.isDestructive) baseColor = Colors.redAccent;

    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleCtrl,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_scaleCtrl.value * 0.03),
            child: child,
          );
        },
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: widget.isAccent
                ? AtaraxiaPalette.accentCardGradient
                : widget.isDestructive
                ? LinearGradient(
                    colors: [
                      Colors.redAccent.withOpacity(0.08),
                      Colors.redAccent.withOpacity(0.03),
                    ],
                  )
                : AtaraxiaPalette.cardInnerGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isAccent
                  ? AtaraxiaPalette.glacialTeal.withOpacity(0.25)
                  : widget.isDestructive
                  ? Colors.redAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: widget.isAccent
                ? [
                    BoxShadow(
                      color: AtaraxiaPalette.glacialTeal.withOpacity(0.12),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ]
                : widget.isDestructive
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ]
                : [],
          ),
          child: widget.isWide
              ? _buildWideLayout(baseColor)
              : _buildStackedLayout(baseColor),
        ),
      ),
    );
  }

  Widget _buildStackedLayout(Color baseColor) {
    // Use teal as the effective accent color for isAccent cards
    final effectiveColor = widget.isAccent
        ? AtaraxiaPalette.glacialTeal
        : baseColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(widget.icon, color: effectiveColor.withOpacity(0.9), size: 24),
        const Spacer(),
        Text(
          widget.title,
          maxLines: 1,
          style: TextStyle(
            color: effectiveColor,
            fontFamily: 'Serif',
            fontStyle: FontStyle.italic,
            fontSize: 20,
            height: 1.1,
            shadows: widget.isAccent
                ? [
                    Shadow(
                      color: AtaraxiaPalette.glacialTeal.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 10,
            letterSpacing: 0.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(Color baseColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          // 🚀 Expanded here prevents long titles from breaking the horizontal layout
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: baseColor.withOpacity(0.8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: baseColor,
                        fontFamily: 'Serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white.withOpacity(0.2),
          size: 14,
        ),
      ],
    );
  }
}

// ─── THE NETWORK MODAL (Social Links) ───
class _CommunityModal extends StatefulWidget {
  const _CommunityModal();

  @override
  State<_CommunityModal> createState() => _CommunityModalState();
}

class _CommunityModalState extends State<_CommunityModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLink(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Link launch failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 0 : 32.0,
                  vertical: 40.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
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
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.1, 0.6),
                      child: Text(
                        "THE\nATARAXIA",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 72 : 48,
                          fontFamily: 'Times New Roman',
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.2, 0.7),
                      child: Text(
                        "You are not the only one remembering.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: isTablet ? 18 : 14,
                          fontFamily: 'Serif',
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.3, 0.8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MANIFESTO",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: isTablet ? 12 : 10,
                              fontFamily: 'Courier',
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Ataraxia is a quiet rebellion against the deafening, ephemeral noise of the modern web. It is a dimensional sanctuary built to trap fleeting moments and crystallize them into permanent echoes. We do not track you. We do not harvest you. We simply provide the void—you provide the frequencies. Anchor your identity, manifest your visions, and preserve what actually matters.",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: isTablet ? 18 : 15,
                              height: 1.6,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 60 : 48),

                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.4, 1.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "LINKS",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: isTablet ? 12 : 10,
                              fontFamily: 'Courier',
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 🚀 THE WIRED UP SOCIAL LINKS
                          _SocialLinkTile(
                            platform: "INSTAGRAM",
                            handle: "@ataraxia.exe",
                            isTablet: isTablet,
                            onTap: () =>
                                _openLink('https://instagram.com/ataraxia.exe'),
                          ),
                          _SocialLinkTile(
                            platform: "YOUTUBE",
                            handle: "The Void Archives",
                            isTablet: isTablet,
                            onTap: () => _openLink(
                              'https://youtube.com/@themadbrogrammers',
                            ), // Replace with your actual channel link
                          ),
                          // _SocialLinkTile(
                          //   platform: "DISCORD",
                          //   handle: "The Collective",
                          //   isTablet: isTablet,
                          //   onTap: () => _openLink(
                          //     'https://discord.gg/your_invite_code',
                          //   ), // Replace with your actual invite
                          // ),
                          _SocialLinkTile(
                            platform: "WEBSITE",
                            handle: "theataraxia.web.app", //ataraxia.space
                            isTablet: isTablet,
                            isLast: true,
                            onTap: () =>
                                _openLink('https://theataraxia.web.app'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLinkTile extends StatelessWidget {
  final String platform;
  final String handle;
  final bool isTablet;
  final bool isLast;
  final VoidCallback onTap;

  const _SocialLinkTile({
    required this.platform,
    required this.handle,
    required this.isTablet,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.white.withOpacity(0.05),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: isTablet ? 24 : 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "[ $platform ]",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: isTablet ? 14 : 11,
                fontFamily: 'Courier',
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              handle,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 18 : 16,
                fontFamily: 'Serif',
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameModal extends StatefulWidget {
  final Identity identity;
  final ValueChanged<String> onNameUpdated;

  const _RenameModal({required this.identity, required this.onNameUpdated});

  @override
  State<_RenameModal> createState() => _RenameModalState();
}

// 1. Add the Observer
class _RenameModalState extends State<_RenameModal>
    with WidgetsBindingObserver {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;

  bool _isChecking = false;
  bool _isTaken = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to raw engine
    _ctrl.text = widget.identity.name;
  }

  void _onTextChanged(String val) {
    final query = val.trim().toLowerCase();

    if (query == widget.identity.name.toLowerCase() || query.isEmpty) {
      setState(() {
        _isTaken = false;
        _isChecking = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _isTaken = false;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final exists = await IdentityStore.nameExists(query);
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isTaken = exists;
        });
      }
    });
  }

  void _executeRename() async {
    if (_isTaken || _isChecking || _ctrl.text.trim().isEmpty) return;

    if (_ctrl.text.trim().toLowerCase() == widget.identity.name.toLowerCase()) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final updated = await IdentityStore.updateName(_ctrl.text.trim());
      widget.onNameUpdated(updated.name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // 2. Trigger rebuild on keyboard pop
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    // 3. Bypass the trap
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // 4. Turn off the default abrupt snapping
      resizeToAvoidBottomInset: false,

      // 5. ANIMATE IT OURSELVES
      body: AnimatedPadding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,

        // 6. THE CENTERING TRICK: LayoutBuilder + ScrollView
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                // Forces it to fill the screen when keyboard is closed
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 1,
                        )
                      : Container(
                          width: 500,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 0 : 40,
                            vertical:
                                40, // Padding so it doesn't hit the absolute top when pushed
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.drive_file_rename_outline_rounded,
                                color: Colors.white.withOpacity(0.5),
                                size: isTablet ? 56 : 40,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                "REDEFINE IDENTITY",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 18 : 14,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 32),
                              TextField(
                                controller: _ctrl,
                                autofocus: true,
                                maxLength: 12,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 64 : 32,
                                  fontFamily: 'Times New Roman',
                                ),
                                textAlign: TextAlign.center,
                                cursorColor: Colors.white,
                                decoration: InputDecoration(
                                  counterText: "",
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderSide: BorderSide(color: Colors.white),
                                  ),
                                ),
                                onChanged: _onTextChanged,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 20,
                                child: _isChecking
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          color: Colors.white54,
                                          strokeWidth: 1,
                                        ),
                                      )
                                    : _isTaken
                                    ? Text(
                                        "IDENTITY ALREADY EXISTING",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: isTablet ? 12 : 10,
                                          letterSpacing: 2,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 24),
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity:
                                    (!_isTaken &&
                                        !_isChecking &&
                                        _ctrl.text.trim().isNotEmpty)
                                    ? 1.0
                                    : 0.0,
                                child: GestureDetector(
                                  onTap: _executeRename,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 48 : 32,
                                      vertical: isTablet ? 18 : 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      "CONFIRM",
                                      style: TextStyle(
                                        color: Colors.white,
                                        letterSpacing: 4,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isTablet ? 12 : 10,
                                      ),
                                    ),
                                  ),
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
            offset: Offset(0, 20 * (1 - slide)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _FrequenciesModal extends StatefulWidget {
  final String userId;
  const _FrequenciesModal({required this.userId});

  @override
  State<_FrequenciesModal> createState() => _FrequenciesModalState();
}

class _FrequenciesModalState extends State<_FrequenciesModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  List<String> _frequencies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadFrequencies();
  }

  Future<void> _loadFrequencies() async {
    final tags = await SupabaseService.fetchUserFrequencies(widget.userId);
    if (mounted) {
      setState(() {
        _frequencies = tags;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 0 : 32.0,
                vertical: 40.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
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
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  _FadeIn(
                    ctrl: _animCtrl,
                    interval: const Interval(0.1, 0.6),
                    child: Text(
                      "CORE\nFREQUENCIES",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 64 : 40,
                        fontFamily: 'Times New Roman',
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeIn(
                    ctrl: _animCtrl,
                    interval: const Interval(0.2, 0.7),
                    child: Text(
                      "Your psychological reflection, built from your subconscious choices in the void.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: isTablet ? 16 : 12,
                        fontFamily: 'Serif',
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                              strokeWidth: 1.5,
                            ),
                          )
                        : _frequencies.isEmpty
                        ? Center(
                            child: Text(
                              "THE VOID IS STILL LEARNING YOU.",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.2),
                                fontFamily: 'Courier',
                                letterSpacing: 4,
                                fontSize: 10,
                              ),
                            ),
                          )
                        : _FadeIn(
                            ctrl: _animCtrl,
                            interval: const Interval(0.4, 1.0),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 16,
                              children: _frequencies.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: Colors.cyanAccent.withOpacity(0.2),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(
                                          0.05,
                                        ),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    tag.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontFamily: 'Courier',
                                      fontSize: 11,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                );
                              }).toList(),
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
  }
}

// ─── THE SYNCHRONIZATION (UPDATE) MODAL ───
class _UpdateModal extends StatefulWidget {
  final String newVersion;
  final String updateUrl;
  final bool isForced; // 🚀 NEW FLAG

  const _UpdateModal({
    required this.newVersion,
    required this.updateUrl,
    required this.isForced,
  });

  @override
  State<_UpdateModal> createState() => _UpdateModalState();
}

class _UpdateModalState extends State<_UpdateModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _initiateSync() async {
    HapticFeedback.heavyImpact();
    final uri = Uri.parse(widget.updateUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Failed to open update URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      // 🚀 Red for forced, Cyan for optional
                      color: widget.isForced
                          ? Colors.redAccent.withOpacity(0.3)
                          : Colors.cyanAccent.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isForced
                            ? Colors.redAccent.withOpacity(0.1)
                            : Colors.cyanAccent.withOpacity(0.1),
                        blurRadius: 60,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FadeIn(
                        ctrl: _animCtrl,
                        interval: const Interval(0.0, 0.5),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isForced
                                ? Colors.redAccent.withOpacity(0.1)
                                : Colors.cyanAccent.withOpacity(0.1),
                          ),
                          child: Icon(
                            widget.isForced
                                ? Icons.warning_rounded
                                : Icons.system_update_alt_rounded,
                            color: widget.isForced
                                ? Colors.redAccent
                                : Colors.cyanAccent,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _FadeIn(
                        ctrl: _animCtrl,
                        interval: const Interval(0.2, 0.7),
                        child: Text(
                          widget.isForced
                              ? "CRITICAL SHIFT\nDETECTED"
                              : "NEW FREQUENCY\nDETECTED",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 32 : 24,
                            fontFamily: 'Times New Roman',
                            height: 1.1,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FadeIn(
                        ctrl: _animCtrl,
                        interval: const Interval(0.3, 0.8),
                        child: Text(
                          widget.isForced
                              ? "Version ${widget.newVersion} is a structural mandate. You cannot proceed in the void without synchronizing."
                              : "Version ${widget.newVersion} is available in the void. A dimensional shift requires your synchronization.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontFamily: 'Serif',
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _FadeIn(
                        ctrl: _animCtrl,
                        interval: const Interval(0.5, 1.0),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _initiateSync,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.isForced
                                      ? Colors.redAccent.withOpacity(0.15)
                                      : Colors.cyanAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: widget.isForced
                                        ? Colors.redAccent.withOpacity(0.5)
                                        : Colors.cyanAccent.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  "INITIATE SYNC",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: widget.isForced
                                        ? Colors.redAccent
                                        : Colors.cyanAccent,
                                    fontFamily: 'Courier',
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            // 🚀 Remove DISMISS button entirely if forced
                            if (!widget.isForced) ...[
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    "LINGER IN THE PAST",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}

class SupportModal extends StatefulWidget {
  final Identity? identity;

  const SupportModal({super.key, this.identity});

  @override
  State<SupportModal> createState() => _SupportModalState();
}

class _SupportModalState extends State<SupportModal>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  // 🚀 ANIMATION STATE
  late final AnimationController _enterCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Smooth Entrance Scale/Fade
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Continuous Radar Pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);

    // Haptic feedback when the user taps the text field
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) HapticFeedback.selectionClick();
      setState(() {}); // Rebuild for border glow
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  Future<void> _sendSignal() async {
    if (_ctrl.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      _focusNode.requestFocus();
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.heavyImpact();

    final message = _ctrl.text.trim();

    final uri = Uri.parse(
      'mailto:theataraxia.exe@gmail.com'
      '?subject=Signal from ${widget.identity?.id ?? "unknown"}'
      '&body=$message',
    );

    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint("Signal failed: $e");
    }

    // Brief delay so the user sees the transmission effect before closing
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: AnimatedPadding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuart,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _enterCtrl,
                    builder: (context, child) {
                      final curve = Curves.easeOutCubic.transform(
                        _enterCtrl.value,
                      );
                      return Opacity(
                        opacity: curve,
                        child: Transform.scale(
                          scale: 0.95 + (0.05 * curve),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: isTablet ? 500 : 400,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 40,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 40 : 32,
                        vertical: 40,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.15),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.05),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 30,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ─── THE PULSING RADAR ───
                          SizedBox(
                            height: 80,
                            width: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1.0 + (_pulseCtrl.value * 0.8),
                                      child: Opacity(
                                        opacity: 1.0 - _pulseCtrl.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.cyanAccent
                                                  .withOpacity(0.5),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.cyanAccent.withOpacity(0.1),
                                  ),
                                  child: Icon(
                                    Icons.radar_rounded,
                                    color: Colors.cyanAccent.withOpacity(0.8),
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ─── TITLE & BODY ───
                          Text(
                            "TRANSMIT SIGNAL",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isTablet ? 18 : 15,
                              fontFamily: 'Courier',
                              letterSpacing: 4,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "The void is listening.\nDescribe the anomaly.\nWe will respond through the network.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: isTablet ? 14 : 12,
                              fontFamily: 'Georgia',
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ─── PREMIUM TEXT INPUT ───
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _focusNode.hasFocus
                                    ? Colors.cyanAccent.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.1),
                                width: _focusNode.hasFocus ? 1.5 : 1.0,
                              ),
                              boxShadow: _focusNode.hasFocus
                                  ? [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(
                                          0.1,
                                        ),
                                        blurRadius: 20,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focusNode,
                              maxLines: 4,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              cursorColor: Colors.cyanAccent,
                              decoration: InputDecoration(
                                hintText: "Describe what went wrong...",
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontFamily: 'Georgia',
                                  fontStyle: FontStyle.italic,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // ─── CTA BUTTON ───
                          _isSending
                              ? const SizedBox(
                                  height: 56,
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
                                )
                              : GestureDetector(
                                  onTap: _sendSignal,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: Colors.cyanAccent.withOpacity(
                                          0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Text(
                                      "SEND SIGNAL",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.cyanAccent,
                                        letterSpacing: 4,
                                        fontSize: 11,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 24),

                          // ─── DISMISS ───
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            child: Text(
                              "DISMISS",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 10,
                                fontFamily: 'Courier',
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
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
    );
  }
}

// ─── PREMIUM UI: ASCENDED IDENTITY TEXT ───
class AscendedIdentityText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const AscendedIdentityText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<AscendedIdentityText> createState() => _AscendedIdentityTextState();
}

class _AscendedIdentityTextState extends State<AscendedIdentityText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slide = Curves.easeInOut.transform(_controller.value);

        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-2.8 + (slide * 4.2), 0),
              end: Alignment(-0.8 + (slide * 4.2), 0),
              colors: const [
                Color(0xFFECECEC),
                Color(0xFF9B59FF),
                Color(0xFF00E5FF),
                Color(0xFFFF9BF5),
                Color(0xFF00E5FF),
                Color(0xFF9B59FF),
                Color(0xFFF8F8F8),
              ],
              stops: const [0.0, 0.18, 0.35, 0.50, 0.65, 0.82, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: widget.style.copyWith(
              color: Colors.white,
              shadows: [
                Shadow(
                  color: const Color(0xFF7B2FFF).withOpacity(.35),
                  blurRadius: 18,
                ),
                Shadow(
                  color: const Color(0xFF00E5FF).withOpacity(.22),
                  blurRadius: 28,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnimatedCount extends ImplicitlyAnimatedWidget {
  final int value;
  final TextStyle style;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    Duration duration = const Duration(milliseconds: 600),
  }) : super(duration: duration);

  @override
  _AnimatedCountState createState() => _AnimatedCountState();
}

class _AnimatedCountState extends AnimatedWidgetBaseState<AnimatedCount> {
  IntTween? _intTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _intTween =
        visitor(
              _intTween,
              widget.value,
              (dynamic value) => IntTween(begin: value as int),
            )
            as IntTween?;
  }

  @override
  Widget build(BuildContext context) {
    final value = _intTween?.evaluate(animation) ?? widget.value;

    return Text("$value", style: widget.style);
  }
}
