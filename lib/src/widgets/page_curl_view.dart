import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/page_curl_config.dart';
import '../core/curl_direction.dart';
import '../core/curl_state.dart';
import '../core/page_curl_controller.dart';
import '../gesture/curl_gesture_handler.dart';
import '../rendering/page_curl_painter.dart';
import '../rendering/widget_rasterizer.dart';

/// A widget that displays pages with a realistic page curl (flip) effect.
///
/// [PageCurlView] renders an indexed collection of child widgets as
/// "pages" that can be curled via drag gestures or programmatic
/// commands. During a curl interaction, the current page is rasterised
/// and manipulated on a [Canvas] to produce a realistic paper-folding
/// illusion, complete with shadows and a visible back-of-page.
///
/// ### Basic Usage
///
/// ```dart
/// PageCurlView(
///   itemCount: 20,
///   itemBuilder: (context, index) => BookPage(index),
/// )
/// ```
///
/// ### With External Controller
///
/// ```dart
/// final controller = PageCurlController(
///   vsync: this,
///   config: const PageCurlConfig(),
///   itemCount: 20,
/// );
///
/// PageCurlView(
///   itemCount: 20,
///   itemBuilder: (context, index) => BookPage(index),
///   controller: controller,
/// )
///
/// // Later:
/// controller.flipForward();
/// controller.dispose();
/// ```
///
/// ### Architecture
///
/// - In **idle** state, the current page Widget is displayed normally
///   (no rasterisation overhead).
/// - On **drag start**, the current and under-page widgets are rasterised
///   to [ui.Image]s via [WidgetRasterizer].
/// - During **dragging** and **animating**, a [PageCurlPainter]
///   ([CustomPainter]) renders the curl effect each frame.
/// - On **completion**, the page index advances/retreats and the widget
///   returns to idle state.
class PageCurlView extends StatefulWidget {
  /// Creates a [PageCurlView].
  const PageCurlView({
    required this.itemCount,
    required this.itemBuilder,
    this.config = const PageCurlConfig(),
    this.controller,
    this.onPageChanged,
    this.initialPage = 0,
    super.key,
  });

  /// Total number of pages.
  final int itemCount;

  /// Builder for individual page widgets.
  final IndexedWidgetBuilder itemBuilder;

  /// Master configuration for the curl effect.
  final PageCurlConfig config;

  /// Optional external controller. If not provided, an internal one
  /// is created and managed automatically.
  final PageCurlController? controller;

  /// Called when the current page changes.
  final ValueChanged<int>? onPageChanged;

  /// The page to display initially.
  final int initialPage;

  @override
  State<PageCurlView> createState() => _PageCurlViewState();
}

