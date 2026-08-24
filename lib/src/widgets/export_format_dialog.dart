import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

import '../utils/export_utils.dart';

class ExportChoice {
  final SvsImageFormat format;
  final int quality;

  const ExportChoice(this.format, this.quality);
}

class SvsExportOptions {
  final int quality;
  final int tileSize;
  final bool includeLabelAndMacroImages;
  final bool includeSourceMetadata;
  final SvsExportCompression compression;
  final double jp2kCompressionRatio;

  const SvsExportOptions({
    required this.quality,
    required this.tileSize,
    required this.includeLabelAndMacroImages,
    required this.includeSourceMetadata,
    required this.compression,
    required this.jp2kCompressionRatio,
  });
}

/// Prompts for the JPEG quality and tile size used to re-encode a cropped
/// region as a brand new pyramidal `.svs` file (`exportSvsRegionAsSvs`).
/// Returns null if the user cancels.
Future<SvsExportOptions?> pickSvsExportOptions(BuildContext context) {
  return showDialog<SvsExportOptions>(context: context, builder: (context) => const _SvsExportOptionsDialog());
}

class _SvsExportOptionsDialog extends StatefulWidget {
  const _SvsExportOptionsDialog();

  @override
  State<_SvsExportOptionsDialog> createState() => _SvsExportOptionsDialogState();
}

class _SvsExportOptionsDialogState extends State<_SvsExportOptionsDialog> {
  double _quality = 90;
  int _tileSize = 256;
  bool _includeLabelAndMacroImages = true;
  bool _includeSourceMetadata = true;
  SvsExportCompression _compression = SvsExportCompression.jpeg;
  double _jp2kCompressionRatio = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export as .svs'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Re-encodes the crop as a brand new, reopenable pyramidal .svs file.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<SvsExportCompression>(
            initialValue: _compression,
            decoration: const InputDecoration(labelText: 'Tile compression', isDense: true),
            items: const [
              DropdownMenuItem(value: SvsExportCompression.jpeg, child: Text('JPEG')),
              DropdownMenuItem(value: SvsExportCompression.jpeg2000, child: Text('JPEG2000')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _compression = value);
            },
          ),
          const SizedBox(height: 8),
          if (_compression == SvsExportCompression.jpeg) ...[
            Text('Tile JPEG quality: ${_quality.round()}', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: _quality,
              min: 1,
              max: 100,
              divisions: 99,
              label: '${_quality.round()}',
              onChanged: (value) => setState(() => _quality = value),
            ),
          ] else ...[
            Text(
              _jp2kCompressionRatio == 0
                  ? 'JPEG2000 target ratio: lossless'
                  : 'JPEG2000 target ratio: ${_jp2kCompressionRatio.round()}:1',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              value: _jp2kCompressionRatio,
              min: 0,
              max: 100,
              divisions: 100,
              label: _jp2kCompressionRatio == 0 ? 'Lossless' : '${_jp2kCompressionRatio.round()}:1',
              onChanged: (value) => setState(() => _jp2kCompressionRatio = value),
            ),
            if (_jp2kCompressionRatio > 0) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _jp2kCompressionRatio >= 50
                          ? 'Lossy: at this ratio, fine detail will be noticeably blurred after decoding.'
                          : 'Lossy: higher ratios blur fine detail after decoding. Use 0 for pixel-exact output.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _tileSize,
            decoration: const InputDecoration(labelText: 'Tile size', isDense: true),
            items: const [
              DropdownMenuItem(value: 128, child: Text('128 × 128')),
              DropdownMenuItem(value: 256, child: Text('256 × 256 (Aperio default)')),
              DropdownMenuItem(value: 512, child: Text('512 × 512')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _tileSize = value);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include label/macro images'),
            subtitle: const Text("Copies the source slide's label and macro images as-is"),
            value: _includeLabelAndMacroImages,
            onChanged: (value) => setState(() => _includeLabelAndMacroImages = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include source metadata'),
            subtitle: const Text('Carries over scanner/file details (excluding original position)'),
            value: _includeSourceMetadata,
            onChanged: (value) => setState(() => _includeSourceMetadata = value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            SvsExportOptions(
              quality: _quality.round(),
              tileSize: _tileSize,
              includeLabelAndMacroImages: _includeLabelAndMacroImages,
              includeSourceMetadata: _includeSourceMetadata,
              compression: _compression,
              jp2kCompressionRatio: _jp2kCompressionRatio,
            ),
          ),
          child: const Text('Export'),
        ),
      ],
    );
  }
}

/// Prompts for an [SvsImageFormat] (and, for JPEG, a quality level) before
/// an export. Returns null if the user cancels.
Future<ExportChoice?> pickExportFormat(BuildContext context) {
  return showDialog<ExportChoice>(context: context, builder: (context) => const _ExportFormatDialog());
}

class _ExportFormatDialog extends StatefulWidget {
  const _ExportFormatDialog();

  @override
  State<_ExportFormatDialog> createState() => _ExportFormatDialogState();
}

class _ExportFormatDialogState extends State<_ExportFormatDialog> {
  SvsImageFormat _format = SvsImageFormat.png;
  double _quality = 92;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export image'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<SvsImageFormat>(
            groupValue: _format,
            onChanged: (value) => setState(() => _format = value!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final format in SvsImageFormat.values)
                  RadioListTile<SvsImageFormat>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(format.label),
                    value: format,
                  ),
              ],
            ),
          ),
          if (_format == SvsImageFormat.jpeg) ...[
            const SizedBox(height: 4),
            Text('Quality: ${_quality.round()}', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: _quality,
              min: 1,
              max: 100,
              divisions: 99,
              label: '${_quality.round()}',
              onChanged: (value) => setState(() => _quality = value),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, ExportChoice(_format, _quality.round())),
          child: const Text('Export'),
        ),
      ],
    );
  }
}
