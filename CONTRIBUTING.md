# Contributing to Page Curl Effect

Thank you for your interest in contributing to **Page Curl Effect**! This document provides guidelines to ensure a smooth collaboration process.

---

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [Getting Started](#-getting-started)
- [Development Workflow](#-development-workflow)
- [Code Standards](#-code-standards)
- [Pull Request Process](#-pull-request-process)
- [Architecture Guidelines](#-architecture-guidelines)
- [Testing Requirements](#-testing-requirements)
- [Performance Guidelines](#-performance-guidelines)

---

## 🤝 Code of Conduct

- Be respectful, constructive, and professional in all interactions.
- Focus on the technical merit of contributions.
- Assume good intent in code reviews and discussions.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (≥ 1.17.0)
- Dart SDK (^3.9.2)
- An Android device or emulator for visual testing

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd page_curl_effect

# Install dependencies
flutter pub get

# Run the test suite
flutter test

# Run the example app
cd example
flutter pub get
flutter run
```

---

## 🔄 Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 2. Make Changes

- Write production-ready, heavily documented code.
- Follow the existing architecture and module structure.
- Add or update unit tests.

### 3. Validate

```bash
# Ensure zero analyzer errors
dart analyze

# Ensure all tests pass
flutter test

# Format all code
dart format .
```

### 4. Commit

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add cylindrical deformation enhancement
fix: correct shadow width at extreme curl depths
docs: update configuration reference in README
test: add edge case tests for fold line computation
refactor: extract shadow geometry into dedicated class
perf: reduce allocations in PageCurlPainter.paint()
```

### 5. Submit a Pull Request

See [Pull Request Process](#-pull-request-process) below.

---

## 📐 Code Standards

### Dart Style

- Follow [Effective Dart](https://dart.dev/effective-dart) guidelines.
- Use `dart format` — no manual formatting exceptions.
- Maximum line length: enforced by `dart format`.

### Documentation

- **Every public API** must have DartDoc comments.
- Use `///` for documentation, `//` for implementation notes.
- Include `@param`-style descriptions for complex constructors.
- Add code examples in DartDoc where helpful.

```dart
/// Computes the [FoldLine] for the given [cornerOrigin] and [touchPoint].
///
/// The fold line is the perpendicular bisector of the segment
/// `cornerOrigin → touchPoint`.
///
/// Returns `null` if the two points are coincident (zero-length segment).
static FoldLine? computeFoldLine(Offset cornerOrigin, Offset touchPoint) {
```

### Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| Classes | PascalCase | `PageCurlPainter` |
| Files | snake_case | `page_curl_painter.dart` |
| Functions/Methods | camelCase | `computeFoldLine` |
| Constants | camelCase | `defaultHotspotRatio` |
| Private members | `_` prefix | `_animationController` |
| Enums | PascalCase values | `CurlState.animatingForward` |

### Immutability

- Configuration classes (`PageCurlConfig`, `CurlShadowConfig`) must be **immutable** with `const` constructors and `copyWith` methods.
- Use `final` for all fields unless mutation is explicitly required.

---

## 🔀 Pull Request Process

### Before Submitting

- [ ] Code compiles with zero analyzer errors (`dart analyze`)
- [ ] All existing tests pass (`flutter test`)
- [ ] New code has corresponding unit tests
- [ ] Code is formatted (`dart format .`)
- [ ] DartDoc comments are added for all public APIs
- [ ] README is updated if the public API changes
- [ ] CHANGELOG.md is updated with the change summary

### PR Description Template

```markdown
## Summary
Brief description of what this PR does.

## Motivation
Why is this change needed?

## Changes
- Bullet list of specific changes.

## Testing
- How was this tested?
- Any manual verification steps?

## Screenshots / Recordings
(If visual changes — attach before/after screenshots or screen recordings)
```

### Review Criteria

PRs are evaluated on:

1. **Correctness** — Does it work as intended?
2. **Architecture** — Does it follow the established module structure?
3. **Performance** — No per-frame allocations in the paint loop.
4. **Testing** — Adequate unit test coverage.
5. **Documentation** — Clear DartDoc for public APIs.

---

## 🏗️ Architecture Guidelines

### Module Structure

```
lib/src/
├── config/      # Immutable configuration DTOs
├── core/        # Pure logic — math, state, controllers (zero widget deps)
├── effects/     # Visual effect painters (shadows, fold-back)
├── gesture/     # Input handling widgets
├── rendering/   # CustomPainters and rasterisation utilities
└── widgets/     # Public-facing composite widgets
```

### Key Principles

1. **Separation of Concerns**: `core/` must have zero Flutter widget imports. It operates on geometric primitives only.
2. **Single Responsibility**: Each file does one thing. `PageCurlPhysics` = math only. `PageCurlPainter` = painting only.
3. **Dependency Direction**: `widgets → gesture + rendering → core + effects → config`. Never reverse this flow.
4. **Immutable Configuration**: All config classes are `const`-constructable with `copyWith`.

### Adding a New Feature

1. **Config first**: Add any new parameters to `PageCurlConfig` or `CurlShadowConfig`.
2. **Core logic**: Implement the math/logic in `core/` with unit tests.
3. **Rendering**: Add visual effects in `effects/` or `rendering/`.
4. **Integration**: Wire it into `PageCurlPainter` and/or `PageCurlView`.
5. **Export**: Update `page_curl_effect.dart` barrel if new public classes are added.

---

## 🧪 Testing Requirements

### Unit Tests (Required)

- All `core/` classes must have comprehensive unit tests.
- Test edge cases: zero-size pages, coincident points, boundary values.
- Use `closeTo` matchers for floating-point comparisons.

```dart
test('fold line direction is unit length', () {
  final fold = PageCurlPhysics.computeFoldLine(corner, touch)!;
  expect(fold.direction.distance, closeTo(1.0, 1e-6));
});
```

### Widget Tests (Recommended)

- Test that `PageCurlView` renders without errors.
- Test controller lifecycle (creation, disposal).
- Test gesture interaction basics.

### Visual Tests (Manual)

- Run the example app on an Android device/emulator.
- Verify smooth 60fps animation via Flutter DevTools.
- Verify shadow rendering at various curl depths.

---

## ⚡ Performance Guidelines

The page curl effect runs at 60/120 FPS. To maintain this:

### Do

- Pre-compute geometry before the `paint()` call.
- Cache `ui.Image` objects — only re-capture on page/size change.
- Use `shouldRepaint` to avoid unnecessary repaints.
- Use `const` constructors wherever possible.

### Don't

- Allocate objects (Lists, Paths, Paints) inside `paint()` on every frame.
- Call `toImage()` during drag/animation (only on drag start).
- Use `setState()` more than once per frame.
- Add expensive widget rebuilds inside `itemBuilder`.

### Profiling

```bash
flutter run --profile
```

Open **Flutter DevTools → Performance** and verify:
- Frame build times < 16ms (60fps) or < 8ms (120fps).
- No jank spikes during drag or animation.
- Memory is stable (no leaks from uncached images).

---

## 💡 Ideas for Future Contributions

- **Cylindrical deformation**: Enhance the 2D fold with a cylinder-based curve near the fold line.
- **RTL support**: Right-to-left page flip for Arabic/Hebrew content.
- **Double-page mode**: Landscape mode with two pages side-by-side.
- **Page turn sound effects**: Optional audio feedback.
- **Fragment shader enhancement**: Use custom GLSL shaders for advanced lighting.
- **iOS optimisation**: Platform-specific tuning for iOS devices.

---

Thank you for contributing!