class _PageCurlViewState extends State<PageCurlView>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Controller
  // ---------------------------------------------------------------------------

  late PageCurlController _controller;
  bool _ownsController = false;

  // ---------------------------------------------------------------------------
  // Rasterisation
  // ---------------------------------------------------------------------------

  /// Keys for the RepaintBoundary wrappers around each page slot.
  final _currentPageBoundaryKey = GlobalKey();
  final _underPageBoundaryKey = GlobalKey();

  /// Cached raster images.
  ui.Image? _currentPageImage;
  ui.Image? _underPageImage;

  /// Tracks whether a capture is pending to avoid redundant captures.
  bool _captureScheduled = false;

  /// Tracks the page index at last capture. Used to detect page changes
  /// and invalidate cached images — critical for external controllers
  /// where [onPageChanged] is not connected to this view.
  int _lastKnownPage = -1;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant PageCurlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _disposeControllerIfOwned();
      _disposeImages();
      _initController();
    }
  }

  @override
  void dispose() {
    _disposeControllerIfOwned();
    _disposeImages();
    super.dispose();
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = PageCurlController(
        vsync: this,
        config: widget.config,
        itemCount: widget.itemCount,
        initialPage: widget.initialPage,
        onPageChanged: _onPageChanged,
      );
      _ownsController = true;
    }

    _lastKnownPage = _controller.currentPage;
    _controller.touchPointNotifier.addListener(_onTouchPointChanged);
  }

  void _disposeControllerIfOwned() {
    _controller.touchPointNotifier.removeListener(_onTouchPointChanged);
    if (_ownsController) {
      _controller.dispose();
    }
  }

  void _disposeImages() {
    _currentPageImage?.dispose();
    _currentPageImage = null;
    _underPageImage?.dispose();
    _underPageImage = null;
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onPageChanged(int page) {
    _disposeImages();
    widget.onPageChanged?.call(page);
    if (mounted) setState(() {});
  }

  void _onTouchPointChanged() {
    // Detect page changes (works for both internal and external controllers).
    // When the controller's currentPage differs from our last-known page,
    // the cached images are stale and must be discarded.
    if (_controller.currentPage != _lastKnownPage) {
      _lastKnownPage = _controller.currentPage;
      _disposeImages();
    }

    // Schedule capture when transitioning from idle to any active state
    // (dragging or animating) and we don't yet have valid images.
    final isActive = _controller.state != CurlState.idle;
    if (isActive && _currentPageImage == null && !_captureScheduled) {
      _scheduleCaptureAfterFrame();
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Rasterisation
  // ---------------------------------------------------------------------------

  /// Schedules a page capture after the current frame finishes painting,
  /// ensuring the RepaintBoundary layers are fully composited.
  void _scheduleCaptureAfterFrame() {
    _captureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (!mounted) return;
      _capturePages();
    });
  }

  Future<void> _capturePages() async {
    final currentBoundary =
        _currentPageBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    final underBoundary =
        _underPageBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (currentBoundary == null || underBoundary == null) return;

    final ratio = MediaQuery.devicePixelRatioOf(context);

    final results = await Future.wait([
      WidgetRasterizer.capture(currentBoundary, pixelRatio: ratio),
      WidgetRasterizer.capture(underBoundary, pixelRatio: ratio),
    ]);

    if (!mounted) return;

    _disposeImages();
    _currentPageImage = results[0];
    _underPageImage = results[1];

    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Computes the under-page index based on current controller state.
  int _computeUnderPageIndex() {
    final currentPage = _controller.currentPage;
    return _controller.direction == CurlDirection.forward
        ? (currentPage + 1).clamp(0, widget.itemCount - 1)
        : (currentPage - 1).clamp(0, widget.itemCount - 1);
  }

  /// Whether the curl overlay has valid images and should be shown.
  bool get _hasValidImages =>
      _currentPageImage != null && _underPageImage != null;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _controller.setPageSize(size);

        final currentPage = _controller.currentPage;
        final isActive = _controller.state != CurlState.idle;
        final underPageIndex = _computeUnderPageIndex();

        // Whether the overlay is ready (active AND images captured).
        final showOverlay = isActive && _hasValidImages;

        return CurlGestureHandler(
          controller: _controller,
          config: widget.config,
          child: Stack(
            children: [
              // ---------------------------------------------------------------
              // Under-page — always painted in the stack (covered by the
              // current page above it). NO Offstage — this ensures
              // RepaintBoundary can always be captured by toImage().
              // ---------------------------------------------------------------
              Positioned.fill(
                child: RepaintBoundary(
                  key: _underPageBoundaryKey,
                  child: widget.itemBuilder(context, underPageIndex),
                ),
              ),

              // ---------------------------------------------------------------
              // Current page — always painted on top of under-page.
              // When the overlay is showing, it visually covers this widget,
              // but we keep it painted so toImage() always works.
              // ---------------------------------------------------------------
              Positioned.fill(
                child: RepaintBoundary(
                  key: _currentPageBoundaryKey,
                  child: widget.itemBuilder(context, currentPage),
                ),
              ),

              // ---------------------------------------------------------------
              // Curl effect overlay — fully covers both pages below when
              // active, producing the fold illusion. Only shown when we
              // have valid raster images.
              // ---------------------------------------------------------------
              if (showOverlay)
                Positioned.fill(
                  child: CustomPaint(
                    painter: PageCurlPainter(
                      currentPageImage: _currentPageImage!,
                      underPageImage: _underPageImage!,
                      touchPoint: _controller.touchPointNotifier.value,
                      cornerOrigin: _controller.cornerOrigin,
                      config: widget.config,
                      pixelRatio: MediaQuery.devicePixelRatioOf(context),
                    ),
                    size: size,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
