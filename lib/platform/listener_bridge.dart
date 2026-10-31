import 'package:flutter/services.dart';

/// Wrappers for the native channels implemented in MainActivity.kt.
class ListenerBridge {
  static const _method = MethodChannel('dev.dineth.recover/listener');
  static const _events = EventChannel('dev.dineth.recover/messages');

  static Future<bool> isPermissionGranted() async =>
      await _method.invokeMethod<bool>('isPermissionGranted') ?? false;

  static Future<void> openPermissionSettings() =>
      _method.invokeMethod('openPermissionSettings');

  static Future<bool> hasStorageAccess() async =>
      await _method.invokeMethod<bool>('hasStorageAccess') ?? false;

  static Future<void> openStorageSettings() =>
      _method.invokeMethod('openStorageSettings');

  /// Opens a captured file in an external app (throws if none can handle it).
  static Future<void> openFile(String path, String? mime) =>
      _method.invokeMethod('openFile', {'path': path, 'mime': mime});

  static Future<void> restartMediaWatcher() =>
      _method.invokeMethod('restartMediaWatcher');

  /// Emits whenever the native service stored a new message.
  static Stream<void> get onNewMessage =>
      _events.receiveBroadcastStream().map((_) {});
}
