import '../models/sample_slide.dart';
import 'sample_library_service.dart';

/// No filesystem on this platform (e.g. the web) — the sample library isn't
/// offered there at all (see `home_screen.dart`, which never navigates to
/// `SampleLibraryScreen` when `kIsWeb`), so every method here is
/// unreachable in practice. They still need to exist, with matching
/// signatures, so this file — transitively imported from `home_screen.dart`
/// on every platform — compiles for the web at all.
class SampleLibraryService {
  static Never _unsupported() => throw UnsupportedError(
    'The sample library requires a filesystem and is not available on the web.',
  );

  Future<String> localFilePath(SampleSlide slide) async => _unsupported();

  Future<bool> isDownloaded(SampleSlide slide) async => _unsupported();

  Stream<DownloadProgress> download(SampleSlide slide) => _unsupported();

  Future<void> delete(SampleSlide slide) async => _unsupported();
}
