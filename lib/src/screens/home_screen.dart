import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

import '../widgets/associated_image_card.dart';
import '../widgets/info_row.dart';
import '../widgets/section_card.dart';
import 'sample_library_screen.dart';
import 'viewer_screen.dart';

/// Opens a local .svs/.tif file (picked, or chosen from the sample
/// library) and displays its metadata, pyramid levels, and associated
/// images.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _browseSamples() async {
    final path = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const SampleLibraryScreen()));
    if (path == null) return;
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
        title: Text(_fileName ?? 'SVS Viewer'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _browseSamples,
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: 'Thư viện file mẫu',
          ),
          IconButton(
            onPressed: _loading ? null : _pickAndOpen,
            icon: const Icon(Icons.folder_open),
            tooltip: 'Chọn file',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final error = _error;
    if (error != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 12),
              Text('$error', style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _pickAndOpen, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    final svs = _svs;
    if (svs == null) {
      return _EmptyState(onPickFile: _pickAndOpen, onBrowseSamples: _browseSamples);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Metadata',
          icon: Icons.info_outline,
          child: Column(
            children: [
              InfoRow('AppMag', svs.metadata.appMag?.toString() ?? '—'),
              InfoRow('MPP', svs.metadata.mppX?.toStringAsFixed(4) ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Levels (${svs.levels.length})',
          icon: Icons.layers_outlined,
          trailing: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerScreen(svs: svs))),
            icon: const Icon(Icons.zoom_in),
            label: const Text('Xem chi tiết'),
          ),
          child: Column(
            children: [
              for (final level in svs.levels)
                InfoRow(
                  'Level ${level.index}',
                  '${level.width}×${level.height}  •  downsample ${level.downsample.toStringAsFixed(1)}x  •  '
                      'tiles ${level.tilesAcrossX}×${level.tilesAcrossY}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Associated images (${svs.associatedImages.length})',
          icon: Icons.photo_library_outlined,
          child: Column(
            children: [
              for (final associated in svs.associatedImages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AssociatedImageCard(associated: associated, preview: _associatedPreviews[associated.kind]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPickFile;
  final VoidCallback onBrowseSamples;

  const _EmptyState({required this.onPickFile, required this.onBrowseSamples});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.biotech_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Chưa có file nào được mở', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Chọn một file .svs/.tif trên máy, hoặc tải một file mẫu để thử nghiệm nhanh.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: onPickFile, icon: const Icon(Icons.folder_open), label: const Text('Chọn file .svs')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onBrowseSamples,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Tải file mẫu để test'),
            ),
          ],
        ),
      ),
    );
  }
}
