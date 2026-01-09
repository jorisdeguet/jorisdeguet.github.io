import '../models/shared_key.dart';
import 'format_service.dart';

/// Service pour calculer les statistiques de clé disponible
class KeyStatsService {
  /// Calcule les bits disponibles dans une clé partagée
  static int getAvailableBits(SharedKey? sharedKey, String localPeerId) {
    if (sharedKey == null) return 0;
    return sharedKey.countAvailableBits(localPeerId);
  }

  /// Calcule les KB disponibles dans une clé partagée
  static double getAvailableKB(SharedKey? sharedKey, String localPeerId) {
    final bits = getAvailableBits(sharedKey, localPeerId);
    return bits / 8 / 1024; // bits -> bytes -> KB
  }

  /// Formatte les KB disponibles pour affichage
  static String formatAvailableKey(SharedKey? sharedKey, String localPeerId) {
    final bits = getAvailableBits(sharedKey, localPeerId);
    final bytes = bits ~/ 8;
    return FormatService.formatBytes(bytes);
  }

  /// Calcule le pourcentage de clé restante
  static double getAvailablePercent(SharedKey? sharedKey, String localPeerId) {
    if (sharedKey == null) return 0;
    final segment = sharedKey.getSegmentForPeer(localPeerId);
    final totalBits = segment.endBit - segment.startBit;
    if (totalBits == 0) return 0;
    final availableBits = getAvailableBits(sharedKey, localPeerId);
    return (availableBits / totalBits) * 100;
  }
}
