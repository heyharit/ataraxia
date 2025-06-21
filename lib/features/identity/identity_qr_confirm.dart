import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/identity_store.dart';
import '../../data/models/identity.dart';
import 'identity_glyph.dart';
import 'identity_seal_broken.dart';

class IdentityQrConfirm extends StatefulWidget {
  final Identity identity;
  final String identityKey;

  const IdentityQrConfirm({
    super.key,
    required this.identity,
    required this.identityKey,
  });

  @override
  State<IdentityQrConfirm> createState() => _IdentityQrConfirmState();
}

class _IdentityQrConfirmState extends State<IdentityQrConfirm>
    with TickerProviderStateMixin {
  late final AnimationController _holdCtrl;
  late final AnimationController _pulseCtrl;
  bool _isAssimilating = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _holdCtrl.addListener(() {
      if (_holdCtrl.value > 0 && _holdCtrl.value < 1.0) {
        if ((_holdCtrl.value * 100).toInt() % 15 == 0) {
          HapticFeedback.selectionClick();
        }
      }
      if (_holdCtrl.value == 1.0 && !_isAssimilating) {
        _assimilateArtifact();
      }
    });
  }

  @override
  void dispose() {
    _holdCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_isAssimilating) return;
    HapticFeedback.mediumImpact();
    _holdCtrl.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (_isAssimilating) return;
    _holdCtrl.reverse();
  }

  void _onTapCancel() {
    if (_isAssimilating) return;
    _holdCtrl.reverse();
  }

  Future<void> _assimilateArtifact() async {
    setState(() => _isAssimilating = true);
    HapticFeedback.heavyImpact();

    await IdentityStore.importFromFile(
      jsonEncode({
        'type': 'ataraxia.identity',
        'identity': widget.identity.toJson(),
        'key': widget.identityKey,
      }),
    );

    if (!mounted) return;

    // 🚀 FIX: Await the Seal Broken screen, instead of replacing
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (_, __, ___) => const IdentitySealBroken(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );

    // 🚀 FIX: Once the seal animation finishes and pops, return true to QrImport!
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8 + (_pulseCtrl.value * 0.2),
                      colors: [
                        Colors.cyanAccent.withOpacity(0.05),
                        Colors.black,
                      ],
                    ),
                  ),
                );
              },
            ),

            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 64 : 32,
                  vertical: 48,
                ),
                child: Column(
                  children: [
                    Text(
                      "ARTIFACT DECRYPTED",
                      style: TextStyle(
                        color: Colors.cyanAccent.withOpacity(0.8),
                        fontFamily: 'Courier',
                        fontSize: isTablet ? 14 : 11,
                        letterSpacing: 4.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),

                    AnimatedBuilder(
                      animation: _holdCtrl,
                      builder: (context, child) {
                        final scale = 1.0 - (_holdCtrl.value * 0.15);
                        final glowOpacity = _holdCtrl.value * 0.6;

                        return Transform.scale(
                          scale: scale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: isTablet ? 220 : 160,
                                height: isTablet ? 220 : 160,
                                child: CircularProgressIndicator(
                                  value: _holdCtrl.value,
                                  strokeWidth: isTablet ? 4 : 3,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.05,
                                  ),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.cyanAccent,
                                      ),
                                ),
                              ),
                              Container(
                                width: isTablet ? 180 : 130,
                                height: isTablet ? 180 : 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withOpacity(
                                        glowOpacity,
                                      ),
                                      blurRadius: 50 * _holdCtrl.value,
                                      spreadRadius: 10 * _holdCtrl.value,
                                    ),
                                    BoxShadow(
                                      color: Colors.purpleAccent.withOpacity(
                                        glowOpacity,
                                      ),
                                      blurRadius: 100 * _holdCtrl.value,
                                      spreadRadius: -10 * _holdCtrl.value,
                                    ),
                                  ],
                                ),
                              ),
                              IdentityGlyph(identity: widget.identity),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Colors.cyanAccent, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        widget.identity.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 32 : 24,
                          letterSpacing: 8.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'An unbroken thread.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),

                    AnimatedBuilder(
                      animation: _holdCtrl,
                      builder: (_, __) {
                        return Opacity(
                          opacity: 1.0 - _holdCtrl.value,
                          child: Text(
                            "PRESS AND HOLD TO ASSIMILATE",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontFamily: 'Courier',
                              fontSize: 10,
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
