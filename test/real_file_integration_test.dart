// Cross-checks the svs package against real Aperio SVS files, not synthetic
// fixtures. These files are large (tens to hundreds of MB) and gitignored —
// see ../sample_data/ — so every test here skips gracefully when the file
// isn't present locally rather than failing.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:svs/src/render/ycbcr_fix.dart';
import 'package:svs/src/svs/aperio_tags.dart';
import 'package:svs/svs.dart';

String? _skipReasonUnless(String path) {
  return File(path).existsSync() ? null : 'sample file not present locally: $path';
}

void main() {
  const jpegSlide = 'sample_data/CMU-1.svs';
  const jp2kSlide = 'sample_data/CMU-1-JP2K-33005.svs';

  test('opens a real JPEG-compressed slide: levels, tiles, and metadata', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);

    expect(svs.levels, hasLength(3));
    expect(svs.levels[0].width, 46000);
    expect(svs.levels[0].height, 32914);
    expect(svs.levels[0].downsample, 1.0);
    expect(svs.levels[1].downsample, 4.0);
    expect(svs.levels[2].downsample, 16.0);

    expect(svs.metadata.appMag, 20);
    expect(svs.metadata.mppX, closeTo(0.4990, 1e-6));

    expect(svs.associatedImages.map((a) => a.kind), [
      AssociatedImageKind.thumbnail,
      AssociatedImageKind.label,
      AssociatedImageKind.macro,
    ]);

    final tile = await svs.readTileJpegBytes(0, 0, 0);
    expect(tile.length, greaterThan(0));
    expect(tile.take(2), [0xFF, 0xD8]); // standalone JPEG after splicing: starts with SOI

    // Thumbnail and macro are JPEG in this file; label is LZW. All three are
    // stored as many strips (see aperio_tags.dart RowsPerStrip), so the
    // per-strip splice/decode must succeed and the composited image must
    // come back at its *full* height, not just one strip's worth of rows.
    final thumbnailStrip0 = await svs.associatedImages[0].readStripJpegBytes(0);
    expect(thumbnailStrip0.take(2), [0xFF, 0xD8]);
    final macroStrip0 = await svs.associatedImages[2].readStripJpegBytes(0);
    expect(macroStrip0.take(2), [0xFF, 0xD8]);

    final thumbnailImage = await decodeAssociatedImage(svs.associatedImages[0]);
    addTearDown(thumbnailImage.dispose);
    expect(thumbnailImage.width, svs.associatedImages[0].width);
    expect(thumbnailImage.height, svs.associatedImages[0].height);

    final macroImage = await decodeAssociatedImage(svs.associatedImages[2]);
    addTearDown(macroImage.dispose);
    expect(macroImage.width, svs.associatedImages[2].width);
    expect(macroImage.height, svs.associatedImages[2].height);
  }, skip: _skipReasonUnless(jpegSlide));

  test('decodes the LZW-compressed label to pixel-exact RGB against an independent oracle', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);

    final label = svs.associatedImages[1];
    expect(label.kind, AssociatedImageKind.label);
    expect(label.isDecodable, isTrue); // Compression=5 (LZW), Predictor=2, 8-bit RGB

    final image = await decodeAssociatedImage(label);
    addTearDown(image.dispose);
    expect(image.width, label.width);
    expect(image.height, label.height);

    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    Color at(int x, int y) {
      final i = (y * label.width + x) * 4;
      return (r: bytes!.getUint8(i), g: bytes.getUint8(i + 1), b: bytes.getUint8(i + 2));
    }

    // Ground truth from Pillow (an independent, mature TIFF/LZW decoder),
    // deliberately including points straddling strip boundaries
    // (RowsPerStrip=7 for this IFD) where a predictor or strip-decode bug
    // would show up first.
    expect(at(0, 0), (r: 0, g: 0, b: 0));
    expect(at(386, 0), (r: 2, g: 2, b: 2));
    expect(at(0, 462), (r: 0, g: 0, b: 0));
    expect(at(386, 462), (r: 0, g: 0, b: 1));
    expect(at(193, 231), (r: 254, g: 168, b: 72));
    expect(at(50, 6), (r: 0, g: 0, b: 4));
    expect(at(50, 7), (r: 1, g: 0, b: 1));
    expect(at(120, 13), (r: 0, g: 0, b: 2));
    expect(at(120, 14), (r: 0, g: 0, b: 0));
    expect(at(100, 100), (r: 190, g: 136, b: 64));
    expect(at(200, 300), (r: 19, g: 16, b: 13));
    expect(at(300, 50), (r: 246, g: 242, b: 255));
    expect(at(10, 455), (r: 0, g: 0, b: 0));
    expect(at(150, 400), (r: 176, g: 122, b: 56));
  }, skip: _skipReasonUnless(jpegSlide));

  test('decodes the JPEG thumbnail to correct RGB, undoing Aperio\'s spurious YCbCr transform', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);

    final thumbnail = svs.associatedImages[0];
    expect(thumbnail.kind, AssociatedImageKind.thumbnail);
    expect(thumbnail.isJpeg, isTrue);
    // This IFD declares PhotometricInterpretation=RGB, meaning the JPEG
    // stream holds literal RGB samples with no YCbCr transform applied at
    // encode time — but `dart:ui`'s decoder has no visibility into that
    // TIFF-level tag and always assumes YCbCr, so its raw output needs the
    // fix undone before it matches the true colors.
    expect(thumbnail.photometricInterpretation, ApPhotometric.rgb);

    final image = await decodeAssociatedImage(thumbnail);
    addTearDown(image.dispose);
    expect(image.width, thumbnail.width);
    expect(image.height, thumbnail.height);

    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    Color at(int x, int y) {
      final i = (y * thumbnail.width + x) * 4;
      return (r: bytes!.getUint8(i), g: bytes.getUint8(i + 1), b: bytes.getUint8(i + 2));
    }

    // Ground truth from Pillow (decode strips as `dart:ui` does, then apply
    // the same inverse RGB->YCbCr fix) — background points plus a couple
    // inside the tissue (which should read as pink/purple H&E staining, not
    // the raw decoder's magenta/green), including points straddling a strip
    // boundary (RowsPerStrip=16 for this IFD).
    expect(at(0, 0), (r: 176, g: 172, b: 184));
    expect(at(1023, 0), (r: 178, g: 172, b: 183));
    expect(at(0, 731), (r: 176, g: 172, b: 184));
    expect(at(1023, 731), (r: 176, g: 172, b: 184));
    expect(at(50, 15), (r: 176, g: 172, b: 184));
    expect(at(50, 16), (r: 176, g: 172, b: 184));
    expect(at(200, 31), (r: 178, g: 172, b: 183));
    expect(at(200, 32), (r: 176, g: 173, b: 185));
    expect(at(150, 550), (r: 182, g: 136, b: 166));
    expect(at(700, 150), (r: 184, g: 141, b: 165));
    expect(at(900, 150), (r: 168, g: 129, b: 167));
  }, skip: _skipReasonUnless(jpegSlide));

  test('pyramid JPEG tiles also need the spurious-YCbCr fix, not just associated images', () async {
    final svs = await SvsFile.open(jpegSlide);
    addTearDown(svs.close);

    final level = svs.levels[1];
    expect(level.isJpeg, isTrue);
    // Same TIFF-level signal as the thumbnail/macro associated images
    // (PhotometricInterpretation=RGB) — Aperio writes the main pyramid's
    // JPEG tiles the same way, so `dart:ui`'s decoder needs the same
    // post-decode correction here too.
    expect(level.photometricInterpretation, ApPhotometric.rgb);
    expect(level.needsYCbCrFix, isTrue);

    final jpegBytes = await svs.readTileJpegBytes(level.index, 0, 0);
    final codec = await ui.instantiateImageCodec(jpegBytes);
    final frame = await codec.getNextFrame();
    addTearDown(frame.image.dispose);
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final raw = data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    // Before the fix: white background decoded as bright magenta.
    expect(raw[0], 255);
    expect(raw[1], closeTo(120, 2));
    expect(raw[2], 255);

    final fixed = Uint8List.fromList(raw);
    undoSpuriousYCbCr(fixed);
    // After the fix: the same light-gray background as the thumbnail's
    // corners (see the test above) — this tile and the thumbnail depict
    // overlapping background, so they should land on the same true color.
    expect(fixed[0], closeTo(176, 2));
    expect(fixed[1], closeTo(172, 2));
    expect(fixed[2], closeTo(184, 2));
  }, skip: _skipReasonUnless(jpegSlide));

  test('opens a real JPEG2000-compressed slide and decodes a tile via openjpeg_ffi', () async {
    final svs = await SvsFile.open(jp2kSlide);
    addTearDown(svs.close);

    // Real Aperio JP2K files (unlike the JPEG file above) put the pyramid
    // levels at IFD 0/2/3, with the thumbnail/label/macro interleaved at
    // IFD 1/4/5 — same associated-image compressions as every other file.
    expect(svs.levels, hasLength(3));
    expect(svs.levels[0].isJp2k, isTrue);
    expect(svs.levels[0].width, 46000);
    expect(svs.levels[0].height, 32893);

    final rgba = await svs.readTileRgba(0, 0, 0);
    expect(rgba.length, 240 * 240 * 4); // openjpeg_ffi's own suite already
    // proves decode correctness pixel-exact against Pillow on this exact
    // tile (see openjpeg_ffi/test/fixtures) — this just proves the *svs*
    // integration (real TileOffsets/TileByteCounts lookup through to a
    // usable RGBA buffer) works end-to-end against the real 132MB file.
    Color at(int x, int y) {
      final i = (y * 240 + x) * 4;
      return (r: rgba[i], g: rgba[i + 1], b: rgba[i + 2]);
    }

    expect(at(0, 0), (r: 239, g: 239, b: 239));
    expect(at(239, 239), (r: 243, g: 243, b: 243));
    expect(at(120, 120), (r: 243, g: 243, b: 243));
    expect(at(10, 10), (r: 239, g: 239, b: 239));
  }, skip: _skipReasonUnless(jp2kSlide));
}

typedef Color = ({int r, int g, int b});
