import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Captures a [RenderRepaintBoundary] as a raster [ui.Image].
///
/// This utility is the bridge between the Flutter widget tree and the
/// pixel-level rendering pipeline used by [PageCurlPainter]. It converts
/// live widgets into GPU-backed images that can be drawn, clipped, and
/// transformed on a [Canvas].
///
/// ### Design Rationale
///
/// We use [RenderRepaintBoundary.toImage] rather than
/// [PictureRecorder] because the former automatically handles:
/// - Compositing of child layers (e.g. Platform Views).
/// - Correct pixel-ratio scaling for high-DPI displays.
///
/// ### Performance Notes
///
/// - `toImage()` is **expensive** — call it only when the page content or
///   size changes, never per-frame.
/// - Callers are responsible for caching the returned [ui.Image] and
///   disposing of it when no longer needed.
class WidgetRasterizer {
  const WidgetRasterizer._();

  /// Captures the widget behind the given [boundaryKey] as a [ui.Image].
  ///
  /// [pixelRatio] controls the output resolution relative to the widget's
  /// logical size. Pass [MediaQuery.devicePixelRatioOf(context)] for
  /// screen-native resolution.
  ///
  /// Returns `null` if the boundary cannot be found or has not been laid out.
  static Future<ui.Image?> capture(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 1.0,
  }) async {
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      return image;
    } catch (_) {
      // May throw if the boundary is not attached or has zero size.
      return null;
    }
  }
}
