import 'dart:async';

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
  final Map<String, DownloadProgress> _progress = {};
  final Map<String, Object> _errors = {};
  final Map<String, StreamSubscription<DownloadProgress>> _subscriptions = {};

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _refreshStatuses() async {
    for (final slide in kSampleSlides) {
      final done = await _service.isDownloaded(slide);
      if (!mounted) return;
      setState(() => _downloaded[slide.fileName] = done);
    }
  }

  void _download(SampleSlide slide) {
    setState(() {
      _progress[slide.fileName] = const DownloadProgress(received: 0);
      _errors.remove(slide.fileName);
    });
    final subscription = _service.download(slide).listen(
      (progress) {
        if (!mounted) return;
        setState(() => _progress[slide.fileName] = progress);
      },
      onError: (Object e) {
        _subscriptions.remove(slide.fileName);
        if (!mounted) return;
        setState(() {
          _progress.remove(slide.fileName);
          _errors[slide.fileName] = e;
        });
      },
      onDone: () {
        _subscriptions.remove(slide.fileName);
        if (!mounted) return;
        setState(() {
          _progress.remove(slide.fileName);
          _downloaded[slide.fileName] = true;
        });
      },
    );
    _subscriptions[slide.fileName] = subscription;
  }

  /// Cancels an in-flight download — the underlying [SampleLibraryService]
  /// aborts the HTTP request and deletes the partial file as soon as the
  /// subscription is cancelled.
  Future<void> _cancelDownload(SampleSlide slide) async {
    final subscription = _subscriptions.remove(slide.fileName);
    if (subscription == null) return;
    await subscription.cancel();
    if (!mounted) return;
    setState(() => _progress.remove(slide.fileName));
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
      appBar: AppBar(title: const Text('Sample file library')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kSampleSlides.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) return const _SourceBanner();
          final slide = kSampleSlides[index - 1];
          return _SampleSlideCard(
            slide: slide,
            isDownloaded: _downloaded[slide.fileName] ?? false,
            progress: _progress[slide.fileName],
            error: _errors[slide.fileName],
            onDownload: () => _download(slide),
            onCancel: () => _cancelDownload(slide),
            onOpen: () => _open(slide),
            onDelete: () => _delete(slide),
          );
        },
      ),
    );
  }
}

/// Explains where every file in this list actually comes from — the
/// OpenSlide project's own public test-data mirror, not this app's servers.
class _SourceBanner extends StatelessWidget {
  const _SourceBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Downloaded directly from the OpenSlide project\'s public test-data mirror at '
              '$kSampleDataSourceUrl — not hosted by this app. Each file below credits its own '
              'source and license.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleSlideCard extends StatelessWidget {
  final SampleSlide slide;
  final bool isDownloaded;
  final DownloadProgress? progress;
  final Object? error;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _SampleSlideCard({
    required this.slide,
    required this.isDownloaded,
    required this.progress,
    required this.error,
    required this.onDownload,
    required this.onCancel,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = this.progress;
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
                _Chip(label: slide.format, theme: theme),
                const SizedBox(width: 6),
                _Chip(label: slide.sizeLabel, theme: theme, emphasized: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(slide.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              'Source: ${slide.url.host} · ${slide.credit} · ${slide.license}',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            if (downloading) ...[
              LinearProgressIndicator(value: progress.fraction),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progress.total != null
                          ? '${formatBytes(progress.received)} / ${formatBytes(progress.total!)}'
                          : formatBytes(progress.received),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ] else if (error != null) ...[
              Text('$error', style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: onDownload, icon: const Icon(Icons.refresh), label: const Text('Retry download')),
            ] else if (isDownloaded) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Open'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: 'Delete downloaded file'),
                ],
              ),
            ] else ...[
              FilledButton.tonalIcon(onPressed: onDownload, icon: const Icon(Icons.download_outlined), label: const Text('Download')),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final ThemeData theme;
  final bool emphasized;

  const _Chip({required this.label, required this.theme, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized ? theme.colorScheme.secondaryContainer : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: emphasized ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
