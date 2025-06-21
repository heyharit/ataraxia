import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/identity_store.dart';
import '../ui/identity/identity_gate.dart';
import '../supabase/supabase_service.dart';
import 'dart:async';
import 'transmission_manager.dart';
import 'cinematic_toast.dart';
import '../utils/admob_service.dart';
import '../ui/modals/exchange_modal.dart';

class AxiomGate {
  static Future<bool> requestToll({
    required BuildContext context,
    required String title,
    required String description,
    required int cost,
    required String actionLabel,
    bool isRefund = false,
  }) async {
    final identity = await IdentityStore.active();
    if (identity == null) return false; // Handled by Ghost Protocol elsewhere

    HapticFeedback.mediumImpact();

    // Local fast check
    if (!isRefund && identity.axioms < cost) {
      _showBrokeSheet(context, identity.axioms, cost);
      return false;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AxiomConfirmSheet(
        title: title,
        description: description,
        cost: cost,
        currentBalance: identity.axioms,
        actionLabel: actionLabel,
        isRefund: isRefund,
      ),
    );

    if (confirmed == true) {
      // 🚀 PROCESS THE TRANSACTION
      try {
        if (isRefund) {
          // 🚀 THE FIX: Actually call the database to add the axioms back!
          await SupabaseService.adjustAxioms(identity.id, cost);
        } else {
          final success = await SupabaseService.spendAxioms(identity.id, cost);
          if (!success) {
            if (context.mounted)
              _showBrokeSheet(context, identity.axioms, cost);
            return false;
          }
        }

        // 🚀 Sync the local app so the UI instantly updates with the refund
        await IdentityStore.syncFromNetwork();
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  static void _showBrokeSheet(BuildContext context, int balance, int cost) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _AxiomRechargeSheet(currentBalance: balance, deficit: cost - balance),
    );
  }

  static void showGhostWall(BuildContext context) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _GhostWallSheet(),
    );
  }
}

class _AxiomConfirmSheet extends StatelessWidget {
  final String title;
  final String description;
  final int cost;
  final int currentBalance;
  final String actionLabel;
  final bool isRefund;

