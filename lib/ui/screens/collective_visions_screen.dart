import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/identity.dart';
import '../../data/models/vision_request.dart';
import '../../supabase/supabase_service.dart';
import '../../utils/cinematic_toast.dart';
import '../../utils/axiom_gate.dart';

class CollectiveVisionsScreen extends StatefulWidget {
  final Identity identity;

  const CollectiveVisionsScreen({super.key, required this.identity});

  @override
  State<CollectiveVisionsScreen> createState() =>
      _CollectiveVisionsScreenState();
}

class _CollectiveVisionsScreenState extends State<CollectiveVisionsScreen> {
  late PageController _pageCtrl;
  int _currentIndex = 0;

  // 🚀 DUAL-CACHE: We store both feeds so swiping is instant and buttery smooth
  List<VisionRequest> _topVisions = [];
  List<VisionRequest> _recentVisions = [];
  bool _isLoadingTop = true;
  bool _isLoadingRecent = true;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(initialPage: 0);
    _loadVisions();
  }

  Future<void> _loadVisions() async {
    // Fetch both feeds simultaneously in the background
    SupabaseService.fetchCollectiveVisions(widget.identity.id, sortByTop: true)
        .then((data) {
          if (mounted)
            setState(() {
              _topVisions = data;
              _isLoadingTop = false;
            });
        })
        .catchError((_) {
          if (mounted) setState(() => _isLoadingTop = false);
        });

    SupabaseService.fetchCollectiveVisions(widget.identity.id, sortByTop: false)
        .then((data) {
          if (mounted)
            setState(() {
              _recentVisions = data;
              _isLoadingRecent = false;
            });
        })
        .catchError((_) {
          if (mounted) setState(() => _isLoadingRecent = false);
        });
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleVote(VisionRequest vision) async {
    final bool isVoting = !vision.hasVoted;

    // 🚀 THE AXIOM GATE
    final confirmed = await AxiomGate.requestToll(
      context: context,
      title: isVoting ? "RESONATE WITH VISION" : "SEVER RESONANCE",
      description: isVoting
          ? "Contribute your essence to manifest this dimension."
          : "Severing resonance burns 3 Axioms to the void. Only 2 will be refunded.",
      cost: isVoting ? 5 : 2,
      actionLabel: isVoting ? "RESONATE" : "SEVER",
      isRefund: !isVoting,
    );

    if (!confirmed) return; // User aborted or couldn't afford it

    HapticFeedback.lightImpact();
    // Optimistic UI update across both lists to keep them perfectly synced
    setState(() {
      _updateVisionInLists(vision.id, isVoting);
      if (isVoting) HapticFeedback.selectionClick();
    });

    try {
      final nowVoted = await SupabaseService.toggleVisionVote(
        widget.identity.id,
        vision.id,
      );
      if (vision.hasVoted != nowVoted && mounted) {
        setState(() => _updateVisionInLists(vision.id, nowVoted));
      }
    } catch (e) {
      if (mounted)
        setState(() => _updateVisionInLists(vision.id, !vision.hasVoted));
    }
  }

  void _updateVisionInLists(String id, bool isVoted) {
    void updateList(List<VisionRequest> list) {
      final index = list.indexWhere((v) => v.id == id);
      if (index != -1) {
        final v = list[index];
        if (v.hasVoted != isVoted) {
          v.hasVoted = isVoted;
          v.upvotes += isVoted ? 1 : -1;
        }
      }
    }

    updateList(_topVisions);
    updateList(_recentVisions);
  }

  void _deleteVision(VisionRequest vision) async {
    HapticFeedback.heavyImpact();

    // Optimistically remove it from the UI so it feels instant
    setState(() {
      _topVisions.removeWhere((v) => v.id == vision.id);
      _recentVisions.removeWhere((v) => v.id == vision.id);
    });

    try {
      await SupabaseService.deleteVisionRequest(vision.id);
      if (mounted) showCinematicToast(context, "VISION EXPUNGED");
    } catch (e) {
      // If it fails, reload the feed to fix the UI state
      _loadVisions();
    }
  }

  void _openRequestModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Required for keyboard push-up
      builder: (context) => _RequestVisionModal(
        userId: widget.identity.id,
        onSubmitted: () {
          // Show loaders again and refetch everything to get the new data
          setState(() {
            _isLoadingTop = true;
            _isLoadingRecent = true;
          });
          _loadVisions();
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white54,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "THE COLLECTIVE",
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ─── THE TOP / NEW TOGGLE ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton("TOP VISIONS", 0)),
                  Expanded(child: _buildTabButton("RECENT", 1)),
                ],
              ),
            ),
          ),

          // ─── THE SWIPEABLE FEED ───
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                HapticFeedback.lightImpact();
              },
              children: [
                _buildFeedList(_topVisions, _isLoadingTop),
                _buildFeedList(_recentVisions, _isLoadingRecent),
              ],
            ),
          ),
        ],
      ),

      // ─── REQUEST BUTTON ───
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        onTap: _openRequestModal,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Colors.cyanAccent.withOpacity(0.9),
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "MANIFEST A VISION",
                    style: TextStyle(
                      color: Colors.cyanAccent.withOpacity(0.9),
                      fontSize: 10,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int tabIndex) {
    final isSelected = _currentIndex == tabIndex;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTab(tabIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedList(List<VisionRequest> feedData, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white24,
          strokeWidth: 1.5,
        ),
      );
    }

    if (feedData.isEmpty) {
      return Center(
        child: Text(
          "THE VOID AWAITS YOUR COMMAND.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.2),
            fontSize: 10,
            fontFamily: 'Courier',
            letterSpacing: 4,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      physics: const BouncingScrollPhysics(),
      itemCount: feedData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildVisionCard(feedData[index]),
    );
  }

  Widget _buildVisionCard(VisionRequest vision) {
    final bool isMine =
        vision.userId ==
        widget.identity.id; // 🚀 CHECK IF IT BELONGS TO CURRENT USER

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vision.hasVoted
              ? Colors.cyanAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${vision.prompt}"',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontFamily: 'Times New Roman',
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (vision.status == 'manifesting')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "CURRENTLY MANIFESTING...",
                          style: TextStyle(
                            color: Colors.deepPurpleAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),

                    // 🚀 THE DELETE BUTTON (Only shows if the user created it)
                    if (isMine)
                      GestureDetector(
                        onTap: () => _deleteVision(vision),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            "SEVER",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _toggleVote(vision),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: vision.hasVoted
                    ? Colors.cyanAccent.withOpacity(0.1)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: vision.hasVoted
                      ? Colors.cyanAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: vision.hasVoted ? Colors.cyanAccent : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${vision.upvotes}",
                    style: TextStyle(
                      color: vision.hasVoted
                          ? Colors.cyanAccent
                          : Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── REQUEST INPUT MODAL ───
class _RequestVisionModal extends StatefulWidget {
  final String userId;
  final VoidCallback onSubmitted;

  const _RequestVisionModal({required this.userId, required this.onSubmitted});

  @override
  State<_RequestVisionModal> createState() => _RequestVisionModalState();
}

// 1. Add the Observer
class _RequestVisionModalState extends State<_RequestVisionModal>
    with WidgetsBindingObserver {
  // 🚀 SESSION STATE: This static variable preserves the text even if they close the modal!
  static String _draftVisionText = "";

  late final TextEditingController _ctrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to raw engine
    _ctrl = TextEditingController(text: _draftVisionText);
  }

  void _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    // 🚀 THE AXIOM GATE
    final confirmed = await AxiomGate.requestToll(
      context: context,
      title: "MANIFEST VISION",
      description:
          "Submit a request to the Collective. This requires immense energy.",
      cost: 25,
      actionLabel: "MANIFEST",
    );

    if (!confirmed) return;

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      await SupabaseService.submitVisionRequest(widget.userId, text);
      _draftVisionText = "";

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        showCinematicToast(context, "VISION ANCHORED IN THE COLLECTIVE");
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Clean up
    _ctrl.dispose();
    super.dispose();
  }

  // 2. Trigger rebuild on keyboard pop
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 3. Bypass the Scaffold trap
    final keyboardHeight = MediaQueryData.fromView(
      View.of(context),
    ).viewInsets.bottom;

    // 4. Animate the padding and wrap in SingleChildScrollView
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutQuart,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Colors.black.withOpacity(0.9),
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DESCRIBE YOUR VISION",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontFamily: 'Courier',
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: 150,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'Times New Roman',
                      fontStyle: FontStyle.italic,
                    ),
                    cursorColor: Colors.cyanAccent,
                    onChanged: (val) {
                      _draftVisionText = val; // 🚀 Constantly saves their draft
                    },
                    decoration: InputDecoration(
                      counterText: "",
                      hintText:
                          'e.g. A lone samurai in a neon-lit cyberpunk alleyway raining heavily...',
                      hintMaxLines: 3,
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_isSaving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.cyanAccent,
                            strokeWidth: 1.5,
                          ),
                        )
                      else
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _submit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              "SUBMIT TO THE VOID",
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 10,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900,
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
      ),
    );
  }
}
