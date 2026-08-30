export 'sample_library_service_stub.dart'
    if (dart.library.io) 'sample_library_service_io.dart';

/// A snapshot of an in-flight download: bytes received so far, and the
/// total if known (from the response's `Content-Length`, or the slide's
/// own size estimate as a fallback).
class DownloadProgress {
  final int received;
  final int? total;

  const DownloadProgress({required this.received, this.total});

  /// `received / total` in `[0, 1]`, or null if [total] isn't known —
  /// callers typically pass that straight to an indeterminate progress bar.
  double? get fraction => (total != null && total! > 0) ? received / total! : null;
}
