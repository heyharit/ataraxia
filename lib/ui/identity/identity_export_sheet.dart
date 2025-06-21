import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/identity_store.dart';
import '../../data/models/identity.dart';

class IdentityExportSheet extends StatefulWidget {
  final Identity identity;
  const IdentityExportSheet({super.key, required this.identity});

  @override
  State<IdentityExportSheet> createState() => _IdentityExportSheetState();
}

// 1. Keep the observer. It is the correct way to bypass the modal viewInset bug.
class _IdentityExportSheetState extends State<IdentityExportSheet>
    with WidgetsBindingObserver {
  final _keyCtrl = TextEditingController();
  String? _error;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Triggers rebuild when the engine detects a keyboard state change
    if (mounted) setState(() {});
  }

  Future<void> _continue() async {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _isProcessing = true;
    });

    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() {
        _error = 'Key required';
        _isProcessing = false;
      });
      HapticFeedback.heavyImpact();
      return;
    }

    // Small artificial delay for premium "processing" feel
    await Future.delayed(const Duration(milliseconds: 400));

    final valid = IdentityStore.verifyKey(widget.identity, key);
    if (!valid) {
      setState(() {
        _error = 'Incorrect key sequence';
        _isProcessing = false;
      });
      HapticFeedback.heavyImpact();
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, key);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    // 2. Fetch raw engine insets to bypass the modal's consumed MediaQuery
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    // 3. The Upgrade: AnimatedPadding gives it a buttery smooth slide-up
    // instead of an aggressive snap when the keyboard appears.
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: SingleChildScrollView(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                isTablet ? 48 : 32,
                40,
                isTablet ? 48 : 32,
                40,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A).withOpacity(0.8),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AUTHENTICATE',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 4.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the key for\n${widget.identity.name}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 32 : 24,
                      fontFamily: 'Serif',
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: true,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 8,
                      fontFamily: 'Courier',
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else
                    const SizedBox(height: 26),

                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: _isProcessing ? null : _continue,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'UNLOCK ARCHIVE',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
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
      ),
    );
  }
}
