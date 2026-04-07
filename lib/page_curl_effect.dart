/// A high-performance Flutter package for rendering realistic, physics-based
/// page curl and flip effects in Book and EPUB reader applications.
///
/// **Page Curl Effect** transforms any basic Flutter widget into an interactive,
/// highly responsive page. It leverages pure 2D geometric math and optimized
/// `CustomPainter` pipelines to calculate fold lines, clip paths, and reflection
/// matrices. This enables dynamic rendering of the page's back face and complex
/// dual-layer shadows at 60/120 FPS.
///
/// ### Core Capabilities
/// * **Widget-to-Mesh:** Converts complex widget trees into rasterized textures
///   for zero-jank transformations.
/// * **Multi-Axis Curling:** Supports [CurlAxis.horizontal], [CurlAxis.vertical],
///   and [CurlAxis.horizontalWithVerticalElasticity] mimicking physical paper.
/// * **Dual-Layer Shadows:** Computes dynamic edge and base shadows via
///   [CurlShadowConfig].
/// * **Extensible Controller:** Full programmatic navigation and lifecycle detection
///   using [PageCurlController].
///
/// ### Quick Start
/// The easiest way to integrate the package is using [PageCurlView] directly:
///
/// ```dart
/// import 'package:page_curl_effect/page_curl_effect.dart';
///
/// PageCurlView(
///   itemCount: 20,
///   itemBuilder: (context, index) {
///     return Container(
///       color: Colors.white,
///       child: Center(child: Text('Page ${index + 1}')),
///     );
///   },
/// )
/// ```
///
/// ### Advanced Configuration
/// For fine-grained control, configure a [PageCurlController] externally. This
/// allows responding to flip events, jumping instantly to specific pages, and
/// tailoring physics metrics via [PageCurlConfig].
///
/// ```dart
/// final controller = PageCurlController(
///   vsync: this,
///   itemCount: 100,
///   config: const PageCurlConfig(
///     hotspotRatio: 0.3, // Larger touch zones on edges
///     curlAxis: CurlAxis.horizontalWithVerticalElasticity,
///   ),
/// );
/// ```
library;

// Configuration
export 'src/config/page_curl_config.dart';
// Core
export 'src/core/curl_axis.dart';
export 'src/core/curl_direction.dart';
export 'src/core/curl_state.dart';
export 'src/core/page_curl_controller.dart';
export 'src/core/page_curl_physics.dart' show PageCurlPhysics, FoldLine;
// Effects
export 'src/effects/shadow/curl_shadow_config.dart';
// Widgets
export 'src/widgets/page_curl_view.dart';
