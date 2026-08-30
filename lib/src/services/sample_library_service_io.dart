import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sample_slide.dart';
import 'sample_library_service.dart';

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

  Future<File> _localFile(SampleSlide slide) async {
    final dir = await _samplesDir();
    return File(p.join(dir.path, slide.fileName));
  }

  /// The path [slide] would be (or already is) cached at locally.
  Future<String> localFilePath(SampleSlide slide) async => (await _localFile(slide)).path;

  Future<bool> isDownloaded(SampleSlide slide) async {
    final file = await _localFile(slide);
    return file.existsSync() && file.lengthSync() > 0;
  }

  /// Downloads [slide], emitting a [DownloadProgress] as each chunk of the
  /// response body arrives.
  ///
  /// Writes to a `.part` file first and renames it on success, so a
  /// cancelled or failed download never leaves behind a file that looks
  /// complete. Cancelling the subscription (`StreamSubscription.cancel()`)
  /// aborts the underlying HTTP request and deletes the partial file — the
  /// standard way to cancel any Dart [Stream] doubles as this download's
  /// cancel button.
  Stream<DownloadProgress> download(SampleSlide slide) {
    http.Client? client;
    StreamSubscription<List<int>>? subscription;
    IOSink? sink;
    File? partFile;
    // Only ever flipped from within onCancel, which — like onListen — is a
    // callback the event loop runs to completion without interleaving, so
    // checking this right after each `await` below is race-free: a cancel
    // can't sneak in between the check and the synchronous work that
    // follows it.
    var cancelled = false;
    late final StreamController<DownloadProgress> controller;

    Future<void> cleanUpPartial() async {
      await sink?.close();
      final pf = partFile;
      if (pf != null && pf.existsSync()) {
        try {
          pf.deleteSync();
        } catch (_) {
          // Best-effort cleanup; a leftover .part file is never mistaken for
          // a complete download (isDownloaded only looks at the final path).
        }
      }
    }

    controller = StreamController<DownloadProgress>(
      onListen: () async {
        try {
          final file = await _localFile(slide);
          if (cancelled) return;
          partFile = File('${file.path}.part');
          client = http.Client();
          final response = await client!.send(http.Request('GET', slide.url));
          if (cancelled) {
            client!.close();
            return;
          }
          if (response.statusCode != 200) {
            throw HttpException('Download failed (status ${response.statusCode})', uri: slide.url);
          }
          final total = response.contentLength ?? (slide.approxSizeBytes > 0 ? slide.approxSizeBytes : null);
          var received = 0;
          sink = partFile!.openWrite();
          subscription = response.stream.listen(
            (chunk) {
              sink!.add(chunk);
              received += chunk.length;
              controller.add(DownloadProgress(received: received, total: total));
            },
            onDone: () async {
              await sink!.close();
              await partFile!.rename(file.path);
              await controller.close();
            },
            onError: (Object e, StackTrace st) async {
              await sink?.close();
              controller.addError(e, st);
              await controller.close();
            },
            cancelOnError: true,
          );
        } catch (e, st) {
          controller.addError(e, st);
          await controller.close();
        }
      },
      onCancel: () async {
        cancelled = true;
        await subscription?.cancel();
        client?.close();
        await cleanUpPartial();
      },
    );
    return controller.stream;
  }

  Future<void> delete(SampleSlide slide) async {
    final file = await _localFile(slide);
    if (file.existsSync()) file.deleteSync();
  }
}
