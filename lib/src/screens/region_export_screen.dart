import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:svs/svs.dart';

import '../utils/export_utils.dart';
import '../widgets/export_format_dialog.dart';
import 'file_info_screen.dart';
import 'viewer_screen.dart';

/// Lets the user draw a selection rectangle over a low-resolution reference
/// image (the pyramid's coarsest level, always small enough to decode in
/// full), pick which pyramid level to export it at, and save the crop —
/// built on the `svs` package's [readSvsRegion]/[exportSvsRegion]/
/// [exportSvsRegionAsSvsToFile]. [adjustments] (from the viewer's brightness/
/// contrast panel, if any) is baked into every exported crop, and previewed
/// live on the reference image via the same GPU color filter the viewer uses.
class RegionExportScreen extends StatefulWidget {
  final SvsFile svs;
  final String suggestedName;
  final SvsImageAdjustments adjustments;

  const RegionExportScreen({
    super.key,
    required this.svs,
    required this.suggestedName,
    this.adjustments = SvsImageAdjustments.none,
  });

  @override
  State<RegionExportScreen> createState() => _RegionExportScreenState();
}

class _RegionExportScreenState extends State<RegionExportScreen> {
  late final SvsLevel _referenceLevel = widget.svs.levels.last;

  ui.Image? _reference;
  Object? _referenceError;

