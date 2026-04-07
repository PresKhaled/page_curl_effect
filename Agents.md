# Page Curl Effect — AI Agent Context

> This file provides structured project context optimised for AI coding agents.
> Read this file first when working on this codebase.

## Project Identity

- **Name**: `page_curl_effect`
- **Type**: Flutter package (library)
- **Language**: Dart 3.9.2+, Flutter ≥1.17.0
- **Platform**: Android (primary target)
- **Purpose**: Realistic page curl (flip) effect for EPUB reader apps
- **License**: MIT

## Quick Reference

```
Root:              d:/Mobile/page_curl_effect/
Barrel export:     lib/page_curl_effect.dart
Main widget:       lib/src/widgets/page_curl_view.dart
Math engine:       lib/src/core/page_curl_physics.dart
Controller:        lib/src/core/page_curl_controller.dart
Painter:           lib/src/rendering/page_curl_painter.dart
Tests:             test/core/page_curl_physics_test.dart
                   test/page_curl_effect_test.dart
Example app:       example/lib/main.dart
```

## Architecture Overview

```
widgets/PageCurlView (StatefulWidget)
  │
  ├── gesture/CurlGestureHandler (detects drag + tap)
  │     │
  │     └── core/PageCurlController (state machine + animation)
  │           │
  │           ├── core/PageCurlPhysics (static math: fold line, reflection, clip)
  │           └── core/CurlState + CurlDirection (enums)
  │
  ├── rendering/PageCurlPainter (CustomPainter — 5-step per frame)
  │     │
  │     ├── core/PageCurlPhysics (fold geometry computation)
  │     └── effects/shadow/CurlShadowPainter (edge + base shadows)
  │
  ├── rendering/WidgetRasterizer (Widget → ui.Image capture)
  │
  └── config/PageCurlConfig, CurlShadowConfig + CurlDefaults (constants)
```

### Dependency Direction (strict, never reverse)

```
widgets → gesture → core
widgets → rendering → core + effects
effects → config
core → config
```

### Module Responsibilities

| Module | Responsibility | Flutter Widget Deps? |
|--------|---------------|---------------------|
| `config/` | Immutable configuration DTOs with `const` constructors | No |
| `core/` | Pure math + state logic (fold line, reflection, state machine) | Minimal (AnimationController) |
| `effects/` | Shadow gradient painting | Yes (Canvas) |
| `gesture/` | Drag/tap detection, forwarding to controller | Yes (GestureDetector) |
| `rendering/` | CustomPainter orchestration + widget rasterisation | Yes (Canvas, RenderObject) |
| `widgets/` | Public-facing composite widget | Yes |

## File Map with Descriptions

### `lib/src/config/page_curl_config.dart`
Master configuration class. Contains all tuneable parameters:
- Gesture: `hotspotRatio`, `enableClickToFlip`, `clickToFlipWidthRatio`, `curlAxis`, `verticalElasticityRatio`
- Animation: `animationDuration`, `animationCurve`, `snapBackCurve`, `flingVelocityThreshold`, `dragCompletionThreshold`
- Geometry: `semiPerimeterRatio`, `foldBackMaskAlpha`
- Shadow: `shadowConfig` (delegates to `CurlShadowConfig`)

### `lib/src/config/curl_defaults.dart`
Centralised constants to avoid magic numbers. Used as fallback for `PageCurlConfig` and `CurlShadowConfig`.

### `lib/src/core/curl_state.dart`
Enum: `idle`, `dragging`, `animatingForward`, `animatingBackward`, `completed`

### `lib/src/core/curl_direction.dart`
Enum: `forward` (next page), `backward` (previous page)

