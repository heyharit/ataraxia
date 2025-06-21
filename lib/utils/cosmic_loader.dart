import 'dart:math';
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────
/// COSMIC LOADER (PUBLIC WIDGET)
/// Use this everywhere:
/// → const CosmicLoaderWidget()
/// ─────────────────────────────────────────────
class CosmicLoaderWidget extends StatefulWidget {
  const CosmicLoaderWidget({super.key});

  @override
  State<CosmicLoaderWidget> createState() => _CosmicLoaderWidgetState();
}

class _CosmicLoaderWidgetState extends State<CosmicLoaderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const _CenteredLoader();
  }
}

/// ─────────────────────────────────────────────
/// INTERNAL WRAPPER (keeps rebuilds clean)
/// ─────────────────────────────────────────────
class _CenteredLoader extends StatefulWidget {
  const _CenteredLoader();

  @override
  State<_CenteredLoader> createState() => _CenteredLoaderState();
}

class _CenteredLoaderState extends State<_CenteredLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
      child: _CosmicVisual(anim: _ctrl),
    );
  }
}

/// ─────────────────────────────────────────────
/// PURE VISUAL (no logic, reusable)
/// ─────────────────────────────────────────────
class _CosmicVisual extends StatelessWidget {
  final Animation<double> anim;

  const _CosmicVisual({required this.anim});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // ─── BREATHING RING ───
              Container(
                width: 60 + (anim.value * 40),
                height: 60 + (anim.value * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(
                      0.1 * (1 - anim.value),
                    ),
                    width: 1,
                  ),
                ),
              ),

              // ─── ROTATING SQUARE ───
              Transform.rotate(
                angle: anim.value * pi,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ─── CORE DOT ───
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 20 * anim.value,
                      spreadRadius: 10 * anim.value,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}