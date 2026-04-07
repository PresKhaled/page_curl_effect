/// A Flutter package for realistic page curl (flip) effects.
///
/// This package provides a [PageCurlView] widget that renders an indexed
/// collection of child widgets as pages with a realistic paper-curling
/// effect, complete with dynamic shadows and fold-back rendering.
///
/// ### Quick Start
///
/// ```dart
/// import 'package:page_curl_effect/page_curl_effect.dart';
///
/// PageCurlView(
///   itemCount: 20,
///   itemBuilder: (context, index) => MyPageWidget(index),
/// )
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
