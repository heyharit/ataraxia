import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// --- PAINTERS (Refined for better "Glow") ---

class ScanlinePainter extends CustomPainter {
  final double progress;
  ScanlinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.cyanAccent.withOpacity(0.05),
              Colors.cyanAccent.withOpacity(0.15),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(0, size.height * progress - 15, size.width, 30),
          );

    double y = size.height * progress;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = Colors.cyanAccent.withOpacity(0.3)
        ..strokeWidth = 0.5,
    );
    canvas.drawRect(Rect.fromLTWH(0, y - 15, size.width, 30), paint);
  }

  @override
  bool shouldRepaint(ScanlinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class StaticGrainPainter extends CustomPainter {
  final double seed;
  StaticGrainPainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random((seed * 1000).toInt());
    final paint = Paint();
    for (int i = 0; i < 400; i++) {
      paint.color = Colors.white.withOpacity(random.nextDouble() * 0.08);
      canvas.drawPoints(PointMode.points, [
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
      ], paint);
    }
  }

  @override
  bool shouldRepaint(StaticGrainPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

// --- HUD COMPONENTS ---

class HologramHUD extends StatefulWidget {
  final String label;
  final String value;
  final bool shouldGlitch;
  final double? progress;

  const HologramHUD({
    super.key,
    required this.label,
    required this.value,
    this.shouldGlitch = true,
    this.progress,
  });

  @override
  State<HologramHUD> createState() => _HologramHUDState();
}

class _HologramHUDState extends State<HologramHUD>
    with SingleTickerProviderStateMixin {
  late AnimationController _hudCtrl;

  @override
  void initState() {
    super.initState();
    _hudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _hudCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hudCtrl,
      builder: (context, _) => Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.03),
                  border: Border.all(
                    color: Colors.cyanAccent.withOpacity(0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.wifi_tethering,
                          color: Colors.cyanAccent,
                          size: 10,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    widget.shouldGlitch
                        ? GlitchText(text: widget.value, style: _holoStyle)
                        : Text(
                            widget.value,
                            style: _holoStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    if (widget.progress != null) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: widget.progress,
                        backgroundColor: Colors.white10,
                        color: Colors.cyanAccent,
                        minHeight: 1,
                      ),
                    ],
                  ],
                ),
              ),
              Positioned.fill(
                child: CustomPaint(painter: StaticGrainPainter(_hudCtrl.value)),
              ),
              Positioned.fill(
                child: CustomPaint(painter: ScanlinePainter(_hudCtrl.value)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _holoStyle => const TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontFamily: 'monospace',
    shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 8)],
  );
}

class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const GlitchText({super.key, required this.text, required this.style});

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> {
  String _displayString = "";
  Timer? _timer;
  final _random = math.Random();
  final _chars = r'<>$_&X%#@!01';

  @override
  void initState() {
    super.initState();
    _displayString = widget.text;
  }

  @override
  void didUpdateWidget(GlitchText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _startGlitch();
  }

  void _startGlitch() {
    _timer?.cancel();
    int frames = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      setState(() {
        if (frames < 3) {
          _displayString = String.fromCharCodes(
            List.generate(
              widget.text.length,
              (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
            ),
          );
        } else {
          _displayString = widget.text;
          timer.cancel();
        }
        frames++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    _displayString,
    style: widget.style,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

// --- SHELL & UI ELEMENTS ---

class SheetShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? topProjection;

  const SheetShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.topProjection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      // 1. THE HERO FIX: Wrap the inner content in a SingleChildScrollView.
      // This allows the contents to gracefully compress and scroll when the keyboard opens!
      child: SingleChildScrollView(
        // 2. THE CLEANUP: Move the padding INSIDE the scroll view, and make it static.
        // We no longer need MediaQuery here because the parent AnimatedPadding handles it perfectly.
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Animated Projection Space
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: topProjection ?? const SizedBox.shrink(),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class IdentityField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final bool isLast;
  final int? maxLength;

  const IdentityField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.isLast = false,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscure,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontFamily: 'monospace',
        letterSpacing: 0.5,
      ),
      cursorColor: Colors.cyanAccent,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      maxLength: maxLength,
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 15,
          fontFamily: 'monospace',
          fontStyle: FontStyle.italic,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.cyanAccent, width: 1.5),
        ),
      ),
    );
  }
}

class PrimaryIdentityButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const PrimaryIdentityButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorDisplay extends StatelessWidget {
  final String error;
  const ErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
