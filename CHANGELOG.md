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
