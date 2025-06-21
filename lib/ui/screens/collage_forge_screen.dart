import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/identity_store.dart';
import '../../utils/axiom_gate.dart';
import '../../data/models/moment.dart';
import '../../utils/imagekit.dart';
import '../../utils/wallpaper_helper.dart';
import '../../utils/cinematic_toast.dart';
import '../../utils/share_processing_overlay.dart';

class CollageForgeScreen extends StatefulWidget {
  final List<Moment> moments;
  final String archiveName;

  const CollageForgeScreen({
    super.key,
    required this.moments,
    required this.archiveName,
  });

  @override
  State<CollageForgeScreen> createState() => _CollageForgeScreenState();
}

class _CollageForgeScreenState extends State<CollageForgeScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final int _maxDimension = 2400; // 🚀 Added for the premium watermark scaler

  late List<Moment> _canvasMoments;
  late List<Moment> _trayMoments;

  int _columns = 2;
  bool _isHumanMode = true;
  bool _isCapturing = false;
  bool _isPreviewMode = false;
  bool _isApplying = false;
  Future<String>? _watermarkTask;

  @override
  void initState() {
    super.initState();
    _canvasMoments = [];
    _trayMoments = [];
    _rebalanceMoments();
  }

  void _rebalanceMoments() {
    int maxCanvasCount = _columns * 4;
    List<Moment> allMoments = [..._canvasMoments, ..._trayMoments];
    if (allMoments.isEmpty) allMoments = List.from(widget.moments);

    if (allMoments.length <= maxCanvasCount) {
      _canvasMoments = List.from(allMoments);
      _trayMoments = [];
    } else {
      _canvasMoments = allMoments.sublist(0, maxCanvasCount);
      _trayMoments = allMoments.sublist(maxCanvasCount);
    }
  }

  void _toggleLayout() {
    HapticFeedback.selectionClick();
    setState(() {
      _columns = _columns == 2 ? 3 : 2;
      _rebalanceMoments();
    });
  }

  void _toggleVibe() {
    HapticFeedback.selectionClick();
    setState(() {
      _isHumanMode = !_isHumanMode;
    });
    showCinematicToast(
      context,
      _isHumanMode ? "ORGANIC FREEWAY" : "RIGID SYSTEMWAY",
    );
  }

  void _shuffle() {
    HapticFeedback.lightImpact();
    setState(() {
      _canvasMoments.shuffle();
      _trayMoments.shuffle();
    });
  }

  void _handleDrop(Map<String, dynamic> data, int targetCanvasIndex) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (data['source'] == 'canvas') {
        final fromIndex = data['index'];
        final temp = _canvasMoments[fromIndex];
        _canvasMoments[fromIndex] = _canvasMoments[targetCanvasIndex];
        _canvasMoments[targetCanvasIndex] = temp;
      } else if (data['source'] == 'tray') {
        final trayIndex = data['index'];
        final temp = _trayMoments[trayIndex];
        _trayMoments[trayIndex] = _canvasMoments[targetCanvasIndex];
        _canvasMoments[targetCanvasIndex] = temp;
      }
    });
  }

  // 🚀 HIGH PERFORMANCE PIPELINE: Toll -> Capture -> Save Clean -> Watermark -> Show UI
  Future<void> _captureAndApply() async {
    if (_isCapturing) return; // Prevent spam clicks

    HapticFeedback.selectionClick();

    // ─── 1. THE AXIOM GATEKEEPER ───
    final identity = await IdentityStore.active();

    if (identity == null) {
      // 👻 GHOST PROTOCOL
      final ghostAppliesLeft = await IdentityStore.getGhostApplies();
      if (ghostAppliesLeft <= 0) {
        if (mounted) AxiomGate.showGhostWall(context);
        return; // Stop the manifestation
      }
      await IdentityStore.decrementGhostApplies();
      if (mounted) {
        showCinematicToast(
          context,
          "GHOST ESSENCE: ${ghostAppliesLeft - 1} REMAINING",
        );
      }
    } else {
      // 💎 LOGGED IN USER: CHARGE 4 AXIOMS
      final confirmed = await AxiomGate.requestToll(
        context: context,
        title: "FORGE COLLAGE",
        description:
            "Fuse these fragmented memories into a single dimensional anchor.",
        cost: 4,
        actionLabel: "MANIFEST",
      );
      if (!confirmed) return; // User backed out or couldn't afford it
    }

    // ─── 2. PROCEED WITH CAPTURE ───
    HapticFeedback.heavyImpact();
    setState(() => _isCapturing = true);

    await Future.delayed(const Duration(milliseconds: 150));

    try {
      showCinematicToast(context, "FORGING PIXELS...");

      RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();

      // UNIQUE TIMESTAMPS: Fixes OS caching bugs
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanPath = '${directory.path}/forged_clean_$timestamp.png';
      final sharePath = '${directory.path}/forged_share_$timestamp.png';

      final cleanFile = File(cleanPath);
      await cleanFile.writeAsBytes(pngBytes);

      // TRACK THE WATERMARK TASK
      _watermarkTask = _generateWatermarkedShare(pngBytes, sharePath);

      // LAG FIX: Let the UI thread breathe before showing the bottom sheet
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;
      _showApplicationSheet(cleanFile.path);
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<String> _generateWatermarkedShare(
    Uint8List cleanBytes,
    String targetPath,
  ) async {
    try {
      final ByteData logoData = await rootBundle.load(
        'assets/app_icon_foreground.png',
      );
      final Uint8List logoBytes = logoData.buffer.asUint8List();

      final watermarkedBytes = await _applyMinimalWatermark(
        cleanBytes,
        logoBytes,
      );

      final shareFile = File(targetPath);
      await shareFile.writeAsBytes(watermarkedBytes);
      return targetPath; // Return path when done
    } catch (e) {
      debugPrint("Watermark failed: $e");
      final shareFile = File(targetPath);
      await shareFile.writeAsBytes(cleanBytes);
      return targetPath; // Fallback to clean
    }
  }

  // 🚀 YOUR PREMIUM WATERMARK LOGIC
  Future<Uint8List> _applyMinimalWatermark(
    Uint8List imageBytes,
    Uint8List logoBytes,
  ) async {
    final ui.Codec bgCodec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: _maxDimension,
    );
    final ui.Image bgImage = (await bgCodec.getNextFrame()).image;

    final int targetLogoWidth = (bgImage.width * 0.12).toInt();
    final ui.Codec logoCodec = await ui.instantiateImageCodec(
      logoBytes,
      targetWidth: targetLogoWidth,
    );
    final ui.Image logoImage = (await logoCodec.getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(bgImage, Offset.zero, Paint());

    final double padding = bgImage.width * 0.035;
    final double logoX = bgImage.width - logoImage.width - padding;
    final double logoY = bgImage.height - logoImage.height - padding;

    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20)
      ..color = const Color(0x33000000);

    canvas.drawCircle(
      Offset(logoX + logoImage.width / 2, logoY + logoImage.height / 2),
      logoImage.width * 0.8,
      glowPaint,
    );

    final logoPaint = Paint()..color = const Color(0xE6FFFFFF);
    canvas.drawImage(logoImage, Offset(logoX, logoY), logoPaint);

    final finalImage = await recorder.endRecording().toImage(
      bgImage.width,
      bgImage.height,
    );
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  // 🚀 THE FIX: Removed outer padding, wrapped in SafeArea & internal padded ScrollView
  void _showApplicationSheet(String filePath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "MANIFEST COLLAGE",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 32),
                _ApplyButton(
                  label: "HOME SCREEN",
                  onTap: () => _apply(filePath, WallpaperHelper.FLAG_SYSTEM),
                ),
                const SizedBox(height: 16),
                _ApplyButton(
                  label: "LOCK SCREEN",
                  onTap: () => _apply(filePath, WallpaperHelper.FLAG_LOCK),
                ),
                const SizedBox(height: 16),
                _ApplyButton(
                  label: "BOTH SCREENS",
                  onTap: () => _apply(filePath, WallpaperHelper.FLAG_BOTH),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 32),
                _ApplyButton(
                  label: "TRANSMIT ONLY",
                  isAccent: true,
                  onTap: () {
                    Navigator.pop(context);
                    _triggerNativeShare();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _isCapturing = false);
    });
  }

  void _apply(String path, int flag) async {
    // 1. Close the bottom sheet
    Navigator.pop(context);
    HapticFeedback.heavyImpact();

    // 2. Trigger the full-screen loading overlay
    setState(() => _isApplying = true);

    // 3. 🚀 THE UI BREATHER (CRITICAL FIX)
    // We give the Flutter engine exactly 400ms to animate the bottom sheet closing
    // and draw our loading overlay before we trigger the heavy native OS wallpaper task.
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      // 4. Now the UI is safe, execute the heavy freeze
      await WallpaperHelper.setWallpaperFromFile(path, location: flag);

      if (mounted) {
        setState(() => _isApplying = false);
        showCinematicToast(context, "DIMENSION ANCHORED");

        // Wait 1.2s for the user to read the toast, then ask to share
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          _showPostApplySharePrompt();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        showCinematicToast(context, "TRANSMISSION FAILED");
      }
    }
  }

  // 🚀 THE EPHEMERAL PROMPT
  void _showPostApplySharePrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.ios_share_rounded,
                color: Colors.cyanAccent,
                size: 32,
              ),
              const SizedBox(height: 24),
              const Text(
                "EPHEMERAL ECHO",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "This frequency will be lost to the void once you leave. Transmit it to the network before it fades?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontFamily: 'Serif',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              _ApplyButton(
                label: "TRANSMIT (SHARE)",
                isAccent: true,
                onTap: () {
                  Navigator.pop(context);
                  _triggerNativeShare();
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "LET IT FADE",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerNativeShare() async {
    HapticFeedback.heavyImpact();

    // 1. Safety check
    if (_watermarkTask == null) return;

    // 2. Launch your premium overlay!
    // barrierDismissible: false prevents them from tapping out of it while it processes
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          Colors.transparent, // Your overlay widget handles its own dark blur!
      builder: (_) => const ShareProcessingOverlay(),
    );

    // 3. Await the watermark AND a minimum cinematic delay.
    // If the watermark is already done, it still waits 800ms so the pulse animation feels deliberate.
    final results = await Future.wait([
      _watermarkTask!,
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    final pathToShare = results[0] as String;
    final finalUrl = 'https://theataraxia.web.app';

    // 4. Close the overlay
    if (mounted) {
      Navigator.pop(context);
    }

    // 5. Fire the native share sheet
    try {
      await Share.shareXFiles([
        XFile(pathToShare),
      ], text: "Forged a new dimension in the void.\n\nThe void: $finalUrl");
    } catch (e) {
      debugPrint("Failed to transmit collage: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              color: Colors.black,
              width: screenSize.width,
              height: screenSize.height,
              child: _isHumanMode
                  ? _buildFreewayLayout()
                  : _buildSystemwayLayout(),
            ),
          ),

          if (!_isCapturing) ...[
            // 🚀 THE EYE ICON
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: _GlassBtn(
                icon: _isPreviewMode
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isPreviewMode = !_isPreviewMode);
                },
              ),
            ),

            // TOP HEADER
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: _isPreviewMode
                  ? -100
                  : MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 80, // Leave room for the eye icon
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isPreviewMode ? 0.0 : 1.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassBtn(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    Text(
                      "FORGE: ${widget.archiveName.toUpperCase()}",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 10,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _GlassBtn(
                          icon: _isHumanMode
                              ? Icons.water_drop_rounded
                              : Icons.grid_4x4_rounded,
                          onTap: _toggleVibe,
                        ),
                        const SizedBox(width: 8),
                        _GlassBtn(
                          icon: _columns == 2
                              ? Icons.grid_view_rounded
                              : Icons.view_module_rounded,
                          onTap: _toggleLayout,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // TRAY OR TEXT
            if (_trayMoments.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: _isPreviewMode ? -150 : 120,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isPreviewMode ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isPreviewMode,
                    child: _buildTray(),
                  ),
                ),
              )
            else
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: _isPreviewMode ? -50 : 140,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isPreviewMode ? 0.0 : 1.0,
                  child: Center(
                    child: Text(
                      "Hold and drag to weave the dimensions.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontFamily: 'Serif',
                        fontStyle: FontStyle.italic,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // BOTTOM BAR
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: _isPreviewMode ? -100 : 40,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isPreviewMode ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isPreviewMode,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GlassBtn(icon: Icons.shuffle_rounded, onTap: _shuffle),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: _captureAndApply,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.2),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Text(
                            "MANIFEST",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_isApplying)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) =>
                    Opacity(opacity: val, child: child),
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            "TRANSCENDING...",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontFamily: 'Courier',
                              letterSpacing: 6,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget _buildFreewayLayout() {
  //   return MasonryGridView.count(
  //     padding: const EdgeInsets.all(8),
  //     crossAxisCount: _columns,
  //     mainAxisSpacing: 6,
  //     crossAxisSpacing: 6,
  //     physics: const NeverScrollableScrollPhysics(),
  //     itemCount: _canvasMoments.length,
  //     itemBuilder: (context, index) {
  //       return _buildCanvasDragTarget(
  //         index: index,
  //         moment: _canvasMoments[index],
  //         borderRadius: 16,
  //       );
  //     },
  //   );
  // }

  Widget _buildFreewayLayout() {
    // 1. Create separate lists for our strict, locked columns
    List<List<Widget>> columnItems = List.generate(_columns, (index) => []);

    // 2. Distribute items strictly by alternating index
    for (int i = 0; i < _canvasMoments.length; i++) {
      columnItems[i % _columns].add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: _buildCanvasDragTarget(
            index: i,
            moment: _canvasMoments[i],
            borderRadius: 16,
          ),
        ),
      );
    }

    // 3. Build the Row layout evenly
    List<Widget> rowChildren = [];
    for (int i = 0; i < _columns; i++) {
      rowChildren.add(
        Expanded(
          // 🚀 THE FIX: We wrap the Column in a non-scrolling SingleChildScrollView.
          // This perfectly mimics the Masonry package's clipping behavior.
          // If images run off the bottom of the screen, it simply cuts them cleanly
          // instead of throwing an overflow error!
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: columnItems[i],
            ),
          ),
        ),
      );

      // Add crossAxisSpacing between columns
      if (i < _columns - 1) {
        rowChildren.add(const SizedBox(width: 6.0));
      }
    }

    // 4. Return the native layout
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      ),
    );
  }

  Widget _buildSystemwayLayout() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        childAspectRatio: 0.65,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      itemCount: _canvasMoments.length,
      itemBuilder: (context, index) {
        return _buildCanvasDragTarget(
          index: index,
          moment: _canvasMoments[index],
          borderRadius: 0,
        );
      },
    );
  }

  Widget _buildCanvasDragTarget({
    required int index,
    required Moment moment,
    required double borderRadius,
  }) {
    return DragTarget<Map<String, dynamic>>(
      onAccept: (data) => _handleDrop(data, index),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        Widget imgChild = Stack(
          fit: StackFit.passthrough,
          children: [
            // 1. The Image (Never changes size, keeping your exact gaps)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: ImageKit.constrainedWidth(
                  path: moment.imageKey,
                  width: 400,
                ),
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF111111)),
              ),
            ),
            // 2. The Hover Border (Drawn OVER the image)
            if (isHovered)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: Colors.cyanAccent, width: 4),
                  ),
                ),
              ),
          ],
        );

        return LongPressDraggable<Map<String, dynamic>>(
          data: {'source': 'canvas', 'index': index},
          delay: const Duration(milliseconds: 200),
          onDragStarted: () => HapticFeedback.selectionClick(),
          feedback: SizedBox(
            width: (MediaQuery.of(context).size.width / _columns) * 1.05,
            height:
                ((MediaQuery.of(context).size.width / _columns) / 0.65) * 1.05,
            child: Opacity(opacity: 0.8, child: imgChild),
          ),
          childWhenDragging: Opacity(opacity: 0.2, child: imgChild),
          child: imgChild,
        );
      },
    );
  }

  Widget _buildTray() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border.symmetric(
              horizontal: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _trayMoments.length,
            itemBuilder: (context, index) {
              final moment = _trayMoments[index];
              Widget imgChild = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: ImageKit.constrainedWidth(
                    path: moment.imageKey,
                    width: 200,
                  ),
                  width: 55,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF111111)),
                ),
              );

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LongPressDraggable<Map<String, dynamic>>(
                  data: {'source': 'tray', 'index': index},
                  delay: const Duration(milliseconds: 150),
                  onDragStarted: () => HapticFeedback.selectionClick(),
                  feedback: SizedBox(
                    width: 100,
                    height: 150,
                    child: Opacity(opacity: 0.9, child: imgChild),
                  ),
                  childWhenDragging: Opacity(opacity: 0.2, child: imgChild),
                  child: imgChild,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- UI COMPONENTS ---
class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAccent; // 🚀 PREMIUM CYAN GLOW FLAG

  const _ApplyButton({
    required this.label,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isAccent
              ? Colors.cyanAccent.withOpacity(0.1)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAccent
                ? Colors.cyanAccent.withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isAccent ? Colors.cyanAccent : Colors.white,
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
