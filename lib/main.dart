import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

void main() {
  runApp(const SvsExampleApp());
}

class SvsExampleApp extends StatelessWidget {
  const SvsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SvsInspectorScreen());
  }
}

class SvsInspectorScreen extends StatefulWidget {
  const SvsInspectorScreen({super.key});

  @override
  State<SvsInspectorScreen> createState() => _SvsInspectorScreenState();
}

class _SvsInspectorScreenState extends State<SvsInspectorScreen> {
  SvsFile? _svs;
  String? _fileName;
  final Map<AssociatedImageKind, ui.Image> _associatedPreviews = {};
  bool _loading = false;
  Object? _error;

  Future<void> _pickAndOpen() async {
    final sampleDir = Directory('sample_data');
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['svs', 'tif', 'tiff'],
      initialDirectory: sampleDir.existsSync() ? sampleDir.absolute.path : null,
    );
    final path = picked?.path;
    if (path == null) return; // cancelled, or platform only returned bytes
    await _openPath(path);
  }

  Future<void> _openPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _fileName = path.split(Platform.pathSeparator).last;
    });

    await _disposeCurrent();

    try {
      final svs = await SvsFile.open(path);
      final previews = <AssociatedImageKind, ui.Image>{};
      for (final associated in svs.associatedImages) {
        if (!associated.isDecodable) continue;
        try {
          previews[associated.kind] = await decodeAssociatedImage(associated);
        } catch (_) {
          // Leave this one without a preview; the rest of the inspector still works.
        }
      }

      if (!mounted) {
        await svs.close();
        for (final image in previews.values) {
          image.dispose();
        }
        return;
      }
      setState(() {
        _svs = svs;
        _associatedPreviews.addAll(previews);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _disposeCurrent() async {
    await _svs?.close();
    _svs = null;
    for (final image in _associatedPreviews.values) {
      image.dispose();
    }
    _associatedPreviews.clear();
  }

  @override
  void dispose() {
    _disposeCurrent();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName ?? 'svs — chọn file để xem'),
        actions: [IconButton(onPressed: _loading ? null : _pickAndOpen, icon: const Icon(Icons.folder_open))],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$error', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
        ),
      );
    }

    final svs = _svs;
    if (svs == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _pickAndOpen,
          icon: const Icon(Icons.folder_open),
          label: const Text('Chọn file .svs'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Metadata'),
        _InfoRow('AppMag', svs.metadata.appMag?.toString() ?? '—'),
        _InfoRow('MPP', svs.metadata.mppX?.toStringAsFixed(4) ?? '—'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _SectionTitle('Levels (${svs.levels.length})')),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SvsViewerScreen(svs: svs))),
              icon: const Icon(Icons.zoom_in),
              label: const Text('Xem chi tiết'),
            ),
          ],
        ),
        for (final level in svs.levels)
          _InfoRow(
            'Level ${level.index}',
            '${level.width}×${level.height}  •  downsample ${level.downsample.toStringAsFixed(1)}x  •  '
                'tiles ${level.tilesAcrossX}×${level.tilesAcrossY}',
          ),
        const SizedBox(height: 16),
        _SectionTitle('Associated images (${svs.associatedImages.length})'),
        for (final associated in svs.associatedImages) _AssociatedImageRow(associated, _associatedPreviews[associated.kind]),
      ],
    );
  }
}

class SvsViewerScreen extends StatelessWidget {
  final SvsFile svs;

  const SvsViewerScreen({super.key, required this.svs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Xem chi tiết — kéo để di chuyển, cuộn/chụm để phóng to')),
      body: SvsImageView(svsFile: svs),
    );
  }
}

class _AssociatedImageRow extends StatelessWidget {
  final SvsAssociatedImage associated;
  final ui.Image? preview;

  const _AssociatedImageRow(this.associated, this.preview);

  @override
  Widget build(BuildContext context) {
    final image = preview;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            SizedBox(
              width: 120,
              height: 120 * image.height / image.width,
              child: RawImage(image: image, fit: BoxFit.contain),
            )
          else
            Container(
              width: 120,
              height: 90,
              alignment: Alignment.center,
              color: Colors.grey.shade200,
              child: const Text('không xem trước được', textAlign: TextAlign.center),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(associated.kind.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${associated.width}×${associated.height}'),
                Text(
                  associated.isDecodable ? 'JPEG' : 'nén không hỗ trợ (compression=${associated.compression})',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