  const _AxiomConfirmSheet({
    required this.title,
    required this.description,
    required this.cost,
    required this.currentBalance,
    required this.actionLabel,
    required this.isRefund,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontFamily: 'Courier',
                  letterSpacing: 4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isRefund ? "+ $cost AXIOMS" : "- $cost AXIOMS",
                style: TextStyle(
                  color: isRefund ? Colors.cyanAccent : Colors.redAccent,
                  fontSize: 48,
                  fontFamily: 'Times New Roman',
                  shadows: [
                    Shadow(
                      color: (isRefund ? Colors.cyanAccent : Colors.redAccent)
                          .withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontFamily: 'Serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "BALANCE: $currentBalance",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontFamily: 'Courier',
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: const Text(
                          "ABORT",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isRefund
                                ? Colors.cyanAccent.withOpacity(0.1)
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isRefund
                                  ? Colors.cyanAccent.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: TextStyle(
                              color: isRefund
                                  ? Colors.cyanAccent
                                  : Colors.white,
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AxiomRechargeSheet extends StatefulWidget {
  final int currentBalance;
  final int deficit;

  const _AxiomRechargeSheet({
    required this.currentBalance,
    required this.deficit,
  });

  @override
  State<_AxiomRechargeSheet> createState() => _AxiomRechargeSheetState();
}

class _AxiomRechargeSheetState extends State<_AxiomRechargeSheet> {
  bool _canWatchAd = false;
  Duration? _cooldownRemaining;
  Timer? _timer;
  bool _isWatchingAd = false;

  @override
  void initState() {
    super.initState();
    _checkTransmissionStatus();
  }

  void _checkTransmissionStatus() async {
    final canWatch = await TransmissionManager.canReceiveTransmission();
    final remaining = await TransmissionManager.timeUntilNextTransmission();

    if (mounted) {
      setState(() {
        _canWatchAd = canWatch;
        _cooldownRemaining = remaining;
      });

      if (!canWatch && remaining != null) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownRemaining != null && _cooldownRemaining!.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _cooldownRemaining =
                _cooldownRemaining! - const Duration(seconds: 1);
          });
        }
      } else {
        timer.cancel();
        _checkTransmissionStatus(); // Recheck when timer hits 0
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _watchTransmission() async {
    if (!_canWatchAd || _isWatchingAd) return;

    setState(() => _isWatchingAd = true);
    HapticFeedback.mediumImpact();

    // 🚀 FIRE THE ADMOB SDK
    bool success = await AdMobService.showRewardedAd();

    if (success) {
      final identity = await IdentityStore.active();
      if (identity != null) {
        // Give them 10 Axioms
        await SupabaseService.adjustAxioms(identity.id, 10);
        await IdentityStore.syncFromNetwork();

        // Start the 30-minute cooldown
        await TransmissionManager.recordTransmission();

        if (mounted) {
          Navigator.pop(context);
          showCinematicToast(context, "TRANSMISSION RECEIVED. +10 AXIOMS.");
        }
      }
    } else {
      if (mounted) {
        setState(() => _isWatchingAd = false);
        // Optional: show a toast if they closed it early
        showCinematicToast(context, "TRANSMISSION SEVERED EARLY.");
      }
    }
  }

  void _openStore() async {
    HapticFeedback.selectionClick();

    // 1. Close the current "Essence Depleted" sheet
    Navigator.pop(context);
    showCinematicToast(context, "ENTERING THE EXCHANGE...");

    // 2. Fetch the identity to pass to the Exchange
    final identity = await IdentityStore.active();
    if (identity == null) return;

    // 3. 🚀 Actually open the Exchange Modal!
    if (mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: "Exchange",
        barrierColor: Colors.black.withOpacity(0.85),
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, _, __) => ExchangeModal(identity: identity),
        transitionBuilder: (context, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10 * anim.value,
                sigmaY: 10 * anim.value,
              ),
              child: child,
            ),
          );
        },
      );
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withOpacity(0.95),
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.energy_savings_leaf_rounded,
                color: Colors.redAccent,
                size: 32,
              ),
              const SizedBox(height: 24),
              const Text(
                "ESSENCE DEPLETED",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Times New Roman',
                  letterSpacing: 4,
                  shadows: [Shadow(color: Colors.redAccent, blurRadius: 20)],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You require ${widget.deficit} more Axioms to proceed.\nYour current balance is ${widget.currentBalance}.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontFamily: 'Serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // ─── OPTION 1: TRANSMISSION (AD) ───
              GestureDetector(
                onTap: _watchTransmission,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: _canWatchAd
                        ? Colors.cyanAccent.withOpacity(0.1)
                        : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _canWatchAd
                          ? Colors.cyanAccent.withOpacity(0.3)
                          : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Center(
                    child: _isWatchingAd
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                              strokeWidth: 1.5,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _canWatchAd
                                    ? "RECEIVE TRANSMISSION (+10 AXIOMS)"
                                    : "TRANSMISSION COOLING DOWN",
                                style: TextStyle(
                                  color: _canWatchAd
                                      ? Colors.cyanAccent
                                      : Colors.white.withOpacity(0.3),
                                  fontFamily: 'Courier',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              if (!_canWatchAd &&
                                  _cooldownRemaining != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "SIGNAL RETURNS IN: ${_formatDuration(_cooldownRemaining!)}",
                                  style: TextStyle(
                                    color: Colors.redAccent.withOpacity(0.8),
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── OPTION 2: STORE (IAP) ───
              GestureDetector(
                onTap: _openStore,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Center(
                    child: Text(
                      "ACQUIRE AXIOM CLUSTERS",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ─── CANCEL ───
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "RETURN TO THE VOID",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontFamily: 'Courier',
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostWallSheet extends StatefulWidget {
  const _GhostWallSheet();

  @override
  State<_GhostWallSheet> createState() => _GhostWallSheetState();
}

class _GhostWallSheetState extends State<_GhostWallSheet> {
  bool _canWatchAd = false;
  Duration? _cooldownRemaining;
  Timer? _timer;
  bool _isWatchingAd = false;

  @override
  void initState() {
    super.initState();
    _checkTransmissionStatus();
  }

  void _checkTransmissionStatus() async {
    final canWatch = await TransmissionManager.canReceiveTransmission();
    final remaining = await TransmissionManager.timeUntilNextTransmission();

    if (mounted) {
      setState(() {
        _canWatchAd = canWatch;
        _cooldownRemaining = remaining;
      });

      if (!canWatch && remaining != null) {
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownRemaining != null && _cooldownRemaining!.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _cooldownRemaining =
                _cooldownRemaining! - const Duration(seconds: 1);
          });
        }
      } else {
        timer.cancel();
        _checkTransmissionStatus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _watchTransmission() async {
    if (!_canWatchAd || _isWatchingAd) return;

    setState(() => _isWatchingAd = true);
    HapticFeedback.mediumImpact();

    // 🚀 FIRE ADMOB SDK
    bool success = await AdMobService.showRewardedAd();

    if (success) {
      // 🚀 GIVE THEM 1 FREE GHOST APPLY
      await IdentityStore.addGhostApplies(1);
      await TransmissionManager.recordTransmission();

      if (mounted) {
        Navigator.pop(context);
        showCinematicToast(
          context,
          "1 GHOST ESSENCE ACQUIRED. YOU MAY PROCEED.",
        );
      }
    } else {
      if (mounted) {
        setState(() => _isWatchingAd = false);
        showCinematicToast(context, "TRANSMISSION SEVERED.");
      }
    }
  }

  void _forgeIdentity() {
    HapticFeedback.selectionClick();
    Navigator.pop(context); // Close the sheet
    // 🚀 Send them to the login gate!
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            IdentityGate(onAuthenticated: () => Navigator.pop(context)),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withOpacity(0.95),
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_off_rounded,
                color: Colors.white54,
                size: 32,
              ),
              const SizedBox(height: 24),
              const Text(
                "ESSENCE DEPLETED",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Times New Roman',
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your free manifestations are exhausted.\nForge an identity to begin generating Axioms, or watch a transmission to proceed as a ghost.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontFamily: 'Serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // ─── OPTION 1: TRANSMISSION (AD) ───
              GestureDetector(
                onTap: _watchTransmission,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: _canWatchAd
                        ? Colors.cyanAccent.withOpacity(0.1)
                        : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _canWatchAd
                          ? Colors.cyanAccent.withOpacity(0.3)
                          : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Center(
                    child: _isWatchingAd
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                              strokeWidth: 1.5,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _canWatchAd
                                    ? "RECEIVE TRANSMISSION (+1 APPLY)"
                                    : "TRANSMISSION COOLING DOWN",
                                style: TextStyle(
                                  color: _canWatchAd
                                      ? Colors.cyanAccent
                                      : Colors.white.withOpacity(0.3),
                                  fontFamily: 'Courier',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              if (!_canWatchAd &&
                                  _cooldownRemaining != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "SIGNAL RETURNS IN: ${_formatDuration(_cooldownRemaining!)}",
                                  style: TextStyle(
                                    color: Colors.redAccent.withOpacity(0.8),
                                    fontFamily: 'Courier',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── OPTION 2: FORGE IDENTITY ───
              GestureDetector(
                onTap: _forgeIdentity,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Center(
                    child: Text(
                      "FORGE IDENTITY",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ─── CANCEL ───
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  "RETURN TO THE VOID",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    fontFamily: 'Courier',
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
