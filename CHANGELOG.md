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
