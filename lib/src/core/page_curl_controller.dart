import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

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
/// This controller is the **brain** of the page curl effect. It:
///
/// 1. Manages the [CurlState] transitions:
///    `idle → dragging → animatingForward/Backward → completed → idle`
///
/// 2. Owns an internal [AnimationController] that drives automatic
///    flip animations (completion and snap-back).
///
/// 3. Exposes a [touchPointNotifier] that emits the current virtual
///    touch position each frame — consumed by [PageCurlPainter].
///
/// 4. Handles fling velocity to decide whether a release should
///    complete or cancel the flip.
///
/// ### Ownership & Lifecycle
///
/// This controller must be created with a [TickerProvider] (usually via
/// [TickerProviderStateMixin]) and **must** be [dispose]d when no longer
/// needed.
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
class PageCurlController {
  /// Creates a [PageCurlController].
  ///
  /// - [vsync] — the [TickerProvider] for the animation controller.
  /// - [config] — master configuration for timing, curves, thresholds.
  /// - [itemCount] — total number of pages.
  /// - [initialPage] — the page to display initially (defaults to 0).
  /// - [onFlipStart] — called when a flip gesture or animation begins.
  /// - [onFlipEnd] — called when a flip animation completes.
  /// - [onPageChanged] — called when the current page index changes.
  PageCurlController({
    required TickerProvider vsync,
    required this.config,
    required this.itemCount,
    this.initialPage = 0,
    this.onFlipStart,
    this.onFlipEnd,
    this.onPageChanged,
  }) : _currentPage = initialPage {
    _animationController = AnimationController(
      vsync: vsync,
      duration: config.animationDuration,
    )..addStatusListener(_onAnimationStatusChanged);
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Master configuration.
  final PageCurlConfig config;

  /// Total number of pages.
  int itemCount;

  /// The initial page index.
  final int initialPage;

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  /// Called when a flip gesture or animation begins.
  final OnFlipStart? onFlipStart;

  /// Called when a flip animation completes.
  final OnFlipEnd? onFlipEnd;

  /// Called when the current page index changes.
  final ValueChanged<int>? onPageChanged;

  // ---------------------------------------------------------------------------
  // State — Public
  // ---------------------------------------------------------------------------

  /// The current page index.
  int get currentPage => _currentPage;
  int _currentPage;

  /// The current state of the curl.
  CurlState get state => _state;
  CurlState _state = CurlState.idle;

  /// The direction of the active curl (valid only when [state] ≠ idle).
  CurlDirection get direction => _direction;
  CurlDirection _direction = CurlDirection.forward;

  /// The corner from which the current curl originates.
  Offset get cornerOrigin => _cornerOrigin;
  Offset _cornerOrigin = Offset.zero;

  /// Notifier for the current virtual touch point — consumed by the painter.
  ///
  /// Emits on every drag update and every animation frame.
  ValueNotifier<Offset> get touchPointNotifier => _touchPointNotifier;
  final ValueNotifier<Offset> _touchPointNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );

  /// The [Animation] driving the current automatic flip.
  ///
  /// Use this as the `repaint` listenable for [PageCurlPainter].
  Animation<double> get animation => _animationController;

  // ---------------------------------------------------------------------------
  // State — Private
  // ---------------------------------------------------------------------------

  late final AnimationController _animationController;

  /// Touch position when the drag was released (start of auto-animation).
  Offset _releasePoint = Offset.zero;

  /// The target touch point for the current animation.
  Offset _animationTarget = Offset.zero;

  /// Cached page size — set externally by the widget on layout.
  Size _pageSize = Size.zero;

  /// The current page size. Returns [Size.zero] if not yet set.
  Size get pageSize => _pageSize;

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public API — Page Size
  // ---------------------------------------------------------------------------

  /// Updates the known page size. Must be called whenever the layout changes.
  void setPageSize(Size size) {
    if (_disposed) return;
    _pageSize = size;
  }

  // ---------------------------------------------------------------------------
  // Public API — Drag Lifecycle
  // ---------------------------------------------------------------------------

