import 'package:logger/logger.dart';
import '../config/app_config.dart';

/// Simple application logger wrapper around `logger` package.
/// Supports enabling/disabling tags to control which messages are shown.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;

  final Logger _logger;
  final Set<String> _enabledTags = {};
  final int _minLevel;

  AppLogger._internal()
      : _logger = Logger(
          printer: PrettyPrinter(methodCount: 0),
        ) {
    // Initialize enabled tags from AppConfig
    if (AppConfig.enabledLogTags.isNotEmpty) {
      for (final t in AppConfig.enabledLogTags) {
        _enabledTags.add(t);
      }
    }

    // Initialize minimum log level
    _minLevel = _levelFromString(AppConfig.minLogLevel);
  }

  /// Enable messages for a tag (e.g. 'KeyStorage', 'KeyExchange')
  void enableTag(String tag) => _enabledTags.add(tag);
  void disableTag(String tag) => _enabledTags.remove(tag);
  bool isTagEnabled(String tag) => _enabledTags.isEmpty || _enabledTags.contains(tag);

  int _levelFromString(String s) {
    switch (s.toLowerCase()) {
      case 'verbose':
      case 'v':
        return 0;
      case 'debug':
      case 'd':
        return 1;
      case 'info':
      case 'i':
        return 2;
      case 'warn':
      case 'w':
        return 3;
      case 'error':
      case 'e':
        return 4;
      case 'off':
        return 999;
      default:
        return 1;
    }
  }

  bool _levelEnabled(int level) => level >= _minLevel && _minLevel != 999;

  void v(String tag, String message) {
    if (isTagEnabled(tag) && _levelEnabled(0)) _logger.v('[$tag] $message');
  }

  void d(String tag, String message) {
    if (isTagEnabled(tag) && _levelEnabled(1)) _logger.d('[$tag] $message');
  }

  void i(String tag, String message) {
    if (isTagEnabled(tag) && _levelEnabled(2)) _logger.i('[$tag] $message');
  }

  void w(String tag, String message) {
    if (isTagEnabled(tag) && _levelEnabled(3)) _logger.w('[$tag] $message');
  }

  void e(String tag, String message) {
    if (isTagEnabled(tag) && _levelEnabled(4)) _logger.e('[$tag] $message');
  }
}
