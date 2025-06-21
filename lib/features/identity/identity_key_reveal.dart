import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IdentityKeyReveal extends StatefulWidget {
  final String secretKey;
  final VoidCallback onContinue;

  const IdentityKeyReveal({
    super.key,
    required this.secretKey,
    required this.onContinue,
  });

  @override
  State<IdentityKeyReveal> createState() => _IdentityKeyRevealState();
}

class _IdentityKeyRevealState extends State<IdentityKeyReveal> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.secretKey));
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // 🛡️ cannot skip
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                Text(
                  'This is your key.',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),

                const SizedBox(height: 16),

                Text(
                  'Ataraxia will never remember this.\n'
                  'If you lose it, this identity becomes sealed forever.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
                ),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: _copy,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withOpacity(0.08),
                    ),
                    child: Text(
                      widget.secretKey,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 1.2,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _copied ? 'Copied ✓' : 'Tap to copy',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _copied ? Colors.greenAccent : Colors.white38,
                  ),
                ),

                const Spacer(),

                ElevatedButton(
                  onPressed: _copied ? widget.onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _copied ? Colors.white : Colors.white24,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('I understand'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
