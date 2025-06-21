import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase/supabase_service.dart';

class ConstellationScreen extends StatefulWidget {
  const ConstellationScreen({super.key});

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen>
    with TickerProviderStateMixin {
  int _activeWanderers = 1;
  final List<_EchoData> _activeEchoes = [];
  final Random _random = Random();

  late final AnimationController _pulseCtrl;
  late final AnimationController _ambientCtrl;

  late final List<_NetworkNode> _nodes;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Slowed down for grander feel
    )..repeat();

    // 🚀 VOXEL NODES: Distributed across the void
    _nodes = List.generate(
      60,
      (index) => _NetworkNode(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 2.0 + _random.nextDouble() * 3.0, // Slightly larger cubes
        phase: _random.nextDouble() * pi * 2,
        spinSpeed: (_random.nextDouble() - 0.5) * 2, // Unique rotation speed
      ),
    );

    _setupConstellationListeners();
  }

  void _setupConstellationListeners() {
    final channel = SupabaseService.constellationChannel;

    // 🚀 THE FIX: Adapted for the new Supabase List<SinglePresenceState> API
    void updateCount() {
      final state = channel.presenceState();

      int count = 0;
      // Loop through the list of states and sum up the connected clients
      for (final presenceGroup in state) {
        count += presenceGroup.presences.length;
      }

      if (mounted) {
        setState(() {
          _activeWanderers = count > 0 ? count : 1;
        });
      }
    }

    // Initial check in case it's already synced
    updateCount();

    channel.onPresenceSync((payload) {
      updateCount();
    });

    channel.onBroadcast(
      event: 'ritual_echo',
      callback: (payload) {
        if (!mounted) return;
        _spawnEcho();
      },
    );
  }

  void _spawnEcho() {
    HapticFeedback.lightImpact();
    final newEcho = _EchoData(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      xOffset: 0.1 + (_random.nextDouble() * 0.8),
      yOffset: 0.1 + (_random.nextDouble() * 0.8),
    );

    setState(() {
      _activeEchoes.add(newEcho);
    });
  }

  void _removeEcho(String id) {
    setState(() {
      _activeEchoes.removeWhere((e) => e.id == id);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Deep Digital Grid Background
          CustomPaint(painter: _AbyssalGridPainter(), size: Size.infinite),

          // 2. The Voxel Constellation Map
          AnimatedBuilder(
            animation: _ambientCtrl,
            builder: (context, child) {
              return CustomPaint(
                painter: _VoxelMatrixPainter(
                  nodes: _nodes,
                  animValue: _ambientCtrl.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // 3. Render Every Global Ritual Echo
          ..._activeEchoes.map((echo) {
            return Positioned(
              left: screenSize.width * echo.xOffset - 100,
              top: screenSize.height * echo.yOffset - 100,
              child: _DigitalRipple(
                key: ValueKey(echo.id),
                onComplete: () => _removeEcho(echo.id),
              ),
            );
          }),

          // 4. Center Typography
          Center(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                return Opacity(
                  opacity:
                      0.4 +
                      (Curves.easeInOutSine.transform(_pulseCtrl.value) * 0.6),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$_activeWanderers",
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 64,
                      fontFamily: 'Courier', // Changed for digital feel
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.cyanAccent, blurRadius: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _activeWanderers == 1
                        ? "WANDERER IN THE VOID"
                        : "WANDERERS SYNCHRONIZING",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontFamily: 'Courier',
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🚀 THE FIX: Moved the Invisible Test Button down here!
          // Now it sits BEHIND the exit button in the Z-Index hierarchy.
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _spawnEcho();
                SupabaseService.emitRitualEcho();
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),

          // 5. Exit Button (Always on TOP now!)
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 24,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              // Wrap in MouseRegion/HitTest to ensure absolute tap priority
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle, // Digital look
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withOpacity(0.5),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.cyanAccent,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HIGH PERFORMANCE DIGITAL PAINTERS ───

class _NetworkNode {
  final double x;
  final double y;
  final double size;
  final double phase;
  final double spinSpeed;

  _NetworkNode({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.spinSpeed,
  });
}

class _VoxelMatrixPainter extends CustomPainter {
  final List<_NetworkNode> nodes;
  final double animValue;

  _VoxelMatrixPainter({required this.nodes, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paintCube = Paint()..color = Colors.cyanAccent.withOpacity(0.8);
    final paintLine = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.08)
      ..strokeWidth = 0.8;

    final threshold = size.width * 0.25;

    final points = nodes
        .map((n) => Offset(n.x * size.width, n.y * size.height))
        .toList();

    // 1. Draw the laser-thin connections
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final dist = (points[i] - points[j]).distance;
        if (dist < threshold) {
          paintLine.color = Colors.cyanAccent.withOpacity(
            (0.15 * (1 - (dist / threshold))).clamp(0.0, 0.15),
          );
          canvas.drawLine(points[i], points[j], paintLine);
        }
      }
    }

    // 2. Draw rotating digital cubes
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final pt = points[i];

      final breathe = (sin(animValue * pi * 4 + n.phase) + 1) / 2;
      final currentSize = n.size + (breathe * 2.0);
      final rotation = animValue * pi * 2 * n.spinSpeed;

      // Hardware accelerated rotation math
      canvas.save();
      canvas.translate(pt.dx, pt.dy);
      canvas.rotate(rotation);

      paintCube.color = Colors.cyanAccent.withOpacity(0.2 + (0.6 * breathe));

      // Draw Square (Voxel) instead of circle
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: currentSize,
          height: currentSize,
        ),
        paintCube,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _VoxelMatrixPainter oldDelegate) => true;
}

// ─── AMBIENT GRID BACKGROUND ───
class _AbyssalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.02)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;

    // Vertical Lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal Lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Add a dark radial gradient to simulate depth
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── GEOMETRIC DIGITAL RIPPLE ───
class _EchoData {
  final String id;
  final double xOffset;
  final double yOffset;
  _EchoData({required this.id, required this.xOffset, required this.yOffset});
}

class _DigitalRipple extends StatefulWidget {
  final VoidCallback onComplete;
  const _DigitalRipple({super.key, required this.onComplete});

  @override
  State<_DigitalRipple> createState() => _DigitalRippleState();
}

class _DigitalRippleState extends State<_DigitalRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Faster, sharper pulse
    );
    _animCtrl.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        final scale = 1.0 + (_animCtrl.value * 4.0); // Expands further
        final opacity = 1.0 - Curves.easeInQuad.transform(_animCtrl.value);
        final rotation = _animCtrl.value * pi / 2; // Spins 90 degrees

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle, // Diamond/Square ripple
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.8),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.rectangle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.white, blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
