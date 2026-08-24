import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

import '../utils/export_utils.dart';

class ExportChoice {
  final SvsImageFormat format;
  final int quality;

  const ExportChoice(this.format, this.quality);
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
