import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

extension SvsImageFormatInfo on SvsImageFormat {
  String get label => switch (this) {
    SvsImageFormat.png => 'PNG',
    SvsImageFormat.jpeg => 'JPEG',
    SvsImageFormat.bmp => 'BMP',
    SvsImageFormat.tiff => 'TIFF',
    SvsImageFormat.webp => 'WebP',
  };

  String get extension => switch (this) {
    SvsImageFormat.png => 'png',
    SvsImageFormat.jpeg => 'jpg',
    SvsImageFormat.bmp => 'bmp',
    SvsImageFormat.tiff => 'tiff',
    SvsImageFormat.webp => 'webp',
  };

  String get mimeType => switch (this) {
    SvsImageFormat.png => 'image/png',
    SvsImageFormat.jpeg => 'image/jpeg',
    SvsImageFormat.bmp => 'image/bmp',
    SvsImageFormat.tiff => 'image/tiff',
    SvsImageFormat.webp => 'image/webp',
  };
}

/// Opens a save-file dialog for [bytes], named `<suggestedName>.<ext>`, and
/// reports the outcome via a [SnackBar].
Future<void> saveExportedBytes(
  BuildContext context, {
  required Uint8List bytes,
  required String suggestedName,
  required SvsImageFormat format,
}) {
  return saveRawBytes(
    context,
    bytes: bytes,
    fileName: '$suggestedName.${format.extension}',
    mimeType: format.mimeType,
    dialogTitle: 'Save exported image',
  );
}

/// Same as [saveExportedBytes], but for a newly re-encoded `.svs` pyramid
/// (from `exportSvsRegionAsSvs`) rather than one of [SvsImageFormat]'s flat
/// raster formats.
Future<void> saveSvsFileBytes(
  BuildContext context, {
  required Uint8List bytes,
  required String suggestedName,
}) {
  return saveRawBytes(
    context,
    bytes: bytes,
    fileName: '$suggestedName.svs',
    mimeType: 'application/octet-stream',
    dialogTitle: 'Save exported slide',
  );
}

Future<void> saveRawBytes(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required String dialogTitle,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final Uri? savedUri;
  try {
    savedUri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      dialogTitle: dialogTitle,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    return;
  }
  if (savedUri == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Save cancelled')));
    return;
  }
  final display = savedUri.scheme == 'file' ? savedUri.toFilePath() : savedUri.toString();
  messenger.showSnackBar(SnackBar(content: Text('Saved: $display')));
}

/// Runs [task] behind a modal, non-dismissible progress dialog titled
/// [title] — wired up to the `svs` package's `onProgress: (double) => ...`
/// export parameter, so [task] should forward the callback it's given
/// straight through to whichever `export*`/`readSvsRegion` call it wraps.
/// The dialog closes once [task] completes, whether it throws or not, and
/// [task]'s result/error is returned/rethrown to the caller.
Future<T> runWithExportProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(void Function(double progress) onProgress) task,
}) async {
  final progress = ValueNotifier<double>(0);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExportProgressDialog(title: title, progress: progress),
    ),
  );
  try {
    return await task((value) => progress.value = value);
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
  }
}

class _ExportProgressDialog extends StatelessWidget {
  final String title;
  final ValueListenable<double> progress;

  const _ExportProgressDialog({required this.title, required this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (context, value, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A progress of exactly 0 means the export hasn't reported
            // anything yet (rather than "0% done") — show it indeterminate.
            LinearProgressIndicator(value: value == 0 ? null : value),
            const SizedBox(height: 12),
            Text('${(value * 100).round()}%'),
          ],
        ),
      ),
    );
  }
}

/// Shows [error] in a dialog rather than a [SnackBar] — export failures
/// (e.g. the [exportSvsLevel] pixel-count guard) carry a paragraph of
/// actionable detail that a SnackBar would truncate.
Future<void> showExportError(BuildContext context, Object error) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export failed'),
      content: Text('$error'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}