### `lib/src/core/page_curl_physics.dart`
**Pure static class — zero widget dependencies.** Key methods:
- `computeFoldLine(cornerOrigin, touchPoint) → FoldLine?` — perpendicular bisector
- `computeFlatClipPath(pageSize, foldLine, cornerOrigin) → Path`
- `computeCurlClipPath(pageSize, foldLine, cornerOrigin) → Path`
- `computeReflectionMatrix(foldLine) → Matrix4` — 2D affine reflection
- `computeCurlDepth(cornerOrigin, touchPoint, pageSize) → double` — normalised [0,1]
- `nearestCorner(touchPosition, pageSize) → Offset`
- `isInHotspot(touchPosition, pageSize, hotspotRatio) → bool`
- `interpolateTouchPoint(start, end, t) → Offset`
- `computeFlipCompletionTarget(cornerOrigin, pageSize) → Offset`

### `lib/src/core/page_curl_controller.dart`
State machine + `AnimationController` owner. Key API:
- `onDragStart(position) → bool` — accepts/rejects drag
- `onDragUpdate(position)` — updates touch point
- `onDragEnd(velocity:)` — decides complete vs snap-back
- `flipForward()` / `flipBackward()` — programmatic flip
- `jumpToPage(int)` — instant jump
- `touchPointNotifier` — `ValueNotifier<Offset>` for painter binding
- `setPageSize(Size)` — called by PageCurlView on layout
- Callbacks: `onFlipStart`, `onFlipEnd`, `onPageChanged`

### `lib/src/effects/shadow/curl_shadow_config.dart`
Shadow configuration DTO. Parameters per shadow type (edge/base):
- `startAlpha`, `endAlpha`, `startColor`, `endColor`
- `minWidth`, `maxWidth`, `widthRatio`
- `computeEdgeShadowWidth(diameter)` / `computeBaseShadowWidth(diameter)`

### `lib/src/effects/shadow/curl_shadow_painter.dart`
Static methods: `paintEdgeShadow(...)` and `paintBaseShadow(...)`.
Draws gradient strips along the fold line with dynamic width based on curl depth.

### `lib/src/rendering/widget_rasterizer.dart`
Static method: `capture(RenderRepaintBoundary, pixelRatio:) → Future<ui.Image?>`.
Wraps `RenderRepaintBoundary.toImage()` with error handling.

### `lib/src/rendering/page_curl_painter.dart`
The main `CustomPainter`. Per-frame pipeline:
1. Draw under-page image (full size)
2. Clip + draw flat region of current page
3. Transform (reflect) + clip + draw curl region with fold-back mask
4. Paint base shadow (on under-page)
5. Paint edge shadow (at fold crease)

### `lib/src/gesture/curl_gesture_handler.dart`
`StatelessWidget` wrapping child with `GestureDetector`:
- `onHorizontalDragStart/Update/End` → forwarded to controller
- `onTapUp` → click-to-flip (if enabled)

### `lib/src/widgets/page_curl_view.dart`
Main public widget. `StatefulWidget` with `TickerProviderStateMixin`.
- Creates/manages internal controller (or uses external one)
- Renders pages in a `Stack` with `RepaintBoundary` + `Offstage`
- Schedules post-frame rasterisation on first drag via `addPostFrameCallback`
- Overlays `CustomPaint(painter: PageCurlPainter(...))` during active curl

## Mathematical Model

The 2D geometric fold model works as follows:

```
Given: cornerOrigin (C), touchPoint (T), pageSize (W×H)

1. Fold Line:
   - midpoint M = (C + T) / 2
   - direction D = perpendicular to (T - C), normalised
   - angle θ = atan2(D.y, D.x)

2. Clip Paths:
   - Find fold line ∩ page rectangle → 2 intersection points
   - Split page corners into two half-planes by signed distance
   - Build polygon: intersection1 → side corners (CW) → intersection2

3. Reflection Matrix (across fold line through M at angle θ):
   | cos2θ   sin2θ   (Mx - cos2θ·Mx - sin2θ·My) |
   | sin2θ  -cos2θ   (My - sin2θ·Mx + cos2θ·My) |
   |  0        0                 1                 |

4. Curl Depth = clamp(dist(C, T) / diagonal, 0, 1)
```

## Common Tasks for Agents

