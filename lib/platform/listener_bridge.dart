import 'package:flutter/services.dart';

/// Wrappers for the native channels implemented in MainActivity.kt.
class ListenerBridge {
  static const _method = MethodChannel('dev.dineth.recover/listener');
  static const _events = EventChannel('dev.dineth.recover/messages');

  static Future<bool> isPermissionGranted() async =>
      await _method.invokeMethod<bool>('isPermissionGranted') ?? false;

  static Future<void> openPermissionSettings() =>
      _method.invokeMethod('openPermissionSettings');

  /// Emits whenever the native service stored a new message.
  static Stream<void> get onNewMessage =>
      _events.receiveBroadcastStream().map((_) {});
}
