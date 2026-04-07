import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_effect/src/core/page_curl_physics.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

void main() {
  // -------------------------------------------------------------------------
  // Test Constants
  // -------------------------------------------------------------------------

  const pageSize = Size(400, 600);
  const bottomRight = Offset(400, 600);
  const bottomLeft = Offset(0, 600);
  const topRight = Offset(400, 0);

  // -------------------------------------------------------------------------
  // computeFoldLine
  // -------------------------------------------------------------------------

  group('computeFoldLine', () {
    test('returns null when corner and touch are coincident', () {
      final result = PageCurlPhysics.computeFoldLine(bottomRight, bottomRight);
      expect(result, isNull);
    });

    test('midpoint is the average of corner and touch', () {
      const touch = Offset(200, 600);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;

      expect(fold.midpoint.dx, closeTo(300, 1e-6));
      expect(fold.midpoint.dy, closeTo(600, 1e-6));
    });

    test('direction is perpendicular to the corner→touch segment', () {
      // Horizontal drag: corner (400,600) → touch (200,600)
      // Segment direction: (-1, 0) → perpendicular should be (0, -1) or (0, 1)
      const touch = Offset(200, 600);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;

      // The direction should be perpendicular — dot product with segment = 0
      final segDx = touch.dx - bottomRight.dx;
      final segDy = touch.dy - bottomRight.dy;
      final dot = fold.direction.dx * segDx + fold.direction.dy * segDy;
      expect(dot, closeTo(0, 1e-6));
    });

    test('direction is unit length', () {
      const touch = Offset(150, 300);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final length = fold.direction.distance;
      expect(length, closeTo(1.0, 1e-6));
    });

    test('fold line angle matches atan2 of direction', () {
      const touch = Offset(100, 400);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final expectedAngle = math.atan2(fold.direction.dy, fold.direction.dx);
      expect(fold.angle, closeTo(expectedAngle, 1e-6));
    });
  });

  // -------------------------------------------------------------------------
  // computeCurlDepth
  // -------------------------------------------------------------------------

  group('computeCurlDepth', () {
    test('returns 0 when touch == corner', () {
      final depth = PageCurlPhysics.computeCurlDepth(
        bottomRight,
        bottomRight,
        pageSize,
      );
      expect(depth, closeTo(0.0, 1e-6));
    });

    test('returns value in (0, 1] for a real drag', () {
      const touch = Offset(200, 300);
      final depth = PageCurlPhysics.computeCurlDepth(
        bottomRight,
        touch,
        pageSize,
      );
      expect(depth, greaterThan(0));
      expect(depth, lessThanOrEqualTo(1.0));
    });

    test('returns 1.0 when drag distance >= diagonal', () {
      // Diagonal ≈ 721.11. Touch very far away.
      const touch = Offset(-500, -200);
      final depth = PageCurlPhysics.computeCurlDepth(
        bottomRight,
        touch,
        pageSize,
      );
      expect(depth, closeTo(1.0, 1e-6));
    });
  });

  // -------------------------------------------------------------------------
  // nearestCorner
  // -------------------------------------------------------------------------

  group('nearestCorner', () {
    test('returns bottom-right for touch in bottom-right quadrant', () {
      final corner = PageCurlPhysics.nearestCorner(
        const Offset(350, 500),
        pageSize,
      );
      expect(corner, equals(bottomRight));
    });

    test('returns bottom-left for touch in bottom-left quadrant', () {
      final corner = PageCurlPhysics.nearestCorner(
        const Offset(50, 500),
        pageSize,
      );
      expect(corner, equals(bottomLeft));
    });

    test('returns top-right for touch in top-right quadrant', () {
      final corner = PageCurlPhysics.nearestCorner(
        const Offset(350, 100),
        pageSize,
      );
      expect(corner, equals(topRight));
    });

    test('returns top-left for touch in top-left quadrant', () {
      final corner = PageCurlPhysics.nearestCorner(
        const Offset(50, 100),
        pageSize,
      );
      expect(corner, equals(Offset.zero));
    });
  });

  // -------------------------------------------------------------------------
  // isInHotspot
  // -------------------------------------------------------------------------

  group('isInHotspot', () {
    test('returns true for touch in left hotspot', () {
      expect(
        PageCurlPhysics.isInHotspot(const Offset(10, 300), pageSize, 0.25),
        isTrue,
      );
    });

    test('returns true for touch in right hotspot', () {
      expect(
        PageCurlPhysics.isInHotspot(const Offset(390, 300), pageSize, 0.25),
        isTrue,
      );
    });

    test('returns false for touch in center', () {
      expect(
        PageCurlPhysics.isInHotspot(const Offset(200, 300), pageSize, 0.25),
        isFalse,
      );
    });
  });

  // -------------------------------------------------------------------------
  // interpolateTouchPoint
  // -------------------------------------------------------------------------

  group('interpolateTouchPoint', () {
    test('returns start at t=0', () {
      const start = Offset(100, 200);
      const end = Offset(300, 400);
      final result = PageCurlPhysics.interpolateTouchPoint(start, end, 0);
      expect(result, equals(start));
    });

    test('returns end at t=1', () {
      const start = Offset(100, 200);
      const end = Offset(300, 400);
      final result = PageCurlPhysics.interpolateTouchPoint(start, end, 1);
      expect(result, equals(end));
    });

    test('returns midpoint at t=0.5', () {
      const start = Offset(100, 200);
      const end = Offset(300, 400);
      final result = PageCurlPhysics.interpolateTouchPoint(start, end, 0.5);
      expect(result.dx, closeTo(200, 1e-6));
      expect(result.dy, closeTo(300, 1e-6));
    });
  });

  // -------------------------------------------------------------------------
  // computeFlipCompletionTarget
  // -------------------------------------------------------------------------

  group('computeFlipCompletionTarget', () {
    test('bottom-right corner → target is bottom-left', () {
      final target = PageCurlPhysics.computeFlipCompletionTarget(
        bottomRight,
        pageSize,
      );
      expect(target, equals(Offset(0, 600)));
    });

    test('bottom-left corner → target is bottom-right', () {
      final target = PageCurlPhysics.computeFlipCompletionTarget(
        bottomLeft,
        pageSize,
      );
      expect(target, equals(Offset(400, 600)));
    });
  });

  // -------------------------------------------------------------------------
  // computeReflectionMatrix
  // -------------------------------------------------------------------------

  group('computeReflectionMatrix', () {
    test('reflecting a point across the fold line and back gives original', () {
      const touch = Offset(200, 600);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final matrix = PageCurlPhysics.computeReflectionMatrix(fold);

      // Reflecting twice should return to the original point.
      // M * M = I for a reflection matrix.
      final doubleReflection = matrix.multiplied(matrix);

      // Check the diagonal is ~identity.
      expect(doubleReflection.entry(0, 0), closeTo(1.0, 1e-6));
      expect(doubleReflection.entry(1, 1), closeTo(1.0, 1e-6));
      expect(doubleReflection.entry(0, 1), closeTo(0.0, 1e-6));
      expect(doubleReflection.entry(1, 0), closeTo(0.0, 1e-6));
    });

    test('a point on the fold line is unchanged by reflection', () {
      const touch = Offset(200, 400);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final matrix = PageCurlPhysics.computeReflectionMatrix(fold);

      // The midpoint lies on the fold line — should be invariant.
      final p = fold.midpoint;
      final transformed = matrix.transform3(Vector3(p.dx, p.dy, 0));

      expect(transformed.x, closeTo(p.dx, 1e-4));
      expect(transformed.y, closeTo(p.dy, 1e-4));
    });
  });

  // -------------------------------------------------------------------------
  // computeFlatClipPath / computeCurlClipPath
  // -------------------------------------------------------------------------

  group('clip paths', () {
    test('flat clip path is not empty for a valid fold', () {
      const touch = Offset(200, 600);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final flatPath = PageCurlPhysics.computeFlatClipPath(
        pageSize,
        fold,
        bottomRight,
      );
      expect(flatPath.getBounds().isEmpty, isFalse);
    });

    test('curl clip path is not empty for a valid fold', () {
      const touch = Offset(200, 600);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final curlPath = PageCurlPhysics.computeCurlClipPath(
        pageSize,
        fold,
        bottomRight,
      );
      expect(curlPath.getBounds().isEmpty, isFalse);
    });

    test('flat + curl clip paths together cover the full page area', () {
      const touch = Offset(200, 400);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final flatPath = PageCurlPhysics.computeFlatClipPath(
        pageSize,
        fold,
        bottomRight,
      );
      final curlPath = PageCurlPhysics.computeCurlClipPath(
        pageSize,
        fold,
        bottomRight,
      );

      // Both paths should have non-trivial bounds.
      final flatBounds = flatPath.getBounds();
      final curlBounds = curlPath.getBounds();

      // The union of their bounds should approximate the full page.
      final unionRect = flatBounds.expandToInclude(curlBounds);
      expect(unionRect.width, closeTo(pageSize.width, 2.0));
      expect(unionRect.height, closeTo(pageSize.height, 2.0));
    });

    test('curl clip path contains the corner origin', () {
      const touch = Offset(200, 400);
      final fold = PageCurlPhysics.computeFoldLine(bottomRight, touch)!;
      final curlPath = PageCurlPhysics.computeCurlClipPath(
        pageSize,
        fold,
        bottomRight,
      );

      // The corner should be inside (or on the edge of) the curl clip.
      expect(curlPath.contains(Offset(399, 599)), isTrue);
    });
  });
}
