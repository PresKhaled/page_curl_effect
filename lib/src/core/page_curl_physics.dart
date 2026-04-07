import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'curl_axis.dart';

/// Immutable value object representing the fold line that divides a page
/// into its flat (uncurled) and curled regions during a page curl.
///
/// The fold line is the perpendicular bisector of the segment from the
/// page [cornerOrigin] to the current [touchPoint].
class FoldLine {
  /// Creates a [FoldLine] from pre-computed values.
  const FoldLine({
    required this.midpoint,
    required this.angle,
    required this.direction,
  });

  /// The midpoint of the segment from the corner origin to the touch point.
  ///
  /// This point lies on the fold line itself.
  final Offset midpoint;

  /// The angle (in radians) of the fold line relative to the positive X-axis.
  final double angle;

  /// The unit-length direction vector of the fold line.
  final Offset direction;
}

/// Pure mathematical engine for computing all page curl geometry.
///
/// This class contains **zero** Flutter widget dependencies and operates
/// solely on geometric primitives ([Offset], [Size], [Path], [Matrix4]).
///
/// ### Model Overview
///
/// The 2D page curl is modelled by treating the drag gesture as pulling a
/// page corner towards the user's finger. A **fold line** — the perpendicular
/// bisector of the segment from the corner to the touch point — divides
/// the page into two regions:
///
/// 1. **Flat region**: The uncurled portion, visible as-is.
/// 2. **Curl region**: The folded portion, reflected across the fold line
///    to show the "back" of the page.
///
/// Shadows are computed based on the **curl depth** (normalized distance
/// from corner to touch point relative to page diagonal).
class PageCurlPhysics {
  const PageCurlPhysics._();

  // ---------------------------------------------------------------------------
  // Fold Line Computation
  // ---------------------------------------------------------------------------

  /// Computes the [FoldLine] for the given [cornerOrigin] and [touchPoint].
  ///
  /// The fold line is the perpendicular bisector of the segment
  /// `cornerOrigin → touchPoint`.
  ///
  /// Returns `null` if the two points are coincident (zero-length segment).
  static FoldLine? computeFoldLine(Offset cornerOrigin, Offset touchPoint) {
    final dx = touchPoint.dx - cornerOrigin.dx;
    final dy = touchPoint.dy - cornerOrigin.dy;
    final length = math.sqrt(dx * dx + dy * dy);

    if (length < 1e-6) return null;

    // Midpoint of the segment.
    final midpoint = Offset(
      (cornerOrigin.dx + touchPoint.dx) / 2.0,
      (cornerOrigin.dy + touchPoint.dy) / 2.0,
    );

    // The fold line direction is perpendicular to the segment direction.
    // Segment direction: (dx, dy) → perpendicular: (-dy, dx), normalised.
    final perpDx = -dy / length;
    final perpDy = dx / length;
    final angle = math.atan2(perpDy, perpDx);

    return FoldLine(
      midpoint: midpoint,
      angle: angle,
      direction: Offset(perpDx, perpDy),
    );
  }

  // ---------------------------------------------------------------------------
  // Clip Path Computation
  // ---------------------------------------------------------------------------

  /// Returns the clip [Path] for the **flat** (uncurled) portion of the page.
  ///
  /// This is the half-plane on the same side as the page area that remains
  /// visible (not folded). The clip boundary is the fold line extended to
  /// the page edges.
  ///
  /// [pageSize] is the logical size of the page.
  /// [foldLine] is the computed fold line.
  /// [cornerOrigin] is the corner from which the curl originates (used to
  /// determine which half-plane to keep).
  static Path computeFlatClipPath(
    Size pageSize,
    FoldLine foldLine,
    Offset cornerOrigin,
  ) {
    // We clip by constructing a large polygon on the "flat" side of the fold.
    // Strategy: Find the intersections of the fold line with the page rect
    // edges, then construct the polygon from the page corners on the flat
    // side plus the two intersection points.

    final intersections = _foldLinePageIntersections(foldLine, pageSize);

    if (intersections.length < 2) {
      // Fold line doesn't cross the page — return full page path.
      return Path()
        ..addRect(Rect.fromLTWH(0, 0, pageSize.width, pageSize.height));
    }

    return _buildHalfPlanePath(
      pageSize,
      intersections[0],
      intersections[1],
      foldLine,
      cornerOrigin,
      keepCornerSide: false, // keep the side OPPOSITE to the corner
    );
  }

