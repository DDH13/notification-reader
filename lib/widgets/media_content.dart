import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../platform/listener_bridge.dart';
import '../screens/image_viewer.dart';
import '../util.dart';
import 'voice_player.dart';

/// Renders a captured media file according to its kind.
class MediaContent extends StatelessWidget {
  const MediaContent({
    super.key,
    required this.kind,
    required this.path,
    this.mime,
  });

  final String kind;
  final String path;
  final String? mime;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case 'image':
      case 'sticker':
      case 'gif':
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ImageViewer(path: path))),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _FileTile(
                    icon: Icons.broken_image, path: path, mime: mime),
              ),
            ),
          ),
        );
      case 'voice':
      case 'audio':
        return VoicePlayer(path: path);
      case 'video':
        return _FileTile(icon: Icons.videocam, path: path, mime: mime);
      default:
        return _FileTile(icon: Icons.insert_drive_file, path: path, mime: mime);
    }
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.icon, required this.path, this.mime});
  final IconData icon;
  final String path;
  final String? mime;

  Future<void> _open(BuildContext context) async {
    try {
      await ListenerBridge.openFile(path, mime);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app can open this file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: waDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(p.basename(path),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
}
