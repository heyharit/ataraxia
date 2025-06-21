import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'identity_export_warning.dart';
import 'create_identity_sheet.dart';
import 'enter_identity_sheet.dart';
import '../../data/identity_store.dart';
import '../../features/identity/identity_qr_import.dart';
import '../../features/identity/identity_seal_broken.dart';
import 'dart:convert';
import '../../data/models/identity.dart';

class IdentityGate extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const IdentityGate({super.key, required this.onAuthenticated});

  @override
  State<IdentityGate> createState() => _IdentityGateState();
}

class _IdentityGateState extends State<IdentityGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _isImporting = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Atmospheric Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.6, -0.4),
                  radius: 1.5,
                  colors: [
                    Color(0xFF151515), // Very dark grey
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // 2. Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 0 : 32,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),

                      // Animated Header
                      SlideTransition(
                        position: _slide,
                        child: FadeTransition(
                          opacity: _fade,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.fingerprint,
                                color: Colors.white24,
                                size: isTablet ? 80 : 48,
                              ),
                              SizedBox(height: isTablet ? 32 : 24),
                              Text(
                                'You belong to\nAtaraxia.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 72 : 44,
                                  fontWeight: FontWeight.w300,
                                  height: 1.1,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              SizedBox(height: isTablet ? 24 : 16),
                              Text(
                                'A quiet continuity.\nA name that remembers.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: isTablet ? 22 : 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Actions
                      FadeTransition(
                        opacity: _fade,
                        child: Column(
                          children: [
                            _GateButton(
                              label: 'Enter your Ataraxia',
                              icon: Icons.login,
                              isPrimary: true,
                              isTablet: isTablet,
                              onTap: () =>
                                  _showSheet(const EnterIdentitySheet()),
                            ),
                            SizedBox(height: isTablet ? 24 : 16),
                            _GateButton(
                              label: 'Create new identity',
                              icon: Icons.add,
                              isTablet: isTablet,
                              onTap: () =>
                                  _showSheet(const CreateIdentitySheet()),
                            ),
                            SizedBox(height: isTablet ? 24 : 16),
                            _GateButton(
                              // Change text dynamically
                              label: _isImporting
                                  ? 'DECRYPTING ARTIFACT...'
                                  : 'Import from file',
                              icon: Icons.folder_open,
                              isTablet: isTablet,
                              isLoading: _isImporting, // Pass the state
                              // Disable taps while loading to prevent spam
                              onTap: _isImporting ? () {} : _importFile,
                            ),
                            SizedBox(height: isTablet ? 24 : 16),
                            _GateButton(
                              label: 'Scan QR Code',
                              icon: Icons.qr_code_scanner,
                              isTablet: isTablet,
                              onTap: () async {
                                // FIX: Await the QR scanner result!
                                final success = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const IdentityQrImport(),
                                  ),
                                );

                                // FIX: If successful, trigger the dashboard reload
                                if (success == true && mounted) {
                                  HapticFeedback.mediumImpact();
                                  widget.onAuthenticated();
                                }
                              },
                            ),
                            // _GateButton(
                            //   label: _isScanning ? 'AWAITING SCAN...' : 'Scan QR Code',
                            //   icon: Icons.qr_code_scanner,
                            //   isTablet: isTablet,
                            //   isLoading: _isScanning, // Activates the cyan glow & spinner
                            //   onTap: _isScanning ? () {} : _scanQrCode,
                            // ),
                          ],
                        ),
                      ),
                      SizedBox(height: isTablet ? 40 : 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSheet(Widget sheet) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );

    if (result == null) return;

    if (result is CreatedIdentity) {
      HapticFeedback.heavyImpact();

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.8),
        builder: (_) => IdentityExportWarning(
          identity: result.identity,
          secretKey: result.key,
          recoveryPhrase: result.recoveryPhrase,
        ),
      );

      if (mounted) widget.onAuthenticated();
      return;
    }

    if (result == true) {
      HapticFeedback.mediumImpact();
      widget.onAuthenticated();
    }
  }

  Future<void> _importFile() async {
    // 1. Pick the file FIRST (don't show loading while the OS picker is open)
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    // 2. TRIGGER PREMIUM LOADING STATE
    setState(() => _isImporting = true);
    HapticFeedback.lightImpact();

    try {
      final contents = await File(result.files.single.path!).readAsString();

      final json = jsonDecode(contents);
      if (json['type'] != 'ataraxia.identity') {
        throw Exception('INVALID_ATARAXIAN');
      }

      final identityData = Identity.fromJson(json['identity']);
      final key = json['key'];

      final remoteIdentity = await IdentityStore.authenticate(
        name: identityData.name,
        key: key,
      );

      if (remoteIdentity == null) {
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'THIS IDENTITY HAS FADED INTO THE VOID.',
                style: TextStyle(
                  fontFamily: 'Courier',
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.red[900],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(20),
            ),
          );
        }
        return;
      }

      await IdentityStore.importFromFile(contents);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const IdentitySealBroken(),
        ),
      );

      HapticFeedback.heavyImpact();
      widget.onAuthenticated();
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'CORRUPTED ARTIFACT',
              style: TextStyle(
                fontFamily: 'Courier',
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.red[900],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } finally {
      // 3. STOP LOADING NO MATTER WHAT HAPPENS
      if (mounted) setState(() => _isImporting = false);
    }
  }

  //  Future<void> _importFile() async {
  //     try {
  //       final result = await FilePicker.platform.pickFiles();
  //       if (result == null || result.files.single.path == null) return;

  //       final contents = await File(result.files.single.path!).readAsString();

  //       // We need to parse the JSON manually first so we can check the server
  //       final json = jsonDecode(contents);
  //       if (json['type'] != 'ataraxia.identity') {
  //         throw Exception('INVALID_ATARAXIAN');
  //       }

  //       final identityData = Identity.fromJson(json['identity']);
  //       final key = json['key'];

  //       // 1. Authenticate against the server BEFORE saving it locally!
  //       // This proves the identity hasn't been burned.
  //       final remoteIdentity = await IdentityStore.authenticate(
  //         name: identityData.name,
  //         key: key
  //       );

  //       // If it returns null, the identity was burned or the key changed.
  //       if (remoteIdentity == null) {
  //         if (mounted) {
  //           HapticFeedback.heavyImpact();
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: const Text(
  //                 'THIS IDENTITY HAS FADED INTO THE VOID.',
  //                 style: TextStyle(
  //                   fontFamily: 'Courier',
  //                   letterSpacing: 2.0,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //               backgroundColor: Colors.red[900],
  //               behavior: SnackBarBehavior.floating,
  //               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //               margin: const EdgeInsets.all(20),
  //             ),
  //           );
  //         }
  //         return; // Abort the import
  //       }

  //       // 2. If it passed the server check, save it locally via the standard import
  //       await IdentityStore.importFromFile(contents);

  //       if (!mounted) return;

  //       await Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           fullscreenDialog: true,
  //           builder: (_) => const IdentitySealBroken(),
  //         ),
  //       );

  //       HapticFeedback.heavyImpact();
  //       widget.onAuthenticated();
  //     } catch (e) {
  //       if (mounted) {
  //         HapticFeedback.heavyImpact();
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: const Text(
  //               'CORRUPTED ARTIFACT',
  //               style: TextStyle(
  //                 fontFamily: 'Courier',
  //                 letterSpacing: 2.0,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             backgroundColor: Colors.red[900],
  //             behavior: SnackBarBehavior.floating,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //             margin: const EdgeInsets.all(20),
  //           ),
  //         );
  //       }
  //     }
  //   }

  Future<void> _scanQrCode() async {
    // 1. TRIGGER PREMIUM LOADING STATE
    setState(() => _isScanning = true);
    HapticFeedback.lightImpact();

    try {
      // 2. Open the Scanner
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true, // Feels more cinematic for a camera view
          builder: (_) => const IdentityQrImport(),
        ),
      );

      // 3. Handle the Result
      if (success == true && mounted) {
        HapticFeedback.mediumImpact();
        widget.onAuthenticated();
      }
    } finally {
      // 4. Always reset the state when the scanner closes
      if (mounted) setState(() => _isScanning = false);
    }
  }
}

