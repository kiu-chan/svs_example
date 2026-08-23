import 'package:flutter/material.dart';
import 'package:svs/svs.dart';

/// Full-screen pannable/zoomable view of an already-opened [SvsFile].
class ViewerScreen extends StatelessWidget {
  final SvsFile svs;

  const ViewerScreen({super.key, required this.svs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Kéo để di chuyển, cuộn/chụm để phóng to'),
      ),
      body: SvsImageView(svsFile: svs),
    );
  }
}
