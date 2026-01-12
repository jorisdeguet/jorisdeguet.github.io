import 'package:logger/logger.dart';

/// Simple application logger wrapper around `logger` package.
/// Supports enabling/disabling tags to control which messages are shown.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;

  final Logger _logger;
  final Set<String> _enabledTags = {};

  AppLogger._internal()
      : _logger = Logger(
          printer: PrettyPrinter(methodCount: 0),
        );

  /// Enable messages for a tag (e.g. 'KeyStorage', 'KeyExchange')
  void enableTag(String tag) => _enabledTags.add(tag);
  void disableTag(String tag) => _enabledTags.remove(tag);
  bool isTagEnabled(String tag) => _enabledTags.isEmpty || _enabledTags.contains(tag);

  void v(String tag, String message) {
    if (isTagEnabled(tag)) _logger.v('[$tag] $message');
  }

  void d(String tag, String message) {
    if (isTagEnabled(tag)) _logger.d('[$tag] $message');
  }

  void i(String tag, String message) {
    if (isTagEnabled(tag)) _logger.i('[$tag] $message');
  }

  void w(String tag, String message) {
    if (isTagEnabled(tag)) _logger.w('[$tag] $message');
  }

  void e(String tag, String message) {
    if (isTagEnabled(tag)) _logger.e('[$tag] $message');
  }
}

