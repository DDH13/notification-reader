import 'dart:async';

import 'package:flutter/material.dart';

import 'platform/listener_bridge.dart';
import 'screens/chat_list_screen.dart';
import 'screens/permission_screen.dart';
import 'util.dart';

void main() => runApp(const RecoverApp());

class RecoverApp extends StatelessWidget {
  const RecoverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: waDark,
      primary: waDark,
      secondary: waGreen,
    );
    return MaterialApp(
      title: 'Recover',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: waDark,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(backgroundColor: waGreen),
      ),
      home: const _Gate(),
    );
  }
}

/// Shows the permission screen until notification access is granted.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final granted = await ListenerBridge.isPermissionGranted();
    if (mounted && granted != _granted) setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) => switch (_granted) {
        null => const Scaffold(body: Center(child: CircularProgressIndicator())),
        true => const ChatListScreen(),
        false => const PermissionScreen(),
      };
}
