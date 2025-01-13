/// Exception that throws in case when inconsistent page data detected.
/// Usually it means that data on the server was changed and we need to reload
/// all items from the first page.
class InconsistentPageDataException implements Exception {
  /// Creates [InconsistentPageDataException].
  const InconsistentPageDataException([this.message]);

  final String? message;

  /// String representation to print in log
  @override
  String toString() =>
      'InconsistentPageDataException${message != null ? ': $message' : ''}';
}
