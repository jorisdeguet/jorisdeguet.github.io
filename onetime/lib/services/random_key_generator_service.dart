import 'dart:math';
import 'dart:typed_data';

/// Service de génération de clés aléatoires avec source d'entropie caméra.
/// 
/// Utilise les variations de luminosité entre pixels de la caméra comme
/// source d'entropie pour générer des bits aléatoires de haute qualité.
class RandomKeyGeneratorService {
  final Random _fallbackRandom = Random.secure();
  
  /// Pool d'entropie accumulée depuis la caméra
  final List<int> _entropyPool = [];
  
  /// Index de lecture dans le pool d'entropie
  int _entropyIndex = 0;
  
  /// Compteur de bits générés pour les statistiques
  int _bitsGenerated = 0;

  /// Capacité maximale d'un QR code en mode binaire (Version 40, niveau L)
  /// En pratique, on utilise ~2900 octets soit ~23200 bits
  static const int maxQrCodeBits = 23200;
  
  /// Taille recommandée pour un QR code facilement scannable (Version 25)
  static const int recommendedQrCodeBits = 8192; // 1024 octets

  /// Ajoute des données de pixels de caméra au pool d'entropie.
  /// 
  /// [rgbData] contient les valeurs RGB des pixels sous forme de liste d'entiers.
  /// L'entropie est extraite des changements entre frames successives.
  void feedCameraEntropy(List<int> rgbData) {
    if (rgbData.length < 2) return;
    
    // Extraire l'entropie des différences entre pixels adjacents
    for (int i = 1; i < rgbData.length; i++) {
      final diff = rgbData[i] - rgbData[i - 1];
      // Utiliser le signe de la différence comme bit d'entropie
      // +1 si augmentation, 0 si diminution ou égal
      if (diff != 0) {
        _entropyPool.add(diff > 0 ? 1 : 0);
      }
    }
    
    // Limiter la taille du pool pour éviter la consommation mémoire
    while (_entropyPool.length > 100000) {
      _entropyPool.removeAt(0);
      if (_entropyIndex > 0) _entropyIndex--;
    }
  }

  /// Ajoute de l'entropie depuis une image de caméra (format RGBA ou RGB).
  /// 
  /// [imageData] - Bytes de l'image
  /// [width] - Largeur en pixels
  /// [height] - Hauteur en pixels
  /// [channels] - Nombre de canaux (3 pour RGB, 4 pour RGBA)
  void feedCameraFrame(Uint8List imageData, int width, int height, {int channels = 4}) {
    final pixelCount = width * height;
    
    for (int i = 0; i < pixelCount - 1; i++) {
      final idx1 = i * channels;
      final idx2 = (i + 1) * channels;
      
      if (idx2 + 2 < imageData.length) {
        // Extraire entropie de chaque canal RGB
        for (int c = 0; c < 3; c++) {
          final diff = imageData[idx2 + c] - imageData[idx1 + c];
          if (diff != 0) {
            _entropyPool.add(diff > 0 ? 1 : 0);
          }
        }
      }
    }
  }

  /// Extrait un bit du pool d'entropie.
  /// Retourne null si le pool est épuisé.
  int? _extractEntropyBit() {
    if (_entropyIndex >= _entropyPool.length) {
      return null;
    }
    return _entropyPool[_entropyIndex++];
  }

  /// Génère un bit aléatoire en utilisant l'entropie disponible.
  /// 
  /// Utilise d'abord l'entropie de la caméra, puis le générateur
  /// cryptographique sécurisé comme fallback.
  int _generateBit() {
    final entropyBit = _extractEntropyBit();
    if (entropyBit != null) {
      // XOR avec un bit du CSPRNG pour renforcer l'aléatoire
      final csprngBit = _fallbackRandom.nextInt(2);
      return entropyBit ^ csprngBit;
    }
    // Fallback sur le CSPRNG uniquement
    return _fallbackRandom.nextInt(2);
  }

  /// Génère une clé aléatoire de la taille spécifiée en bits.
  /// 
  /// [lengthInBits] - Longueur de la clé en bits
  /// [requireCameraEntropy] - Si true, lance une exception si pas assez d'entropie caméra
  Uint8List generateKey(int lengthInBits, {bool requireCameraEntropy = false}) {
    if (requireCameraEntropy) {
      final availableEntropy = _entropyPool.length - _entropyIndex;
      if (availableEntropy < lengthInBits) {
        throw InsufficientEntropyException(
          'Not enough camera entropy: $availableEntropy bits available, $lengthInBits needed',
        );
      }
    }
    
    final bytesNeeded = (lengthInBits + 7) ~/ 8;
    final result = Uint8List(bytesNeeded);
    
    for (int i = 0; i < lengthInBits; i++) {
      final bit = _generateBit();
      final byteIndex = i ~/ 8;
      final bitOffset = i % 8;
      if (bit == 1) {
        result[byteIndex] |= (1 << bitOffset);
      }
    }
    
    _bitsGenerated += lengthInBits;
    return result;
  }

