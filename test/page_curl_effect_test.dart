import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_effect/page_curl_effect.dart';

void main() {
  test('PageCurlConfig has sensible defaults', () {
    const config = PageCurlConfig();
    expect(config.hotspotRatio, 0.25);
    expect(config.semiPerimeterRatio, 0.8);
    expect(config.foldBackMaskAlpha, 0.6);
    expect(config.enableClickToFlip, isTrue);
    expect(config.flingVelocityThreshold, 800.0);
    expect(config.dragCompletionThreshold, 0.35);
  });

  test('CurlShadowConfig computes edge shadow width correctly', () {
    const config = CurlShadowConfig();
    // diameter * 0.3 = 100 * 0.3 = 30, within [3, 30].
    expect(config.computeEdgeShadowWidth(100), closeTo(30, 1e-6));
    // diameter * 0.3 = 5 * 0.3 = 1.5, clamped to min 3.
    expect(config.computeEdgeShadowWidth(5), closeTo(3, 1e-6));
  });

  test('CurlShadowConfig computes base shadow width correctly', () {
    const config = CurlShadowConfig();
    // diameter * 0.4 = 50 * 0.4 = 20, within [5, 40].
    expect(config.computeBaseShadowWidth(50), closeTo(20, 1e-6));
  });
}
