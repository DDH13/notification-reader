import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../util.dart';

/// Play/pause + seek bar for a local audio file. The player is created lazily
/// on first play so a long chat does not spin up one decoder per bubble.
class VoicePlayer extends StatefulWidget {
  const VoicePlayer({super.key, required this.path});
  final String path;

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  AudioPlayer? _player;
  bool _failed = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    var player = _player;
    if (player == null) {
      player = _player = AudioPlayer();
      setState(() {});
      try {
        await player.setFilePath(widget.path);
      } catch (_) {
        if (mounted) setState(() => _failed = true);
        return;
      }
    }
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      unawaited(player.play());
    }
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Could not play this file',
            style: TextStyle(color: Colors.black54)),
      );
    }
    final player = _player;
    return SizedBox(
      width: 240,
      child: Row(children: [
        StreamBuilder<bool>(
          stream: player?.playingStream,
          initialData: false,
          builder: (_, snap) => IconButton(
            icon: Icon(snap.data == true ? Icons.pause : Icons.play_arrow),
            color: waDark,
            onPressed: _toggle,
          ),
        ),
        Expanded(
          child: StreamBuilder<Duration?>(
            stream: player?.durationStream,
            builder: (_, durSnap) {
              final total = durSnap.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: player?.positionStream,
                initialData: Duration.zero,
                builder: (_, posSnap) {
                  final pos = posSnap.data ?? Duration.zero;
                  final max = total.inMilliseconds.toDouble();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        value: max <= 0
                            ? 0
                            : pos.inMilliseconds.clamp(0, max.toInt()).toDouble(),
                        max: max <= 0 ? 1 : max,
                        onChanged: max <= 0
                            ? null
                            : (v) => player?.seek(Duration(milliseconds: v.toInt())),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Text(
                            max <= 0 ? '' : '${_fmt(pos)} / ${_fmt(total)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
