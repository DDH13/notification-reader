import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../widgets/media_content.dart';

/// Captured files that never matched a notification message.
class UnlinkedMediaScreen extends StatefulWidget {
  const UnlinkedMediaScreen({super.key});

  @override
  State<UnlinkedMediaScreen> createState() => _UnlinkedMediaScreenState();
}

class _UnlinkedMediaScreenState extends State<UnlinkedMediaScreen> {
  List<MediaItem>? _items;

  @override
  void initState() {
    super.initState();
    AppDb.instance.unlinkedMedia().then((v) {
      if (mounted) setState(() => _items = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Unlinked media')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('No unlinked media.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final ts = m.fileTs;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MediaContent(kind: m.kind, path: m.path, mime: m.mime),
                          if (ts != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat.yMMMd().add_jm().format(
                                    DateTime.fromMillisecondsSinceEpoch(ts)),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
