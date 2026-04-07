# iOS Support — Technical Guide & Roadmap

> Comprehensive plan for extending `page_curl_effect` to fully support iOS,
> covering rendering differences, gesture nuances, platform-specific
> optimisations, and a phased implementation strategy.

---

## Table of Contents

- [1. Current State Analysis](#1-current-state-analysis)
- [2. iOS vs Android — Key Differences](#2-ios-vs-android--key-differences)
- [3. Rendering Engine Considerations](#3-rendering-engine-considerations)
- [4. Gesture & Haptic Feedback](#4-gesture--haptic-feedback)
- [5. Memory & Performance](#5-memory--performance)
- [6. Safe Area & Display Notch Handling](#6-safe-area--display-notch-handling)
- [7. Platform-Specific Configuration](#7-platform-specific-configuration)
- [8. Testing Strategy](#8-testing-strategy)
- [9. Implementation Phases](#9-implementation-phases)
- [10. File Change Manifest](#10-file-change-manifest)
- [11. Risks & Mitigations](#11-risks--mitigations)

---

## 1. Current State Analysis

### What Works on iOS Today (Untested)

The package is built entirely in Dart using Flutter's `CustomPainter` + `Canvas` APIs.
In theory, **the core rendering pipeline should work on iOS out of the box** because:

- `PageCurlPhysics` is pure math — no platform dependencies.
- `PageCurlPainter` uses `Canvas.drawImageRect`, `clipPath`, `transform` — all cross-platform.
- `WidgetRasterizer` uses `RenderRepaintBoundary.toImage()` — supported on both platforms.
- `CurlGestureHandler` uses `GestureDetector` — Flutter's unified gesture system.

### What Needs Attention

| Area | Risk Level | Reason |
|------|-----------|--------|
| Rendering engine (Impeller vs Skia) | 🔴 High | Impeller is iOS-default; clip path and transform perf characteristics differ |
| `toImage()` performance | 🟡 Medium | iOS Metal backend has different GPU→CPU readback costs |
| Haptic feedback | 🟢 Low | Missing but expected by iOS users |
| ProMotion (120Hz) | 🟡 Medium | iPad Pro / iPhone 13+ support 120fps; frame budget halves |
| Safe Areas | 🟡 Medium | Notch, Dynamic Island, home indicator insets |
| Gesture conflict with iOS edge swipe | 🔴 High | iOS system "back swipe" from left edge conflicts with our left-edge hotspot |
| Memory pressure handling | 🟡 Medium | iOS is more aggressive with memory warnings |

---

## 2. iOS vs Android — Key Differences

### 2.1 Rendering Backend

| Feature | Android | iOS |
|---------|---------|-----|
| Default engine | Impeller (or Skia fallback) | **Impeller** (mandatory since Flutter 3.16) |
| GPU API | Vulkan / OpenGL ES | **Metal** |
| `clipPath` perf | Fast on Impeller | ✅ Fast on Impeller/Metal |
| `transform` (matrix) | Fast | ✅ Fast |
| `drawImageRect` | Fast | ✅ Fast |
| `toImage()` readback | Moderate | ⚠️ **Slower** — Metal GPU→CPU readback can stall pipeline |

**Impact**: The main concern is `toImage()` latency. On some iOS devices, the GPU→CPU readback
required by `RenderRepaintBoundary.toImage()` can take 10–30ms on the first call, causing a
visible stutter on drag start.

### 2.2 Gesture System

| Gesture | Android | iOS |
|---------|---------|-----|
| Edge swipe (back) | Handled by `Navigator.pop()` | **System-level left-edge swipe** — intercepts before Flutter |
| Scroll physics | `ClampingScrollPhysics` default | `BouncingScrollPhysics` default |
| Haptic feedback | Limited API | **Rich taptic engine** (`HapticFeedback.lightImpact`, etc.) |
| Force Touch / 3D Touch | N/A | Available on older models (< iPhone 11) |

**Impact**: Left-edge drag for backward page flip will conflict with iOS system back gesture.
We need to either shrink the left hotspot zone or use a different gesture recognizer.

### 2.3 Display & Layout

| Property | Android | iOS |
|----------|---------|-----|
| Notch / cutout | `MediaQuery.padding` | `MediaQuery.padding` (same API) |
| Dynamic Island | N/A | Additional top padding needed |
| Home indicator | N/A | Bottom safe area inset |
| ProMotion (120Hz) | Some devices | iPhone 13 Pro+, iPad Pro |

---

## 3. Rendering Engine Considerations

### 3.1 Impeller on iOS

Flutter's Impeller backend on iOS uses Metal. Key characteristics:

- **Pre-compiled shaders**: No shader compilation jank (unlike Skia). ✅ Beneficial for us.
- **Tessellation**: `Path` operations (our clip paths) are tessellated on the CPU, then rendered
  on the GPU. Complex paths with many segments should be kept simple.
- **No `saveLayer` overhead**: Our shadow rendering uses `drawPath` with shader gradients —
  this is Impeller-friendly. ✅

### 3.2 Optimisation: `toImage()` Warm-Up

To mitigate the first-call stutter of `toImage()` on iOS:

```dart
/// Pre-warms the rasterisation pipeline by performing a dummy capture
/// during the first idle frame after layout.
///
/// This forces Metal to allocate the readback buffer ahead of time,
/// so the first real capture during a drag feels instantaneous.
void _preWarmRasterisation() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    final boundary = _currentPageBoundaryKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    // Perform a low-res dummy capture to warm up the pipeline.
    final warmUpImage = await WidgetRasterizer.capture(
      boundary,
      pixelRatio: 0.25, // Low-res — just to warm up.
    );
    warmUpImage?.dispose();
  });
}
```

**Where**: Call from `_PageCurlViewState.initState()` on iOS only.

### 3.3 Pixel Ratio Awareness

iOS devices have varying pixel ratios:

| Device | Pixel Ratio |
|--------|------------|
| iPhone SE | 2.0 |
| iPhone 14 | 3.0 |
| iPad | 2.0 |
| iPad Pro 12.9" | 2.0 |

High pixel ratios mean larger `ui.Image` buffers. For a 393×852 logical iPhone 14 screen at 3x,
the raster image is 1179×2556 pixels — **~12 MB** per image (RGBA). Two pages = ~24 MB.

**Mitigation**: Add a `rasterizationScale` parameter to `PageCurlConfig`:

```dart
/// Scale factor for rasterisation resolution relative to device pixel ratio.
///
/// Set to a value < 1.0 to reduce memory usage on high-DPI devices
/// at the cost of slight blurriness during the curl.
/// Default: 1.0 (full native resolution).
final double rasterizationScale;
```

---

## 4. Gesture & Haptic Feedback

### 4.1 iOS Edge Swipe Conflict

**Problem**: iOS intercepts left-edge horizontal swipes for system "back" navigation before
Flutter's `GestureDetector` receives the event.

**Solutions** (ordered by preference):

#### Option A: Shrink Left Hotspot (Recommended)

```dart
/// iOS-specific hotspot configuration that avoids the system's
/// edge-swipe zone (the leftmost ~20 logical pixels).
const PageCurlConfig iosConfig = PageCurlConfig(
  hotspotRatio: 0.20,  // Narrower than default 0.25
  // Additionally, add an iosEdgeInset to push the hotspot inward:
  iosLeftEdgeInset: 20.0,
);
```

Add to `PageCurlPhysics.isInHotspot()`:

```dart
static bool isInHotspot(
  Offset touchPosition,
  Size pageSize,
  double hotspotRatio, {
  double leftEdgeInset = 0.0,
}) {
  final zoneWidth = pageSize.width * hotspotRatio;
  final inLeftZone = touchPosition.dx >= leftEdgeInset &&
      touchPosition.dx <= leftEdgeInset + zoneWidth;
  final inRightZone = touchPosition.dx >= pageSize.width - zoneWidth;
  return inLeftZone || inRightZone;
}
```

#### Option B: Disable iOS Back Swipe (Aggressive)

```dart
// In the widget wrapping PageCurlView:
return PopScope(
  canPop: false, // Disable iOS back swipe entirely
  child: PageCurlView(...),
);
```

#### Option C: Use `RawGestureDetector` with `ImmediateMultiDragGestureRecognizer`

This can win the gesture arena before the iOS system intercepts, but is fragile
and not recommended for long-term stability.

### 4.2 Haptic Feedback Integration

iOS users expect haptic feedback on significant interactions. Add haptic events at:

| Event | Haptic Type | API |
|-------|-----------|-----|
| Drag starts (enters curl mode) | `lightImpact` | `HapticFeedback.lightImpact()` |
| Page flip completes | `mediumImpact` | `HapticFeedback.mediumImpact()` |
| Snap-back (cancelled flip) | `selectionClick` | `HapticFeedback.selectionClick()` |

```dart
// In PageCurlController._onAnimationStatusChanged:
if (status == AnimationStatus.completed) {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    if (_state == CurlState.animatingForward) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }
}
```

**Config integration**:

```dart
/// Whether to trigger haptic feedback on curl interactions.
/// Default: true on iOS, false on Android.
final bool enableHapticFeedback;
```

---

## 5. Memory & Performance

### 5.1 iOS Memory Pressure

iOS is more aggressive with memory warnings than Android. When the system sends
a memory warning, Flutter's `WidgetsBindingObserver.didReceiveMemoryPressure` is called.

**Action**: Dispose cached images on memory pressure:

```dart
class _PageCurlViewState extends State<PageCurlView>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didReceiveMemoryPressure() {
    // Release cached raster images to free GPU memory.
    _disposeImages();
  }
}
```

### 5.2 ProMotion (120Hz) Frame Budget

On 120Hz devices, the frame budget is **8.33ms** instead of 16.67ms. Our rendering pipeline
must be profiled at 120fps:

| Step | Expected Cost | Notes |
|------|-------------|-------|
| `computeFoldLine` | < 0.01ms | Pure math |
| `computeFlatClipPath` | < 0.05ms | Path construction |
| `computeReflectionMatrix` | < 0.01ms | Pure math |
| `clipPath` (GPU) | < 1ms | Impeller tessellation |
| `drawImageRect` × 3 | < 2ms | GPU blit |
| `drawPath` (shadows) × 2 | < 1ms | Gradient fills |
| **Total** | **< 4ms** | ✅ Well within 8.33ms budget |

### 5.3 Image Cache Strategy

```
Lifecycle:
  Idle → [no images cached — zero memory overhead]
  Drag start → capture current + under page (post-frame callback)
  Dragging → images cached, reused every frame
  Animation → same cached images
  Complete → dispose both images immediately
  Memory pressure → dispose images (re-capture on next drag)
```

---

## 6. Safe Area & Display Notch Handling

### 6.1 Layout Considerations

The `PageCurlView` is typically embedded inside a `Scaffold` or custom layout that already
accounts for safe areas. However, if used full-screen:

```dart
// Ensure the curl effect respects safe area insets:
SafeArea(
  child: PageCurlView(
    itemCount: 100,
    itemBuilder: (context, index) => BookPage(index),
  ),
)
```

### 6.2 Corner Origin Adjustment

On devices with rounded display corners (all modern iPhones), the page corners
don't visually touch the screen corners. The curl origin should optionally be
inset to match the display corner radius:

```dart
/// Inset from the physical screen corner to the visual page corner.
/// Useful for fullscreen modes on devices with rounded displays.
/// Default: 0.0 (no inset).
final double cornerInset;
```

---

## 7. Platform-Specific Configuration

### 7.1 Proposed `PlatformCurlConfig`

A factory that returns platform-appropriate defaults:

```dart
/// Returns a [PageCurlConfig] with platform-optimised defaults.
factory PageCurlConfig.adaptive() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return const PageCurlConfig(
      hotspotRatio: 0.20,
      enableHapticFeedback: true,
      rasterizationScale: 0.85,     // Slight downscale on 3x devices
      animationCurve: Curves.easeOutCubic,
      snapBackCurve: Curves.easeOutBack,
      iosLeftEdgeInset: 20.0,
    );
  }
  return const PageCurlConfig(); // Android defaults
}
```

### 7.2 New Config Parameters Summary

| Parameter | Type | Default | iOS Default | Purpose |
|-----------|------|---------|-------------|---------|
| `rasterizationScale` | `double` | `1.0` | `0.85` | Downscale rasterisation on high-DPI |
| `iosLeftEdgeInset` | `double` | `0.0` | `20.0` | Push left hotspot inward to avoid system back gesture |
| `enableHapticFeedback` | `bool` | `false` | `true` | Haptic feedback on curl events |
| `cornerInset` | `double` | `0.0` | `0.0` | Inset corner origin from screen edge |
| `enablePreWarm` | `bool` | `false` | `true` | Pre-warm `toImage()` pipeline on init |

---

## 8. Testing Strategy

### 8.1 Automated Tests

| Test Category | What to Test | Tool |
|--------------|-------------|------|
| Unit | All `PageCurlPhysics` methods with iOS-specific configs | `flutter test` |
| Unit | `isInHotspot` with `iosLeftEdgeInset` parameter | `flutter test` |
| Unit | `PageCurlConfig.adaptive()` returns correct platform values | `flutter test` |
| Widget | `PageCurlView` renders without errors on simulated iOS | `flutter test` |
| Integration | Full drag-to-flip cycle | `flutter_test` with `TestGesture` |

### 8.2 Manual Tests

| Test | Device | What to Verify |
|------|--------|---------------|
| Basic curl | iPhone simulator | Visual correctness of fold, shadow, reflection |
| Edge swipe conflict | iPhone simulator | Left-edge drag doesn't trigger iOS back |
| Performance (60fps) | iPhone SE 3 | No jank on A15 chip |
| Performance (120fps) | iPhone 14 Pro | Smooth at ProMotion 120Hz |
| Memory pressure | Xcode Memory Debugger | Images disposed on warning |
| Haptic feedback | Physical iPhone | Haptics fire at correct moments |
| Safe area | iPhone 14 Pro | No content behind Dynamic Island / notch |
| Landscape | iPad | Correct fold geometry in landscape |

### 8.3 CI/CD Pipeline Extension

```yaml
# .github/workflows/ios-test.yml
jobs:
  ios-test:
    runs-on: macos-latest
    steps:
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24'
      - run: flutter test
      - run: flutter build ios --no-codesign  # Verify iOS compilation
```

---

## 9. Implementation Phases

### Phase A: Validation (Estimated: 1 day)

- [ ] Run existing tests on macOS with iOS simulator
- [ ] Build and launch example app on iOS simulator
- [ ] Profile with Flutter DevTools — baseline metrics
- [ ] Document any visual glitches or crashes

### Phase B: Edge Swipe Resolution (Estimated: 1 day)

- [ ] Add `iosLeftEdgeInset` parameter to `PageCurlConfig`
- [ ] Update `PageCurlPhysics.isInHotspot()` to accept inset parameter
- [ ] Update `CurlGestureHandler` to pass inset from config
- [ ] Add `PageCurlConfig.adaptive()` factory
- [ ] Write unit tests for inset logic
- [ ] Manual test on iOS simulator — verify no system back conflict

### Phase C: Performance Optimisation (Estimated: 2 days)

- [ ] Add `rasterizationScale` parameter to `PageCurlConfig`
- [ ] Apply scale in `WidgetRasterizer.capture()` → scaled `pixelRatio`
- [ ] Implement `toImage()` pre-warm logic in `PageCurlView`
- [ ] Add `WidgetsBindingObserver` for memory pressure handling
- [ ] Profile on physical iPhone at 120Hz
- [ ] Ensure frame times < 8.33ms on ProMotion devices

### Phase D: Haptic Feedback (Estimated: 0.5 day)

- [ ] Add `enableHapticFeedback` parameter to `PageCurlConfig`
- [ ] Inject haptic calls in `PageCurlController` at drag start, flip complete, snap-back
- [ ] Guard with `defaultTargetPlatform == TargetPlatform.iOS`
- [ ] Manual test on physical iPhone

### Phase E: Polish & Documentation (Estimated: 0.5 day)

- [ ] Add `cornerInset` parameter for rounded display corners
- [ ] Update `README.md` with iOS-specific usage notes
- [ ] Update `Agents.md` with iOS considerations
- [ ] Update `CHANGELOG.md` with iOS support release notes
- [ ] Add iOS build to CI workflow

**Total Estimated Effort**: ~5 days

---

## 10. File Change Manifest

| File | Change Type | Description |
|------|-----------|-------------|
| `lib/src/config/page_curl_config.dart` | **Modify** | Add `rasterizationScale`, `iosLeftEdgeInset`, `enableHapticFeedback`, `cornerInset`, `enablePreWarm`; add `PageCurlConfig.adaptive()` factory |
| `lib/src/core/page_curl_physics.dart` | **Modify** | Update `isInHotspot()` signature to accept `leftEdgeInset` |
| `lib/src/core/page_curl_controller.dart` | **Modify** | Add haptic feedback calls guarded by platform + config |
| `lib/src/rendering/widget_rasterizer.dart` | **Modify** | Apply `rasterizationScale` to pixel ratio |
| `lib/src/widgets/page_curl_view.dart` | **Modify** | Add `WidgetsBindingObserver` for memory pressure; add pre-warm logic; pass `iosLeftEdgeInset` through |
| `lib/src/gesture/curl_gesture_handler.dart` | **Modify** | Pass inset parameter to controller |
| `test/core/page_curl_physics_test.dart` | **Modify** | Add tests for `isInHotspot` with inset |
| `test/page_curl_effect_test.dart` | **Modify** | Add tests for `PageCurlConfig.adaptive()` |
| `example/ios/` | **Create** | iOS runner project (via `flutter create`) |
| `pubspec.yaml` | **Modify** | Add `platform: ios` and update description |
| `README.md` | **Modify** | Add iOS section |
| `CHANGELOG.md` | **Modify** | Add iOS release notes |

---

## 11. Risks & Mitigations

| # | Risk | Severity | Probability | Mitigation |
|---|------|----------|-------------|------------|
| 1 | `toImage()` stalls on first call (Metal readback) | 🟡 Medium | High | Pre-warm in `initState()` with low-res dummy capture |
| 2 | iOS system back swipe steals left-edge drags | 🔴 High | Certain | `iosLeftEdgeInset` pushes hotspot inward (20px) |
| 3 | Memory pressure kills cached images mid-animation | 🟡 Medium | Low | `didReceiveMemoryPressure` → graceful image disposal; re-capture on next drag |
| 4 | 120Hz frame budget exceeded on older iPhones | 🟡 Medium | Low | `rasterizationScale < 1.0` reduces image size; painting is < 4ms |
| 5 | Impeller clip path tessellation slowdown | 🟢 Low | Low | Our paths have ≤6 vertices — trivial tessellation |
| 6 | Landscape iPad has different aspect ratio assumptions | 🟡 Medium | Medium | All geometry is `Size`-relative — no hardcoded aspect ratios |
| 7 | App Store review flags missing haptic feedback | 🟢 Low | Low | `enableHapticFeedback` defaults to `true` on iOS |

---

## Appendix: iOS Device Reference

| Device | Screen (logical px) | Pixel Ratio | Refresh Rate | Chip |
|--------|-------------------|-------------|-------------|------|
| iPhone SE 3 | 375 × 667 | 2.0 | 60Hz | A15 |
| iPhone 14 | 390 × 844 | 3.0 | 60Hz | A15 |
| iPhone 14 Pro | 393 × 852 | 3.0 | 120Hz | A16 |
| iPhone 15 Pro Max | 430 × 932 | 3.0 | 120Hz | A17 Pro |
| iPad (10th gen) | 820 × 1180 | 2.0 | 60Hz | A14 |
| iPad Pro 12.9" | 1024 × 1366 | 2.0 | 120Hz | M2 |
