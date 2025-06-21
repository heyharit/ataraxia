import 'dart:io'; // 🚀 REQUIRED FOR REAL INTERNET PINGING
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/update_manager.dart';
import '../../utils/void_signal.dart';
import 'void_connection_banner.dart';

class GlobalUpdateWrapper extends StatefulWidget {
  final Widget child;

  const GlobalUpdateWrapper({super.key, required this.child});

  @override
  State<GlobalUpdateWrapper> createState() => _GlobalUpdateWrapperState();
}

class _GlobalUpdateWrapperState extends State<GlobalUpdateWrapper>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ─── UPDATE STATE ───
  Map<String, dynamic>? _forcedUpdateInfo;
  late final AnimationController _animCtrl;

  // ─── NETWORK STATE ───
  late StreamSubscription<List<ConnectivityResult>> _networkSub;
  bool _isOffline = false;
  bool _isPinging = false; // Prevents spamming network requests

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _verifySystemIntegrity();

    // 1. Start the passive antenna listener
    _networkSub = Connectivity().onConnectivityChanged.listen(_onNetworkChange);

    // 2. Perform an active ping right now
    _verifyRealInternet();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animCtrl.dispose();
    _networkSub.cancel();
    super.dispose();
  }

  // 🚀 THE LIFECYCLE WAKE-UP
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // If you leave the app for 50 minutes and come back, it pings the internet
      // the exact millisecond the app opens again. No waiting!
      _verifySystemIntegrity();
      _verifyRealInternet();
    }
  }

  // ─── NETWORK LOGIC ───
  void _onNetworkChange(List<ConnectivityResult> results) {
    // Has the antenna connected to ANYTHING? (Wi-Fi, Cellular, Ethernet)
    final antennaHasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );

    if (antennaHasConnection) {
      // Antenna says yes. Now we verify if it actually has data.
      _verifyRealInternet();
    } else {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  // 🚀 THE IRONCLAD ACTIVE SONAR
  int _retryCount = 0;

  Future<void> _verifyRealInternet() async {
    if (_isPinging) return;
    _isPinging = true;

    bool hasRealInternet = false;

    for (int i = 0; i < 4; i++) {
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          hasRealInternet = true;
          break;
        }
      } catch (_) {}

      await Future.delayed(const Duration(seconds: 1));
    }

    _isPinging = false;

    if (hasRealInternet) {
      _retryCount = 0; // 🔥 reset

      if (_isOffline) {
        HapticFeedback.mediumImpact();
        VoidSignal.broadcast();
      }

      if (mounted) setState(() => _isOffline = false);
    } else {
      if (mounted) setState(() => _isOffline = true);

      // 🔥 SMART RETRY (not infinite spam)
      if (_retryCount < 5) {
        _retryCount++;

        final delay = Duration(seconds: 2 * _retryCount); // 2s, 4s, 6s...
        // final delay = Duration(seconds: 1 << _retryCount); // 2s, 4s, 8s, 16s, 32s

        Future.delayed(delay, () {
          if (mounted && _isOffline) {
            _verifyRealInternet();
          }
        });
      }
    }
  }

  // ─── UPDATE LOGIC ───
  Future<void> _verifySystemIntegrity() async {
    final updateInfo = await UpdateManager.checkForUpdates();
    if (!mounted || updateInfo == null) return;

    if (updateInfo['isForced'] == true) {
      setState(() => _forcedUpdateInfo = updateInfo);
      _animCtrl.forward();
    }
  }

  void _initiateSync() async {
    if (_forcedUpdateInfo == null) return;

    HapticFeedback.heavyImpact();
    final uri = Uri.parse(_forcedUpdateInfo!['url']);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Failed to open update URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: _forcedUpdateInfo != null,
              child: widget.child,
            ),

            VoidConnectionBanner(isOffline: _isOffline),

            if (_forcedUpdateInfo != null) ...[
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(color: Colors.black.withOpacity(0.85)),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.15),
                            blurRadius: 80,
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _animCtrl,
                            builder: (context, child) {
                              return Opacity(
                                opacity: Curves.easeOut.transform(
                                  _animCtrl.value,
                                ),
                                child: Transform.translate(
                                  offset: Offset(0, 20 * (1 - _animCtrl.value)),
                                  child: child,
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.redAccent.withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.warning_rounded,
                                    color: Colors.redAccent,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  "CRITICAL SHIFT\nDETECTED",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 32 : 24,
                                    fontFamily: 'Times New Roman',
                                    height: 1.1,
                                    letterSpacing: 2,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Version ${_forcedUpdateInfo!['version']} is a structural mandate. You cannot proceed in the void without synchronizing.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 14,
                                    fontFamily: 'Serif',
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                GestureDetector(
                                  onTap: _initiateSync,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: Colors.redAccent.withOpacity(
                                          0.5,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      "INITIATE SYNC",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                        fontSize: 11,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
