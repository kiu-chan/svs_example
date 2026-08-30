import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:svs/svs.dart';

import '../utils/dev_sample_dir.dart';
import '../utils/export_utils.dart';
import '../widgets/associated_image_card.dart';
import '../widgets/export_format_dialog.dart';
import '../widgets/info_row.dart';
import '../widgets/section_card.dart';
import 'file_info_screen.dart';
import 'region_export_screen.dart';
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
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['svs', 'tif', 'tiff'],
      initialDirectory: devSampleDirPath(),
    );
    if (picked == null) return;
    final path = picked.path;
    if (path != null) {
      await _openWith(() => SvsFile.open(path), fileName: p.basename(path));
      return;
    }
    // No local file path (e.g. the web) — read the bytes directly.
    final bytes = await picked.readAsBytes();
    await _openWith(() => SvsFile.openBytes(bytes), fileName: picked.name);
  }

  Future<void> _browseSamples() async {
    final path = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const SampleLibraryScreen()));
    if (path == null) return;
    await _openWith(() => SvsFile.open(path), fileName: p.basename(path));
  }

  Future<void> _openWith(Future<SvsFile> Function() open, {required String fileName}) async {
    setState(() {
      _loading = true;
      _error = null;
      _fileName = fileName;
    });

    await _disposeCurrent();

    try {
      final svs = await open();
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

  String get _suggestedExportName => _fileName != null ? p.basenameWithoutExtension(_fileName!) : 'slide';

  Future<void> _exportAssociated(SvsAssociatedImage associated) async {
    final choice = await pickExportFormat(context);
    if (choice == null) return;
    try {
      final bytes = await exportAssociatedImage(associated, format: choice.format, quality: choice.quality);
      if (!mounted) return;
      await saveExportedBytes(
        context,
        bytes: bytes,
        suggestedName: '${_suggestedExportName}_${associated.kind.name}',
        format: choice.format,
      );
    } catch (e) {
      if (!mounted) return;
      await showExportError(context, e);
    }
  }

  Future<void> _exportLevel(SvsLevel level) async {
    final svs = _svs;
    if (svs == null) return;
    final choice = await pickExportFormat(context);
    if (choice == null) return;
    if (!mounted) return;
    try {
      final bytes = await runWithExportProgress(
        context,
        title: 'Exporting level ${level.index}…',
        task: (onProgress) => exportSvsLevel(
          svs,
          level: level.index,
          format: choice.format,
          quality: choice.quality,
          onProgress: onProgress,
        ),
      );
      if (!mounted) return;
      await saveExportedBytes(
        context,
        bytes: bytes,
        suggestedName: '${_suggestedExportName}_level${level.index}',
        format: choice.format,
      );
    } catch (e) {
      if (!mounted) return;
      await showExportError(context, e);
    }
  }

  void _openRegionExport(SvsFile svs) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RegionExportScreen(svs: svs, suggestedName: _suggestedExportName)));
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
          if (_svs != null)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FileInfoScreen(svs: _svs!, title: _fileName ?? 'slide'),
                ),
              ),
              icon: const Icon(Icons.description_outlined),
              tooltip: 'View all file info (TIFF tags)',
            ),
          if (_svs != null)
            IconButton(
              onPressed: () => _openRegionExport(_svs!),
              icon: const Icon(Icons.crop),
              tooltip: 'Export region',
            ),
          // The sample library downloads files up to several GB, which
          // would need to fully fit in the browser tab's memory to open via
          // SvsFile.openBytes — not offered on the web.
          if (!kIsWeb)
            IconButton(
              onPressed: _loading ? null : _browseSamples,
              icon: const Icon(Icons.cloud_download_outlined),
              tooltip: 'Sample file library',
            ),
          IconButton(
            onPressed: _loading ? null : _pickAndOpen,
            icon: const Icon(Icons.folder_open),
            tooltip: 'Pick file',
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
              FilledButton.icon(onPressed: _pickAndOpen, icon: const Icon(Icons.refresh), label: const Text('Retry')),
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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ViewerScreen(svs: svs, suggestedExportName: _suggestedExportName)),
            ),
            icon: const Icon(Icons.zoom_in),
            label: const Text('View details'),
          ),
          child: Column(
            children: [
              for (final level in svs.levels)
                Row(
                  children: [
                    Expanded(
                      child: InfoRow(
                        'Level ${level.index}',
                        '${level.width}×${level.height}  •  downsample ${level.downsample.toStringAsFixed(1)}x  •  '
                            'tiles ${level.tilesAcrossX}×${level.tilesAcrossY}',
                      ),
                    ),
                    IconButton(
                      onPressed: () => _exportLevel(level),
                      icon: const Icon(Icons.ios_share),
                      tooltip: 'Export this whole level',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
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
                  child: AssociatedImageCard(
                    associated: associated,
                    preview: _associatedPreviews[associated.kind],
                    onExport: associated.isDecodable ? () => _exportAssociated(associated) : null,
                  ),
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
            Text('No file open yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'Pick a .svs/.tif file from your device.'
                  : 'Pick a .svs/.tif file on your device, or download a sample file for a quick test.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: onPickFile, icon: const Icon(Icons.folder_open), label: const Text('Pick a .svs file')),
            if (!kIsWeb) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onBrowseSamples,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Download a sample file'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
