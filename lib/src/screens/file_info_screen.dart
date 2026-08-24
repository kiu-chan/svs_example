import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

import '../widgets/info_row.dart';
import '../widgets/section_card.dart';

/// Renders one decoded TIFF tag value for display — see `TiffIfd.readValues`
/// for the possible runtime types (`String`, `List<int>`,
/// `List<(int, int)>` for RATIONAL/SRATIONAL, `List<double>`, or a raw
/// `Uint8List` for UNDEFINED) — with long lists/byte arrays truncated so one
/// oversized tag can't blow out the layout.
String _formatTagValue(Object value) {
  const maxItems = 16;
  if (value is String) return value;
  if (value is Uint8List) {
    final hex = value.take(maxItems).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final suffix = value.length > maxItems ? ' … (${value.length} bytes)' : ' (${value.length} bytes)';
    return '$hex$suffix';
  }
  if (value is List) {
    final items = value.take(maxItems).map((e) {
      if (e is (int, int)) {
        final (num, den) = e;
        return den == 0 ? '$num/0' : '${(num / den)}';
      }
      return '$e';
    });
    final suffix = value.length > maxItems ? ', … (${value.length} total)' : '';
    return '${items.join(', ')}$suffix';
  }
  return '$value';
}

/// Full structured dump of an open [SvsFile] — every TIFF tag on every
/// pyramid level and associated image, plus the file's own container facts
/// and parsed Aperio metadata — via the `svs` package's [SvsFile.readInfo].
class FileInfoScreen extends StatefulWidget {
  final SvsFile svs;
  final String title;

  const FileInfoScreen({super.key, required this.svs, required this.title});

  @override
  State<FileInfoScreen> createState() => _FileInfoScreenState();
}

class _FileInfoScreenState extends State<FileInfoScreen> {
  SvsFileInfo? _info;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await widget.svs.readInfo();
      if (!mounted) return;
      setState(() => _info = info);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('File info — ${widget.title}')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not read file info: $error')),
      );
    }
    final info = _info;
    if (info == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Container',
          icon: Icons.folder_zip_outlined,
          child: Column(
            children: [
              InfoRow('Path', info.path),
              InfoRow('Format', info.isBigTiff ? 'BigTIFF' : 'Classic TIFF'),
              InfoRow('Byte order', info.byteOrder.toString()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Aperio metadata',
          icon: Icons.info_outline,
          child: Column(
            children: [
              InfoRow('AppMag', info.metadata.appMag?.toString() ?? '—'),
              InfoRow('MPP (X)', info.metadata.mppX?.toStringAsFixed(4) ?? '—'),
              InfoRow('MPP (Y)', info.metadata.mppY?.toStringAsFixed(4) ?? '—'),
              const Divider(height: 20),
              for (final entry in info.metadata.raw.entries) InfoRow(entry.key, entry.value),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Pyramid levels (${info.levels.length})',
          icon: Icons.layers_outlined,
          child: Column(
            children: [
              for (final level in info.levels) _IfdTile(title: 'Level ${level.index}', ifd: level),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Associated images (${info.associatedImages.length})',
          icon: Icons.photo_library_outlined,
          child: Column(
            children: [
              for (final image in info.associatedImages) _IfdTile(title: 'IFD ${image.index}', ifd: image),
            ],
          ),
        ),
      ],
    );
  }
}

class _IfdTile extends StatelessWidget {
  final String title;
  final SvsIfdInfo ifd;

  const _IfdTile({required this.title, required this.ifd});

  @override
  Widget build(BuildContext context) {
    final named = ifd.namedTags;
    final names = named.keys.toList()..sort();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('$title (${named.length} tags)'),
      children: [
        for (final name in names)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InfoRow(name, _formatTagValue(named[name]!)),
          ),
      ],
    );
  }
}