  Offset? _dragStartRef;
  Rect? _selectionRef; // in _referenceLevel's own pixel coordinates
  late int _targetLevel = 0;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadReference();
  }

  Future<void> _loadReference() async {
    try {
      final image = await readSvsRegion(
        widget.svs,
        level: _referenceLevel.index,
        x: 0,
        y: 0,
        width: _referenceLevel.width,
        height: _referenceLevel.height,
      );
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _reference = image);
    } catch (e) {
      if (!mounted) return;
      setState(() => _referenceError = e);
    }
  }

  @override
  void dispose() {
    _reference?.dispose();
    super.dispose();
  }

  /// Maps [refRect] (in [_referenceLevel] pixel coordinates) to an
  /// `(x, y, width, height)` rectangle in [_targetLevel]'s own pixel
  /// coordinates, via level-0 as the common space — see [SvsLevel.downsample].
  ({int x, int y, int width, int height}) _regionForTargetLevel(Rect refRect) {
    final level0Left = refRect.left * _referenceLevel.downsample;
    final level0Top = refRect.top * _referenceLevel.downsample;
    final level0Width = refRect.width * _referenceLevel.downsample;
    final level0Height = refRect.height * _referenceLevel.downsample;

    final target = widget.svs.levels[_targetLevel];
    final scale = 1 / target.downsample;
    return (
      x: (level0Left * scale).round(),
      y: (level0Top * scale).round(),
      width: math.max(1, (level0Width * scale).round()),
      height: math.max(1, (level0Height * scale).round()),
    );
  }

  Future<void> _export() async {
    final selection = _selectionRef;
    if (selection == null) return;
    final region = _regionForTargetLevel(selection);

    final choice = await pickExportFormat(context);
    if (choice == null) return;
    if (!mounted) return;

    setState(() => _exporting = true);
    try {
      final bytes = await runWithExportProgress(
        context,
        title: 'Exporting crop…',
        task: (onProgress) => exportSvsRegion(
          widget.svs,
          level: _targetLevel,
          x: region.x,
          y: region.y,
          width: region.width,
          height: region.height,
          format: choice.format,
          quality: choice.quality,
          adjustments: widget.adjustments,
          onProgress: onProgress,
        ),
      );
      if (!mounted) return;
      await saveExportedBytes(
        context,
        bytes: bytes,
        suggestedName: '${widget.suggestedName}_crop',
        format: choice.format,
      );
    } catch (e) {
      if (!mounted) return;
      await showExportError(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Re-encodes the selected crop as a brand new, reopenable pyramidal
  /// `.svs` file (rather than a flat raster image) via
  /// [exportSvsRegionAsSvsToFile], writing it to a temp file first so it can
  /// be immediately opened/inspected without a round-trip through the
  /// platform's save-file picker.
  Future<void> _exportAsSvs() async {
    final selection = _selectionRef;
    if (selection == null) return;
    final region = _regionForTargetLevel(selection);

    final options = await pickSvsExportOptions(context);
    if (options == null) return;
    if (!mounted) return;

    setState(() => _exporting = true);
    try {
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final tempPath =
          '${tempDir.path}/${widget.suggestedName}_crop_${DateTime.now().millisecondsSinceEpoch}.svs';
      final file = await runWithExportProgress(
        context,
        title: 'Building .svs pyramid…',
        task: (onProgress) => exportSvsRegionAsSvsToFile(
          widget.svs,
          path: tempPath,
          level: _targetLevel,
          x: region.x,
          y: region.y,
          width: region.width,
          height: region.height,
          quality: options.quality,
          tileSize: options.tileSize,
          includeLabelAndMacroImages: options.includeLabelAndMacroImages,
          includeSourceMetadata: options.includeSourceMetadata,
          compression: options.compression,
          jp2kCompressionRatio: options.jp2kCompressionRatio,
          adjustments: widget.adjustments,
          onProgress: onProgress,
        ),
      );
      if (!mounted) return;
      await _showNewSvsFileSheet(file);
    } catch (e) {
      if (!mounted) return;
      await showExportError(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _showNewSvsFileSheet(File file) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New .svs file created', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  file.path,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openExportedFile(file, viewer: true);
                  },
                  icon: const Icon(Icons.zoom_in),
                  label: const Text('Open in viewer'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openExportedFile(file, viewer: false);
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View file info'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    final bytes = await file.readAsBytes();
                    if (!mounted) return;
                    await saveSvsFileBytes(context, bytes: bytes, suggestedName: '${widget.suggestedName}_crop');
                  },
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Save a copy'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the freshly exported [file] as its own [SvsFile] (independent of
  /// [widget.svs]) and pushes either [ViewerScreen] or [FileInfoScreen] on
  /// it, closing it again once that screen is popped.
  Future<void> _openExportedFile(File file, {required bool viewer}) async {
    final SvsFile opened;
    try {
      opened = await SvsFile.open(file.path);
    } catch (e) {
      if (!mounted) return;
      await showExportError(context, e);
      return;
    }
    if (!mounted) {
      await opened.close();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => viewer
            ? ViewerScreen(svs: opened, suggestedExportName: '${widget.suggestedName}_crop')
            : FileInfoScreen(svs: opened, title: '${widget.suggestedName}_crop.svs'),
      ),
    );
    await opened.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export region'),
        actions: [
          if (_selectionRef != null)
            IconButton(
              onPressed: () => setState(() => _selectionRef = null),
              icon: const Icon(Icons.deselect),
              tooltip: 'Clear selection',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildReferenceArea()),
          _buildControls(),
        ],
      ),
    );
  }

  /// Wraps [child] in the same GPU `ColorFilter` [SvsImageView] applies live,
  /// so this screen's reference preview matches what the exported crop will
  /// actually look like.
  Widget _applyAdjustments(Widget child) {
    final filter = widget.adjustments.toColorFilter();
    if (filter == null) return child;
    return ColorFiltered(colorFilter: filter, child: child);
  }

  Widget _buildReferenceArea() {
    final error = _referenceError;
    if (error != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load reference image: $error')),
      );
    }
    final image = _reference;
    if (image == null) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final aspect = image.width / image.height;
          var displayWidth = constraints.maxWidth;
          var displayHeight = displayWidth / aspect;
          if (displayHeight > constraints.maxHeight) {
            displayHeight = constraints.maxHeight;
            displayWidth = displayHeight * aspect;
          }
          final refPerDisplayPixel = image.width / displayWidth;

          Rect toDisplayRect(Rect ref) => Rect.fromLTWH(
            ref.left / refPerDisplayPixel,
            ref.top / refPerDisplayPixel,
            ref.width / refPerDisplayPixel,
            ref.height / refPerDisplayPixel,
          );

          Offset toRefPoint(Offset display) => display * refPerDisplayPixel;

          final refBounds = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

          return Center(
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _applyAdjustments(
                    RawImage(image: image, width: displayWidth, height: displayHeight, fit: BoxFit.fill),
                  ),
                  if (_selectionRef != null)
                    Positioned.fromRect(
                      rect: toDisplayRect(_selectionRef!),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.amberAccent, width: 2),
                          color: Colors.amberAccent.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        final start = toRefPoint(details.localPosition);
                        setState(() {
                          _dragStartRef = start;
                          _selectionRef = Rect.fromPoints(start, start);
                        });
                      },
                      onPanUpdate: (details) {
                        final start = _dragStartRef;
                        if (start == null) return;
                        final current = toRefPoint(details.localPosition);
                        setState(() {
                          _selectionRef = Rect.fromPoints(start, current).intersect(refBounds);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    final theme = Theme.of(context);
    final selection = _selectionRef;
    final region = selection != null ? _regionForTargetLevel(selection) : null;

    return DecoratedBox(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              region == null
                  ? 'Drag on the image to select a region to export'
                  : 'Selection: ${region.width}×${region.height} px (at level $_targetLevel)',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _targetLevel,
                    decoration: const InputDecoration(labelText: 'Export level', isDense: true),
                    items: [
                      for (final level in widget.svs.levels)
                        DropdownMenuItem(
                          value: level.index,
                          child: Text('Level ${level.index} — ${level.width}×${level.height}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _targetLevel = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: selection == null || _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.ios_share),
                  label: const Text('Export'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: selection == null || _exporting ? null : _exportAsSvs,
              icon: const Icon(Icons.biotech_outlined),
              label: const Text('Export as new .svs slide'),
            ),
          ],
        ),
      ),
    );
  }
}
