import 'package:flutter/material.dart';

import '../models/sample_slide.dart';
import '../services/sample_library_service.dart';

/// Lets the user download one of a curated set of public test .svs files
/// and returns the local path of the one they choose to open, via
/// [Navigator.pop].
class SampleLibraryScreen extends StatefulWidget {
  const SampleLibraryScreen({super.key});

  @override
  State<SampleLibraryScreen> createState() => _SampleLibraryScreenState();
}

class _SampleLibraryScreenState extends State<SampleLibraryScreen> {
  final _service = SampleLibraryService();
  final Map<String, bool> _downloaded = {};
  final Map<String, double> _progress = {};
  final Map<String, Object> _errors = {};

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    for (final slide in kSampleSlides) {
      final done = await _service.isDownloaded(slide);
      if (!mounted) return;
      setState(() => _downloaded[slide.fileName] = done);
    }
  }

  Future<void> _download(SampleSlide slide) async {
    setState(() {
      _progress[slide.fileName] = 0;
      _errors.remove(slide.fileName);
    });
    try {
      await for (final progress in _service.download(slide)) {
        if (!mounted) return;
        setState(() => _progress[slide.fileName] = progress);
      }
      if (!mounted) return;
      setState(() {
        _progress.remove(slide.fileName);
        _downloaded[slide.fileName] = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _progress.remove(slide.fileName);
        _errors[slide.fileName] = e;
      });
    }
  }

  Future<void> _delete(SampleSlide slide) async {
    await _service.delete(slide);
    if (!mounted) return;
    setState(() => _downloaded[slide.fileName] = false);
  }

  Future<void> _open(SampleSlide slide) async {
    final file = await _service.localFile(slide);
    if (!mounted) return;
    Navigator.of(context).pop(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thư viện file mẫu')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kSampleSlides.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final slide = kSampleSlides[index];
          return _SampleSlideCard(
            slide: slide,
            isDownloaded: _downloaded[slide.fileName] ?? false,
            progress: _progress[slide.fileName],
            error: _errors[slide.fileName],
            onDownload: () => _download(slide),
            onOpen: () => _open(slide),
            onDelete: () => _delete(slide),
          );
        },
      ),
    );
  }
}

class _SampleSlideCard extends StatelessWidget {
  final SampleSlide slide;
  final bool isDownloaded;
  final double? progress;
  final Object? error;
  final VoidCallback onDownload;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _SampleSlideCard({
    required this.slide,
    required this.isDownloaded,
    required this.progress,
    required this.error,
    required this.onDownload,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloading = progress != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(slide.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    slide.sizeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(slide.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (downloading) ...[
              LinearProgressIndicator(value: progress == 0 ? null : progress),
              const SizedBox(height: 8),
              Text('${((progress ?? 0) * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodySmall),
            ] else if (error != null) ...[
              Text('$error', style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: onDownload, icon: const Icon(Icons.refresh), label: const Text('Thử tải lại')),
            ] else if (isDownloaded) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Mở'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: 'Xoá file đã tải'),
                ],
              ),
            ] else ...[
              FilledButton.tonalIcon(onPressed: onDownload, icon: const Icon(Icons.download_outlined), label: const Text('Tải về')),
            ],
          ],
        ),
      ),
    );
  }
}
