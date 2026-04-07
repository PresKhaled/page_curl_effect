import 'dart:ui';

/// Configuration for the shadow effects rendered during a page curl.
///
/// Two distinct shadow types are supported:
/// - **Edge Shadow**: A narrow gradient shadow along the fold edge of the
///   curled page, simulating the depth of the curl.
/// - **Base Shadow**: A wider gradient shadow cast onto the underlying page,
///   simulating the shadow of the curled page hovering above it.
///
/// Both shadow types support configurable color, alpha (opacity), and width
/// ranges. The actual shadow width at any frame is computed as:
/// ```
/// width = clamp(diameter * widthRatio, minWidth, maxWidth)
/// ```
/// where `diameter` is the diameter of the virtual semi-cylinder formed by
/// the curl at the current drag depth.
class CurlShadowConfig {
  /// Creates a [CurlShadowConfig] with the specified shadow parameters.
  ///
  /// All width values are in logical pixels. Alpha values range from 0.0
  /// (fully transparent) to 1.0 (fully opaque).
  const CurlShadowConfig({
    this.edgeShadowStartColor = const Color(0xFF000000),
    this.edgeShadowEndColor = const Color(0xFF000000),
    this.edgeShadowStartAlpha = 0.25,
    this.edgeShadowEndAlpha = 0.0,
    this.edgeShadowMinWidth = 3.0,
    this.edgeShadowMaxWidth = 30.0,
    this.edgeShadowWidthRatio = 0.3,
    this.baseShadowStartColor = const Color(0xFF000000),
    this.baseShadowEndColor = const Color(0xFF000000),
    this.baseShadowStartAlpha = 0.15,
    this.baseShadowEndAlpha = 0.0,
    this.baseShadowMinWidth = 5.0,
    this.baseShadowMaxWidth = 40.0,
    this.baseShadowWidthRatio = 0.4,
  });

  // ---------------------------------------------------------------------------
  // Edge Shadow — along the fold line on the curled page
  // ---------------------------------------------------------------------------

  /// The start color of the edge shadow gradient (closest to the fold line).
  final Color edgeShadowStartColor;

  /// The end color of the edge shadow gradient (farthest from the fold line).
  final Color edgeShadowEndColor;

  /// The start alpha (opacity) of the edge shadow gradient.
  ///
  /// Range: 0.0 (transparent) – 1.0 (opaque). Defaults to 0.25.
  final double edgeShadowStartAlpha;

  /// The end alpha (opacity) of the edge shadow gradient.
  ///
  /// Range: 0.0 (transparent) – 1.0 (opaque). Defaults to 0.0.
  final double edgeShadowEndAlpha;

  /// Minimum width of the edge shadow in logical pixels.
  final double edgeShadowMinWidth;

  /// Maximum width of the edge shadow in logical pixels.
  final double edgeShadowMaxWidth;

  /// Ratio of the semi-cylinder diameter used to compute the edge shadow width.
  ///
  /// Actual width = `clamp(diameter * ratio, minWidth, maxWidth)`.
  final double edgeShadowWidthRatio;

  // ---------------------------------------------------------------------------
  // Base Shadow — cast onto the underlying (next/previous) page
  // ---------------------------------------------------------------------------

  /// The start color of the base shadow gradient (closest to the fold line).
  final Color baseShadowStartColor;

  /// The end color of the base shadow gradient (farthest from the fold line).
  final Color baseShadowEndColor;

  /// The start alpha (opacity) of the base shadow gradient.
  ///
  /// Range: 0.0 (transparent) – 1.0 (opaque). Defaults to 0.15.
  final double baseShadowStartAlpha;

  /// The end alpha (opacity) of the base shadow gradient.
  ///
  /// Range: 0.0 (transparent) – 1.0 (opaque). Defaults to 0.0.
  final double baseShadowEndAlpha;

  /// Minimum width of the base shadow in logical pixels.
  final double baseShadowMinWidth;

  /// Maximum width of the base shadow in logical pixels.
  final double baseShadowMaxWidth;

  /// Ratio of the semi-cylinder diameter used to compute the base shadow width.
  ///
  /// Actual width = `clamp(diameter * ratio, minWidth, maxWidth)`.
  final double baseShadowWidthRatio;

  /// Computes the effective edge shadow width for the given [diameter].
  double computeEdgeShadowWidth(double diameter) {
    return (diameter * edgeShadowWidthRatio).clamp(
      edgeShadowMinWidth,
      edgeShadowMaxWidth,
    );
  }

  /// Computes the effective base shadow width for the given [diameter].
  double computeBaseShadowWidth(double diameter) {
    return (diameter * baseShadowWidthRatio).clamp(
      baseShadowMinWidth,
      baseShadowMaxWidth,
    );
  }

  /// Creates a copy of this config with the given fields replaced.
  CurlShadowConfig copyWith({
    Color? edgeShadowStartColor,
    Color? edgeShadowEndColor,
    double? edgeShadowStartAlpha,
    double? edgeShadowEndAlpha,
    double? edgeShadowMinWidth,
    double? edgeShadowMaxWidth,
    double? edgeShadowWidthRatio,
    Color? baseShadowStartColor,
    Color? baseShadowEndColor,
    double? baseShadowStartAlpha,
    double? baseShadowEndAlpha,
    double? baseShadowMinWidth,
    double? baseShadowMaxWidth,
    double? baseShadowWidthRatio,
  }) {
    return CurlShadowConfig(
      edgeShadowStartColor: edgeShadowStartColor ?? this.edgeShadowStartColor,
      edgeShadowEndColor: edgeShadowEndColor ?? this.edgeShadowEndColor,
      edgeShadowStartAlpha: edgeShadowStartAlpha ?? this.edgeShadowStartAlpha,
      edgeShadowEndAlpha: edgeShadowEndAlpha ?? this.edgeShadowEndAlpha,
      edgeShadowMinWidth: edgeShadowMinWidth ?? this.edgeShadowMinWidth,
      edgeShadowMaxWidth: edgeShadowMaxWidth ?? this.edgeShadowMaxWidth,
      edgeShadowWidthRatio: edgeShadowWidthRatio ?? this.edgeShadowWidthRatio,
      baseShadowStartColor: baseShadowStartColor ?? this.baseShadowStartColor,
      baseShadowEndColor: baseShadowEndColor ?? this.baseShadowEndColor,
      baseShadowStartAlpha: baseShadowStartAlpha ?? this.baseShadowStartAlpha,
      baseShadowEndAlpha: baseShadowEndAlpha ?? this.baseShadowEndAlpha,
      baseShadowMinWidth: baseShadowMinWidth ?? this.baseShadowMinWidth,
      baseShadowMaxWidth: baseShadowMaxWidth ?? this.baseShadowMaxWidth,
      baseShadowWidthRatio: baseShadowWidthRatio ?? this.baseShadowWidthRatio,
    );
  }
}
