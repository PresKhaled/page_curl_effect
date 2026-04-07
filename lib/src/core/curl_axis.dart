/// The allowed axis for page curl drag movement.
///
/// Controls whether the user can curl pages horizontally (left/right),
/// vertically (up/down), or in any direction.
enum CurlAxis {
  /// Only horizontal curl is allowed.
  ///
  /// The touch point's Y-coordinate is locked to the corner origin's Y,
  /// producing a purely horizontal page flip.
  horizontal,

  /// Only vertical curl is allowed.
  ///
  /// The touch point's X-coordinate is locked to the corner origin's X,
  /// producing a purely vertical page flip.
  vertical,

  /// Both horizontal and vertical curl are allowed.
  ///
  /// The user can drag in any direction, allowing diagonal curls.
  both,
}
