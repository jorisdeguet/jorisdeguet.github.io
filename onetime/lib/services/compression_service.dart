import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Service de compression des messages avant chiffrement.
/// 
/// Utilise GZIP pour compresser les messages texte, ce qui peut
/// réduire significativement la consommation de clé OTP.
class CompressionService {
  /// Compresse une chaîne de caractères.
  /// 
  /// Retourne les données compressées en bytes.
  Uint8List compress(String text) {
    final bytes = utf8.encode(text);
    final compressed = gzip.encode(bytes);
    return Uint8List.fromList(compressed);
  }

  /// Décompresse des données en chaîne de caractères.
  Uint8List decompress(Uint8List compressedData) {
    final decompressed = gzip.decode(compressedData);
    return Uint8List.fromList(decompressed);
  }

  /// Compresse et retourne le texte décompressé (pour vérification).
  String compressAndDecompress(String text) {
    final compressed = compress(text);
    final decompressed = decompress(compressed);
    return utf8.decode(decompressed);
  }

  /// Calcule le ratio de compression pour un texte.
  /// 
  /// Retourne un ratio < 1 si la compression est efficace.
  /// Exemple: 0.5 = 50% de la taille originale.
  double getCompressionRatio(String text) {
    final originalSize = utf8.encode(text).length;
    final compressedSize = compress(text).length;
    return compressedSize / originalSize;
  }

  /// Calcule les économies en bits pour un texte.
  CompressionStats getStats(String text) {
    final originalBytes = utf8.encode(text);
    final compressedBytes = compress(text);
    
    return CompressionStats(
      originalSizeBytes: originalBytes.length,
      compressedSizeBytes: compressedBytes.length,
      originalSizeBits: originalBytes.length * 8,
      compressedSizeBits: compressedBytes.length * 8,
    );
  }

  /// Vérifie si la compression est bénéfique pour un texte.
  /// 
  /// La compression GZIP a un overhead, donc pour les très courts
  /// messages, elle peut augmenter la taille.
  bool isCompressionBeneficial(String text) {
    return getCompressionRatio(text) < 1.0;
  }

  /// Compresse uniquement si bénéfique, sinon retourne les bytes originaux.
  /// 
  /// Retourne un tuple (données, estCompressé).
  ({Uint8List data, bool isCompressed}) smartCompress(String text) {
    final original = Uint8List.fromList(utf8.encode(text));
    final compressed = compress(text);
    
    if (compressed.length < original.length) {
      return (data: compressed, isCompressed: true);
    }
    return (data: original, isCompressed: false);
  }

  /// Décompresse si les données étaient compressées.
  String smartDecompress(Uint8List data, bool wasCompressed) {
    if (wasCompressed) {
      return utf8.decode(decompress(data));
    }
    return utf8.decode(data);
  }
}

/// Statistiques de compression pour un message.
class CompressionStats {
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int originalSizeBits;
  final int compressedSizeBits;

  CompressionStats({
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.originalSizeBits,
    required this.compressedSizeBits,
  });

  /// Ratio de compression (< 1 = compression efficace)
  double get ratio => compressedSizeBytes / originalSizeBytes;
  
  /// Pourcentage de réduction de taille
  double get reductionPercent => (1 - ratio) * 100;
  
  /// Bits économisés
  int get bitsSaved => originalSizeBits - compressedSizeBits;
  
  /// Bytes économisés
  int get bytesSaved => originalSizeBytes - compressedSizeBytes;

  @override
  String toString() {
    return 'CompressionStats: ${originalSizeBytes}B -> ${compressedSizeBytes}B '
           '(${reductionPercent.toStringAsFixed(1)}% saved, ${bitsSaved} bits)';
  }
}

/// Résultats d'analyse de compression sur un ensemble de messages.
class CompressionBenchmark {
  final List<CompressionStats> stats;
  final List<String> messages;

  CompressionBenchmark({required this.stats, required this.messages});

  /// Ratio de compression moyen
  double get averageRatio {
    if (stats.isEmpty) return 1.0;
    return stats.map((s) => s.ratio).reduce((a, b) => a + b) / stats.length;
  }

  /// Réduction moyenne en pourcentage
  double get averageReductionPercent => (1 - averageRatio) * 100;

  /// Total des bits économisés
  int get totalBitsSaved => stats.fold(0, (sum, s) => sum + s.bitsSaved);

  /// Total des bytes originaux
  int get totalOriginalBytes => stats.fold(0, (sum, s) => sum + s.originalSizeBytes);

  /// Total des bytes compressés
  int get totalCompressedBytes => stats.fold(0, (sum, s) => sum + s.compressedSizeBytes);

  /// Nombre de messages où la compression est bénéfique
  int get beneficialCount => stats.where((s) => s.ratio < 1.0).length;

  /// Pourcentage de messages avec compression bénéfique
  double get beneficialPercent => (beneficialCount / stats.length) * 100;

  @override
  String toString() {
    return '''
CompressionBenchmark (${stats.length} messages):
  Average ratio: ${averageRatio.toStringAsFixed(3)}
  Average reduction: ${averageReductionPercent.toStringAsFixed(1)}%
  Total saved: ${totalBitsSaved} bits (${(totalBitsSaved / 8).toStringAsFixed(0)} bytes)
  Beneficial for: ${beneficialCount}/${stats.length} messages (${beneficialPercent.toStringAsFixed(1)}%)
  Original total: ${totalOriginalBytes} bytes
  Compressed total: ${totalCompressedBytes} bytes
''';
  }
}