### Adding a new configuration parameter
1. Add field + constructor param to `PageCurlConfig` (with default value)
2. Add to `copyWith` method
3. Add DartDoc comment
4. Use the parameter in the relevant engine/painter
5. Add unit test for the default value in `test/page_curl_effect_test.dart`
6. Update `README.md` configuration table

### Modifying the rendering pipeline
1. Edit `PageCurlPainter.paint()` — maintain the 5-step ordering
2. If adding new geometry: add static method to `PageCurlPhysics`
3. Write unit test in `test/core/page_curl_physics_test.dart`
4. Run: `dart analyze && flutter test`

### Adding a new shadow type
1. Add parameters to `CurlShadowConfig` with a new compute method
2. Add a new static `paint*Shadow()` method in `CurlShadowPainter`
3. Call it from `PageCurlPainter.paint()` at the appropriate step
4. Add unit test for the compute method

### Debugging visual issues
1. Run the example app: `cd example && flutter run`
2. Add `debugPrint` in `PageCurlPainter.paint()` for geometry values
3. Check fold line midpoint, curl depth, intersection points
4. Use Flutter DevTools > Widget Inspector to verify clip paths

## Code Examples

### Minimal integration
```dart
import 'package:page_curl_effect/page_curl_effect.dart';

PageCurlView(
  itemCount: 10,
  itemBuilder: (context, index) => Container(
    color: Colors.white,
    child: Center(child: Text('Page $index')),
  ),
)
```

### Custom configuration
```dart
PageCurlView(
  itemCount: 50,
  config: PageCurlConfig(
    hotspotRatio: 0.3,
    animationDuration: Duration(milliseconds: 600),
    animationCurve: Curves.easeInOutCubic,
    foldBackMaskAlpha: 0.4,
    enableClickToFlip: false,
    shadowConfig: CurlShadowConfig(
      edgeShadowStartAlpha: 0.3,
      baseShadowWidthRatio: 0.5,
    ),
  ),
  itemBuilder: (context, index) => MyBookPage(index),
)
```

### External controller with callbacks
```dart
class _ReaderState extends State<Reader> with TickerProviderStateMixin {
  late final PageCurlController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageCurlController(
      vsync: this,
      config: const PageCurlConfig(),
      itemCount: 100,
      onFlipStart: (page, dir) => print('Flipping from $page ($dir)'),
      onFlipEnd: (page) => print('Arrived at $page'),
      onPageChanged: (page) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Page ${_ctrl.currentPage + 1} / 100'),
        Expanded(
          child: PageCurlView(
            itemCount: 100,
            controller: _ctrl,
            itemBuilder: (_, i) => PageWidget(i),
          ),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: _ctrl.flipBackward,
              child: Text('Previous'),
            ),
            ElevatedButton(
              onPressed: _ctrl.flipForward,
              child: Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
```

## Testing

```bash
# Run all tests (29 tests)
flutter test

# Run physics tests only
flutter test test/core/page_curl_physics_test.dart

# Run with verbose output
flutter test --reporter expanded
```

## Key Constraints & Gotchas

1. **`core/` must stay widget-free**: `PageCurlPhysics` operates only on `Offset`, `Size`, `Path`, `Matrix4`. Do not import `package:flutter/material.dart` there.
2. **`toImage()` is expensive**: Only call on drag start (via `addPostFrameCallback`), never per-frame.
3. **`Matrix4` comes from `vector_math`**: Imported as `package:vector_math/vector_math_64.dart`.
4. **Reflection matrix uses row/column indexing**: `setEntry(row, col, value)` — column 3 is the translation column.
5. **Clip path winding order matters**: The half-plane polygon builder sorts corners by perimeter position `[0,4)` for correct CW winding.
6. **Shadow strips extend beyond page bounds**: The painter clips to page rect before drawing shadows to prevent bleed.
7. **`PageCurlView` uses `Offstage`** (not `Opacity`) to hide off-screen pages — avoids unnecessary compositing.
