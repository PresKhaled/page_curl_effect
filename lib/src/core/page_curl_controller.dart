import 'package:flutter/widgets.dart';

import '../config/page_curl_config.dart';
import 'curl_axis.dart';
import 'curl_direction.dart';
import 'curl_state.dart';
import 'page_curl_physics.dart';

/// Signature for callbacks triggered when a page flip starts.
typedef OnFlipStart = void Function(int currentPage, CurlDirection direction);

/// Signature for callbacks triggered when a page flip completes.
typedef OnFlipEnd = void Function(int newPage);

/// Orchestrates the page curl state machine and animation lifecycle.
///
/// Extends Flutter's [PageController] so that **one controller instance**
/// can serve both navigation modes of an EPUB / book reader:
///
/// | Mode | Scroll clients | Navigation |
/// |------|---------------|-----------|
/// | `PageView` (curl OFF) | `hasClients == true` | Delegates to [PageController] scroll physics |
/// | `PageCurlView` (curl ON) | `hasClients == false` | Internal curl animation |
///
/// ### Why extend `PageController`?
///
/// Consumer apps that conditionally toggle the page curl effect previously had
/// to maintain two separate controllers — a [PageController] for a regular
/// [PageView] and a [PageCurlController] for [PageCurlView] — then keep their
/// page-index state in sync manually. By inheriting from [PageController],
/// one controller suffices regardless of which view is active:
///
/// ```dart
/// final ctrl = PageCurlController(vsync: this, config: ..., itemCount: 100);
///
/// // Curl mode — pass to PageCurlView:
/// PageCurlView(controller: ctrl, ...)
///
/// // Normal mode — pass to PageView:
/// PageView.builder(controller: ctrl, ...)
///
/// // Navigation works the same way in both modes:
/// ctrl.nextPage(duration: kThemeAnimationDuration, curve: Curves.easeInOut);
/// ctrl.jumpToPage(5);
/// ```
///
/// ### `PageController` API behaviour by mode
///
/// * **[page]** — returns the actual scroll-position page when a [PageView]
///   is attached; otherwise returns [currentPage] as a [double].
/// * **[jumpToPage]** — updates [currentPage] and, when clients are attached,
///   also jumps the underlying scroll position.
/// * **[animateToPage]** / **[nextPage]** / **[previousPage]** — delegates to
///   scroll animation in PageView mode; uses curl animation in curl mode.
///
/// ### Lifecycle
///
/// Must be created with a [TickerProvider] (typically via
/// [TickerProviderStateMixin]) and **must** be [dispose]d when no longer
/// needed — this cleans up both the curl [AnimationController] and the
/// [PageController] scroll resources.
///
/// ```dart
/// final controller = PageCurlController(
///   vsync: this,
///   config: const PageCurlConfig(),
///   itemCount: 20,
/// );
/// // ...
/// controller.dispose();
/// ```
class PageCurlController extends PageController {
  /// Creates a [PageCurlController].
  ///
  /// - [vsync] — the [TickerProvider] for the internal curl animation.
  /// - [config] — master configuration for timing, curves, and thresholds.
  /// - [itemCount] — total number of pages.
  /// - [initialPage] — the page shown initially (defaults to 0). Forwarded
  ///   to [PageController] so [PageView] starts at the correct position.
  /// - [keepPage] — forwarded to [PageController] (relevant in PageView mode).
  /// - [viewportFraction] — forwarded to [PageController] (PageView mode).
  /// - [scrollBehavior] — forwarded to [PageController] (PageView mode).
  /// - [onFlipStart] — called when a curl flip gesture or animation begins.
  /// - [onFlipEnd] — called when a curl flip animation completes.
  /// - [onPageChanged] — called when the current page index changes in
  ///   **either** mode (swipe in PageView or curl flip completion).
  PageCurlController({
    required TickerProvider vsync,
    required this.config,
    required this.itemCount,
    super.initialPage = 0,
    super.keepPage = true,
    super.viewportFraction = 1.0,
    this.onFlipStart,
    this.onFlipEnd,
    this.onPageChanged,
  })  : _currentPage = initialPage {
    _animationController = AnimationController(
      vsync: vsync,
      duration: config.animationDuration,
    )..addStatusListener(_onAnimationStatusChanged);
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Master configuration for the curl effect.
  final PageCurlConfig config;

  /// Total number of pages managed by this controller.
  int itemCount;

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  /// Called when a curl flip gesture or animation begins (curl mode only).
  final OnFlipStart? onFlipStart;

  /// Called when a curl flip animation completes (curl mode only).
  final OnFlipEnd? onFlipEnd;

  /// Called when the current page index changes.
  ///
  /// Fires in **both** modes:
  /// - In PageView mode: when a swipe settles on a new page.
  /// - In curl mode: when a flip animation completes or [jumpToPage] is called.
  final ValueChanged<int>? onPageChanged;

  // ---------------------------------------------------------------------------
  // State — Public (curl-specific)
  // ---------------------------------------------------------------------------

  /// The current integer page index.
  ///
  /// In PageView mode this stays in sync with the scroll position via
  /// [_syncFromScrollPosition]. In curl mode it is updated on flip completion
  /// or [jumpToPage].
  int get currentPage => _currentPage;
  int _currentPage;

  /// The current state of the curl lifecycle (meaningful in curl mode only).
  CurlState get state => _state;
  CurlState _state = CurlState.idle;

  /// The direction of the active curl (valid only when [state] ≠ [CurlState.idle]).
  CurlDirection get direction => _direction;
  CurlDirection _direction = CurlDirection.forward;

  /// The corner from which the current curl originates.
  Offset get cornerOrigin => _cornerOrigin;
  Offset _cornerOrigin = Offset.zero;

  /// Notifier for the current virtual touch point — consumed by [PageCurlPainter].
  ///
  /// Emits on every drag update and every animation frame in curl mode.
  ValueNotifier<Offset> get touchPointNotifier => _touchPointNotifier;
  final ValueNotifier<Offset> _touchPointNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );

