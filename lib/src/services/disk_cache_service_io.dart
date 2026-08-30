import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:svs/svs.dart';

/// Opens a persistent on-disk tile cache for [svs], scoped to its own path
/// (per `DiskTileCache`'s requirement that different slides not share a
/// directory — their tile keys would collide). Returns null (no persistent
/// cache, `SvsImageView`'s in-memory `TileCache` still applies) if [svs] has
/// no path (opened via `SvsFile.openBytes` — no stable identity to scope a
/// cache directory to) or if opening the cache fails for any other reason;
/// this is a speed optimization only, never required for correctness.
Future<DiskTileCache?> openDiskCacheFor(SvsFile svs) async {
  final path = svs.path;
  if (path == null) return null;
  try {
    final cacheRoot = await getApplicationCacheDirectory();
    final dir = Directory('${cacheRoot.path}/svs_tiles/${path.hashCode}');
    return await DiskTileCache.open(dir);
  } catch (_) {
    return null;
  }
}
