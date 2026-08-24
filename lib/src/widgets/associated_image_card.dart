import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

/// A thumbnail plus metadata for one associated image (label, macro,
/// thumbnail) embedded in an .svs file.
class AssociatedImageCard extends StatelessWidget {
  final SvsAssociatedImage associated;
  final ui.Image? preview;
  final VoidCallback? onExport;

  const AssociatedImageCard({super.key, required this.associated, required this.preview, this.onExport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = preview;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image != null
                ? SizedBox(
                    width: 100,
                    height: 100 * image.height / image.width,
                    child: RawImage(image: image, fit: BoxFit.contain),
                  )
                : Container(
                    width: 100,
                    height: 76,
                    alignment: Alignment.center,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(associated.kind.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${associated.width}×${associated.height}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  associated.isDecodable ? 'JPEG' : 'Unsupported compression (compression=${associated.compression})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: associated.isDecodable ? theme.colorScheme.primary : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          if (onExport != null)
            IconButton(
              onPressed: onExport,
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export image',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
