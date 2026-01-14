import 'package:flutter/foundation.dart';

import 'background_message_service.dart';

/// Simple singleton locator for the background message service.
/// Use [init] once (for example at app startup) and then access [instance].
class BackgroundServiceLocator {
  BackgroundServiceLocator._();

  static BackgroundMessageService? _instance;

  /// Initialize the locator with the local user id. Safe to call multiple times;
  /// if _instance already exists it will be returned.
  static BackgroundMessageService init({required String localUserId}) {
    if (_instance == null) {
      _instance = BackgroundMessageService(localUserId: localUserId);
      // Start watching by default
      _instance!.startWatchingUserConversations();
    }
    return _instance!;
  }

  /// Returns the existing instance. Throws if not initialized.
  static BackgroundMessageService get instance {
    if (_instance == null) {
      throw FlutterError('BackgroundServiceLocator not initialized. Call BackgroundServiceLocator.init(localUserId: ...)');
    }
    return _instance!;
  }

  /// Optional helper to stop and clear the instance (for sign-out).
  static Future<void> dispose() async {
    if (_instance != null) {
      await _instance!.stopAll();
      await _instance!.stopWatchingUserConversations();
      _instance = null;
    }
  }
}

