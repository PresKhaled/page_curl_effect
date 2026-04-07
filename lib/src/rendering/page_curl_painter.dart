import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/page_curl_config.dart';
import '../core/page_curl_physics.dart';
import '../effects/shadow/curl_shadow_painter.dart';

/// A [CustomPainter] that renders the page curl effect for a single frame.
///
/// ### Rendering Pipeline (per frame)
///
/// 1. **Under-page**: Draw the next/previous page image at full size.
/// 2. **Flat region**: Clip the current page to the uncurled half-plane
///    and draw it.
/// 3. **Curled region**: Reflect the curled half-plane across the fold line
///    and draw it (the "back" of the page) with an alpha mask.
/// 4. **Edge shadow**: Draw a narrow gradient shadow along the fold line
///    on the curled side.
/// 5. **Base shadow**: Draw a wider gradient shadow on the under-page
///    beneath the curled portion.
///
/// ### Usage
///
/// This painter is driven by the [PageCurlController], which provides
/// the current [touchPoint] and [cornerOrigin] each frame. It should be
/// placed inside a [CustomPaint] widget that repaints whenever the
/// controller's animation value changes.
class PageCurlPainter extends CustomPainter {
  /// Creates a [PageCurlPainter].
  ///
  /// - [currentPageImage] — rasterised image of the page being curled.
  /// - [underPageImage] — rasterised image of the page revealed beneath.
  /// - [touchPoint] — the current drag/animation touch position.
  /// - [cornerOrigin] — the page corner from which the curl originates.
  /// - [config] — master configuration for curl behaviour and shadows.
  /// - [repaint] — listenable that triggers repaints (typically the
  ///   controller's animation).
  PageCurlPainter({
    required this.currentPageImage,
    required this.underPageImage,
    required this.touchPoint,
    required this.cornerOrigin,
    required this.config,
    required this.pixelRatio,
    super.repaint,
  });

  /// The rasterised image of the page currently being curled.
  final ui.Image currentPageImage;

  /// The rasterised image of the page underneath (next or previous page).
  final ui.Image underPageImage;

  /// The current touch / animation position in logical coordinates.
  final Offset touchPoint;

  /// The corner of the page from which the curl originates.
  final Offset cornerOrigin;

  /// Master configuration.
  final PageCurlConfig config;

  /// The device pixel ratio used during rasterisation.
  ///
  /// Required to correctly scale the paint operations to match
  /// the rasterised image resolution.
  final double pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // Compute fold geometry.
    final foldLine = PageCurlPhysics.computeFoldLine(cornerOrigin, touchPoint);

    if (foldLine == null) {
      // No curl — draw the current page flat.
      _drawImage(canvas, currentPageImage, size);
      return;
    }

    final curlDepth = PageCurlPhysics.computeCurlDepth(
      cornerOrigin,
      touchPoint,
      size,
    );

    // -----------------------------------------------------------------------
    // Step 1: Draw the under-page (full size, below everything).
    // -----------------------------------------------------------------------
    _drawImage(canvas, underPageImage, size);

    // -----------------------------------------------------------------------
    // Step 2: Draw the flat (uncurled) portion of the current page.
    // -----------------------------------------------------------------------
    final flatClip = PageCurlPhysics.computeFlatClipPath(
      size,
      foldLine,
      cornerOrigin,
    );

    canvas.save();
    canvas.clipPath(flatClip);
    _drawImage(canvas, currentPageImage, size);
    canvas.restore();

    // -----------------------------------------------------------------------
    // Step 3: Draw the curled (folded-back) portion.
    // -----------------------------------------------------------------------
    final curlClip = PageCurlPhysics.computeCurlClipPath(
      size,
      foldLine,
      cornerOrigin,
    );
    final reflectionMatrix = PageCurlPhysics.computeReflectionMatrix(foldLine);

    canvas.save();

    // Clip to the curl region after reflection to avoid overdraw.
    // We apply the reflection transform, then clip by the *original* curl
    // path (which, in reflected space, covers the correct area).
    canvas.transform(reflectionMatrix.storage);
    canvas.clipPath(curlClip);
    _drawImage(canvas, currentPageImage, size);

    // Draw the fold-back darkening overlay.
    final maskAlpha = (config.foldBackMaskAlpha * curlDepth).clamp(0.0, 1.0);
    if (maskAlpha > 0.01) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Color.fromRGBO(0, 0, 0, maskAlpha),
      );
    }

    canvas.restore();

    // -----------------------------------------------------------------------
    // Step 4: Draw shadows.
    // -----------------------------------------------------------------------

    // Clip shadows to the page bounds to prevent bleeding.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Base shadow (on the under-page, wider & subtler).
    CurlShadowPainter.paintBaseShadow(
      canvas: canvas,
      foldLine: foldLine,
      curlDepth: curlDepth,
      pageSize: size,
      config: config,
    );

    // Edge shadow (on the curled page, narrow & intense).
    CurlShadowPainter.paintEdgeShadow(
      canvas: canvas,
      foldLine: foldLine,
      curlDepth: curlDepth,
      pageSize: size,
      config: config,
    );

    canvas.restore();
  }

  /// Draws [image] scaled to fit [size], accounting for [pixelRatio].
  void _drawImage(Canvas canvas, ui.Image image, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant PageCurlPainter oldDelegate) {
    return touchPoint != oldDelegate.touchPoint ||
        cornerOrigin != oldDelegate.cornerOrigin ||
        currentPageImage != oldDelegate.currentPageImage ||
        underPageImage != oldDelegate.underPageImage;
  }
}