  /// Génère une clé optimisée pour un QR code.
  /// 
  /// [version] - Version du QR code (1-40), affecte la capacité
  Uint8List generateKeyForQrCode({int version = 25}) {
    // Capacités approximatives en octets pour différentes versions QR (niveau L)
    final capacities = <int, int>{
      10: 174,
      15: 412,
      20: 666,
      25: 1024,
      30: 1370,
      35: 1732,
      40: 2953,
    };
    
    final capacity = capacities[version] ?? 1024;
    return generateKey(capacity * 8);
  }

  /// Retourne le nombre de bits d'entropie caméra disponibles
  int get availableCameraEntropy => _entropyPool.length - _entropyIndex;
  
  /// Retourne le nombre total de bits générés
  int get totalBitsGenerated => _bitsGenerated;
  
  /// Réinitialise le pool d'entropie
  void resetEntropyPool() {
    _entropyPool.clear();
    _entropyIndex = 0;
  }

  /// Calcule des statistiques sur le générateur pour validation.
  RandomGeneratorStats getStats(Uint8List sample) {
    return RandomGeneratorStats.fromSample(sample);
  }
}

/// Exception levée quand il n'y a pas assez d'entropie caméra
class InsufficientEntropyException implements Exception {
  final String message;
  InsufficientEntropyException(this.message);
  
  @override
  String toString() => 'InsufficientEntropyException: $message';
}

/// Statistiques pour valider la qualité du générateur aléatoire
class RandomGeneratorStats {
  /// Nombre de 0 dans l'échantillon
  final int zeros;
  
  /// Nombre de 1 dans l'échantillon
  final int ones;
  
  /// Statistique Chi-carré pour le test d'uniformité
  final double chiSquare;
  
  /// Nombre de runs (séquences consécutives de même bit)
  final int runs;
  
  /// Longueur du plus long run
  final int longestRun;
  
  /// Test passé ?
  final bool passesFrequencyTest;
  final bool passesRunsTest;
  final bool passesChiSquareTest;

  RandomGeneratorStats({
    required this.zeros,
    required this.ones,
    required this.chiSquare,
    required this.runs,
    required this.longestRun,
    required this.passesFrequencyTest,
    required this.passesRunsTest,
    required this.passesChiSquareTest,
  });

  /// Analyse un échantillon de données
  factory RandomGeneratorStats.fromSample(Uint8List sample) {
    int zeros = 0;
    int ones = 0;
    int runs = 1;
    int currentRun = 1;
    int longestRun = 1;
    int? lastBit;
    
    for (int i = 0; i < sample.length * 8; i++) {
      final byteIndex = i ~/ 8;
      final bitOffset = i % 8;
      final bit = (sample[byteIndex] >> bitOffset) & 1;
      
      if (bit == 0) {
        zeros++;
      } else {
        ones++;
      }
      
      if (lastBit != null) {
        if (bit == lastBit) {
          currentRun++;
          if (currentRun > longestRun) longestRun = currentRun;
        } else {
          runs++;
          currentRun = 1;
        }
      }
      lastBit = bit;
    }
    
    final total = zeros + ones;
    final expected = total / 2;
    
    // Test Chi-carré pour la fréquence des bits
    final chiSquare = ((zeros - expected) * (zeros - expected) / expected) +
                     ((ones - expected) * (ones - expected) / expected);
    
    // Seuils pour les tests (niveau de confiance 95%)
    // Chi-carré critique pour 1 degré de liberté : 3.841
    final passesChiSquare = chiSquare < 3.841;
    
    // Test de fréquence : proportion de 1 entre 0.45 et 0.55
    final proportion = ones / total;
    final passesFrequency = proportion > 0.45 && proportion < 0.55;
    
    // Test des runs : nombre attendu ~= n/2 pour bits équilibrés
    final expectedRuns = total / 2;
    final runsDeviation = (runs - expectedRuns).abs() / expectedRuns;
    final passesRuns = runsDeviation < 0.1; // 10% de déviation max
    
    return RandomGeneratorStats(
      zeros: zeros,
      ones: ones,
      chiSquare: chiSquare,
      runs: runs,
      longestRun: longestRun,
      passesFrequencyTest: passesFrequency,
      passesRunsTest: passesRuns,
      passesChiSquareTest: passesChiSquare,
    );
  }

  /// Tous les tests passent
  bool get allTestsPassed => passesFrequencyTest && passesRunsTest && passesChiSquareTest;

  @override
  String toString() {
    return '''RandomGeneratorStats:
  Zeros: $zeros, Ones: $ones (${(ones / (zeros + ones) * 100).toStringAsFixed(2)}%)
  Chi-Square: ${chiSquare.toStringAsFixed(4)} (${passesChiSquareTest ? 'PASS' : 'FAIL'})
  Runs: $runs, Longest Run: $longestRun (${passesRunsTest ? 'PASS' : 'FAIL'})
  Frequency Test: ${passesFrequencyTest ? 'PASS' : 'FAIL'}
  Overall: ${allTestsPassed ? 'PASS' : 'FAIL'}''';
  }
}
