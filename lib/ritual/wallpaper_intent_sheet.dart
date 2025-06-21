import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 🚀 IMPORT YOUR GLOBAL HANDLERS
import '../data/models/moment.dart';
import '../utils/moment_action_handler.dart';
import '../utils/moment_actions.dart';
import '../utils/share_service.dart'; // For ShareStyle

enum WallpaperVariant { immersive, still }

enum WallpaperLocation { home, lock, both }

class WallpaperConfig {
  final WallpaperVariant variant;
  final WallpaperLocation location;
  WallpaperConfig(this.variant, this.location);
}

class WallpaperIntentSheet extends StatefulWidget {
  final Moment moment; // 🚀 NEW: We need the moment to save/share it!

  const WallpaperIntentSheet({super.key, required this.moment});

  @override
  State<WallpaperIntentSheet> createState() => _WallpaperIntentSheetState();
}

class _WallpaperIntentSheetState extends State<WallpaperIntentSheet>
    with SingleTickerProviderStateMixin {
  WallpaperVariant _selectedVariant = WallpaperVariant.immersive;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🚀 Trigger global share/save logic
  void _triggerAction(MomentAction action) {
    HapticFeedback.heavyImpact();
    // We pop the sheet first so the cinematic overlays can take over the screen
    Navigator.pop(context);

    // Give the pop animation a tiny moment to clear before launching overlay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        handleMomentAction(
          context: context,
          moment: widget.moment,
          action: action,
          // If they share from the Ritual screen, give it the moody Memory style!
          style: ShareStyle.memory,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),

                // 🚀 NEW: Quick Actions Bar (Save & Share)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QuickActionBtn(
                      icon: Icons.bookmark_add_rounded,
                      label: "SAVE ECHO",
                      onTap: () => _triggerAction(MomentAction.save),
                    ),
                    const SizedBox(width: 16),
                    _QuickActionBtn(
                      icon: Icons.ios_share_rounded,
                      label: "TRANSMIT",
                      onTap: () => _triggerAction(MomentAction.share),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Text(
                  'APPLY TO DEVICE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    letterSpacing: 4.0,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                _buildVariantToggle(),
                const SizedBox(height: 24),
                _buildAnimatedOption(
                  0,
                  'Home Screen',
                  Icons.home_filled,
                  WallpaperLocation.home,
                ),
                const SizedBox(height: 12),
                _buildAnimatedOption(
                  1,
                  'Lock Screen',
                  Icons.lock_outline_rounded,
                  WallpaperLocation.lock,
                ),
                const SizedBox(height: 12),
                _buildAnimatedOption(
                  2,
                  'Both Screens',
                  Icons.layers_outlined,
                  WallpaperLocation.both,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleBtn(
              label: 'Immersive',
              isSelected: _selectedVariant == WallpaperVariant.immersive,
              onTap: () =>
                  setState(() => _selectedVariant = WallpaperVariant.immersive),
            ),
          ),
          Expanded(
            child: _ToggleBtn(
              label: 'Still',
              isSelected: _selectedVariant == WallpaperVariant.still,
              onTap: () =>
                  setState(() => _selectedVariant = WallpaperVariant.still),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedOption(
    int index,
    String title,
    IconData icon,
    WallpaperLocation location,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _controller,
              curve: Interval(
                0.2 + (index * 0.1),
                1.0,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: Interval(0.2 + (index * 0.1), 1.0, curve: Curves.easeOut),
        ),
        child: _PremiumOptionTile(
          title: title,
          icon: icon,
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context, WallpaperConfig(_selectedVariant, location));
          },
        ),
      ),
    );
  }
}

// 🚀 NEW: The sleek Quick Action buttons for Save/Share
class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.cyanAccent, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _PremiumOptionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.cyanAccent.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            color: Colors.black.withOpacity(0.2),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(0.2),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
