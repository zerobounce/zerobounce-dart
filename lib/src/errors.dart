/// The one error type the SDK throws.
///
/// [statusCode] is the HTTP status of the response the error came from,
/// including the HTTP 200 answers that are still failures (an invalid key, a
/// `"success": false` body, a body of the wrong shape). It is `0` for errors
/// raised before or without a response: a bad argument, a refused base URL, a
/// transport failure or a timeout.
///
/// The message is short and never carries the API key: it is redacted where
/// the error is built, in every encoding the SDK can produce or a server can
/// echo.
class ZBException implements Exception {
  /// Creates an error with a [message] and an HTTP [statusCode] (`0` when there
  /// was no response).
  const ZBException(this.message, [this.statusCode = 0]);

  /// What went wrong, already redacted.
  final String message;

  /// The HTTP status of the response, or `0` when there was none.
  final int statusCode;

  @override
  String toString() => 'ZBException(statusCode: $statusCode): $message';
}
