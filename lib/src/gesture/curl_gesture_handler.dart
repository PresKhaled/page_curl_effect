import 'package:flutter/widgets.dart';

import '../config/page_curl_config.dart';
import '../core/page_curl_controller.dart';

/// A widget that wraps its [child] with gesture detection for the page
/// curl effect.
///
/// This handler intercepts horizontal drag gestures in the hotspot zones
/// (defined by [PageCurlConfig.hotspotRatio]) and forwards them to the
/// [PageCurlController]. It also handles tap gestures for click-to-flip
/// when enabled.
///
/// ### Design Decisions
///
/// - Uses [GestureDetector] rather than [RawGestureDetector] for
///   simplicity. The trade-off is that nested scrollables may conflict;
///   this is mitigated by the hotspot zones limiting where drags begin.
///
/// - Click-to-flip uses [onTapUp] with a position check rather than
///   split left/right tap zones to avoid multiple overlapping detectors.
class CurlGestureHandler extends StatelessWidget {
  /// Creates a [CurlGestureHandler].
  const CurlGestureHandler({
    required this.controller,
    required this.config,
    required this.child,
    super.key,
  });

  /// The page curl controller to forward gestures to.
  final PageCurlController controller;

  /// Master configuration (used for click-to-flip settings).
  final PageCurlConfig config;

  /// The child widget to wrap.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // -- Drag gestures --
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      // -- Tap gesture (click-to-flip) --
      onTapUp: config.enableClickToFlip ? _onTapUp : null,
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Drag Handlers
  // ---------------------------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    controller.onDragStart(details.localPosition);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    controller.onDragUpdate(details.localPosition);
  }

  void _onDragEnd(DragEndDetails details) {
    controller.onDragEnd(velocity: details.velocity.pixelsPerSecond);
  }

  // ---------------------------------------------------------------------------
  // Tap Handler (Click-to-Flip)
  // ---------------------------------------------------------------------------

  void _onTapUp(TapUpDetails details) {
    final pos = details.localPosition;
    final halfWidth = controller.pageSize.width * config.clickToFlipWidthRatio;

    if (pos.dx > halfWidth) {
      controller.flipForward();
    } else {
      controller.flipBackward();
    }
  }
}