  /// Returns the clip [Path] for the **curled** (folded) portion of the page.
  ///
  /// This is the half-plane on the corner side of the fold line — the part
  /// that is being lifted off the page.
  static Path computeCurlClipPath(
    Size pageSize,
    FoldLine foldLine,
    Offset cornerOrigin,
  ) {
    final intersections = _foldLinePageIntersections(foldLine, pageSize);

    if (intersections.length < 2) {
      return Path(); // No curl visible.
    }

    return _buildHalfPlanePath(
      pageSize,
      intersections[0],
      intersections[1],
      foldLine,
      cornerOrigin,
      keepCornerSide: true, // keep the side containing the corner
    );
  }

  // ---------------------------------------------------------------------------
  // Reflection Matrix
  // ---------------------------------------------------------------------------

  /// Computes a [Matrix4] that reflects geometry across the [foldLine].
  ///
  /// This is used to mirror the curled page region to display the "back"
  /// of the page.
  ///
  /// ### Mathematical Derivation
  ///
  /// Reflection across a line through point `P` with angle `θ`:
  /// 1. Translate so that `P` is at the origin.
  /// 2. Rotate by `-θ` to align the line with the X-axis.
  /// 3. Reflect across the X-axis (negate Y).
  /// 4. Rotate back by `θ`.
  /// 5. Translate back.
  static Matrix4 computeReflectionMatrix(FoldLine foldLine) {
    final px = foldLine.midpoint.dx;
    final py = foldLine.midpoint.dy;
    final theta = foldLine.angle;
    final cos2T = math.cos(2 * theta);
    final sin2T = math.sin(2 * theta);

    // Combined reflection matrix (translate → rotate → reflect → rotate → translate)
    // Using the 2D reflection formula across a line through (px, py) at angle θ:
    //
    //   x' = cos2θ·(x - px) + sin2θ·(y - py) + px
    //   y' = sin2θ·(x - px) - cos2θ·(y - py) + py
    //
    // As a 3×3 affine matrix (embedded in 4×4 Matrix4):
    //
    //   | cos2θ   sin2θ   (px - cos2θ·px - sin2θ·py) |
    //   | sin2θ  -cos2θ   (py - sin2θ·px + cos2θ·py) |
    //   |  0        0                 1                |
    final m = Matrix4.identity();
    m.setEntry(0, 0, cos2T);
    m.setEntry(0, 1, sin2T);
    m.setEntry(0, 3, px - cos2T * px - sin2T * py);
    m.setEntry(1, 0, sin2T);
    m.setEntry(1, 1, -cos2T);
    m.setEntry(1, 3, py - sin2T * px + cos2T * py);

    return m;
  }

  // ---------------------------------------------------------------------------
  // Curl Depth
  // ---------------------------------------------------------------------------

