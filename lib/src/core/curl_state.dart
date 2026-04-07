/// Represents the current state of the page curl animation lifecycle.
///
/// The state machine follows this flow:
/// ```
/// idle → dragging → animatingForward/animatingBackward → completed → idle
/// ```
///
/// - [idle]: No curl interaction is active. The page is displayed flat.
/// - [dragging]: The user is actively dragging to curl the page.
/// - [animatingForward]: The curl animation is completing a forward page flip.
/// - [animatingBackward]: The curl animation is snapping back (cancelling flip).
/// - [completed]: The flip animation has finished. Transitions back to [idle]
///   after the page index is updated.
enum CurlState {
  /// No curl interaction is active. The page is displayed flat.
  idle,

  /// The user is actively dragging to curl the page.
  dragging,

  /// The curl animation is completing a forward page flip.
  animatingForward,

  /// The curl animation is snapping back (cancelling the flip).
  animatingBackward,

  /// The flip animation has finished and the page index will be updated.
  completed,
}
