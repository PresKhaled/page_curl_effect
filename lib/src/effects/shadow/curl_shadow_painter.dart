import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../config/page_curl_config.dart';
import '../../core/page_curl_physics.dart';

/// Paints edge and base shadow gradients along the fold line during a
/// page curl.
///
/// Shadows are critical for the depth illusion in a 2D page curl:
///
/// - **Edge Shadow**: A narrow gradient on the *curled* side of the fold
///   line, simulating the darkness at the crease where the page bends.
///
/// - **Base Shadow**: A wider gradient on the *flat* (underlying) page,
///   simulating the shadow cast by the hovering curled portion.
///
/// Both shadows scale dynamically based on [curlDepth] (0.0 – 1.0).
class CurlShadowPainter {
  const CurlShadowPainter._();

  /// Paints the **edge shadow** along the fold line on the curled page side.
  ///
  /// [canvas] — the canvas to paint on.
  /// [foldLine] — the computed fold line geometry.
  /// [curlDepth] — normalised curl depth (0.0 – 1.0).
  /// [pageSize] — the logical page size.
  /// [config] — master configuration containing shadow settings.
  static void paintEdgeShadow({
    required Canvas canvas,
    required FoldLine foldLine,
    required double curlDepth,
    required Size pageSize,
    required PageCurlConfig config,
  }) {
    if (curlDepth < 0.01) return; // No visible shadow at near-zero depth.

    final shadowConfig = config.shadowConfig;
    final diameter = curlDepth * pageSize.width * config.semiPerimeterRatio;
    final shadowWidth = shadowConfig.computeEdgeShadowWidth(diameter);

    if (shadowWidth < 1.0) return;

    // Build the gradient perpendicular to the fold line, extending into
    // the curled region.
    final normalX = -foldLine.direction.dy;
    final normalY = foldLine.direction.dx;

    // Shadow starts at the fold line midpoint and extends outward.
    final startPoint = foldLine.midpoint;
    final endPoint = Offset(
      startPoint.dx + normalX * shadowWidth,
      startPoint.dy + normalY * shadowWidth,
    );

    final startAlpha = (shadowConfig.edgeShadowStartAlpha * curlDepth).clamp(
      0.0,
      1.0,
    );
    final endAlpha = shadowConfig.edgeShadowEndAlpha;

    final gradient = ui.Gradient.linear(startPoint, endPoint, [
      shadowConfig.edgeShadowStartColor.withValues(alpha: startAlpha),
      shadowConfig.edgeShadowEndColor.withValues(alpha: endAlpha),
    ]);

    // Paint a strip along the fold line.
    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    final stripPath = _buildShadowStrip(
      foldLine: foldLine,
      pageSize: pageSize,
      width: shadowWidth,
      normalX: normalX,
      normalY: normalY,
    );

    canvas.drawPath(stripPath, paint);
  }

  /// Paints the **base shadow** on the underlying page beneath the curl.
  ///
  /// This shadow is wider and subtler than the edge shadow, simulating
  /// the diffuse shadow cast by the hovering curled page portion.
  static void paintBaseShadow({
    required Canvas canvas,
    required FoldLine foldLine,
    required double curlDepth,
    required Size pageSize,
    required PageCurlConfig config,
  }) {
    if (curlDepth < 0.01) return;

    final shadowConfig = config.shadowConfig;
    final diameter = curlDepth * pageSize.width * config.semiPerimeterRatio;
    final shadowWidth = shadowConfig.computeBaseShadowWidth(diameter);

    if (shadowWidth < 1.0) return;

    // The base shadow extends into the *flat* region (opposite to the curl
    // normal). We reverse the normal direction compared to the edge shadow.
    final normalX = foldLine.direction.dy;
    final normalY = -foldLine.direction.dx;

    final startPoint = foldLine.midpoint;
    final endPoint = Offset(
      startPoint.dx + normalX * shadowWidth,
      startPoint.dy + normalY * shadowWidth,
    );

    final startAlpha = (shadowConfig.baseShadowStartAlpha * curlDepth).clamp(
      0.0,
      1.0,
    );
    final endAlpha = shadowConfig.baseShadowEndAlpha;

    final gradient = ui.Gradient.linear(startPoint, endPoint, [
      shadowConfig.baseShadowStartColor.withValues(alpha: startAlpha),
      shadowConfig.baseShadowEndColor.withValues(alpha: endAlpha),
    ]);

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    final stripPath = _buildShadowStrip(
      foldLine: foldLine,
      pageSize: pageSize,
      width: shadowWidth,
      normalX: normalX,
      normalY: normalY,
    );

    canvas.drawPath(stripPath, paint);
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Builds a parallelogram strip along the fold line with the given [width]
  /// in the normal direction.
  ///
  /// The strip is long enough to cover the entire page diagonal so it
  /// always fully spans the visible area regardless of fold angle.
  static Path _buildShadowStrip({
    required FoldLine foldLine,
    required Size pageSize,
    required double width,
    required double normalX,
    required double normalY,
  }) {
    // Extend the fold line far enough to cover the entire page.
    final halfDiag = pageSize.longestSide * 1.5;
    final dx = foldLine.direction.dx;
    final dy = foldLine.direction.dy;
    final mx = foldLine.midpoint.dx;
    final my = foldLine.midpoint.dy;

    // Two endpoints of the fold line segment (overshooting the page).
    final p1 = Offset(mx - dx * halfDiag, my - dy * halfDiag);
    final p2 = Offset(mx + dx * halfDiag, my + dy * halfDiag);

    // Offset by the normal to create a strip.
    final offsetX = normalX * width;
    final offsetY = normalY * width;

    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p2.dx + offsetX, p2.dy + offsetY)
      ..lineTo(p1.dx + offsetX, p1.dy + offsetY)
      ..close();
  }
}
