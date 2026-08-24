import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:svs/svs.dart';

import 'file_info_screen.dart';
import 'region_export_screen.dart';

/// Full-screen pannable/zoomable view of an already-opened [SvsFile], with
/// annotation drawing/measurement and a persistent on-disk tile cache.
class ViewerScreen extends StatefulWidget {
  final SvsFile svs;
  final String suggestedExportName;

  const ViewerScreen({super.key, required this.svs, required this.suggestedExportName});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final SvsAnnotationController _annotations = SvsAnnotationController(drawColor: Colors.amberAccent);
  DiskTileCache? _diskCache;
  SvsImageAdjustments _adjustments = SvsImageAdjustments.none;

  @override
  void initState() {
    super.initState();
    _annotations.addListener(_onAnnotationsChanged);
    _openDiskCache();
  }

  // Scoped to this slide's own path, per DiskTileCache's requirement that
  // different slides not share a directory (their tile keys would collide).
  Future<void> _openDiskCache() async {
    try {
      final cacheRoot = await getApplicationCacheDirectory();
      final dir = Directory('${cacheRoot.path}/svs_tiles/${widget.svs.path.hashCode}');
      final cache = await DiskTileCache.open(dir);
      if (!mounted) return;
      setState(() => _diskCache = cache);
    } catch (_) {
      // Persistent cache is a speed optimization only; fall back to
      // in-memory-only tile caching silently on any failure.
    }
  }

  void _onAnnotationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _annotations.removeListener(_onAnnotationsChanged);
    _annotations.dispose();
    super.dispose();
  }

  void _openAdjustments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (sheetContext) {
        return _AdjustmentsSheet(
          initial: _adjustments,
          onChanged: (value) => setState(() => _adjustments = value),
        );
      },
    );
  }

  void _openFileInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FileInfoScreen(svs: widget.svs, title: widget.suggestedExportName)),
    );
  }

  void _toggleMode(SvsAnnotationDrawMode mode) {
    setState(() {
      _annotations.drawMode = _annotations.drawMode == mode ? SvsAnnotationDrawMode.none : mode;
    });
  }

  void _onAnnotationTap(SvsAnnotation? annotation) {
    if (annotation != null) _showAnnotationSheet(annotation);
  }

  void _showAnnotationSheet(SvsAnnotation annotation) {
    final measurement = measureAnnotation(
      annotation,
      mppX: widget.svs.metadata.mppX,
      mppY: widget.svs.metadata.mppY,
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Annotation: ${_shapeLabel(annotation.type)}', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (measurement.lengthMicrons != null)
                  Text(
                    annotation.type == SvsAnnotationShapeType.polyline
                        ? 'Length: ${formatMicrons(measurement.lengthMicrons!)}'
                        : 'Perimeter: ${formatMicrons(measurement.lengthMicrons!)}',
                  ),
                if (measurement.areaMicronsSquared != null)
                  Text('Area: ${formatMicronsSquared(measurement.areaMicronsSquared!)}'),
                if (measurement.lengthMicrons == null && measurement.areaMicronsSquared == null)
                  const Text('No measurement available (a point, or the slide lacks microns-per-pixel data).'),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () {
                    _annotations.remove(annotation.id);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete annotation'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _shapeLabel(SvsAnnotationShapeType type) {
    switch (type) {
      case SvsAnnotationShapeType.point:
        return 'Point';
      case SvsAnnotationShapeType.rectangle:
        return 'Rectangle';
      case SvsAnnotationShapeType.polyline:
        return 'Polyline';
      case SvsAnnotationShapeType.polygon:
        return 'Polygon';
    }
  }

  Future<void> _confirmClearAnnotations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all annotations?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) _annotations.clear();
  }

  @override
  Widget build(BuildContext context) {
    final drawMode = _annotations.drawMode;
    final isPathMode = drawMode == SvsAnnotationDrawMode.polyline || drawMode == SvsAnnotationDrawMode.polygon;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          drawMode == SvsAnnotationDrawMode.none
              ? 'Drag to pan, scroll/pinch to zoom'
              : 'Tap on the image to draw an annotation',
        ),
        actions: [
          if (_annotations.annotations.isNotEmpty)
            IconButton(
              onPressed: _confirmClearAnnotations,
              icon: const Icon(Icons.layers_clear_outlined),
              tooltip: 'Delete all annotations',
            ),
          IconButton(
            onPressed: _openFileInfo,
            icon: const Icon(Icons.description_outlined),
            tooltip: 'View all file info (TIFF tags)',
          ),
          IconButton(
            onPressed: _openAdjustments,
            icon: Icon(
              Icons.tune,
              color: _adjustments.isIdentity ? Colors.white : Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Brightness / contrast',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RegionExportScreen(
                  svs: widget.svs,
                  suggestedName: widget.suggestedExportName,
                  adjustments: _adjustments,
                ),
              ),
            ),
            icon: const Icon(Icons.crop),
            tooltip: 'Export region',
          ),
        ],
      ),
      body: SvsImageView(
        svsFile: widget.svs,
        diskCache: _diskCache,
        annotationController: _annotations,
        onAnnotationTap: _onAnnotationTap,
        adjustments: _adjustments,
      ),
      bottomNavigationBar: _AnnotationToolbar(
        drawMode: drawMode,
        showDone: isPathMode,
        onSelectMode: _toggleMode,
        onDone: _annotations.finishPath,
      ),
    );
  }
}

