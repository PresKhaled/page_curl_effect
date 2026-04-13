## 0.1.2

### ✨ Enhancements

- **`PageCurlController` now extends `PageController`**: Eliminates the need to maintain two separate controllers when toggling the curl effect on/off. A single `PageCurlController` instance can be passed to both `PageCurlView` (curl ON) and Flutter's built-in `PageView` (curl OFF) without losing page-index synchronisation.
  - **`page` getter**: Returns the scroll-position-based fractional page when a `PageView` is attached (`hasClients == true`); falls back to `currentPage.toDouble()` in curl mode.
  - **`jumpToPage`**: Updates the internal index and, when clients are attached, also moves the `PageView` scroll position instantly.
  - **`animateToPage` / `nextPage` / `previousPage`**: Delegate to `PageController` scroll animation in PageView mode; use the curl flip animation in curl mode.
  - **Automatic sync**: `currentPage` stays in sync with `PageView` swipes via `attach`/`detach` hooks — no manual listener required.
  - **`keepPage` and `viewportFraction`**: New optional constructor parameters forwarded to `PageController` for PageView mode.

### 🐛 Bug Fixes

- **`PageView` starts at wrong page after toggling curl off**: Fixed by overriding the `initialPage` getter to dynamically return `_currentPage` instead of the frozen constructor value. Flutter's internal `_PagePosition` reads `this.initialPage` during layout to compute the starting scroll offset — by making this getter dynamic, the attached `PageView` always starts at the correct current page with zero flicker and no post-frame workarounds.

### 🧪 Testing

- Added `test/core/page_curl_controller_test.dart` with **6 new unit tests** covering `PageController` inheritance, navigation routing, and the `initialPage` regression.
- Total test count: **37 tests**.

---

## 0.1.1

### 🐛 Bug Fixes & Refinements

- **Vertical Page Curl**: Fully implemented vertical axis (`CurlAxis.vertical`) with proper direction inference, hotspot detection, and spine bounding constraints.
- **Elasticity Axis**: Added `CurlAxis.horizontalWithVerticalElasticity` (now default) to allow realistic vertical bending while tearing pages horizontally without detaching the paper.
- **Page Caching**: Fixed a bug where external controllers failed to drop the rasterized cache, leading to the first page permanently appearing across all curls.
- **Constants Extraction**: Centralized magic numbers to `CurlDefaults` for easier config maintenance.

---

## 0.1.0

### 🎉 Initial Release

#### Core Features
- **PageCurlView**: Main widget for rendering pages with realistic curl effect.
- **PageCurlController**: Full state machine for programmatic page control (flip forward/backward, jump to page).
- **PageCurlPhysics**: Pure geometric math engine — fold line computation, 2D reflection matrix, clip path generation, curl depth normalisation.
- **CurlGestureHandler**: Gesture detection with configurable hotspot zones and click-to-flip support.

#### Rendering Pipeline
- **PageCurlPainter**: 5-step per-frame `CustomPainter` — under-page draw, flat clip, reflected curl with fold-back alpha mask, edge shadow, base shadow.
- **CurlShadowPainter**: Dual-layer shadow system (edge + base) with dynamic width scaling.
- **WidgetRasterizer**: Captures any Flutter widget as `ui.Image` via `RepaintBoundary.toImage()`.

#### Configuration
- **PageCurlConfig**: Master configuration for gestures, animation curves/durations, geometry, and shadows.
- **CurlShadowConfig**: Fine-grained shadow control — colours, alpha, min/max width, width ratios.

#### Testing
- 29 unit tests covering physics engine, configuration defaults, and shadow computation.

#### Example
- Demo app with 10 book-styled literary pages.
