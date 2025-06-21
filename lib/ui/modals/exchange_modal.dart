import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../data/models/identity.dart';
import '../../utils/cinematic_toast.dart';
import '../../utils/purchase_service.dart';

class ExchangeModal extends StatefulWidget {
  final Identity identity;
  const ExchangeModal({super.key, required this.identity});

  @override
  State<ExchangeModal> createState() => _ExchangeModalState();
}

class _ExchangeModalState extends State<ExchangeModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  bool _isProcessing = false;
  bool _isLoadingPrices = true;

  Map<String, String> _priceStrings = {}; // e.g., {'axiom_pack_500': '$3.99'}
  Map<String, double> _rawPrices = {};
  Map<String, Package> _offeredPackages = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fetchDynamicPrices();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDynamicPrices() async {
    try {
      final offerings = await Purchases.getOfferings();

      if (offerings.current != null) {
        final Map<String, String> fetchedPrices = {};
        final Map<String, double> fetchedRaw = {};
        final Map<String, Package> fetchedPackages = {};

        for (final package in offerings.current!.availablePackages) {
          final product = package.storeProduct;
          final cleanId = product.identifier.split(':').first;

          fetchedPrices[cleanId] = product.priceString;
          fetchedRaw[cleanId] = product.price;
          fetchedPackages[cleanId] = package;
        }

        if (mounted) {
          setState(() {
            _priceStrings = fetchedPrices;
            _rawPrices = fetchedRaw;
            _offeredPackages = fetchedPackages;
            _isLoadingPrices = false;
          });
        }
      } else {
        debugPrint("REVENUECAT: No current offering found.");
        if (mounted) setState(() => _isLoadingPrices = false);
      }
    } catch (e) {
      debugPrint("REVENUECAT ERROR: Failed to fetch offerings: $e");
      if (mounted) setState(() => _isLoadingPrices = false);
    }
  }

  void _initiatePurchase(String productId) async {
    if (_isProcessing) return;

    // 🚀 Grab the exact package from our map
    final packageToBuy = _offeredPackages[productId];
    if (packageToBuy == null) {
      showCinematicToast(context, "ERROR: ARTIFACT NOT FOUND.");
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.heavyImpact();
    showCinematicToast(context, "ESTABLISHING SECURE CONNECTION...");

    // 🚀 FIRE REVENUE CAT WITH THE PACKAGE
    bool success = await PurchaseService.buyPackage(packageToBuy);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        Navigator.pop(context);
        showCinematicToast(
          context,
          "TRANSACTION SUCCESSFUL. THE VOID PROVIDES.",
        );
      } else {
        showCinematicToast(context, "TRANSACTION SEVERED.");
      }
    }
  }

  // ─── DYNAMIC DISCOUNT CALCULATORS ───

  /// Calculates savings for Yearly vs Monthly
  String _calculateYearlySavings(double monthlyPrice, double yearlyPrice) {
    if (monthlyPrice <= 0 || yearlyPrice <= 0) return "";

    double costIfPaidMonthly = monthlyPrice * 12;
    if (yearlyPrice >= costIfPaidMonthly) return ""; // No discount

    double savingsFraction = 1 - (yearlyPrice / costIfPaidMonthly);
    int percentage = (savingsFraction * 100).round();

    return "SAVE $percentage%";
  }

  /// Calculates bonus for bulk Axioms based on the base tier (100 Axioms)
  String _calculateAxiomBonus(
    double basePrice100,
    double bulkPrice,
    int bulkAmount,
  ) {
    if (basePrice100 <= 0 || bulkPrice <= 0) return "";

    // How much would it cost to buy this amount using the 100-pack?
    double expectedCost = (bulkAmount / 100) * basePrice100;

    if (bulkPrice >= expectedCost) return "";

    double savingsFraction = 1 - (bulkPrice / expectedCost);
    int percentage = (savingsFraction * 100).round();

    return "BONUS $percentage%";
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final isPremium = widget.identity.isPremium; // 🚀 CHECK STATUS

    // 🚀 1. USE THE LOADING STATE HERE
    if (_isLoadingPrices) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFB38728), // Matches your Ascension theme
                strokeWidth: 2,
              ),
              SizedBox(height: 24),
              Text(
                "SYNCHRONIZING EXCHANGE...",
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Courier',
                  letterSpacing: 4,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🚀 2. THE REST OF YOUR UI (Only shows when loading is done)
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 0 : 32.0,
                  vertical: 40.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CLOSE BUTTON
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // TITLE
                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.0, 0.4),
                      child: Text(
                        "THE\nEXCHANGE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 72 : 48,
                          fontFamily: 'Times New Roman',
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.1, 0.5),
                      child: Text(
                        "Acquire raw essence or transcend constraints.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: isTablet ? 18 : 14,
                          fontFamily: 'Serif',
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // 🚀 ATARAXIA ASCENDED (PREMIUM LOGIC GATE)
                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.2, 0.6),
                      child: isPremium
                          ? _buildActiveAscendedCard(
                              isTablet,
                            ) // 🚀 SHOWS IF ALREADY BOUGHT
                          : _buildPurchaseAscendedCard(
                              isTablet,
                            ), // 🚀 SHOWS IF FREE
                    ),

                    const SizedBox(height: 48),

                    // 🚀 STANDALONE UNLOCKS
                    Text(
                      "DIMENSIONAL EXPANSION",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 10,
                        fontFamily: 'Courier',
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!isPremium && !widget.identity.hasInfiniteArchives)
                      _buildStandaloneUnlock(
                        title: "INFINITE ARCHIVES",
                        subtitle:
                            "Forge unlimited custom collections permanently.",
                        price:
                            _priceStrings['unlock_infinite_archives'] ?? "...",
                        productId: "unlock_infinite_archives",
                        icon: Icons.all_inclusive_rounded,
                      ),

                    const SizedBox(height: 48),

                    _FadeIn(
                      ctrl: _animCtrl,
                      interval: const Interval(0.3, 0.7),
                      child: Text(
                        "AXIOM CLUSTERS",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                          fontFamily: 'Courier',
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildAxiomPack(
                      interval: const Interval(0.4, 0.8),
                      title: "FRAGMENT",
                      amount: 100,
                      price: _priceStrings['axiom_pack_100'] ?? "...",
                      productId: 'axiom_pack_100',
                    ),
                    const SizedBox(height: 12),

                    _buildAxiomPack(
                      interval: const Interval(0.5, 0.9),
                      title: "CORE",
                      amount: 500,
                      price: _priceStrings['axiom_pack_500'] ?? "...",
                      productId: 'axiom_pack_500',
                      isPopular: true,
                      badge: _calculateAxiomBonus(
                        _rawPrices['axiom_pack_100'] ?? 0,
                        _rawPrices['axiom_pack_500'] ?? 0,
                        500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAxiomPack(
                      interval: const Interval(0.6, 1.0),
                      title: "MONOLITH",
                      amount: 1500,
                      price: _priceStrings['axiom_pack_1500'] ?? "...",
                      productId: 'axiom_pack_1500',
                      badge: _calculateAxiomBonus(
                        _rawPrices['axiom_pack_100'] ?? 0,
                        _rawPrices['axiom_pack_1500'] ?? 0,
                        1500,
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 🚀 NEW: ACTIVE ASCENDED CARD (Shows if already premium) ───
  Widget _buildActiveAscendedCard(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A150C), Color(0xFF2A2012), Color(0xFF141008)],
        ),
        border: Border.all(
          color: const Color(0xFFB38728).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFCF6BA).withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFFFCF6BA),
            size: 32,
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFCF6BA), Color(0xFFB38728), Color(0xFFFBF5B7)],
            ).createShader(bounds),
            child: Text(
              "ASCENSION ACTIVE",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Courier',
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Your identity is bound to the highest frequency of the void. All dimensions and constraints have been unlocked.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Serif',
              fontStyle: FontStyle.italic,
              height: 1.6,
              fontSize: isTablet ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PURCHASE ASCENDED CARD (Shows if free user) ───
  Widget _buildPurchaseAscendedCard(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A150C), // Dark bronze
            Color(0xFF2A2012),
            Color(0xFF141008),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFB38728).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFCF6BA).withOpacity(0.05),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFCF6BA), Color(0xFFB38728), Color(0xFFFBF5B7)],
            ).createShader(bounds),
            child: Text(
              "ATARAXIA ASCENDED",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Courier',
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontSize: isTablet ? 14 : 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "• 50 Axioms daily generation\n• Infinite Personal Archives\n• Automated Dynamic Void\n• Iridescent Identity Signature",
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Serif',
              fontStyle: FontStyle.italic,
              height: 1.6,
              fontSize: isTablet ? 16 : 13,
            ),
          ),
          const SizedBox(height: 32),

          // ─── MONTHLY ───
          _buildSubscriptionTier(
            title: "MONTHLY",
            price: _priceStrings['sub_ascended_monthly'] ?? "...",
            duration: "/ MO",
            productId: "sub_ascended_monthly",
          ),
          const SizedBox(height: 12),

          // ─── YEARLY (HIGHLIGHTED) ───
          _buildSubscriptionTier(
            title: "YEARLY",
            price: _priceStrings['sub_ascended_yearly'] ?? "...",
            duration: "/ YR",
            productId: "sub_ascended_yearly",
            isHighlighted: true,
            // Dynamic Math Badge!
            badge: _calculateYearlySavings(
              _rawPrices['sub_ascended_monthly'] ?? 0,
              _rawPrices['sub_ascended_yearly'] ?? 0,
            ),
          ),
          const SizedBox(height: 12),

          // ─── LIFETIME ───
          _buildSubscriptionTier(
            title: "LIFETIME",
            // OLD: price: "\$89.99",
            price: _priceStrings['sub_ascended_lifetime'] ?? "...",
            duration: "ONCE",
            productId: "sub_ascended_lifetime",
          ),
        ],
      ),
    );
  }

  // ─── HELPER: SUBSCRIPTION TIER BUTTON ───
  Widget _buildSubscriptionTier({
    required String title,
    required String price,
    required String duration,
    required String productId,
    bool isHighlighted = false,
    String? badge,
  }) {
    return GestureDetector(
      onTap: () => _initiatePurchase(productId),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isHighlighted
              ? const Color(0xFFB38728).withOpacity(0.15)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFFB38728).withOpacity(0.6)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🚀 THE FIX: Expanded wraps the left side to prevent RenderFlex overflow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 THE FIX: Changed to Wrap so the badge safely drops down if the screen is too tight
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isHighlighted
                              ? const Color(0xFFFCF6BA)
                              : Colors.white70,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB38728).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Color(0xFFFCF6BA),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12), // Safe buffer zone
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    color: isHighlighted ? Colors.white : Colors.white70,
                    fontFamily: 'Times New Roman',
                    fontSize: 22, // slightly bigger = premium feel
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontFamily: 'Serif',
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(String duration) {
    switch (duration) {
      case "/ MO":
        return "per month";
      case "/ YR":
        return "per year";
      case "ONCE":
        return "lifetime ascended";
      default:
        return duration;
    }
  }

  // ─── HELPER: AXIOM PACK BUTTON ───
  Widget _buildAxiomPack({
    required Interval interval,
    required String title,
    required int amount,
    required String price,
    required String productId,
    bool isPopular = false,
    String? badge,
  }) {
    return _FadeIn(
      ctrl: _animCtrl,
      interval: interval,
      child: GestureDetector(
        onTap: () => _initiatePurchase(productId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPopular
                  ? Colors.cyanAccent.withOpacity(0.4)
                  : Colors.white.withOpacity(0.05),
              width: isPopular ? 1.5 : 1.0,
            ),
            boxShadow: isPopular
                ? [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPopular
                      ? Colors.cyanAccent.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                ),
                child: Icon(
                  Icons.change_history_rounded,
                  color: isPopular ? Colors.cyanAccent : Colors.white54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🚀 2. WRAP ADDED TO PREVENT OVERFLOW IF MULTIPLE BADGES APPEAR
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                        if (isPopular)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "MOST RESONANT",
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 6,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        // 🚀 3. DRAW THE DYNAMIC MATH BADGE IF IT EXISTS
                        if (badge != null && badge.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCF6BA).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Color(0xFFFCF6BA),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$amount Axioms",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontFamily: 'Serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Times New Roman',
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandaloneUnlock({
    required String title,
    required String subtitle,
    required String price,
    required String productId,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _initiatePurchase(productId),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── TOP ROW (ICON + TITLE) ───
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: Icon(icon, color: Colors.white70, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ─── DESCRIPTION ───
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontFamily: 'Serif',
                fontStyle: FontStyle.italic,
                fontSize: 12,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // ─── PRICE BLOCK (MATCHES SUBSCRIPTIONS) ───
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Times New Roman',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "lifetime unlock",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontFamily: 'Serif',
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── REUSABLE ANIMATION COMPONENT ───
class _FadeIn extends StatelessWidget {
  final AnimationController ctrl;
  final Interval interval;
  final Widget child;

  const _FadeIn({
    required this.ctrl,
    required this.interval,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final anim = CurvedAnimation(parent: ctrl, curve: interval);
        final opacity = Curves.easeOut.transform(anim.value);
        final slide = Curves.easeOutQuart.transform(anim.value);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - slide)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
