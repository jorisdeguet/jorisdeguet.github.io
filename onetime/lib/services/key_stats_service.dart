import '../model_local/shared_key.dart';
import 'format_service.dart';

/// Service pour calculer les statistiques de clé disponible
class KeyStatsService {
  /// Calcule les octets disponibles dans une clé partagée
  static int getAvailableBytes(SharedKey? sharedKey, String localPeerId) {
    if (sharedKey == null) return 0;
    return sharedKey.countAvailableBytes(localPeerId);
  }

  /// Calcule les KB disponibles dans une clé partagée
  static double getAvailableKB(SharedKey? sharedKey, String localPeerId) {
    final bytes = getAvailableBytes(sharedKey, localPeerId);
    return bytes / 1024.0; // bytes -> KB
  }

  /// Formatte les octets disponibles pour affichage
  static String formatAvailableKey(SharedKey? sharedKey, String localPeerId) {
    final bytes = getAvailableBytes(sharedKey, localPeerId);
    return FormatService.formatBytes(bytes);
  }

  /// Calcule le pourcentage de clé restante
  static double getAvailablePercent(SharedKey? sharedKey, String localPeerId) {
    if (sharedKey == null) return 0;
    // Allocation linéaire : on utilise la taille totale de la clé
    final totalBytes = sharedKey.lengthInBytes;
    if (totalBytes == 0) return 0;
    final availableBytes = getAvailableBytes(sharedKey, localPeerId);
    return (availableBytes / totalBytes) * 100;
  }
}
