import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onetime/services/random_key_generator_service.dart';

void main() {
  group('RandomKeyGeneratorService', () {
    late RandomKeyGeneratorService service;

    setUp(() {
      service = RandomKeyGeneratorService();
    });

    group('Key Generation', () {
      test('generates key of correct length in bits', () {
        final key = service.generateKey(1024);
        expect(key.length, equals(128)); // 1024 bits = 128 bytes
      });

      test('generates key of correct length for non-multiple of 8', () {
        final key = service.generateKey(100);
        expect(key.length, equals(13)); // ceil(100/8) = 13 bytes
      });

      test('generates different keys on successive calls', () {
        final key1 = service.generateKey(256);
        final key2 = service.generateKey(256);
        
        // Les clés doivent être différentes (probabilité d'égalité négligeable)
        bool areEqual = true;
        for (int i = 0; i < key1.length; i++) {
          if (key1[i] != key2[i]) {
            areEqual = false;
            break;
          }
        }
        expect(areEqual, isFalse);
      });

      test('generateKeyForQrCode returns correct size', () {
        final key = service.generateKeyForQrCode(version: 25);
        expect(key.length, equals(1024)); // Version 25 = 1024 bytes
      });
    });

    group('Camera Entropy', () {
      test('feedCameraEntropy accumulates entropy', () {
        expect(service.availableCameraEntropy, equals(0));
        
        service.feedCameraEntropy([100, 110, 105, 120, 115, 130]);
        expect(service.availableCameraEntropy, greaterThan(0));
      });

      test('feedCameraFrame extracts entropy from image', () {
        final imageData = Uint8List.fromList(
          List.generate(100 * 4, (i) => Random().nextInt(256))
        );
        
        service.feedCameraFrame(imageData, 10, 10, channels: 4);
        expect(service.availableCameraEntropy, greaterThan(0));
      });

      test('resetEntropyPool clears entropy', () {
        service.feedCameraEntropy([100, 110, 105, 120]);
        expect(service.availableCameraEntropy, greaterThan(0));
        
        service.resetEntropyPool();
        expect(service.availableCameraEntropy, equals(0));
      });

      test('throws when requiring camera entropy without enough', () {
        expect(
          () => service.generateKey(1000, requireCameraEntropy: true),
          throwsA(isA<InsufficientEntropyException>()),
        );
      });

      test('uses camera entropy when available', () {
        // Ajouter beaucoup d'entropie
        for (int i = 0; i < 100; i++) {
          service.feedCameraEntropy(
            List.generate(100, (j) => Random().nextInt(256))
          );
        }
        
        final initialEntropy = service.availableCameraEntropy;
        service.generateKey(100, requireCameraEntropy: true);
        
        // L'entropie doit avoir été consommée
        expect(service.availableCameraEntropy, lessThan(initialEntropy));
      });
    });

    group('Statistical Tests - Chi-Square', () {
      test('generated key passes chi-square test for uniformity', () {
        // Générer un échantillon significatif
        final key = service.generateKey(10000);
        final stats = service.getStats(key);
        
        // Le test chi-carré doit passer (< 3.841 pour 95% confiance)
        expect(stats.passesChiSquareTest, isTrue,
          reason: 'Chi-square: ${stats.chiSquare}, should be < 3.841');
      });

      test('chi-square test fails for biased data', () {
        // Créer des données biaisées (tous des 1)
        final biasedData = Uint8List.fromList(List.filled(100, 0xFF));
        final stats = RandomGeneratorStats.fromSample(biasedData);
        
        expect(stats.passesChiSquareTest, isFalse);
      });

      test('chi-square value is reasonable for random data', () {
        final key = service.generateKey(8000);
        final stats = service.getStats(key);
        
        // Chi-carré devrait être proche de 0 pour données uniformes
        // mais avec variance naturelle
        expect(stats.chiSquare, lessThan(10.0));
      });
    });

    group('Statistical Tests - Frequency', () {
      test('bit frequency is approximately 50/50', () {
        final key = service.generateKey(10000);
        final stats = service.getStats(key);
        
        final proportion = stats.ones / (stats.ones + stats.zeros);
        
        // La proportion de 1 doit être entre 45% et 55%
        expect(proportion, greaterThan(0.45));
        expect(proportion, lessThan(0.55));
        expect(stats.passesFrequencyTest, isTrue);
      });

      test('frequency test fails for biased data', () {
        // Données avec 80% de 1
        final biasedData = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0x00]);
        final stats = RandomGeneratorStats.fromSample(biasedData);
        
        expect(stats.passesFrequencyTest, isFalse);
      });
    });

    group('Statistical Tests - Runs', () {
      test('run count is reasonable for random data', () {
        final key = service.generateKey(8000);
        final stats = service.getStats(key);
        
        // Le nombre de runs devrait être proche de n/2
        final totalBits = stats.zeros + stats.ones;
        final expectedRuns = totalBits / 2;
        final deviation = (stats.runs - expectedRuns).abs() / expectedRuns;
        
        expect(deviation, lessThan(0.15)); // 15% de déviation max
        expect(stats.passesRunsTest, isTrue);
      });

      test('longest run is reasonable', () {
        final key = service.generateKey(8000);
        final stats = service.getStats(key);
        
        // Pour 8000 bits, le plus long run ne devrait pas dépasser ~20
        // (probabilité de run > 20 est 2^-20 ≈ 0.000001)
        expect(stats.longestRun, lessThan(25));
      });

      test('runs test fails for non-random data', () {
        // Données avec très peu de runs (longues séquences de même bit)
        final fewRuns = Uint8List.fromList([
          0xFF, 0xFF, 0xFF, 0xFF, // 32 bits de 1
          0x00, 0x00, 0x00, 0x00, // 32 bits de 0
          0xFF, 0xFF, 0xFF, 0xFF, // 32 bits de 1
        ]);
        final stats = RandomGeneratorStats.fromSample(fewRuns);
        
        // Seulement 3 runs pour 96 bits - très non-aléatoire
        expect(stats.runs, lessThan(10));
        expect(stats.passesRunsTest, isFalse);
      });
    });

    group('Statistical Tests - Combined', () {
      test('all tests pass for large random sample', () {
        final key = service.generateKey(20000);
        final stats = service.getStats(key);
        
        expect(stats.allTestsPassed, isTrue,
          reason: 'Stats: $stats');
      });

      test('multiple samples all pass tests', () {
        // Vérifier que plusieurs générations passent les tests
        int passed = 0;
        const trials = 10;
        
        for (int i = 0; i < trials; i++) {
          final key = service.generateKey(5000);
          final stats = service.getStats(key);
          if (stats.allTestsPassed) passed++;
        }
        
        // Au moins 90% des essais doivent passer
        expect(passed, greaterThanOrEqualTo(trials * 0.9));
      });
    });

    group('QR Code Capacity', () {
      test('maxQrCodeBits constant is reasonable', () {
        expect(RandomKeyGeneratorService.maxQrCodeBits, equals(23200));
      });

      test('recommendedQrCodeBits is achievable', () {
        expect(RandomKeyGeneratorService.recommendedQrCodeBits, equals(8192));
        
        final key = service.generateKey(
          RandomKeyGeneratorService.recommendedQrCodeBits
        );
        expect(key.length, equals(1024));
      });
    });

    group('Entropy Quality with Camera', () {
      test('camera entropy improves randomness', () {
        // Cette test vérifie que l'entropie caméra est utilisée
        final random = Random();
        
        // Simuler des données de caméra avec bruit
        for (int frame = 0; frame < 50; frame++) {
          final frameData = List.generate(
            1000,
            (i) => 128 + random.nextInt(20) - 10, // Variation autour de 128
          );
          service.feedCameraEntropy(frameData);
        }
        
        // Générer une clé avec entropie caméra
        final keyWithEntropy = service.generateKey(2000);
        final statsWithEntropy = service.getStats(keyWithEntropy);
        
        // Au minimum, les tests de base doivent passer
        expect(statsWithEntropy.passesFrequencyTest, isTrue);
        expect(statsWithEntropy.passesChiSquareTest, isTrue);
      });

      test('RGB channel variations contribute to entropy', () {
        // Simuler une image avec variations RGB
        final width = 100;
        final height = 100;
        final channels = 4; // RGBA
        final random = Random();
        
        final imageData = Uint8List(width * height * channels);
        for (int i = 0; i < imageData.length; i++) {
          imageData[i] = random.nextInt(256);
        }
        
        service.resetEntropyPool();
        service.feedCameraFrame(imageData, width, height, channels: channels);
        
        // Devrait avoir extrait de l'entropie de chaque canal RGB
        // (width * height - 1) pixels adjacents * 3 canaux * probabilité de diff != 0
        expect(service.availableCameraEntropy, greaterThan(0));
      });
    });
  });

  group('RandomGeneratorStats', () {
    test('fromSample calculates correct counts', () {
      // 0xFF = 11111111, 0x00 = 00000000
      final data = Uint8List.fromList([0xFF, 0x00]);
      final stats = RandomGeneratorStats.fromSample(data);
      
      expect(stats.ones, equals(8));
      expect(stats.zeros, equals(8));
    });

    test('toString provides readable output', () {
      final data = Uint8List.fromList(List.generate(100, (i) => i));
      final stats = RandomGeneratorStats.fromSample(data);
      
      final str = stats.toString();
      expect(str, contains('Zeros:'));
      expect(str, contains('Ones:'));
      expect(str, contains('Chi-Square:'));
      expect(str, contains('Runs:'));
    });
  });
}
