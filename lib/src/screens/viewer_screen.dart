import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:svs/svs.dart';

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
                Text('Chú thích: ${_shapeLabel(annotation.type)}', style: Theme.of(sheetContext).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (measurement.lengthMicrons != null)
                  Text(
                    annotation.type == SvsAnnotationShapeType.polyline
                        ? 'Độ dài: ${formatMicrons(measurement.lengthMicrons!)}'
                        : 'Chu vi: ${formatMicrons(measurement.lengthMicrons!)}',
                  ),
                if (measurement.areaMicronsSquared != null)
                  Text('Diện tích: ${formatMicronsSquared(measurement.areaMicronsSquared!)}'),
                if (measurement.lengthMicrons == null && measurement.areaMicronsSquared == null)
                  const Text('Không có dữ liệu đo (điểm, hoặc slide thiếu thông tin microns-per-pixel).'),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () {
                    _annotations.remove(annotation.id);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xóa chú thích'),
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
        return 'Điểm';
      case SvsAnnotationShapeType.rectangle:
        return 'Hình chữ nhật';
      case SvsAnnotationShapeType.polyline:
        return 'Đường gấp khúc';
      case SvsAnnotationShapeType.polygon:
        return 'Đa giác';
    }
  }

  Future<void> _confirmClearAnnotations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tất cả chú thích?'),
        content: const Text('Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Xóa')),
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
              ? 'Kéo để di chuyển, cuộn/chụm để phóng to'
              : 'Chạm vào ảnh để vẽ chú thích',
        ),
        actions: [
          if (_annotations.annotations.isNotEmpty)
            IconButton(
              onPressed: _confirmClearAnnotations,
              icon: const Icon(Icons.layers_clear_outlined),
              tooltip: 'Xóa tất cả chú thích',
            ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RegionExportScreen(svs: widget.svs, suggestedName: widget.suggestedExportName),
              ),
            ),
            icon: const Icon(Icons.crop),
            tooltip: 'Xuất vùng ảnh',
          ),
        ],
      ),
      body: SvsImageView(
        svsFile: widget.svs,
        diskCache: _diskCache,
        annotationController: _annotations,
        onAnnotationTap: _onAnnotationTap,
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
            label: 'Di chuyển',
            selected: drawMode == SvsAnnotationDrawMode.none,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.none),
          ),
          _ToolButton(
            icon: Icons.radio_button_checked,
            label: 'Điểm',
            selected: drawMode == SvsAnnotationDrawMode.point,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.point),
          ),
          _ToolButton(
            icon: Icons.crop_square,
            label: 'Chữ nhật',
            selected: drawMode == SvsAnnotationDrawMode.rectangle,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.rectangle),
          ),
          _ToolButton(
            icon: Icons.timeline,
            label: 'Đường',
            selected: drawMode == SvsAnnotationDrawMode.polyline,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.polyline),
          ),
          _ToolButton(
            icon: Icons.pentagon_outlined,
            label: 'Đa giác',
            selected: drawMode == SvsAnnotationDrawMode.polygon,
            onPressed: () => onSelectMode(SvsAnnotationDrawMode.polygon),
          ),
          if (showDone)
            _ToolButton(icon: Icons.check_circle_outline, label: 'Xong', selected: false, onPressed: onDone),
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
