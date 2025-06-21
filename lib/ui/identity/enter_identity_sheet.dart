import 'package:flutter/material.dart';
import '../../data/identity_store.dart';
import 'identity_ui.dart';
import 'recover_identity_sheet.dart';

class EnterIdentitySheet extends StatefulWidget {
  const EnterIdentitySheet({super.key});
  @override
  State<EnterIdentitySheet> createState() => _EnterIdentitySheetState();
}

// 1. Added WidgetsBindingObserver
class _EnterIdentitySheetState extends State<EnterIdentitySheet>
    with WidgetsBindingObserver {
  final _nameCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _keyFocus = FocusNode();

  String? _error;
  bool _isLoading = false;
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

  Future<void> _enter() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final identity = await IdentityStore.authenticate(
      name: _nameCtrl.text.trim(),
      key: _keyCtrl.text.trim(),
    );

    if (identity == null) {
      if (mounted) {
        setState(() {
          _error = 'THE VOID DOES NOT RECOGNIZE THIS NAME.';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) Navigator.pop(context, true);
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
        title: 'Welcome back',
        subtitle: 'Identify yourself to the void.',
        topProjection: _isKeyboardVisible
            ? HologramHUD(
                label: _nameFocus.hasFocus ? "QUERY_USER" : "DECRYPT_KEY",
                value: _nameFocus.hasFocus
                    ? _nameCtrl.text
                    : _keyCtrl.text.replaceAll(RegExp(r'.'), '•'),
              )
            : null,
        children: [
          IdentityField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            hint: 'Ataraxia name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          IdentityField(
            controller: _keyCtrl,
            focusNode: _keyFocus,
            hint: 'Security Key',
            obscure: _obscureKey,
            isLast: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _enter(),
            suffix: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_off : Icons.visibility,
                color: Colors.white10,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
          if (_error != null) ErrorDisplay(error: _error!),
          const SizedBox(height: 32),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.cyanAccent,
                    strokeWidth: 2,
                  ),
                )
              : PrimaryIdentityButton(label: 'ENTER', onTap: _enter),

          const SizedBox(height: 16),

          // 🚀 THE RECOVERY BUTTON
          if (!_isLoading)
            Center(
              child: TextButton(
                onPressed: () async {
                  FocusScope.of(context).unfocus(); // Dismiss keyboard
                  final recovered = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const RecoverIdentitySheet(),
                  );
                  // If recovery succeeded, close this sheet too and log them in!
                  if (recovered == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text(
                  'LOST YOUR SECRET?',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
