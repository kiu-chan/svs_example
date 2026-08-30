import 'dart:typed_data';

import 'package:svs/svs.dart';

import 'svs_pyramid_builder.dart';

/// Builds a `.svs` pyramid entirely in memory — there's no filesystem to
/// stream through on this platform (e.g. the web), so the whole result is
/// held as a single [Uint8List] (same as `exportSvsRegionAsSvs`/
/// `exportSvsRegionAsSvsPreservingLevels` already do internally).
Future<BuiltSvsPyramid> buildSvsPyramidExport(
  SvsFile svs, {
  required bool preserveSourceLevels,
  required int level,
  required int x,
  required int y,
  required int width,
  required int height,
  required int? tileSize,
  required int quality,
  required SvsExportCompression compression,
  required double jp2kCompressionRatio,
  required bool matchSourceCompression,
  required bool includeLabelAndMacroImages,
  required bool includeSourceMetadata,
  required SvsImageAdjustments adjustments,
  required String tempFileBaseName,
  required void Function(double progress)? onProgress,
}) async {
  final bytes = await (preserveSourceLevels
      ? exportSvsRegionAsSvsPreservingLevels(
          svs,
          level: level,
          x: x,
          y: y,
          width: width,
          height: height,
          quality: quality,
          tileSize: tileSize,
          includeLabelAndMacroImages: includeLabelAndMacroImages,
          includeSourceMetadata: includeSourceMetadata,
          compression: compression,
          jp2kCompressionRatio: jp2kCompressionRatio,
          matchSourceCompression: matchSourceCompression,
          adjustments: adjustments,
          onProgress: onProgress,
        )
      : exportSvsRegionAsSvs(
          svs,
          level: level,
          x: x,
          y: y,
          width: width,
          height: height,
          quality: quality,
          tileSize: tileSize,
          includeLabelAndMacroImages: includeLabelAndMacroImages,
          includeSourceMetadata: includeSourceMetadata,
          compression: compression,
          jp2kCompressionRatio: jp2kCompressionRatio,
          matchSourceCompression: matchSourceCompression,
          adjustments: adjustments,
          onProgress: onProgress,
        ));
  return _BytesPyramid(bytes);
}

class _BytesPyramid implements BuiltSvsPyramid {
  final Uint8List bytes;
  _BytesPyramid(this.bytes);

  @override
  Future<SvsFile> open() => SvsFile.openBytes(bytes);

  @override
  Future<Uint8List> readBytes() async => bytes;

  @override
  Future<void> dispose() async {}
}