class _GateButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isTablet;
  final bool isLoading; // 👈 ADDED

  const _GateButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    required this.isTablet,
    this.isLoading = false, // 👈 ADDED
  });

  @override
  State<_GateButton> createState() => _GateButtonState();
}

class _GateButtonState extends State<_GateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isLoading) return; // Prevent press animation if loading
    _pressCtrl.forward();
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isLoading) return; // Prevent action if loading
    _pressCtrl.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) {
          final scale = 1.0 - (_pressCtrl.value * 0.03);
          final isProcessing = widget.isLoading;

          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: widget.isTablet ? 24 : 18,
                horizontal: widget.isTablet ? 28 : 20,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.isPrimary
                    ? Colors.white
                    : Colors.white.withOpacity(isProcessing ? 0.02 : 0.05),
                // ✨ IGNITE BORDER ON LOAD
                border: isProcessing
                    ? Border.all(color: Colors.cyanAccent.withOpacity(0.5))
                    : (widget.isPrimary
                          ? null
                          : Border.all(color: Colors.white10)),
                // ✨ CAST AURA ON LOAD
                boxShadow: isProcessing
                    ? [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // ✨ SWAP ICON FOR SPINNER
                  if (isProcessing)
                    SizedBox(
                      width: widget.isTablet ? 26 : 20,
                      height: widget.isTablet ? 26 : 20,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyanAccent,
                      ),
                    )
                  else
                    Icon(
                      widget.icon,
                      color: widget.isPrimary ? Colors.black : Colors.white54,
                      size: widget.isTablet ? 26 : 20,
                    ),
                  const SizedBox(width: 16),

                  // ✨ KINETIC TEXT UPDATE
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontFamily: isProcessing ? 'Courier' : null,
                        color: isProcessing
                            ? Colors.cyanAccent
                            : (widget.isPrimary ? Colors.black : Colors.white),
                        fontWeight: isProcessing
                            ? FontWeight.w900
                            : FontWeight.w600,
                        fontSize: widget.isTablet ? 18 : 15,
                        // Expands letter spacing for a sci-fi feel while loading
                        letterSpacing: isProcessing ? 2.0 : 0.3,
                      ),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Hide arrow when loading
                  if (!isProcessing)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: widget.isPrimary ? Colors.black38 : Colors.white12,
                      size: widget.isTablet ? 18 : 14,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
