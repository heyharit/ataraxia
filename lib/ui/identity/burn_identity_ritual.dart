import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/identity.dart';
import '../../data/identity_store.dart';
import 'ash_dissolve_painter.dart';

class IdentityBurnRitual extends StatefulWidget {
  final Identity identity;

  const IdentityBurnRitual({super.key, required this.identity});

  @override
  State<IdentityBurnRitual> createState() => _IdentityBurnRitualState();
}

class _IdentityBurnRitualState extends State<IdentityBurnRitual>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _confirmCtrl = TextEditingController();
  bool _armed = false;
  bool _burning = false;
  int _lastHapticTick = 0;

  late final AnimationController _ambientCtrl;
  late final AnimationController _ashController;
  late final AnimationController _holdController;

  late final Animation<double> _ashOpacity;
  late final Animation<double> _ashScale;
  late final Animation<double> _holdProgress;

  bool get _nameMatches => _confirmCtrl.text.trim() == widget.identity.name;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    // 1. Slow breathing background ember
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // 2. The Final Ash Dissolve
    _ashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ashOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ashController, curve: Curves.easeOut));
    _ashScale = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _ashController, curve: Curves.easeIn));

    // 3. The Hold-to-Burn Engine
    _holdController =
        AnimationController(
            vsync: this,
            duration: const Duration(
              milliseconds: 1500,
            ), // Slightly longer for tension
          )
          ..addListener(_onHoldTick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _burn();
            }
          });

    _holdProgress = CurvedAnimation(
      parent: _holdController,
      curve: Curves.easeInExpo, // Starts slow, accelerates at the end
    );
  }

  void _onHoldTick() {
    if (_burning) return;

    // Escalating Haptic Heartbeat
    int currentTick = (_holdProgress.value * 20).toInt();
    if (currentTick > _lastHapticTick) {
      if (currentTick > 15) {
        HapticFeedback.heavyImpact();
      } else if (currentTick > 8) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
      _lastHapticTick = currentTick;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confirmCtrl.dispose();
    _ambientCtrl.dispose();
    _ashController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _ashController,
          _ambientCtrl,
          _holdController,
        ]),
        builder: (_, child) {
          // Calculate the escalating red intensity based on hold progress
          final emberGlow =
              0.1 + (_ambientCtrl.value * 0.1) + (_holdProgress.value * 0.8);

          // Violent screen shake at the very end of the hold
          final shake = _holdProgress.value > 0.8
              ? sin(DateTime.now().millisecondsSinceEpoch) *
                    4 *
                    (_holdProgress.value - 0.8)
              : 0.0;

          return Stack(
            children: [
              // ─── 1. REACTIVE BACKGROUND EMBER ───
              Positioned.fill(
                child: Opacity(
                  // Fade background out as ash progresses
                  opacity: 1.0 - _ashController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.8),
                        radius: 1.5,
                        colors: [
                          Colors.redAccent.withOpacity(emberGlow * 0.6),
                          Colors.black,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── 2. MAIN CONTENT SCALED BY ASH ───
              Transform.translate(
                offset: Offset(shake, 0),
                child: Transform.scale(
                  scale: _ashScale.value,
                  child: Opacity(
                    opacity: _ashOpacity.value,
                    child: SafeArea(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutQuart,
                        padding: EdgeInsets.only(
                          bottom: keyboardHeight > 0 ? keyboardHeight * 0.6 : 0,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            isTablet ? 60 : 32,
                            24,
                            isTablet ? 60 : 32,
                            40,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header & Close
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: Colors.redAccent,
                                    size: 28,
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.05),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Spacer(),

                              // Typography
                              Text(
                                'BURN\nIDENTITY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 72 : 52,
                                  fontFamily: 'Times New Roman',
                                  height: 0.95,
                                  letterSpacing: -2.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.redAccent.withOpacity(
                                        _holdProgress.value,
                                      ),
                                      blurRadius: 30,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'This action is absolute.\nAll echoes will be severed.\nAtaraxia will forget you entirely.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: isTablet ? 16 : 14,
                                  fontFamily: 'Courier',
                                  height: 1.6,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 60),

                              // Input Field
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _armed
                                        ? Colors.redAccent.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: TextField(
                                  controller: _confirmCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontFamily: 'Serif',
                                    fontStyle: FontStyle.italic,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type "${widget.identity.name}"',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.2),
                                      fontFamily: 'Serif',
                                      fontStyle: FontStyle.italic,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (_) {
                                    final matches = _nameMatches;
                                    if (matches != _armed) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _armed = matches);
                                    }
                                  },
                                ),
                              ),

                              const Spacer(),

                              // ─── TACTILE HOLD BUTTON ───
                              GestureDetector(
                                onTapDown: (_) {
                                  if (_armed && !_burning) {
                                    _lastHapticTick = 0;
                                    _holdController.forward();
                                  } else {
                                    HapticFeedback.heavyImpact(); // Error thud
                                  }
                                },
                                onTapUp: (_) => _cancelHold(),
                                onTapCancel: _cancelHold,
                                child: Container(
                                  height: 64,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                    color: Colors.white.withOpacity(0.03),
                                    border: Border.all(
                                      color: _armed
                                          ? Colors.redAccent.withOpacity(0.5)
                                          : Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    children: [
                                      // The expanding fluid red fill
                                      FractionallySizedBox(
                                        widthFactor: _holdProgress.value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.redAccent.withOpacity(
                                                  0.5,
                                                ),
                                                Colors.redAccent,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.redAccent
                                                    .withOpacity(0.5),
                                                blurRadius: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // The Label
                                      Center(
                                        child: Text(
                                          _burning
                                              ? 'INCINERATING...'
                                              : _armed
                                              ? 'HOLD TO BURN'
                                              : 'CONFIRM NAME TO UNLOCK',
                                          style: TextStyle(
                                            color: _holdProgress.value > 0.5
                                                ? Colors.white
                                                : (_armed
                                                      ? Colors.redAccent
                                                      : Colors.white38),
                                            fontSize: 11,
                                            fontFamily: 'Courier',
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 4.0,
                                          ),
                                        ),
                                      ),
                                    ],
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

              // ─── 3. THE ASH PAINTER (Top Layer) ───
              if (_burning)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: AshDissolvePainter(
                        progress: _ashController.value,
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

  void _cancelHold() {
    if (!_holdController.isCompleted && !_burning) {
      _holdController.reverse();
    }
  }

  Future<void> _burn() async {
    if (_burning) return;

    setState(() => _burning = true);
    HapticFeedback.heavyImpact();

    // 1. Ash dissolve
    await _ashController.forward();

    if (!mounted) return;

    // FIX: Capture the navigator before we replace the route and unmount the widget
    final nav = Navigator.of(context);

    // 2. Hard blackout (replace, don’t wait)
    nav.pushReplacement(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) =>
            const Scaffold(backgroundColor: Colors.black),
        transitionDuration: Duration.zero,
      ),
    );

    // 3. Destroy data OFF-SCREEN
    await IdentityStore.burnIdentity(confirmName: widget.identity.name);

    // 4. Reset app state using the captured navigator
    nav.pushNamedAndRemoveUntil('/', (_) => false);
  }
}
