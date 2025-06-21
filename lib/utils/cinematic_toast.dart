import 'dart:ui';
import 'package:flutter/material.dart';

void showCinematicToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _CinematicToastWidget(
      message: message,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _CinematicToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _CinematicToastWidget({required this.message, required this.onDismiss});

  @override
  State<_CinematicToastWidget> createState() => _CinematicToastWidgetState();
}

class _CinematicToastWidgetState extends State<_CinematicToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // 🚀 Upgraded timing for a more dramatic, premium feel
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart);

    // Slight pop-in effect
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    // Glides up from slightly lower down
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));

    _playSequence();
  }

  void _playSequence() async {
    await _ctrl.forward();
    await Future.delayed(
      const Duration(seconds: 3),
    ); // Gives them time to read it
    if (mounted) {
      await _ctrl.reverse();
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 30, // below status bar
      left: 0,
      right: 0,
      child: IgnorePointer(
        // 🚀 THE MAGIC FIX: This entirely removes the ugly yellow/red underlines!
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnim.value,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ScaleTransition(scale: _scaleAnim, child: child),
                ),
              );
            },
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(100),
                      // Glowing cyan border
                      border: Border.all(
                        color: Colors.cyanAccent.withOpacity(0.3),
                        width: 1,
                      ),
                      // Soft ambient under-glow
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.1),
                          blurRadius: 40,
                          spreadRadius: -5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome, // Better icon for the void theme
                          color: Colors.cyanAccent.withOpacity(0.9),
                          size: 18,
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          // 👈 FIX
                          child: Text(
                            widget.message.toUpperCase(),
                            maxLines: 2, // optional
                            overflow: TextOverflow.ellipsis, // optional
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'Courier',
                              letterSpacing: 3,
                              fontWeight: FontWeight.w900,
                            ),
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
    );
  }
}
