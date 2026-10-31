import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen, zoomable view of a captured image.
class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: Center(
          child: InteractiveViewer(
            maxScale: 6,
            child: Image.file(
              File(path),
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image,
                  color: Colors.white54, size: 64),
            ),
          ),
        ),
      );
}
