import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/identity.dart';
import '../../data/identity_store.dart';

class IdentityExportWarning extends StatelessWidget {
  final Identity identity;
  final String secretKey;
  final String? recoveryPhrase; // 👈 MAKE IT OPTIONAL

  const IdentityExportWarning({
    super.key,
    required this.identity,
    required this.secretKey,
    this.recoveryPhrase, // 👈 NOT REQUIRED ANYMORE
  });

  Future<void> _export(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final export = IdentityStore.buildExport(
      identity: identity,
      key: secretKey,
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${identity.name}.ataraxian');

    await file.writeAsString(export);
    await Share.shareXFiles([XFile(file.path)], text: 'Your Ataraxia identity');
  }

  void _copyCipher(BuildContext context) {
    if (recoveryPhrase == null) return;
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: recoveryPhrase!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'MASTER CIPHER COPIED TO CLIPBOARD',
          style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.cyan[900],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are showing the phrase or just the export warning
    final hasPhrase = recoveryPhrase != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasPhrase
                      ? Icons.vpn_key_rounded
                      : Icons.warning_amber_rounded,
                  color: (hasPhrase ? Colors.cyanAccent : Colors.amber)
                      .withOpacity(0.8),
                  size: 48,
                ),
                const SizedBox(height: 24),
                Text(
                  hasPhrase ? 'The Master Cipher' : 'The Void Forgets',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontFamily: 'Serif',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasPhrase
                      ? 'If you forget your password, these 12 words are the ONLY way to recover your account and purchases. Write them down or copy them now.'
                      : 'Your key is known only to you. If you lose it, this identity becomes a sealed time capsule—unreachable forever.\n\nWe strongly advise saving this file.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),

                // 🚀 ONLY SHOW CIPHER BOX IF WE HAVE THE PHRASE
                if (hasPhrase) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.cyanAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      recoveryPhrase!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontFamily: 'Courier',
                        fontSize: 16,
                        letterSpacing: 1.2,
                        height: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  const SizedBox(height: 16),
                ],

                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🚀 ONLY SHOW COPY BUTTON IF WE HAVE THE PHRASE
                    if (hasPhrase) ...[
                      GestureDetector(
                        onTap: () => _copyCipher(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.5),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'COPY TO CLIPBOARD',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // EXPORT FILE BUTTON
                    GestureDetector(
                      onTap: () async {
                        await _export(context);
                        if (!hasPhrase && context.mounted) {
                          Navigator.pop(
                            context,
                          ); // Close automatically if standard export
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            hasPhrase
                                ? 'DOWNLOAD .ATARAXIAN FILE'
                                : 'EXPORT & SECURE',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // DISMISS BUTTON
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          border: hasPhrase
                              ? null
                              : Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                        ),
                        child: Center(
                          child: Text(
                            hasPhrase
                                ? 'I HAVE SECURED MY CIPHER'
                                : 'I UNDERSTAND THE RISK',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