  /// The [Animation] driving the current automatic curl flip.
  ///
  /// Use this as the `repaint` listenable for [PageCurlPainter].
  Animation<double> get animation => _animationController;

  // ---------------------------------------------------------------------------
  // State — Private (curl-specific)
  // ---------------------------------------------------------------------------

  late final AnimationController _animationController;

  /// Touch position when the drag was released (start of auto-animation).
  Offset _releasePoint = Offset.zero;

  /// The target touch point for the current animation.
  Offset _animationTarget = Offset.zero;

  /// Cached page size — set externally by [PageCurlView] on layout.
  Size _pageSize = Size.zero;

  /// The current page size. Returns [Size.zero] if not yet set.
  Size get pageSize => _pageSize;

  bool _disposed = false;
  TextDirection _textDirection = TextDirection.ltr;

  /// The text direction of the parent widget, used to correctly map RTL gestures.
  TextDirection get textDirection => _textDirection;

  // ---------------------------------------------------------------------------
  // PageController overrides
  // ---------------------------------------------------------------------------

  /// The logical initial page used by [PageController] when creating a new
  /// [ScrollPosition] for an attached [PageView].
  ///
  /// **Why this override is critical:**
  /// Flutter's `PageController.createScrollPosition()` passes `this.initialPage`
  /// to the internal `_PagePosition`, which uses it to compute the starting
  /// scroll offset during the first layout pass. Without this override,
  /// `initialPage` would forever return the value frozen at construction time
  /// (e.g. `0`), so switching a [PageView] on while `_currentPage == 9` would
  /// incorrectly render page 0.
  ///
  /// By returning `_currentPage` here, the attached [PageView] always starts
  /// at the correct page — with zero flicker, no post-frame callbacks, and no
  /// need to recreate the controller.
  @override
  int get initialPage => _currentPage;

  /// The current page as a [double].
  ///
  /// * **PageView mode** (`hasClients == true`): returns the fractional scroll
  ///   position from the attached [ScrollPosition] (e.g. `0.7` mid-swipe).
  /// * **Curl mode** (`hasClients == false`): returns [currentPage] cast to
  ///   [double] (always an integer value).
  @override
  double? get page {
    if (hasClients && positions.length == 1) {
      return super.page;
    }
    return _currentPage.toDouble();
  }

