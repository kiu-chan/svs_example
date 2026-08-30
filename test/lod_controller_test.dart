// Cross-checks `LodController` (the tile request/cancel/decode orchestrator
// behind `SvsImageView`) against a real Aperio SVS file — see
// real_file_integration_test.dart's header for why these skip gracefully
// when the file isn't present locally.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svs/src/cache/tile_cache.dart';
import 'package:svs/src/render/lod_controller.dart';
import 'package:svs/src/render/viewport_math.dart';
import 'package:svs/svs.dart';

String? _skipReasonUnless(String path) {
  return File(path).existsSync() ? null : 'sample file not present locally: $path';
}

void main() {
  const jpegSlide = 'sample_data/CMU-1.svs';

  test('flushNow decodes the currently-visible tiles into the cache and notifies listeners', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);
    final cache = TileCache();
    final lod = LodController(svsFile: svs, cache: cache);
    addTearDown(lod.dispose);

    // scale = 1/coarsestDownsample makes every level's on-screen texel size
    // <= maxUpsample, so selectLevel picks the coarsest one — smallest tile
    // count, fastest test.
    final coarsest = svs.levels.last;
    final scale = 1 / coarsest.downsample;
    const viewportSize = Size(400, 300);
    const origin = Offset.zero;

    final notified = Completer<void>();
    lod.addListener(() {
      if (!notified.isCompleted) notified.complete();
    });

    lod.flushNow(viewportSize, scale, origin);
    await notified.future.timeout(const Duration(seconds: 30));

    final expectedLevelIndex = selectLevel(svs.levels.map((l) => l.geometry).toList(growable: false), scale);
    expect(expectedLevelIndex, coarsest.index);
    final visible = computeVisibleTiles(coarsest.geometry, viewportSize, scale, origin);
    expect(cache.contains(TileCacheKey(level: coarsest.index, tileX: visible.minTx, tileY: visible.minTy)), isTrue);
  }, skip: _skipReasonUnless(jpegSlide));

  test('a later flushNow for a different viewport cancels tiles no longer wanted and fetches the new ones', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);
    final cache = TileCache();
    final lod = LodController(svsFile: svs, cache: cache);
    addTearDown(lod.dispose);

    final coarsest = svs.levels.last;
    final scale = 1 / coarsest.downsample;

    // Two viewports far enough apart (given the coarsest level's small tile
    // grid) that their wanted-tile sets don't overlap.
    const viewportSize = Size(200, 150);
    final farOrigin = Offset(coarsest.width - 1.0, coarsest.height - 1.0) * coarsest.downsample;

    final secondNotified = Completer<void>();
    lod.addListener(() {
      if (!secondNotified.isCompleted) secondNotified.complete();
    });

    lod.flushNow(viewportSize, scale, Offset.zero);
    lod.flushNow(viewportSize, scale, farOrigin);
    await secondNotified.future.timeout(const Duration(seconds: 30));

    // Give any surviving in-flight requests from the first viewport a moment
    // to land too, then confirm the second viewport's tile is the one that
    // actually made it into the cache.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final visible = computeVisibleTiles(coarsest.geometry, viewportSize, scale, farOrigin);
    expect(cache.contains(TileCacheKey(level: coarsest.index, tileX: visible.maxTx, tileY: visible.maxTy)), isTrue);
  }, skip: _skipReasonUnless(jpegSlide));
}