  /// Computes the **normalised curl depth** in the range [0.0, 1.0].
  ///
  /// This represents how "deep" the curl is relative to the page diagonal.
  /// 0.0 means no curl (touch == corner), 1.0 means maximally curled.
  ///
  /// Used to size shadows, compute fold-back alpha, etc.
  static double computeCurlDepth(
    Offset cornerOrigin,
    Offset touchPoint,
    Size pageSize,
  ) {
    final dragDistance = (touchPoint - cornerOrigin).distance;
    final diagonal = math.sqrt(
      pageSize.width * pageSize.width + pageSize.height * pageSize.height,
    );

    if (diagonal < 1e-6) return 0.0;
    return (dragDistance / diagonal).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Touch-to-Corner Mapping
  // ---------------------------------------------------------------------------

  /// Determines the nearest page corner to the given [touchPosition].
  ///
  /// Returns the corner [Offset] in local page coordinates (top-left origin).
  /// This is used to decide from which corner the curl should originate.
  static Offset nearestCorner(Offset touchPosition, Size pageSize) {
    final cx = touchPosition.dx < pageSize.width / 2 ? 0.0 : pageSize.width;
    final cy = touchPosition.dy < pageSize.height / 2 ? 0.0 : pageSize.height;
    return Offset(cx, cy);
  }

  /// Returns `true` if [touchPosition] falls within any of the corner
  /// hotspot zones defined by [hotspotRatio].
  ///
  /// Hotspots are rectangular zones at the page's left and right edges,
  /// spanning the full height, each with width = `pageWidth * hotspotRatio`.
  static bool isInHotspot(
    Offset touchPosition,
    Size pageSize,
    double hotspotRatio,
  ) {
    final zoneWidth = pageSize.width * hotspotRatio;
    return touchPosition.dx <= zoneWidth ||
        touchPosition.dx >= pageSize.width - zoneWidth;
  }

  // ---------------------------------------------------------------------------
  // Animation Interpolation Helpers
  // ---------------------------------------------------------------------------

  /// Interpolates the touch point along the path from [start] to [end] by [t].
  ///
  /// Used during automatic flip animations to smoothly move the virtual
  /// touch point from its current position to the target (e.g., the
  /// opposite corner for completion, or back to the origin for snap-back).
  static Offset interpolateTouchPoint(Offset start, Offset end, double t) {
    return Offset(
      start.dx + (end.dx - start.dx) * t,
      start.dy + (end.dy - start.dy) * t,
    );
  }

  /// Computes the target touch point for a **completed forward flip**.
  ///
  /// This is the point diagonally opposite the [cornerOrigin] on the page,
  /// representing the page being fully flipped over.
  static Offset computeFlipCompletionTarget(
    Offset cornerOrigin,
    Size pageSize,
  ) {
    // If corner is bottom-right, target is bottom-left, and vice versa.
    // We mirror only the X coordinate to simulate a horizontal page flip.
    final targetX = cornerOrigin.dx < pageSize.width / 2 ? pageSize.width : 0.0;
    return Offset(targetX, cornerOrigin.dy);
  }

  // ---------------------------------------------------------------------------
  // Touch Point Constraints
  // ---------------------------------------------------------------------------

  /// Constrains [touchPoint] to prevent the page from appearing detached
  /// from the book spine, and enforces [CurlAxis] locking.
  ///
  /// Two constraints are applied:
  ///
  /// 1. **Spine attachment**: The touch cannot move past the corner origin
  ///    horizontally (e.g., dragging a right-corner curl further right
  ///    would make the page look like a loose sheet).
  ///
  /// 2. **Axis locking**: Based on [curlAxis], one of the touch coordinates
  ///    is locked to the corner origin to produce a purely horizontal or
  ///    vertical flip.
  static Offset constrainTouchPoint(
    Offset touchPoint,
    Offset cornerOrigin,
    Size pageSize,
    CurlAxis curlAxis,
  ) {
    var x = touchPoint.dx;
    var y = touchPoint.dy;

    // --- Spine attachment constraint ---
    // Prevent the touch from going past the corner in the drag direction.
    if (cornerOrigin.dx >= pageSize.width / 2) {
      // Right corner — touch must stay to the LEFT of the corner.
      x = math.min(x, cornerOrigin.dx);
    } else {
      // Left corner — touch must stay to the RIGHT of the corner.
      x = math.max(x, cornerOrigin.dx);
    }

    // Keep within reasonable vertical bounds.
    y = y.clamp(-pageSize.height * 0.1, pageSize.height * 1.1);

    // --- Axis locking ---
    switch (curlAxis) {
      case CurlAxis.horizontal:
        y = cornerOrigin.dy;
      case CurlAxis.vertical:
        x = cornerOrigin.dx;
      case CurlAxis.both:
        break; // No additional constraint.
    }

    return Offset(x, y);
  }

  // ---------------------------------------------------------------------------
  // Private Helpers — Fold Line ↔ Page Rect Intersection
  // ---------------------------------------------------------------------------

  /// Finds the intersection points of the fold line with the page rectangle.
  ///
  /// Returns 0, 1, or 2 intersection [Offset]s, sorted by distance along
  /// the fold line direction.
  static List<Offset> _foldLinePageIntersections(
    FoldLine foldLine,
    Size pageSize,
  ) {
    final results = <Offset>[];
    final px = foldLine.midpoint.dx;
    final py = foldLine.midpoint.dy;
    final dx = foldLine.direction.dx;
    final dy = foldLine.direction.dy;
    final w = pageSize.width;
    final h = pageSize.height;

    // Parametric line: P(t) = midpoint + t * direction
    // Check intersection with each of the 4 edges of the rect [0,w] × [0,h].

    // Left edge (x = 0): t = (0 - px) / dx  if dx ≠ 0
    if (dx.abs() > 1e-9) {
      final t = -px / dx;
      final y = py + t * dy;
      if (y >= -1e-6 && y <= h + 1e-6) {
        results.add(Offset(0, y.clamp(0, h)));
      }
    }

    // Right edge (x = w): t = (w - px) / dx
    if (dx.abs() > 1e-9) {
      final t = (w - px) / dx;
      final y = py + t * dy;
      if (y >= -1e-6 && y <= h + 1e-6) {
        results.add(Offset(w, y.clamp(0, h)));
      }
    }

    // Top edge (y = 0): t = (0 - py) / dy  if dy ≠ 0
    if (dy.abs() > 1e-9) {
      final t = -py / dy;
      final x = px + t * dx;
      if (x > 1e-6 && x < w - 1e-6) {
        results.add(Offset(x.clamp(0, w), 0));
      }
    }

    // Bottom edge (y = h): t = (h - py) / dy
    if (dy.abs() > 1e-9) {
      final t = (h - py) / dy;
      final x = px + t * dx;
      if (x > 1e-6 && x < w - 1e-6) {
        results.add(Offset(x.clamp(0, w), h));
      }
    }

    // Deduplicate very close points (corner intersections).
    if (results.length > 2) {
      final deduped = <Offset>[results.first];
      for (var i = 1; i < results.length; i++) {
        if ((results[i] - deduped.last).distance > 1e-3) {
          deduped.add(results[i]);
        }
      }
      return deduped.take(2).toList();
    }

    return results;
  }

  /// Builds a closed [Path] covering one half-plane of the page split by
  /// the fold line.
  ///
  /// [keepCornerSide] determines which half-plane to return:
  /// - `true` → the side containing [cornerOrigin] (the curled portion).
  /// - `false` → the opposite side (the flat, visible portion).
  static Path _buildHalfPlanePath(
    Size pageSize,
    Offset intersection1,
    Offset intersection2,
    FoldLine foldLine,
    Offset cornerOrigin, {
    required bool keepCornerSide,
  }) {
    final w = pageSize.width;
    final h = pageSize.height;

    // All four page corners.
    final corners = <Offset>[
      Offset.zero, // top-left
      Offset(w, 0), // top-right
      Offset(w, h), // bottom-right
      Offset(0, h), // bottom-left
    ];

    // Determine which side of the fold line each corner is on.
    // Using the signed distance: d = (C - M) · N
    // where N is the normal to the fold line (same as segment direction).
    final normalX = foldLine.direction.dy; // perpendicular to fold direction
    final normalY = -foldLine.direction.dx;

    bool isOnCornerSide(Offset point) {
      final d1 =
          (point.dx - foldLine.midpoint.dx) * normalX +
          (point.dy - foldLine.midpoint.dy) * normalY;
      final d2 =
          (cornerOrigin.dx - foldLine.midpoint.dx) * normalX +
          (cornerOrigin.dy - foldLine.midpoint.dy) * normalY;
      return d1 * d2 >= 0; // same sign → same side
    }

    // Collect corners on the desired side.
    final sideCorners = <Offset>[];
    for (final corner in corners) {
      final onCornerSide = isOnCornerSide(corner);
      if (keepCornerSide ? onCornerSide : !onCornerSide) {
        sideCorners.add(corner);
      }
    }

    // Build the polygon: intersection1 → side corners (in order) → intersection2
    // We need to order the corners correctly around the perimeter.
    // Sort by angle from the centroid of the side corners for correct winding.
    if (sideCorners.isEmpty) {
      return Path(); // Degenerate case.
    }

    // Order the polygon vertices: i1 → corners on this side (in CW order) → i2

    // Sort side corners by their position along the page perimeter.
    sideCorners.sort((a, b) {
      return _perimeterPosition(a, w, h).compareTo(_perimeterPosition(b, w, h));
    });

    // Determine the correct insertion order so the polygon winds correctly.
    final i1Pos = _perimeterPosition(intersection1, w, h);
    final i2Pos = _perimeterPosition(intersection2, w, h);

    // Collect corners between i1 and i2 going clockwise.
    final allPerimeterPoints = <_PerimPoint>[
      _PerimPoint(intersection1, i1Pos),
      _PerimPoint(intersection2, i2Pos),
      for (final c in sideCorners) _PerimPoint(c, _perimeterPosition(c, w, h)),
    ];
    allPerimeterPoints.sort((a, b) => a.t.compareTo(b.t));

    // Find the segment from i1 going through the side corners to i2.
    // We might need to go CW or CCW. Choose the path that includes the
    // side corners.

    final int i1Idx = allPerimeterPoints.indexWhere(
      (p) => (p.point - intersection1).distance < 1e-3,
    );
    final int i2Idx = allPerimeterPoints.indexWhere(
      (p) => (p.point - intersection2).distance < 1e-3,
    );

    if (i1Idx == -1 || i2Idx == -1) {
      // Fallback: simple polygon.
      return Path()
        ..addRect(Rect.fromLTWH(0, 0, pageSize.width, pageSize.height));
    }

    // Try forward (CW): from i1Idx to i2Idx.
    final forwardPath = <Offset>[];
    for (var i = i1Idx; ; i = (i + 1) % allPerimeterPoints.length) {
      forwardPath.add(allPerimeterPoints[i].point);
      if (i == i2Idx) break;
      if (forwardPath.length > allPerimeterPoints.length + 1) break;
    }

    // Try backward (CCW): from i1Idx to i2Idx.
    final backwardPath = <Offset>[];
    for (
      var i = i1Idx;
      ;
      i = (i - 1 + allPerimeterPoints.length) % allPerimeterPoints.length
    ) {
      backwardPath.add(allPerimeterPoints[i].point);
      if (i == i2Idx) break;
      if (backwardPath.length > allPerimeterPoints.length + 1) break;
    }

    // The correct path is the one that includes the side corners.
    final forwardHasSideCorner = forwardPath.any(
      (p) => sideCorners.any((sc) => (p - sc).distance < 1e-3),
    );

    final selectedPath = forwardHasSideCorner ? forwardPath : backwardPath;

    final path = Path();
    if (selectedPath.isNotEmpty) {
      path.moveTo(selectedPath.first.dx, selectedPath.first.dy);
      for (var i = 1; i < selectedPath.length; i++) {
        path.lineTo(selectedPath[i].dx, selectedPath[i].dy);
      }
      path.close();
    }

    return path;
  }

  /// Returns a normalised [0, 4) parameter representing a point's position
  /// on the perimeter of a rectangle of size `w × h`, going clockwise
  /// from the top-left corner.
  ///
  /// - `[0, 1)` → top edge (left to right)
  /// - `[1, 2)` → right edge (top to bottom)
  /// - `[2, 3)` → bottom edge (right to left)
  /// - `[3, 4)` → left edge (bottom to top)
  static double _perimeterPosition(Offset point, double w, double h) {
    final x = point.dx.clamp(0.0, w);
    final y = point.dy.clamp(0.0, h);

    // Top edge.
    if (y.abs() < 1e-3) return x / w;
    // Right edge.
    if ((x - w).abs() < 1e-3) return 1.0 + y / h;
    // Bottom edge (reversed direction).
    if ((y - h).abs() < 1e-3) return 2.0 + (w - x) / w;
    // Left edge (reversed direction).
    if (x.abs() < 1e-3) return 3.0 + (h - y) / h;

    // Interior point — shouldn't happen, but handle gracefully.
    return 0.0;
  }
}

/// Internal helper for sorting perimeter points.
class _PerimPoint {
  const _PerimPoint(this.point, this.t);
  final Offset point;
  final double t;
}
