import 'package:flutter_test/flutter_test.dart';
import 'package:onetime/services/compression_service.dart';

void main() {
  group('CompressionService', () {
    late CompressionService service;

    setUp(() {
      service = CompressionService();
    });

    group('Basic compression', () {
      test('compress and decompress returns original text', () {
        const original = 'Hello, World!';
        final result = service.compressAndDecompress(original);
        expect(result, equals(original));
      });

      test('compress and decompress works with unicode', () {
        const original = 'Bonjour le monde! 🌍 日本語 العربية';
        final result = service.compressAndDecompress(original);
        expect(result, equals(original));
      });

      test('compress and decompress works with long text', () {
        final original = 'Lorem ipsum ' * 100;
        final result = service.compressAndDecompress(original);
        expect(result, equals(original));
      });
    });

    group('Compression ratio', () {
      test('short messages may not benefit from compression', () {
        const shortMessage = 'Hi!';
        final ratio = service.getCompressionRatio(shortMessage);
        // Short messages often expand due to GZIP header overhead
        expect(ratio, greaterThan(0));
      });

      test('repetitive text compresses well', () {
        final repetitive = 'AAAAAAAAAA' * 100; // 1000 As
        final ratio = service.getCompressionRatio(repetitive);
        expect(ratio, lessThan(0.1)); // Should compress to less than 10%
      });

      test('random-looking text compresses less', () {
        const randomLike = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0';
        final ratio = service.getCompressionRatio(randomLike);
        // Random text doesn't compress as well
        expect(ratio, greaterThan(0.5));
      });
    });

    group('Smart compression', () {
      test('smartCompress uses compression when beneficial', () {
        final longText = 'This is a test message that repeats. ' * 20;
        final result = service.smartCompress(longText);
        expect(result.isCompressed, isTrue);
        expect(result.data.length, lessThan(longText.length));
      });

      test('smartCompress skips compression for short messages', () {
        const shortText = 'Hi';
        final result = service.smartCompress(shortText);
        // May or may not compress depending on overhead
        expect(result.data.isNotEmpty, isTrue);
      });

      test('smartDecompress reverses smartCompress', () {
        const original = 'Test message for round trip';
        final compressed = service.smartCompress(original);
        final decompressed = service.smartDecompress(
          compressed.data, 
          compressed.isCompressed,
        );
        expect(decompressed, equals(original));
      });
    });

    group('Statistics', () {
      test('getStats returns correct values', () {
        const text = 'Hello, World!';
        final stats = service.getStats(text);
        
        expect(stats.originalSizeBytes, equals(13)); // "Hello, World!"
        expect(stats.originalSizeBits, equals(104)); // 13 * 8
        expect(stats.compressedSizeBytes, greaterThan(0));
        expect(stats.ratio, greaterThan(0));
      });

      test('stats show savings for compressible text', () {
        final compressible = 'The quick brown fox ' * 50;
        final stats = service.getStats(compressible);
        
        expect(stats.reductionPercent, greaterThan(50)); // Should save >50%
        expect(stats.bitsSaved, greaterThan(0));
      });
    });

    group('Typical chat messages benchmark', () {
      final typicalMessages = [
        // Salutations courtes
        'Salut!',
        'Hello',
        'Coucou',
        'Hey',
        'Yo',
        
        // Messages courts
        'Ça va?',
        'Oui et toi?',
        'On se voit ce soir?',
        'OK parfait',
        'D\'accord',
        
        // Messages moyens
        'Je serai là dans 10 minutes environ',
        'Tu peux m\'appeler quand tu as le temps?',
        'J\'ai vu ton message, je te réponds bientôt',
        'Merci beaucoup pour ton aide!',
        'Bonne journée à toi aussi!',
        
        // Messages longs
        'Je voulais te dire que j\'ai bien reçu le document et que tout me semble correct. On peut valider de mon côté.',
        'Salut, j\'espère que tu vas bien! Je voulais prendre de tes nouvelles. Ça fait longtemps qu\'on ne s\'est pas vus.',
        'Pour la réunion de demain, peux-tu préparer les slides sur le projet Alpha? Il faudrait aussi inclure les chiffres du trimestre.',
        
        // Avec emojis
        '😊',
        '👍',
        '❤️',
        'Super! 🎉🎉🎉',
        'Haha 😂😂😂',
        
        // Avec répétitions
        'Ouiiiiiiii!',
        'Nooooooon!',
        'hahahahaha',
        '!!!!!!!!!',
        
        // Adresses et infos
        '123 rue de la Paix, Paris 75001',
        'Mon numéro: 06 12 34 56 78',
        'rdv@email.com',
        
        // Questions
        'Tu es où?',
        'À quelle heure?',
        'C\'est quoi le code wifi?',
        'Tu as reçu mon message?',
      ];

      test('benchmark on typical messages', () {
        final stats = typicalMessages.map((m) => service.getStats(m)).toList();
        final benchmark = CompressionBenchmark(
          stats: stats,
          messages: typicalMessages,
        );
        
        // Afficher les résultats pour analyse
        print(benchmark);
        
        // La plupart des messages courts ne bénéficient pas de la compression
        // mais les messages plus longs oui
        expect(benchmark.stats.length, equals(typicalMessages.length));
      });

      test('individual message compression analysis', () {
        print('\n=== Analyse de compression par message ===\n');
        
        for (final msg in typicalMessages) {
          final stats = service.getStats(msg);
          final status = stats.ratio < 1.0 ? '✓' : '✗';
          print('$status "${msg.length > 40 ? '${msg.substring(0, 37)}...' : msg}"');
          print('   Original: ${stats.originalSizeBytes}B -> Compressed: ${stats.compressedSizeBytes}B');
          print('   Ratio: ${stats.ratio.toStringAsFixed(2)} (${stats.reductionPercent.toStringAsFixed(1)}% saved)\n');
        }
      });

      test('compression threshold analysis', () {
        // Trouver à partir de quelle taille la compression devient bénéfique
        final testSizes = [10, 20, 30, 40, 50, 75, 100, 150, 200, 300, 500];
        
        print('\n=== Seuil de compression (texte répétitif) ===\n');
        for (final size in testSizes) {
          final text = 'test ' * (size ~/ 5);
          final stats = service.getStats(text);
          final status = stats.ratio < 1.0 ? '✓' : '✗';
          print('$status ${text.length} chars: ratio=${stats.ratio.toStringAsFixed(2)}');
        }
        
        print('\n=== Seuil de compression (texte varié) ===\n');
        for (final size in testSizes) {
          final text = List.generate(size, (i) => String.fromCharCode(65 + (i % 26))).join();
          final stats = service.getStats(text);
          final status = stats.ratio < 1.0 ? '✓' : '✗';
          print('$status ${text.length} chars: ratio=${stats.ratio.toStringAsFixed(2)}');
        }
      });

      test('compression savings summary', () {
        int totalOriginal = 0;
        int totalCompressed = 0;
        int beneficialCount = 0;
        
        for (final msg in typicalMessages) {
          final stats = service.getStats(msg);
          totalOriginal += stats.originalSizeBytes;
          totalCompressed += stats.compressedSizeBytes;
          if (stats.ratio < 1.0) beneficialCount++;
        }
        
        // Utiliser smart compression pour le total réel
        int smartTotal = 0;
        for (final msg in typicalMessages) {
          final result = service.smartCompress(msg);
          smartTotal += result.data.length;
        }
        
        print('\n=== Résumé des économies ===');
        print('Messages: ${typicalMessages.length}');
        print('Compression bénéfique: $beneficialCount/${typicalMessages.length}');
        print('Total original: $totalOriginal bytes');
        print('Total compressé (forcé): $totalCompressed bytes');
        print('Total avec smart compression: $smartTotal bytes');
        print('Économie forcée: ${totalOriginal - totalCompressed} bytes (${((1 - totalCompressed/totalOriginal) * 100).toStringAsFixed(1)}%)');
        print('Économie smart: ${totalOriginal - smartTotal} bytes (${((1 - smartTotal/totalOriginal) * 100).toStringAsFixed(1)}%)');
      });
    });

    group('Edge cases', () {
      test('empty string', () {
        final stats = service.getStats('');
        expect(stats.originalSizeBytes, equals(0));
      });

      test('single character', () {
        final result = service.smartCompress('A');
        expect(result.data.isNotEmpty, isTrue);
        final decompressed = service.smartDecompress(result.data, result.isCompressed);
        expect(decompressed, equals('A'));
      });

      test('very long message', () {
        final longMessage = 'A' * 10000;
        final stats = service.getStats(longMessage);
        expect(stats.ratio, lessThan(0.01)); // Extreme compression for repetitive
      });

      test('binary-like content', () {
        // Simuler du contenu qui ressemble à du binaire (base64)
        const base64Like = 'SGVsbG8gV29ybGQhIFRoaXMgaXMgYSB0ZXN0IG1lc3NhZ2Uu';
        final stats = service.getStats(base64Like);
        // Base64 ne se compresse pas bien
        expect(stats.ratio, greaterThan(0.8));
      });
    });
  });
}
