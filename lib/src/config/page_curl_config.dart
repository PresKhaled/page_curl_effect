import 'package:flutter/animation.dart';

import '../core/curl_axis.dart';
import '../effects/shadow/curl_shadow_config.dart';

/// Master configuration for the [PageCurlView] widget.
///
/// Groups all tunable parameters that control the behavior and appearance
/// of the page curl effect, including gesture zones, animation timing,
/// shadow styling, and curl geometry.
///
/// Example:
/// ```dart
/// PageCurlConfig(
///   hotspotRatio: 0.25,
///   animationDuration: Duration(milliseconds: 400),
///   animationCurve: Curves.easeOut,
///   shadowConfig: CurlShadowConfig(
///     edgeShadowStartAlpha: 0.3,
///   ),
/// )
/// ```
class PageCurlConfig {
  /// Creates a [PageCurlConfig] with the specified parameters.
  ///
  /// All parameters have sensible defaults tuned for a book-reading
  /// experience.
  const PageCurlConfig({
    this.hotspotRatio = 0.25,
    this.semiPerimeterRatio = 0.8,
    this.foldBackMaskAlpha = 0.6,
    this.animationDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.easeOut,
    this.snapBackCurve = Curves.easeOut,
    this.enableClickToFlip = true,
    this.clickToFlipWidthRatio = 0.5,
    this.flingVelocityThreshold = 800.0,
    this.dragCompletionThreshold = 0.35,
    this.curlAxis = CurlAxis.horizontal,
    this.shadowConfig = const CurlShadowConfig(),
  });

  // ---------------------------------------------------------------------------
  // Gesture Configuration
  // ---------------------------------------------------------------------------

  /// The ratio of page width that defines the gesture hotspot zones at the
  /// left and right edges for initiating a curl drag.
  ///
  /// Range: 0.0 – 0.5. A value of 0.25 means the outer 25% on each side
  /// is a valid drag-start zone.
  final double hotspotRatio;

  /// Whether tapping on the left/right side of the page triggers a flip.
  ///
  /// When enabled, tapping the right [clickToFlipWidthRatio] of the page
  /// flips forward, and tapping the left portion flips backward.
  final bool enableClickToFlip;

  /// The ratio of page width that defines the click-to-flip boundary.
  ///
  /// Range: 0.0 – 0.5. Defaults to 0.5 (left half = backward, right half
  /// = forward).
  final double clickToFlipWidthRatio;

  /// Minimum fling velocity (in logical pixels/second) required to
  /// automatically complete a page flip when the user releases the drag.
  ///
  /// Below this threshold, the flip direction is determined by
  /// [dragCompletionThreshold] instead.
  final double flingVelocityThreshold;

  /// The normalized drag distance (0.0 – 1.0) beyond which a released drag
  /// will complete the flip rather than snap back.
  ///
  /// Defaults to 0.35, meaning the user must drag at least 35% of the page
  /// width for the flip to auto-complete on release.
  final double dragCompletionThreshold;

  // ---------------------------------------------------------------------------
  // Curl Geometry
  // ---------------------------------------------------------------------------

  /// Ratio of the semi-perimeter of the virtual cylinder that forms the curl.
  ///
  /// Controls the "roundness" of the curl — higher values produce a wider,
  /// gentler curve. Range: 0.0 – 1.0. Defaults to 0.8.
  ///
  /// The semi-cylinder perimeter is computed as:
  /// `perimeter = lineLength * semiPerimeterRatio`
  /// where `lineLength = distance(corner, touchPoint)`.
  final double semiPerimeterRatio;

  /// Alpha (opacity) mask applied to the back face of the folded page.
  ///
  /// Simulates the slightly darkened appearance of a real paper back.
  /// Range: 0.0 (fully transparent) – 1.0 (fully opaque). Defaults to 0.6.
  final double foldBackMaskAlpha;

  /// The axis along which the page curl is allowed.
  ///
  /// - [CurlAxis.horizontal]: Only horizontal curl (left/right). Default.
  /// - [CurlAxis.vertical]: Only vertical curl (up/down).
  /// - [CurlAxis.both]: Free-form curl in any direction.
  final CurlAxis curlAxis;

  // ---------------------------------------------------------------------------
  // Animation
  // ---------------------------------------------------------------------------

  /// Duration of the automatic flip animation (after release or on tap).
  final Duration animationDuration;

  /// The easing curve for the forward-flip completion animation.
  final Curve animationCurve;

  /// The easing curve for the snap-back (cancel) animation.
  final Curve snapBackCurve;

  // ---------------------------------------------------------------------------
  // Shadow
  // ---------------------------------------------------------------------------

  /// Configuration for the edge and base shadow effects.
  final CurlShadowConfig shadowConfig;

  /// Creates a copy of this config with the given fields replaced.
  PageCurlConfig copyWith({
    double? hotspotRatio,
    double? semiPerimeterRatio,
    double? foldBackMaskAlpha,
    Duration? animationDuration,
    Curve? animationCurve,
    Curve? snapBackCurve,
    bool? enableClickToFlip,
    double? clickToFlipWidthRatio,
    double? flingVelocityThreshold,
    double? dragCompletionThreshold,
    CurlAxis? curlAxis,
    CurlShadowConfig? shadowConfig,
  }) {
    return PageCurlConfig(
      hotspotRatio: hotspotRatio ?? this.hotspotRatio,
      semiPerimeterRatio: semiPerimeterRatio ?? this.semiPerimeterRatio,
      foldBackMaskAlpha: foldBackMaskAlpha ?? this.foldBackMaskAlpha,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      snapBackCurve: snapBackCurve ?? this.snapBackCurve,
      enableClickToFlip: enableClickToFlip ?? this.enableClickToFlip,
      clickToFlipWidthRatio:
          clickToFlipWidthRatio ?? this.clickToFlipWidthRatio,
      flingVelocityThreshold:
          flingVelocityThreshold ?? this.flingVelocityThreshold,
      dragCompletionThreshold:
          dragCompletionThreshold ?? this.dragCompletionThreshold,
      curlAxis: curlAxis ?? this.curlAxis,
      shadowConfig: shadowConfig ?? this.shadowConfig,
    );
  }
}
