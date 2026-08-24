import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sample_slide.dart';

/// Downloads and caches [SampleSlide] files under the app's support
/// directory, so the sample gallery survives restarts without touching
/// user-visible documents.
class SampleLibraryService {
  Directory? _dir;

  Future<Directory> _samplesDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'sample_slides'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<File> localFile(SampleSlide slide) async {
    final dir = await _samplesDir();
    return File(p.join(dir.path, slide.fileName));
  }

  Future<bool> isDownloaded(SampleSlide slide) async {
    final file = await localFile(slide);
    return file.existsSync() && file.lengthSync() > 0;
  }

  /// Downloads [slide], yielding progress in `[0, 1]` as bytes arrive.
  ///
  /// Writes to a `.part` file first and renames on success, so a
  /// cancelled or failed download never leaves behind a file that looks
  /// complete.
  Stream<double> download(SampleSlide slide) async* {
    final file = await localFile(slide);
    final partFile = File('${file.path}.part');
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', slide.url));
      if (response.statusCode != 200) {
        throw HttpException('Download failed (status ${response.statusCode})', uri: slide.url);
      }
      final total = response.contentLength ?? slide.approxSizeBytes;
      var received = 0;
      final sink = partFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          yield total > 0 ? received / total : 0;
        }
      } finally {
        await sink.close();
      }
      await partFile.rename(file.path);
      yield 1;
    } finally {
      client.close();
    }
  }

  Future<void> delete(SampleSlide slide) async {
    final file = await localFile(slide);
    if (file.existsSync()) file.deleteSync();
  }
}
