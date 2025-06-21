import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/identity_store.dart';
import 'identity_ui.dart';

class CreateIdentitySheet extends StatefulWidget {
  const CreateIdentitySheet({super.key});
  @override
  State<CreateIdentitySheet> createState() => _CreateIdentitySheetState();
}

// 1. Added WidgetsBindingObserver
class _CreateIdentitySheetState extends State<CreateIdentitySheet>
    with WidgetsBindingObserver {
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _keyFocus = FocusNode();

  String? _error;
  bool _loading = false;
  double _creationProgress = 0.0;
  bool _isKeyboardVisible = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to engine
    _nameFocus.addListener(_updateFocus);
    _keyFocus.addListener(_updateFocus);
  }

  void _updateFocus() => setState(
    () => _isKeyboardVisible = _nameFocus.hasFocus || _keyFocus.hasFocus,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up
    _nameFocus.dispose();
    _keyFocus.dispose();
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  // 2. Trigger rebuild when keyboard state changes
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final key = _keyCtrl.text.trim();

    if (name.isEmpty || key.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error =
            'NAMELESS ECHOES FADE IN THE VOID. PROVIDE BOTH AN IDENTITY AND A SECRET.';
      });
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
      _creationProgress = 0.1;
    });

    final timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (_creationProgress < 0.9) {
        setState(() => _creationProgress += 0.02);
      } else {
        t.cancel();
      }
    });

    try {
      final created = await IdentityStore.create(name: name, key: key);
      setState(() => _creationProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.pop(context, created);
    } catch (_) {
      timer.cancel();
      setState(() {
        _error = 'THIS THREAD IS ALREADY BOUND. CHOOSE ANOTHER NAME.';
        _loading = false;
        _creationProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3. Bypass the trap: get raw engine insets
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    // 4. Wrap the entire SheetShell in the AnimatedPadding
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: SheetShell(
        title: 'New Identity',
        subtitle: 'Choose a name to be remembered by.',
        topProjection: (_isKeyboardVisible || _loading)
            ? HologramHUD(
                label: _loading
                    ? "SYNC_VOID"
                    : (_nameFocus.hasFocus ? "INIT_ID" : "HASH_KEY"),
                value: _loading
                    ? "TRANSMITTING..."
                    : (_nameFocus.hasFocus
                          ? _nameCtrl.text
                          : _keyCtrl.text.replaceAll(RegExp(r'.'), '•')),
                shouldGlitch: !_loading,
                progress: _loading ? _creationProgress : null,
              )
            : null,
        children: [
          IdentityField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            maxLength: 12,
            hint: 'Ataraxia name',
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          IdentityField(
            controller: _keyCtrl,
            focusNode: _keyFocus,
            maxLength: 16,
            hint: 'Secret Key',
            obscure: _obscureKey,
            onChanged: (_) => setState(() => _error = null),
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

          if (!_loading)
            PrimaryIdentityButton(label: 'BEGIN', onTap: _create)
          else
            const Center(
              child: SizedBox(
                height: 50,
                child: CircularProgressIndicator(
                  color: Colors.cyanAccent,
                  strokeWidth: 2,
                ),
              ),
            ),

          const SizedBox(height: 12), // Removed the broken bottomInset hack!
        ],
      ),
    );
  }
}