  /// Called when a drag gesture begins at [position] (local coordinates).
  ///
  /// Returns `true` if the drag was accepted (started in a hotspot and
  /// the flip direction is valid). Returns `false` otherwise.
  bool onDragStart(Offset position) {
    if (_disposed) return false;
    if (_state != CurlState.idle) return false;
    if (_pageSize == Size.zero) return false;

    // Check if the touch is in a hotspot.
    if (!PageCurlPhysics.isInHotspot(
      position,
      _pageSize,
      config.hotspotRatio,
      config.curlAxis,
    )) {
      return false;
    }

    // Determine direction and validate boundaries.
    final corner = PageCurlPhysics.nearestCorner(position, _pageSize);
    final CurlDirection newDirection;
    if (config.curlAxis == CurlAxis.vertical) {
      final isBottom = corner.dy >= _pageSize.height / 2;
      newDirection = isBottom ? CurlDirection.forward : CurlDirection.backward;
    } else {
      final isRight = corner.dx >= _pageSize.width / 2;
      newDirection = isRight ? CurlDirection.forward : CurlDirection.backward;
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

    // Constrain the touch to prevent detached-page look and enforce axis.
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

    // Decide: complete the flip or snap back.
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

    // Drive the touch point via the animation.
    _animationController.addListener(_onAnimationTick);
  }

  // ---------------------------------------------------------------------------
  // Public API — Programmatic Flip
  // ---------------------------------------------------------------------------

  /// Programmatically flips to the next page with animation.
  void flipForward() {
    if (_disposed) return;
    if (_state != CurlState.idle) return;
    if (!_canFlip(CurlDirection.forward)) return;

    _direction = CurlDirection.forward;
    if (config.curlAxis == CurlAxis.vertical) {
      _cornerOrigin = Offset(_pageSize.width, _pageSize.height);
      _releasePoint = Offset(_pageSize.width * 0.9, _pageSize.height * 0.7);
    } else {
      _cornerOrigin = Offset(_pageSize.width, _pageSize.height);
      _releasePoint = Offset(_pageSize.width * 0.7, _pageSize.height * 0.9);
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

  /// Programmatically flips to the previous page with animation.
  void flipBackward() {
    if (_disposed) return;
    if (_state != CurlState.idle) return;
    if (!_canFlip(CurlDirection.backward)) return;

    _direction = CurlDirection.backward;
    if (config.curlAxis == CurlAxis.vertical) {
      _cornerOrigin = const Offset(0, 0); // Top-left corner
      _releasePoint = Offset(_pageSize.width * 0.1, _pageSize.height * 0.3);
    } else {
      _cornerOrigin = Offset(0, _pageSize.height);
      _releasePoint = Offset(_pageSize.width * 0.3, _pageSize.height * 0.9);
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

  /// Jumps directly to [page] without animation.
  void jumpToPage(int page) {
    if (_disposed) return;
    if (page < 0 || page >= itemCount) return;
    if (_state != CurlState.idle) return;
    _currentPage = page;
    onPageChanged?.call(_currentPage);
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Disposes the internal animation controller and notifiers.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _animationController
      ..removeListener(_onAnimationTick)
      ..removeStatusListener(_onAnimationStatusChanged)
      ..dispose();
    _touchPointNotifier.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private — Animation
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
      // Flip completed — update the page index.
      _state = CurlState.completed;
      if (_direction == CurlDirection.forward) {
        _currentPage++;
      } else {
        _currentPage--;
      }
      onFlipEnd?.call(_currentPage);
      onPageChanged?.call(_currentPage);
    }

    // Reset to idle.
    _state = CurlState.idle;
    _animationController.reset();
  }

  // ---------------------------------------------------------------------------
  // Private — Decision Logic
  // ---------------------------------------------------------------------------

  /// Whether a flip in [direction] is allowed given the current page.
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
    // Check fling velocity first depending on the axis.
    final isForward = _direction == CurlDirection.forward;
    final relevantVelocity = config.curlAxis == CurlAxis.vertical ? (isForward ? -velocity.dy : velocity.dy) : (isForward ? -velocity.dx : velocity.dx);

    if (relevantVelocity > config.flingVelocityThreshold) {
      return true;
    }
    if (relevantVelocity < -config.flingVelocityThreshold) {
      return false;
    }

    // Fall back to drag distance threshold.
    final depth = PageCurlPhysics.computeCurlDepth(
      _cornerOrigin,
      _touchPointNotifier.value,
      _pageSize,
    );

    return depth >= config.dragCompletionThreshold;
  }
}
