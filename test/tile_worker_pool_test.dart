// Cross-checks `TileWorkerPool` (background-isolate tile fetching) against
// real Aperio SVS files — see real_file_integration_test.dart's header for
// why these skip gracefully when the file isn't present locally.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:svs/src/io/tile_worker_pool.dart';
import 'package:svs/svs.dart';

String? _skipReasonUnless(String path) {
  return File(path).existsSync() ? null : 'sample file not present locally: $path';
}

void main() {
  const jpegSlide = 'sample_data/CMU-1.svs';
  const jp2kSlide = 'sample_data/CMU-1-JP2K-33005.svs';

  test('fetches JPEG tiles across two levels, matching the direct (main-isolate) read byte-for-byte', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);
    final pool = await TileWorkerPool.spawn(svs.path!);
    addTearDown(pool.dispose);

    // One tile from level 0 and one from level 1, requested concurrently —
    // exercises both the splice-on-a-worker path and the two-level lookup,
    // not just a single easy case.
    final results = await Future.wait([
      pool.requestTile(level: 0, tileX: 0, tileY: 0).result,
      pool.requestTile(level: 1, tileX: 2, tileY: 3).result,
    ]);

    final expected0 = await svs.readTileJpegBytes(0, 0, 0);
    final expected1 = await svs.readTileJpegBytes(1, 2, 3);

    expect(results[0].isRgba, isFalse);
    expect(results[0].bytes, expected0);
    expect(results[1].isRgba, isFalse);
    expect(results[1].bytes, expected1);
  }, skip: _skipReasonUnless(jpegSlide));

  test('fetches and decodes a JPEG2000 tile on the worker, matching the direct openjpeg_ffi decode', () async {
    final svs = await SvsFile.open(jp2kSlide);
    addTearDown(svs.close);
    final pool = await TileWorkerPool.spawn(svs.path!);
    addTearDown(pool.dispose);

    final result = await pool.requestTile(level: 0, tileX: 0, tileY: 0).result;
    final expected = await svs.readTileRgba(0, 0, 0);

    expect(result.isRgba, isTrue);
    expect(result.bytes, expected);
  }, skip: _skipReasonUnless(jp2kSlide));

  test('a batch of concurrent requests across both workers all resolve correctly', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);
    final pool = await TileWorkerPool.spawn(svs.path!);
    addTearDown(pool.dispose);

    final level = svs.levels[1]; // smaller level, faster to fetch a wide batch from
    final requests = <({int tx, int ty, TileRequestHandle handle})>[];
    for (var ty = 0; ty < 4; ty++) {
      for (var tx = 0; tx < 4; tx++) {
        final priority = (tx + ty).isEven ? TilePriority.visible : TilePriority.prefetch;
        requests.add((tx: tx, ty: ty, handle: pool.requestTile(level: level.index, tileX: tx, tileY: ty, priority: priority)));
      }
    }

    for (final request in requests) {
      final expected = await svs.readTileJpegBytes(level.index, request.tx, request.ty);
      final result = await request.handle.result;
      expect(result.bytes, expected, reason: 'tile (${request.tx},${request.ty})');
    }
  }, skip: _skipReasonUnless(jpegSlide));

  test('cancel() rejects the pending result immediately instead of letting it hang', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);
    final pool = await TileWorkerPool.spawn(svs.path!);
    addTearDown(pool.dispose);

    // Queue several requests behind each other on the same (single-worker)
    // priority lane, then cancel one that hasn't started yet — its result
    // should reject right away, not quietly complete later with a decoded
    // tile the caller no longer wants (or hang forever).
    final level = svs.levels[0];
    final blockers = [
      pool.requestTile(level: level.index, tileX: 0, tileY: 0),
      pool.requestTile(level: level.index, tileX: 1, tileY: 0),
      pool.requestTile(level: level.index, tileX: 2, tileY: 0),
    ];
    final toCancel = pool.requestTile(level: level.index, tileX: 3, tileY: 0);
    pool.cancel(toCancel.requestId);

    await expectLater(toCancel.result, throwsA(isA<TileRequestCancelledException>()));
    await Future.wait(blockers.map((h) => h.result));
  }, skip: _skipReasonUnless(jpegSlide));

  test('spawn() fails clearly for a path that does not exist', () async {
    await expectLater(TileWorkerPool.spawn('sample_data/does-not-exist.svs'), throwsA(isA<SvsFormatException>()));
  });
}
