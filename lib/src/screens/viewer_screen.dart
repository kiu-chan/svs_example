import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

import 'region_export_screen.dart';

/// Full-screen pannable/zoomable view of an already-opened [SvsFile].
class ViewerScreen extends StatelessWidget {
  final SvsFile svs;
  final String suggestedExportName;

  const ViewerScreen({super.key, required this.svs, required this.suggestedExportName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Kéo để di chuyển, cuộn/chụm để phóng to'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RegionExportScreen(svs: svs, suggestedName: suggestedExportName)),
            ),
            icon: const Icon(Icons.crop),
            tooltip: 'Xuất vùng ảnh',
          ),
        ],
      ),
      body: SvsImageView(svsFile: svs),
    );
  }
}
