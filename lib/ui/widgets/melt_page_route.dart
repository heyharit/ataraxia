import 'package:flutter/material.dart';
import 'dart:ui';
import '../navigation/swipe_direction.dart';

class MeltPageRoute<T> extends PageRoute<T> {
  late final AnimationController meltController;
  MeltPageRoute({
    required this.builder,
    required this.direction,
    RouteSettings? settings,
  }) : super(settings: settings);

  final WidgetBuilder builder;
  final SwipeDirection direction;

  bool _installed = false;

  @override
  void install() {
    super.install();
    meltController = controller!;
    _installed = true;
  }

  bool get isReady => _installed;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true; // 👈 THIS WAS MISSING

  @override
  Duration get transitionDuration => const Duration(milliseconds: 520);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final v = animation.value.clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(v);

    late Offset offset;
    switch (direction) {
      case SwipeDirection.left:
        offset = Offset(1 - eased, 0);
        break;
      case SwipeDirection.right:
        offset = Offset(eased - 1, 0);
        break;
      case SwipeDirection.up:
        offset = Offset(0, 1 - eased);
        break;
      case SwipeDirection.down:
        offset = Offset(0, eased - 1);
        break;
    }

    return Transform.translate(
      offset: offset * 140,
      child: Transform.scale(
        scale: lerpDouble(0.94, 1.0, eased) ?? 1.0,
        child: child,
      ),
    );
  }
}
