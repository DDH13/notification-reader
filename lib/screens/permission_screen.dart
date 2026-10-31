import 'package:flutter/material.dart';

import '../platform/listener_bridge.dart';
import '../util.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.notifications_active, size: 80, color: waDark),
              const SizedBox(height: 24),
              Text('Notification access needed',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Recover reads your WhatsApp notifications to keep a copy of '
                'every message, so you can still read them if they are '
                'deleted later. Everything stays on this device.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: waDark),
                onPressed: ListenerBridge.openPermissionSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Grant notification access'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: ListenerBridge.openStorageSettings,
                icon: const Icon(Icons.folder_open),
                label: const Text('Allow All files access to save media'),
              ),
              const SizedBox(height: 8),
              Text(
                'Optional. Lets Recover keep copies of voice notes, photos and '
                'other media WhatsApp downloads. Text capture works without it.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Tip: also disable battery optimization for Recover so the '
                'system does not stop it in the background.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
