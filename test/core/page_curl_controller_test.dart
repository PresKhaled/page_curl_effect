// ignore_for_file: unnecessary_import
// The `scheduler.dart` import provides [Ticker] and [TickerCallback] which are
// needed by [MockTickerProvider] even though they are also re-exported by
// `widgets.dart`. The explicit import makes the dependency intent clear.
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_curl_effect/page_curl_effect.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Minimal [TickerProvider] for use outside a widget tree.
///
/// [AnimationController] requires a [TickerProvider] to drive its internal
/// [Ticker]. In unit tests there is no widget tree or [State], so we provide
/// this lightweight stand-in. Each call to [createTicker] returns a new
/// [Ticker] that the [AnimationController] owns and disposes.
class MockTickerProvider implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  // Initialise the Flutter binding before any test runs.
  //
  // [AnimationController] accesses [SemanticsBinding.instance] (via the
  // scheduler) at construction time. Without this call the test suite fails
  // with "Binding has not yet been initialized."
  TestWidgetsFlutterBinding.ensureInitialized();

  late PageCurlController controller;
  late TickerProvider vsync;

  // Tracks the last page reported by [PageCurlController.onPageChanged].
  int? lastNotifiedPage;

  setUp(() {
    vsync = MockTickerProvider();
    lastNotifiedPage = null;

    // Construct a controller starting at page 2 out of 10.
    // Using a non-zero initial page lets us verify that the constructor
    // argument is correctly propagated rather than silently defaulting to 0.
    controller = PageCurlController(
      vsync: vsync,
      itemCount: 10,
      config: const PageCurlConfig(),
      initialPage: 2,
      onPageChanged: (page) => lastNotifiedPage = page,
    );
  });

  group('PageCurlController (Inheritance & Navigation)', () {
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    test('Initial page index is correctly set from constructor', () {
      // Both the internal integer tracker and the PageController-compatible
      // double getter must reflect the constructor argument.
      expect(controller.currentPage, 2);
      expect(controller.page, 2.0);
    });

    // -----------------------------------------------------------------------
    // jumpToPage
    // -----------------------------------------------------------------------

    test('jumpToPage updates index and notifies listeners', () {
      controller.jumpToPage(5);

      // Internal integer index must advance.
      expect(controller.currentPage, 5);
      // The onPageChanged callback must have fired with the new page.
      expect(lastNotifiedPage, 5);
      // The PageController-compatible getter must agree.
      expect(controller.page, 5.0);
    });

    // -----------------------------------------------------------------------
    // nextPage / previousPage — curl mode routing
    // -----------------------------------------------------------------------

    test('nextPage triggers flipForward in curl mode (no clients)', () {
      // setPageSize is required before any flip; without a known page size
      // flipForward has no geometry to work with and is a no-op.
      controller.setPageSize(const Size(400, 800));

      // No PageView is attached, so nextPage must route to flipForward() and
      // the state machine must enter animatingForward immediately.
      controller.nextPage(
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );

      expect(controller.state, CurlState.animatingForward);
      expect(controller.direction, CurlDirection.forward);
    });

    test('previousPage triggers flipBackward in curl mode (no clients)', () {
      // Start at page 5 so that flipping backward is allowed.
      controller.jumpToPage(5);
      controller.setPageSize(const Size(400, 800));

      controller.previousPage(
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );

      // The curl state machine must record the backward direction.
      expect(controller.state, CurlState.animatingForward);
      expect(controller.direction, CurlDirection.backward);
    });

    // -----------------------------------------------------------------------
    // page getter — curl mode (no scroll clients)
    // -----------------------------------------------------------------------

    test('page getter returns double index when no clients exist', () {
      controller.jumpToPage(0);
      expect(controller.page, 0.0);

      controller.jumpToPage(9);
      expect(controller.page, 9.0);
    });

    // -----------------------------------------------------------------------
    // Regression: initialPage override (PageView sync fix)
    // -----------------------------------------------------------------------

    test(
        'initialPage getter reflects _currentPage so PageView always starts '
        'at the correct page after curl flips', () {
      // ── Before any navigation ──────────────────────────────────────────
      // The override must return the constructor argument, not a hard-coded 0.
      expect(controller.initialPage, 2,
          reason: 'Before any navigation, initialPage must equal '
              'the constructor argument.');

      // ── After advancing via jumpToPage ─────────────────────────────────
      // Flutter reads this.initialPage inside _PagePosition.applyContentDimensions
      // to compute the starting scroll offset. Without this override a PageView
      // that attaches after page flips would always render page 0.
      controller.jumpToPage(7);
      expect(controller.initialPage, 7,
          reason: 'After advancing to page 7, initialPage must return 7 '
              'so that a newly attached PageView starts there, not at 0.');

      // ── After jumping back ─────────────────────────────────────────────
      controller.jumpToPage(0);
      expect(controller.initialPage, 0,
          reason: 'After jumping back to page 0, initialPage must reflect '
              'the new position.');
    });
  });
}
