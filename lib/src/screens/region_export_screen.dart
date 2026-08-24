import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

import '../utils/export_utils.dart';
import '../widgets/export_format_dialog.dart';

/// Lets the user draw a selection rectangle over a low-resolution reference
/// image (the pyramid's coarsest level, always small enough to decode in
/// full), pick which pyramid level to export it at, and save the crop —
/// built on the `svs` package's [readSvsRegion]/[exportSvsRegion].
class RegionExportScreen extends StatefulWidget {
  final SvsFile svs;
  final String suggestedName;

  const RegionExportScreen({super.key, required this.svs, required this.suggestedName});

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

    setState(() => _exporting = true);
    try {
      final bytes = await exportSvsRegion(
        widget.svs,
        level: _targetLevel,
        x: region.x,
        y: region.y,
        width: region.width,
        height: region.height,
        format: choice.format,
        quality: choice.quality,
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
                  RawImage(image: image, width: displayWidth, height: displayHeight, fit: BoxFit.fill),
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
          ],
        ),
      ),
    );
  }
}