  /// Jumps to [page] without animation.
  ///
  /// In **PageView mode**, updates [currentPage] and immediately moves the
  /// underlying scroll position. In **curl mode**, updates [currentPage]
  /// directly (the visual update is immediate because no scroll position
  /// exists).
  @override
  void jumpToPage(int page) {
    if (_disposed) return;
    if (page < 0 || page >= itemCount) return;
    // Update our internal index and notify listeners in both modes.
    _currentPage = page;
    onPageChanged?.call(_currentPage);
    // Also move the scroll position when a PageView is attached.
    if (hasClients) {
      super.jumpToPage(page);
    }
  }

  /// Animates to [page].
  ///
  /// * **PageView mode**: delegates to [PageController]'s scroll animation.
  /// * **Curl mode**: performs an immediate [jumpToPage] (the animated curl
  ///   experience is provided via the gesture-driven API or [flipForward] /
  ///   [flipBackward]).
  @override
  Future<void> animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
  }) async {
    if (_disposed) return;
    if (hasClients) {
      await super.animateToPage(page, duration: duration, curve: curve);
    } else {
      jumpToPage(page);
    }
  }

  /// Animates to the next page.
  ///
  /// * **PageView mode**: delegates to [PageController.nextPage].
  /// * **Curl mode**: triggers [flipForward] with a curl animation.
  @override
  Future<void> nextPage({
    required Duration duration,
    required Curve curve,
  }) async {
    if (_disposed) return;
    if (hasClients) {
      await super.nextPage(duration: duration, curve: curve);
    } else {
      flipForward();
    }
  }

  /// Animates to the previous page.
  ///
  /// * **PageView mode**: delegates to [PageController.previousPage].
  /// * **Curl mode**: triggers [flipBackward] with a curl animation.
  @override
  Future<void> previousPage({
    required Duration duration,
    required Curve curve,
  }) async {
    if (_disposed) return;
    if (hasClients) {
      await super.previousPage(duration: duration, curve: curve);
    } else {
      flipBackward();
    }
  }

  // ---------------------------------------------------------------------------
  // ScrollController hooks — bidirectional sync with PageView
  // ---------------------------------------------------------------------------

  /// Attaches a [ScrollPosition] (called automatically when a [PageView] using
  /// this controller is built) and registers [_syncFromScrollPosition] so that
  /// [currentPage] stays in sync while the user swipes in PageView mode.
  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    position.addListener(_syncFromScrollPosition);
  }

  /// Detaches the [ScrollPosition] and removes the sync listener.
  @override
  void detach(ScrollPosition position) {
    position.removeListener(_syncFromScrollPosition);
    super.detach(position);
  }

  /// Reads the current scroll-position page and updates [_currentPage].
  ///
  /// Called on every scroll frame in PageView mode. Only fires [onPageChanged]
  /// when the rounded integer page actually changes, preventing redundant
  /// rebuilds during mid-swipe fractional values.
  void _syncFromScrollPosition() {
    if (_disposed) return;
    if (!hasClients || positions.length != 1) return;
    final rawPage = super.page;
    if (rawPage == null) return;
    final newPage = rawPage.round().clamp(0, itemCount - 1);
    if (newPage != _currentPage) {
      _currentPage = newPage;
      onPageChanged?.call(_currentPage);
    }
  }

  // ---------------------------------------------------------------------------
  // Public API — Page Size & Direction (curl mode)
  // ---------------------------------------------------------------------------

  /// Updates the known page size. Must be called whenever the layout changes.
  void setPageSize(Size size) {
    if (_disposed) return;
    _pageSize = size;
  }

  /// Updates the text direction context dynamically.
  void setTextDirection(TextDirection direction) {
    if (_disposed) return;
    _textDirection = direction;
  }

  // ---------------------------------------------------------------------------
  // Public API — Drag Lifecycle (curl mode)
  // ---------------------------------------------------------------------------

  /// Called when a drag gesture begins at [position] (local coordinates).
  ///
  /// Returns `true` if the drag was accepted (started in a hotspot and
  /// the flip direction is valid). Returns `false` otherwise.
  bool onDragStart(Offset position) {
    if (_disposed) return false;
    if (_state != CurlState.idle) return false;
    if (_pageSize == Size.zero) return false;

    if (!PageCurlPhysics.isInHotspot(
      position,
      _pageSize,
      config.hotspotRatio,
      config.curlAxis,
    )) {
      return false;
    }

    final corner = PageCurlPhysics.nearestCorner(position, _pageSize);
    final CurlDirection newDirection;
    final isRtl = _textDirection == TextDirection.rtl;

    if (config.curlAxis == CurlAxis.vertical) {
      final isBottom = corner.dy >= _pageSize.height / 2;
      newDirection = isBottom ? CurlDirection.forward : CurlDirection.backward;
    } else {
      final isRight = corner.dx >= _pageSize.width / 2;
      if (isRtl) {
        newDirection = isRight ? CurlDirection.backward : CurlDirection.forward;
      } else {
        newDirection = isRight ? CurlDirection.forward : CurlDirection.backward;
      }
    }

    if (!_canFlip(newDirection)) return false;

    _direction = newDirection;
    _cornerOrigin = corner;
    _state = CurlState.dragging;
    _touchPointNotifier.value = position;

    onFlipStart?.call(_currentPage, _direction);
    return true;
  }

  /// Called on each drag update with the new [position].
  void onDragUpdate(Offset position) {
    if (_disposed) return;
    if (_state != CurlState.dragging) return;

    final constrained = PageCurlPhysics.constrainTouchPoint(
      position,
      _cornerOrigin,
      _pageSize,
      config.curlAxis,
      verticalElasticityRatio: config.verticalElasticityRatio,
    );
    _touchPointNotifier.value = constrained;
  }

  /// Called when the drag gesture ends.
  ///
  /// [velocity] is the fling velocity in logical pixels/second.
  void onDragEnd({Offset velocity = Offset.zero}) {
    if (_disposed) return;
    if (_state != CurlState.dragging) return;

    _releasePoint = _touchPointNotifier.value;

    final shouldComplete = _shouldCompleteFlip(velocity);

    if (shouldComplete) {
      _animationTarget = PageCurlPhysics.computeFlipCompletionTarget(
        _cornerOrigin,
        _pageSize,
        config.curlAxis,
      );
      _state = CurlState.animatingForward;
      _animationController.duration = config.animationDuration;
      _animationController.forward(from: 0);
    } else {
      _animationTarget = _cornerOrigin;
      _state = CurlState.animatingBackward;
      _animationController.duration = config.animationDuration;
      _animationController.forward(from: 0);
    }

    _animationController.addListener(_onAnimationTick);
  }

  // ---------------------------------------------------------------------------
  // Public API — Programmatic Curl Flip
  // ---------------------------------------------------------------------------

  /// Programmatically flips to the next page with a curl animation.
  ///
  /// No-op if [state] ≠ [CurlState.idle] or already on the last page.
  void flipForward() {
    if (_disposed) return;
    if (_state != CurlState.idle) return;
    if (!_canFlip(CurlDirection.forward)) return;

    _direction = CurlDirection.forward;
    if (config.curlAxis == CurlAxis.vertical) {
      _cornerOrigin = Offset(_pageSize.width, _pageSize.height);
      _releasePoint = Offset(_pageSize.width * 0.9, _pageSize.height * 0.7);
    } else {
      if (_textDirection == TextDirection.rtl) {
        _cornerOrigin = Offset(0, _pageSize.height);
        _releasePoint = Offset(_pageSize.width * 0.3, _pageSize.height * 0.9);
      } else {
        _cornerOrigin = Offset(_pageSize.width, _pageSize.height);
        _releasePoint = Offset(_pageSize.width * 0.7, _pageSize.height * 0.9);
      }
    }
    _animationTarget = PageCurlPhysics.computeFlipCompletionTarget(
      _cornerOrigin,
      _pageSize,
      config.curlAxis,
    );
    _state = CurlState.animatingForward;

    onFlipStart?.call(_currentPage, _direction);

    _animationController
      ..duration = config.animationDuration
      ..addListener(_onAnimationTick)
      ..forward(from: 0);
  }

  /// Programmatically flips to the previous page with a curl animation.
  ///
  /// No-op if [state] ≠ [CurlState.idle] or already on the first page.
  void flipBackward() {
    if (_disposed) return;
    if (_state != CurlState.idle) return;
    if (!_canFlip(CurlDirection.backward)) return;

    _direction = CurlDirection.backward;
    if (config.curlAxis == CurlAxis.vertical) {
      _cornerOrigin = const Offset(0, 0);
      _releasePoint = Offset(_pageSize.width * 0.1, _pageSize.height * 0.3);
    } else {
      if (_textDirection == TextDirection.rtl) {
        _cornerOrigin = Offset(_pageSize.width, _pageSize.height);
        _releasePoint = Offset(_pageSize.width * 0.7, _pageSize.height * 0.9);
      } else {
        _cornerOrigin = Offset(0, _pageSize.height);
        _releasePoint = Offset(_pageSize.width * 0.3, _pageSize.height * 0.9);
      }
    }
    _animationTarget = PageCurlPhysics.computeFlipCompletionTarget(
      _cornerOrigin,
      _pageSize,
      config.curlAxis,
    );
    _state = CurlState.animatingForward;

    onFlipStart?.call(_currentPage, _direction);

    _animationController
      ..duration = config.animationDuration
      ..addListener(_onAnimationTick)
      ..forward(from: 0);
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Disposes the curl [AnimationController], the [touchPointNotifier], and
  /// the underlying [PageController] scroll resources.
  ///
  /// Must be called exactly once. Subsequent calls are no-ops.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // 1. Clean up curl-specific resources first.
    _animationController
      ..removeListener(_onAnimationTick)
      ..removeStatusListener(_onAnimationStatusChanged)
      ..dispose();
    _touchPointNotifier.dispose();
    // 2. Clean up PageController / ScrollController / ChangeNotifier.
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private — Curl Animation
  // ---------------------------------------------------------------------------

  void _onAnimationTick() {
    if (_disposed) return;
    final t = _state == CurlState.animatingForward
        ? config.animationCurve.transform(_animationController.value)
        : config.snapBackCurve.transform(_animationController.value);

    _touchPointNotifier.value = PageCurlPhysics.interpolateTouchPoint(
      _releasePoint,
      _animationTarget,
      t,
    );
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (_disposed) return;
    if (status != AnimationStatus.completed) return;

    _animationController.removeListener(_onAnimationTick);

    if (_state == CurlState.animatingForward) {
      _state = CurlState.completed;
      if (_direction == CurlDirection.forward) {
        _currentPage++;
      } else {
        _currentPage--;
      }
      onFlipEnd?.call(_currentPage);
      onPageChanged?.call(_currentPage);
    }

    _state = CurlState.idle;
    _animationController.reset();
  }

  // ---------------------------------------------------------------------------
  // Private — Decision Logic
  // ---------------------------------------------------------------------------

  /// Whether a flip in [direction] is allowed given the current page index.
  bool _canFlip(CurlDirection direction) {
    if (direction == CurlDirection.forward) {
      return _currentPage < itemCount - 1;
    } else {
      return _currentPage > 0;
    }
  }

  /// Decides whether the flip should complete or snap back based on
  /// drag distance and fling velocity.
  bool _shouldCompleteFlip(Offset velocity) {
    final isForward = _direction == CurlDirection.forward;
    final relevantVelocity = config.curlAxis == CurlAxis.vertical
        ? (isForward ? -velocity.dy : velocity.dy)
        : (isForward ? -velocity.dx : velocity.dx);

    if (relevantVelocity > config.flingVelocityThreshold) return true;
    if (relevantVelocity < -config.flingVelocityThreshold) return false;

    final depth = PageCurlPhysics.computeCurlDepth(
      _cornerOrigin,
      _touchPointNotifier.value,
      _pageSize,
    );
    return depth >= config.dragCompletionThreshold;
  }
}
