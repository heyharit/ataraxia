import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ritual/ambient/ambient_manager.dart';
import '../data/identity_store.dart';
import '../../utils/axiom_gate.dart';
import '../ui/modals/exchange_modal.dart';
import '../../utils/cinematic_toast.dart';

class AmbientRitualScreen extends StatefulWidget {
  const AmbientRitualScreen({super.key});

  @override
  State<AmbientRitualScreen> createState() => _AmbientRitualScreenState();
}

class _AmbientRitualScreenState extends State<AmbientRitualScreen>
    with SingleTickerProviderStateMixin {
  bool _enabled = false;
  String _source = 'today';
  String _type = 'both';
  int _frequency = 24;
  bool _isLoading = true;
  bool _isSummoning = false;
  bool _isPremium = false;

  bool _targetHome = true;
  bool _targetLock = true;
  bool _targetWidget = true;

  late AnimationController _ambientBgCtrl;

  @override
  void initState() {
    super.initState();
    _ambientBgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _loadPrefs();
  }

  @override
  void dispose() {
    _ambientBgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final identity = await IdentityStore.active();

    setState(() {
      _isPremium = identity?.isPremium ?? false;
      _enabled = prefs.getBool('ambient_enabled') ?? false;

      if (!_isPremium && _enabled) {
        _enabled = false;
        prefs.setBool('ambient_enabled', false);
        AmbientManager.cancel();
      }

      _source = prefs.getString('ambient_source') ?? 'today';
      _type = prefs.getString('ambient_type') ?? 'both';
      _frequency = prefs.getInt("ambient_freq") ?? 24;

      _targetHome = prefs.getBool('ambient_target_home') ?? true;
      _targetLock = prefs.getBool('ambient_target_lock') ?? true;
      _targetWidget = prefs.getBool('ambient_target_widget') ?? true;

      _isLoading = false;
    });
  }

  Future<void> _saveAndSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ambient_enabled', _enabled);
    await prefs.setString('ambient_source', _source);
    await prefs.setString('ambient_type', _type);
    await prefs.setInt("ambient_freq", _frequency);

    await prefs.setBool('ambient_target_home', _targetHome);
    await prefs.setBool('ambient_target_lock', _targetLock);
    await prefs.setBool('ambient_target_widget', _targetWidget);

    if (_enabled) {
      await AmbientManager.schedule(_frequency);
    } else {
      await AmbientManager.cancel();
    }
  }

  void _toggleTarget(String target) {
    HapticFeedback.lightImpact();
    setState(() {
      if (target == 'home') _targetHome = !_targetHome;
      if (target == 'lock') _targetLock = !_targetLock;
      if (target == 'widget') _targetWidget = !_targetWidget;
    });
    _saveAndSchedule();
  }

  void _updateType(String val) {
    if (_type == val) return;
    setState(() => _type = val);
    HapticFeedback.lightImpact();
    _saveAndSchedule();
  }

  void _updateSource(String val) {
    if (_source == val) return;
    setState(() => _source = val);
    HapticFeedback.lightImpact();
    _saveAndSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _ambientBgCtrl,
            builder: (context, child) {
              final breathe = Curves.easeInOutSine.transform(
                _ambientBgCtrl.value,
              );
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.8 + (breathe * 0.1)),
                    radius: 1.5 + (breathe * 0.2),
                    colors: const [
                      Color(0xFF151A22),
                      Colors.black,
                      Colors.black,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
                strokeWidth: 1.5,
              ),
            )
          else
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  floating: true,
                  elevation: 0,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 10),

                      Text(
                        "DIMENSIONAL",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontFamily: 'Courier',
                          letterSpacing: 6.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Ritual",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontFamily: 'Times New Roman',
                          fontStyle: FontStyle.italic,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Configure your visual environment. Anchor frequencies manually, or let the void passively sync them for you.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // 1. AESTHETIC
                      _sectionHeader("AESTHETIC"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SelectionCard(
                              title: "Full",
                              subtitle: "Img + Quote",
                              icon: Icons.format_quote_rounded,
                              isSelected: _type == 'both',
                              onTap: () => _updateType('both'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SelectionCard(
                              title: "Clean",
                              subtitle: "Image Only",
                              icon: Icons.wallpaper_rounded,
                              isSelected: _type == 'image',
                              onTap: () => _updateType('image'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // 2. TARGET PROTOCOLS
                      _sectionHeader("TARGET PROTOCOLS"),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SelectionCard(
                                  title: "Home",
                                  subtitle: "Wallpaper",
                                  icon: Icons.home_outlined,
                                  isSelected: _targetHome,
                                  onTap: () => _toggleTarget('home'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SelectionCard(
                                  title: "Lock",
                                  subtitle: "Screen",
                                  icon: Icons.lock_outline_rounded,
                                  isSelected: _targetLock,
                                  onTap: () => _toggleTarget('lock'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _SelectionCard(
                                  title: "Widget",
                                  subtitle: "Home Panel",
                                  icon: Icons.widgets_outlined,
                                  isSelected: _targetWidget,
                                  onTap: () => _toggleTarget('widget'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // 3. SOURCE
                      _sectionHeader("SOURCE"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SelectionCard(
                              title: "Today",
                              subtitle: "Daily Ritual",
                              icon: Icons.wb_sunny_outlined,
                              isSelected: _source == 'today',
                              onTap: () => _updateSource('today'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SelectionCard(
                              title: "Chaos",
                              subtitle: "Random Pull",
                              icon: Icons.shuffle_rounded,
                              isSelected: _source == 'explore',
                              onTap: () => _updateSource('explore'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // 4. PASSIVE ENGINE (THE GLASS BOX)
                      _sectionHeader("PASSIVE ENGINE (AUTO-SYNC)"),
                      const SizedBox(height: 16),

                      GestureDetector(
                        // 🚀 If free, intercept taps. If premium, let taps pass through.
                        onTap: _isPremium ? null : _showPremiumUpsell,
                        child: AbsorbPointer(
                          // 🚀 Eats native slider/switch touches if they are free
                          absorbing: !_isPremium,
                          child: Opacity(
                            // 🚀 Ghost out the UI if they don't own it
                            opacity: _isPremium ? 1.0 : 0.4,
                            child: Column(
                              children: [
                                _buildMasterSwitch(),
                                // 🚀 If premium, hide/show slider based on the switch.
                                // 🚀 If free, ALWAYS show the slider so they see what they are missing.
                                if (_isPremium)
                                  AnimatedCrossFade(
                                    firstChild: const SizedBox(
                                      height: 0,
                                      width: double.infinity,
                                    ),
                                    secondChild: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 32),
                                        _sectionHeader("FREQUENCY"),
                                        const SizedBox(height: 16),
                                        _buildFrequencySlider(),
                                      ],
                                    ),
                                    crossFadeState: _enabled
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    duration: const Duration(milliseconds: 500),
                                    firstCurve: Curves.easeOutExpo,
                                    secondCurve: Curves.easeOutExpo,
                                    sizeCurve: Curves.easeOutExpo,
                                    alignment: Alignment.topCenter,
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 32),
                                      _sectionHeader("FREQUENCY"),
                                      const SizedBox(height: 16),
                                      _buildFrequencySlider(),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 5. EVERYONE GETS THE MANUAL BUTTON
                      const SizedBox(height: 56),
                      _buildSummonButton(),
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            fontFamily: 'Courier',
            letterSpacing: 3.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildMasterSwitch() {
    return _SpringButton(
      onTap: () {
        setState(() => _enabled = !_enabled);
        HapticFeedback.mediumImpact();
        _saveAndSchedule();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: _enabled ? Colors.white : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _enabled ? Colors.white : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: -5,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enabled ? "ACTIVE" : "DORMANT",
                  style: TextStyle(
                    color: _enabled ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontFamily: 'Courier',
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Background Engine",
                  style: TextStyle(
                    color: _enabled ? Colors.black54 : Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _enabled
                    ? Colors.cyanAccent.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                color: _enabled ? Colors.black : Colors.white54,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySlider() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Refresh Cycle",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "$_frequency",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'Times New Roman',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "hrs",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: Colors.white,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              overlayColor: Colors.cyanAccent.withOpacity(0.1),
            ),
            child: Slider(
              value: _frequency.toDouble(),
              min: 1,
              max: 48,
              divisions: 47,
              onChanged: (v) => setState(() => _frequency = v.toInt()),
              onChangeEnd: (_) => _saveAndSchedule(),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 FIXED: GHOST PROTOCOL & AXIOM GATEKEEPER
  Widget _buildSummonButton() {
    return _SpringButton(
      onTap: _isSummoning
          ? () {}
          : () async {
              HapticFeedback.selectionClick();

              final identity = await IdentityStore.active();

              if (identity == null) {
                // 👻 GHOST PROTOCOL
                final ghostAppliesLeft = await IdentityStore.getGhostApplies();
                if (ghostAppliesLeft <= 0) {
                  if (mounted) AxiomGate.showGhostWall(context);
                  return;
                }
                await IdentityStore.decrementGhostApplies();
                if (mounted)
                  showCinematicToast(
                    context,
                    "GHOST ESSENCE: ${ghostAppliesLeft - 1} REMAINING",
                  );
              } else {
                // 💎 LOGGED IN USER: CHARGE 3 AXIOMS
                final confirmed = await AxiomGate.requestToll(
                  context: context,
                  title: "FORCE SUMMON",
                  description:
                      "Manually pull a new frequency from the void and anchor it to your reality.",
                  cost: 3,
                  actionLabel: "SUMMON",
                );
                if (!confirmed) return;
              }

              setState(() => _isSummoning = true);
              HapticFeedback.heavyImpact();

              try {
                await AmbientManager.triggerManualRefresh();
                // We give the background task a little extra time to download and crop
                await Future.delayed(const Duration(milliseconds: 2500));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.white,
                      content: const Text(
                        "RITUAL COMPLETE",
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Courier',
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(
                        bottom: 40,
                        left: 24,
                        right: 24,
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSummoning = false);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isSummoning
                ? Colors.cyanAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          color: _isSummoning
              ? Colors.cyanAccent.withOpacity(0.05)
              : Colors.transparent,
          boxShadow: _isSummoning
              ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    blurRadius: 20,
                  ),
                ]
              : [],
        ),
        child: Center(
          child: _isSummoning
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.cyanAccent,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  "FORCE SUMMON",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Courier',
                    letterSpacing: 4.0,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── THE UPSELL MODAL ───
  void _showPremiumUpsell() async {
    HapticFeedback.heavyImpact();

    // We need the identity to pass to the ExchangeModal
    final identity = await IdentityStore.active();
    if (identity == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF151A22),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: const Color(0xFFB38728).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFCF6BA).withOpacity(0.05),
                blurRadius: 40,
                spreadRadius: -5,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFB38728),
                  size: 40,
                ),
                const SizedBox(height: 16),
                const Text(
                  "ASCENDED EXCLUSIVE",
                  style: TextStyle(
                    color: Color(0xFFFCF6BA),
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Automated background synchronization is a heavy operation reserved for Ascended members.\n\nTranscend your constraints to unlock the Passive Engine.",
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

                // 🚀 ROUTE TO EXCHANGE
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context); // Close the bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExchangeModal(identity: identity),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB38728).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFB38728).withOpacity(0.6),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      "ENTER THE EXCHANGE",
                      style: TextStyle(
                        color: Color(0xFFFCF6BA),
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SpringButton(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.9)
                  : Colors.white.withOpacity(0.03),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.white54,
                  size: 24,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isSelected ? Colors.black54 : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _SpringButton({required this.child, required this.onTap});

  @override
  State<_SpringButton> createState() => _SpringButtonState();
}

class _SpringButtonState extends State<_SpringButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.animateTo(0.92, curve: Curves.easeOutCubic),
      onTapUp: (_) {
        _controller.animateWith(
          SpringSimulation(
            const SpringDescription(mass: 0.4, stiffness: 400, damping: 20),
            _controller.value,
            1.0,
            0.0,
          ),
        );
        widget.onTap();
      },
      onTapCancel: () => _controller.animateTo(1.0),
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}
