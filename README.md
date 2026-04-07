# Page Curl Effect 📖

[![Dart](https://img.shields.io/badge/Dart-^3.9.2-blue.svg)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-≥1.17.0-02569B.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A high-performance Flutter package that delivers a **realistic page curl (flip) effect**, inspired by [android-PageFlip](https://github.com/eschao/android-PageFlip). Designed for EPUB readers and book-style applications targeting Android.

<p align="center">
  <em>Drag from any corner to curl the page — complete with dynamic shadows, fold-back rendering, and smooth animations.</em>
</p>

---

## ✨ Features

- **Widget-to-Mesh**: Any Flutter widget (text, images, buttons) can be a page — no image-only limitation.
- **Realistic Shadows**: Dual-layer shadow system (edge shadow + base shadow) with configurable colors, alpha, and width.
- **Fold-Back Rendering**: See the "back" of the page during a curl with adjustable darkening alpha.
- **Gesture-Driven**: High-precision touch tracking with configurable hotspot zones for drag initiation.
- **Click-to-Flip**: Optional tap-to-flip on left/right halves of the page.
- **Smooth Animations**: `AnimationController`-driven with configurable curves (ease-out, elastic, etc.) and fling velocity detection.
- **Programmatic Control**: Flip forward/backward, jump to page, and listen to page change events via `PageCurlController`.
- **60/120 FPS**: Optimised rendering pipeline using `CustomPainter` + `Canvas`, leveraging Flutter's Impeller/Skia engine.

---

## 🚀 Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  page_curl_effect:
    path: ../  # or your package source
```

### Basic Usage

```dart
import 'package:page_curl_effect/page_curl_effect.dart';

PageCurlView(
  itemCount: 20,
  itemBuilder: (context, index) => Container(
    color: Colors.white,
    child: Center(child: Text('Page ${index + 1}')),
  ),
)
```

### With External Controller

```dart
class _MyReaderState extends State<MyReader> with TickerProviderStateMixin {
  late final PageCurlController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageCurlController(
      vsync: this,
      config: const PageCurlConfig(
        animationDuration: Duration(milliseconds: 500),
        animationCurve: Curves.easeInOut,
        hotspotRatio: 0.3,
      ),
      itemCount: 100,
      onPageChanged: (page) => debugPrint('Page: $page'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageCurlView(
      itemCount: 100,
      controller: _controller,
      itemBuilder: (context, index) => BookPageWidget(index),
    );
  }
}
```

### Programmatic Navigation

```dart
_controller.flipForward();   // Animate to next page
_controller.flipBackward();  // Animate to previous page
_controller.jumpToPage(5);   // Jump without animation
```

---

## ⚙️ Configuration

### PageCurlConfig

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `hotspotRatio` | `double` | `0.25` | Width ratio of drag-start zones at left/right edges (0.0–0.5) |
| `semiPerimeterRatio` | `double` | `0.8` | Controls curl "roundness" — higher = wider, gentler curve |
| `foldBackMaskAlpha` | `double` | `0.6` | Darkening opacity of the page back face (0.0–1.0) |
| `animationDuration` | `Duration` | `400ms` | Duration of auto-flip animations |
| `animationCurve` | `Curve` | `easeOut` | Easing curve for flip completion |
| `snapBackCurve` | `Curve` | `easeOut` | Easing curve for snap-back (cancelled flip) |
| `enableClickToFlip` | `bool` | `true` | Enable tap-to-flip on left/right halves |
| `clickToFlipWidthRatio` | `double` | `0.5` | Boundary ratio for left/right tap zones |
| `flingVelocityThreshold` | `double` | `800.0` | Min fling velocity (px/s) to auto-complete a flip |
| `dragCompletionThreshold` | `double` | `0.35` | Min normalised drag distance to auto-complete on release |
| `shadowConfig` | `CurlShadowConfig` | *(defaults)* | Shadow appearance configuration |

### CurlShadowConfig

Controls the dual-layer shadow system:

```dart
const CurlShadowConfig(
  // Edge shadow (at the fold crease)
  edgeShadowStartAlpha: 0.25,
  edgeShadowEndAlpha: 0.0,
  edgeShadowMinWidth: 3.0,
  edgeShadowMaxWidth: 30.0,
  edgeShadowWidthRatio: 0.3,

  // Base shadow (cast on the under-page)
  baseShadowStartAlpha: 0.15,
  baseShadowEndAlpha: 0.0,
  baseShadowMinWidth: 5.0,
  baseShadowMaxWidth: 40.0,
  baseShadowWidthRatio: 0.4,
)
```

Shadow widths are computed dynamically: `width = clamp(diameter × ratio, min, max)`.

---

## 🏗️ Architecture

```
lib/
├── page_curl_effect.dart              # Barrel export
└── src/
    ├── config/
    │   └── page_curl_config.dart      # Master configuration
    ├── core/
    │   ├── curl_state.dart            # State machine enum
    │   ├── curl_direction.dart        # Flip direction enum
    │   ├── page_curl_physics.dart     # Math engine (fold line, reflection, clipping)
    │   └── page_curl_controller.dart  # State machine + AnimationController
    ├── effects/
    │   └── shadow/
    │       ├── curl_shadow_config.dart  # Shadow configuration
    │       └── curl_shadow_painter.dart # Edge + base shadow rendering
    ├── gesture/
    │   └── curl_gesture_handler.dart  # Drag + tap gesture forwarding
    ├── rendering/
    │   ├── page_curl_painter.dart     # Main CustomPainter (5-step pipeline)
    │   └── widget_rasterizer.dart     # Widget → ui.Image capture
    └── widgets/
        └── page_curl_view.dart        # Public API widget
```

### Rendering Pipeline (per frame)

1. **Draw under-page** — the next/previous page, full size
2. **Clip & draw flat region** — uncurled portion of current page
3. **Reflect & draw curl region** — back of page with fold-back alpha mask
4. **Paint edge shadow** — narrow gradient at the fold crease
5. **Paint base shadow** — wider gradient on the under-page

---

## 📚 API Reference

| Class | Purpose |
|-------|--------|
| `PageCurlView` | Main widget — drop-in replacement for `PageView` with curl effect |
| `PageCurlController` | State machine + animation controller for programmatic control |
| `PageCurlConfig` | Master configuration DTO (gestures, animation, geometry, shadows) |
| `CurlShadowConfig` | Shadow appearance configuration (edge + base) |
| `PageCurlPhysics` | Pure static math engine (fold line, reflection, clipping) |
| `FoldLine` | Immutable value object for fold line geometry |
| `CurlState` | Enum: `idle`, `dragging`, `animatingForward`, `animatingBackward`, `completed` |
| `CurlDirection` | Enum: `forward`, `backward` |

---

## 🧮 Mathematical Model

The curl is modelled using a **2D geometric fold**:

- **Fold Line**: The perpendicular bisector of the segment from the drag corner to the touch point.
- **Clip Paths**: The page is split into two half-planes by the fold line — flat and curled.
- **Reflection Matrix**: A 2D affine reflection across the fold line renders the back of the page.
- **Curl Depth**: Normalised distance (0.0–1.0) used to scale shadows and fold-back opacity.

---

## 🧪 Testing

Run the test suite:

```bash
flutter test
```

The package includes **29 unit tests** covering:

- Fold line computation (midpoint, perpendicularity, unit length, angle)
- Reflection matrix (double-reflection = identity, fold-line invariance)
- Clip path geometry (non-empty, union covers page, corner containment)
- Curl depth normalisation and edge cases
- Corner detection and hotspot detection
- Animation interpolation
- Configuration defaults and shadow width computation

---

## 📱 Example App

```bash
cd example
flutter run
```

The example app demonstrates 10 book-style pages with chapter titles, decorative dividers, and literary sample text.

---

## 📋 Requirements

- **Flutter**: ≥ 1.17.0
- **Dart SDK**: ^3.9.2
- **Platform**: Android (primary target)

---

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
