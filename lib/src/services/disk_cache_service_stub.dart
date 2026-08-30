import 'package:svs/svs.dart';

/// No filesystem on this platform (e.g. the web) — no persistent tile
/// cache. `SvsImageView`'s in-memory `TileCache` still applies.
Future<DiskTileCache?> openDiskCacheFor(SvsFile svs) async => null;
