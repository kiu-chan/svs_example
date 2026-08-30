import 'dart:typed_data';

import 'package:svs/svs.dart';

export 'svs_pyramid_builder_stub.dart'
    if (dart.library.io) 'svs_pyramid_builder_io.dart';

/// A freshly re-encoded `.svs` pyramid, built by `buildSvsPyramidExport` —
/// either backed by a native temp file (streamed, memory-bounded) or an
/// in-memory buffer (the web, which has no filesystem to stream through).
abstract class BuiltSvsPyramid {
  /// Opens this pyramid as its own [SvsFile], independent of the source
  /// file it was cropped from.
  Future<SvsFile> open();

  /// The pyramid's raw bytes, e.g. to hand to a save-file dialog.
  Future<Uint8List> readBytes();

  /// Releases any underlying resource (a temp file on native; a no-op on
  /// the web, where the bytes are just an in-memory buffer).
  Future<void> dispose();
}
