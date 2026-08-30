// exportSvsRegionAsSvsToFile/exportSvsRegionAsSvsPreservingLevelsToFile only
// exist in svs's own dart:io conditional-export branch (they return
// dart:io's File) — the analyzer resolves conditional exports to their
// default/stub branch absent a specific compile target, so it doesn't see
// these symbols even though they're genuinely present (and this file is
// only ever selected for native builds itself, via this same file's own
// conditional export — see svs_pyramid_builder.dart).
// ignore_for_file: undefined_function

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:svs/svs.dart';

import 'svs_pyramid_builder.dart';

/// Builds a `.svs` pyramid by streaming straight to a temp file — memory-
/// bounded even for a very large crop, unlike holding the whole result in
/// RAM (see the byte-based web implementation of this same function).
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
  final tempDir = await getTemporaryDirectory();
  final tempPath =
      '${tempDir.path}/${tempFileBaseName}_${DateTime.now().millisecondsSinceEpoch}.svs';
  final file = await (preserveSourceLevels
      ? exportSvsRegionAsSvsPreservingLevelsToFile(
          svs,
          path: tempPath,
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
      : exportSvsRegionAsSvsToFile(
          svs,
          path: tempPath,
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
  return _TempFilePyramid(file);
}

class _TempFilePyramid implements BuiltSvsPyramid {
  final File file;
  _TempFilePyramid(this.file);

  @override
  Future<SvsFile> open() => SvsFile.open(file.path);

  @override
  Future<Uint8List> readBytes() => file.readAsBytes();

  @override
  Future<void> dispose() async {
    try {
      await file.delete();
    } catch (_) {
      // Best-effort cleanup of a temp file; not user-visible either way.
    }
  }
}
