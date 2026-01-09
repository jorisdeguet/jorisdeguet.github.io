/// Service utilitaire pour le formatage (bytes, dates, etc.)
class FormatService {
  /// Formate une taille en octets en format lisible (B, KB, MB)
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
