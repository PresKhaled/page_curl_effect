import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_effect/page_curl_effect.dart';

class Mockvsync implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PageCurlController controller;
  late TickerProvider vsync;
  int? lastNotifiedPage;

  setUp(() {
    vsync = Mockvsync();
    lastNotifiedPage = null;
    controller = PageCurlController(
      vsync: vsync,
      itemCount: 10,
      config: const PageCurlConfig(),
      initialPage: 2,
      onPageChanged: (page) => lastNotifiedPage = page,
    );
  });

  group('PageCurlController (Inheritance & Navigation)', () {
    test('Initial page index is correctly set from constructor', () {
      expect(controller.currentPage, 2);
      expect(controller.page, 2.0);
    });

    test('jumpToPage updates index and notifies listeners', () {
      controller.jumpToPage(5);

      expect(controller.currentPage, 5);
      expect(lastNotifiedPage, 5);
      expect(controller.page, 5.0);
    });

    test('nextPage triggers flipForward in curl mode (no clients)', () {
      controller.setPageSize(const Size(400, 800));
      
      controller.nextPage(
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );

      expect(controller.state, CurlState.animatingForward);
      expect(controller.direction, CurlDirection.forward);
    });

    test('previousPage triggers flipBackward in curl mode (no clients)', () {
      controller.jumpToPage(5);
      controller.setPageSize(const Size(400, 800));
      
      controller.previousPage(
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );

      expect(controller.state, CurlState.animatingForward);
      expect(controller.direction, CurlDirection.backward);
    });

    test('page getter returns double index when no clients exist', () {
      controller.jumpToPage(0);
      expect(controller.page, 0.0);

      controller.jumpToPage(9);
      expect(controller.page, 9.0);
    });

    // -----------------------------------------------------------------------
    // Regression test: PageView mode sync (initialPage override)
    // -----------------------------------------------------------------------

    test(
        'initialPage getter reflects _currentPage so PageView always starts '
        'at the correct page after curl flips', () {
      // Constructed with initialPage: 2.
      expect(controller.initialPage, 2,
          reason: 'Before any navigation, initialPage must equal '
              'the constructor argument.');

      // Simulate advancing pages via jumpToPage (as curl flips would do).
      controller.jumpToPage(7);
      expect(controller.initialPage, 7,
          reason: 'After advancing to page 7, initialPage must return 7 '
              'so that a newly attached PageView starts there, not at 0.');

      controller.jumpToPage(0);
      expect(controller.initialPage, 0,
          reason: 'After jumping back to page 0, initialPage must reflect '
              'the new position.');
    });
  });
}
