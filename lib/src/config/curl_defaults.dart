import 'package:flutter/animation.dart';

import '../core/curl_axis.dart';

/// Centralized default values and constants for the page curl effect.
class CurlDefaults {
  const CurlDefaults._();

  /// Default gesture and threshold constants.
  static const double hotspotRatio = 0.25;
  static const double clickToFlipWidthRatio = 0.5;
  static const double flingVelocityThreshold = 800.0;
  static const double dragCompletionThreshold = 0.35;
  static const double verticalElasticityRatio = 0.20;

  /// Default geometry and rendering constants.
  static const double semiPerimeterRatio = 0.8;
  static const double foldBackMaskAlpha = 0.6;
  static const CurlAxis curlAxis = CurlAxis.horizontalWithVerticalElasticity;

  /// Default animation constants.
  static const Duration animationDuration = Duration(milliseconds: 400);
  static const Curve animationCurve = Curves.easeOutCubic;
  static const Curve snapBackCurve = Curves.easeOutBack;

  /// Shadow constants.
  static const double edgeShadowStartAlpha = 0.3;
  static const double edgeShadowEndAlpha = 0.0;
  static const double edgeShadowWidthMultiplier = 0.3;
  static const double baseShadowStartAlpha = 0.2;
  static const double baseShadowEndAlpha = 0.0;
  static const double baseShadowWidthMultiplier = 0.4;
}