class _AnnotationToolbar extends StatelessWidget {
  final SvsAnnotationDrawMode drawMode;
  final bool showDone;
  final ValueChanged<SvsAnnotationDrawMode> onSelectMode;
  final VoidCallback onDone;

  const _AnnotationToolbar({
    required this.drawMode,
    required this.showDone,
    required this.onSelectMode,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(
            icon: Icons.pan_tool_alt_outlined,
            label: 'Pan',
            selected: drawMode == SvsAnnotationDrawMode.none,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.none),
          ),
          _ToolButton(
            icon: Icons.radio_button_checked,
            label: 'Point',
            selected: drawMode == SvsAnnotationDrawMode.point,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.point),
          ),
          _ToolButton(
            icon: Icons.crop_square,
            label: 'Rectangle',
            selected: drawMode == SvsAnnotationDrawMode.rectangle,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.rectangle),
          ),
          _ToolButton(
            icon: Icons.timeline,
            label: 'Polyline',
            selected: drawMode == SvsAnnotationDrawMode.polyline,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.polyline),
          ),
          _ToolButton(
            icon: Icons.pentagon_outlined,
            label: 'Polygon',
            selected: drawMode == SvsAnnotationDrawMode.polygon,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.polygon),
          ),
          if (showDone)
            _ToolButton(icon: Icons.check_circle_outline, label: 'Done', selected: false, onPressed: onDone),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _ToolButton({required this.icon, required this.label, required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.white70;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Live brightness/contrast/shadows/highlights controls for the
/// `SvsImageAdjustments` GPU-accelerated color filter applied to the slide
/// under it — every slider move is reported immediately via [onChanged], so
/// the viewer behind the sheet updates live.
class _AdjustmentsSheet extends StatefulWidget {
  final SvsImageAdjustments initial;
  final ValueChanged<SvsImageAdjustments> onChanged;

  const _AdjustmentsSheet({required this.initial, required this.onChanged});

  @override
  State<_AdjustmentsSheet> createState() => _AdjustmentsSheetState();
}

class _AdjustmentsSheetState extends State<_AdjustmentsSheet> {
  late double _brightness = widget.initial.brightness;
  late double _contrast = widget.initial.contrast;
  late double _shadows = widget.initial.shadows;
  late double _highlights = widget.initial.highlights;

  void _apply() {
    widget.onChanged(
      SvsImageAdjustments(
        brightness: _brightness,
        contrast: _contrast,
        shadows: _shadows,
        highlights: _highlights,
      ),
    );
  }

  void _reset() {
    setState(() {
      _brightness = 0;
      _contrast = 0;
      _shadows = 0;
      _highlights = 0;
    });
    _apply();
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Slider(
          value: value,
          min: -1,
          max: 1,
          onChanged: (v) {
            setState(() => onChanged(v));
            _apply();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Adjustments', style: TextStyle(color: Colors.white, fontSize: 16)),
                const Spacer(),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            _slider('Brightness', _brightness, (v) => _brightness = v),
            _slider('Contrast', _contrast, (v) => _contrast = v),
            _slider('Shadows', _shadows, (v) => _shadows = v),
            _slider('Highlights', _highlights, (v) => _highlights = v),
          ],
        ),
      ),
    );
  }
}
