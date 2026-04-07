/// The direction in which a page curl/flip is occurring.
///
/// - [forward]: Flipping to the next page (right-to-left in LTR layouts).
/// - [backward]: Flipping to the previous page (left-to-right in LTR layouts).
enum CurlDirection {
  /// Flipping to the next page (right-to-left in LTR layouts).
  forward,

  /// Flipping to the previous page (left-to-right in LTR layouts).
  backward,
}
