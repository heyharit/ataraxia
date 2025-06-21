import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/identity_store.dart';
import 'identity_ui.dart';

class RecoverIdentitySheet extends StatefulWidget {
  const RecoverIdentitySheet({super.key});
  @override
  State<RecoverIdentitySheet> createState() => _RecoverIdentitySheetState();
}

class _RecoverIdentitySheetState extends State<RecoverIdentitySheet>
    with WidgetsBindingObserver {
  final _phraseCtrl = TextEditingController();
  final _newKeyCtrl = TextEditingController();
  final _phraseFocus = FocusNode();
  final _newKeyFocus = FocusNode();

  String? _error;
  bool _isLoading = false;
  bool _isKeyboardVisible = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phraseFocus.addListener(_updateFocus);
    _newKeyFocus.addListener(_updateFocus);
  }

  void _updateFocus() => setState(
        () => _isKeyboardVisible = _phraseFocus.hasFocus || _newKeyFocus.hasFocus,
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phraseFocus.dispose();
    _newKeyFocus.dispose();
    _phraseCtrl.dispose();
    _newKeyCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  Future<void> _recover() async {
    final phrase = _phraseCtrl.text.trim();
    final newKey = _newKeyCtrl.text.trim();

    if (phrase.isEmpty || newKey.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'PROVIDE BOTH THE CIPHER AND A NEW SECRET.');
      return;
    }

    // Quick word-count check
    if (phrase.split(RegExp(r'\s+')).length != 12) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'THE CIPHER MUST BE EXACTLY 12 WORDS.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await IdentityStore.recoverWithCipher(
      phrase: phrase,
      newKey: newKey,
    );

    if (!success) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'INVALID CIPHER. THE VOID REJECTS THIS COMBINATION.';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true); // Success! Pop back to IdentityGate
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: SheetShell(
        title: 'Recover Identity',
        subtitle: 'Enter your 12-word Master Cipher.',
        topProjection: _isKeyboardVisible
            ? HologramHUD(
                label: _phraseFocus.hasFocus ? "DECRYPT_CIPHER" : "NEW_KEY",
                value: _phraseFocus.hasFocus
                    ? "ANALYZING..."
                    : _newKeyCtrl.text.replaceAll(RegExp(r'.'), '•'),
                shouldGlitch: _error != null,
              )
            : null,
        children: [
          IdentityField(
            controller: _phraseCtrl,
            focusNode: _phraseFocus,
            hint: '12-word Master Cipher',
            // Allow multiple lines for a 12-word phrase
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          IdentityField(
            controller: _newKeyCtrl,
            focusNode: _newKeyFocus,
            hint: 'New Security Key',
            maxLength: 16,
            obscure: _obscureKey,
            isLast: true,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _recover(),
            suffix: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_off : Icons.visibility,
                color: Colors.white10,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorDisplay(error: _error!),
          ],
          const SizedBox(height: 32),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.cyanAccent,
                    strokeWidth: 2,
                  ),
                )
              : PrimaryIdentityButton(label: 'RESTORE', onTap: _recover),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}