import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onetime/models/shared_key.dart';
import 'package:onetime/services/crypto_service.dart';

void main() {
  group('CryptoService', () {
    late CryptoService service;
    late SharedKey sharedKey;

    setUp(() {
      service = CryptoService(localPeerId: 'peer_a');
      
      // Créer une clé de test avec 2 peers
      sharedKey = SharedKey(
        id: 'test_key',
        keyData: Uint8List.fromList(List.generate(1000, (i) => i % 256)),
        peerIds: ['peer_a', 'peer_b'],
      );
    });

    group('Encryption', () {
      test('encrypts message correctly', () {
        final result = service.encrypt(
          plaintext: 'Hello',
          sharedKey: sharedKey,
        );

        expect(result.message.ciphertext.length, equals(5)); // "Hello" = 5 bytes
        expect(result.message.senderId, equals('peer_a'));
        expect(result.message.keyId, equals('test_key'));
        expect(result.usedSegment.keyId, equals('test_key'));
      });

      test('encryption uses available bits', () {
        final result = service.encrypt(
          plaintext: 'Test',
          sharedKey: sharedKey,
        );

        // peer_a utilise les bits disponibles (linéaire)
        // Vérifie juste que les bits sont dans la plage valide de la clé
        expect(result.usedSegment.startBit, greaterThanOrEqualTo(0));
        expect(result.usedSegment.endBit, lessThanOrEqualTo(sharedKey.lengthInBits));
      });

      test('marks key bits as used after encryption', () {
        final result = service.encrypt(
          plaintext: 'Hello',
          sharedKey: sharedKey,
        );

        // Les bits utilisés doivent être marqués
        for (int i = result.usedSegment.startBit; i < result.usedSegment.endBit; i++) {
          expect(sharedKey.isBitUsed(i), isTrue);
        }
      });

      test('throws when not enough key bits', () {
        // Créer une petite clé
        final smallKey = SharedKey(
          id: 'small',
          keyData: Uint8List(5), // 40 bits
          peerIds: ['peer_a', 'peer_b'],
        );

        // Essayer de chiffrer un message trop long
        expect(
          () => service.encrypt(
            plaintext: 'This message is too long',
            sharedKey: smallKey,
          ),
          throwsA(isA<InsufficientKeyException>()),
        );
      });
    });

    group('Decryption', () {
      test('decrypts message correctly', () {
        final originalText = 'Hello, World!';
        
        final encrypted = service.encrypt(
          plaintext: originalText,
          sharedKey: sharedKey,
        );

        // Créer un nouveau service pour simuler le destinataire
        final receiverService = CryptoService(localPeerId: 'peer_b');
        
        // Créer une copie de la clé pour le destinataire
        final receiverKey = SharedKey(
          id: sharedKey.id,
          keyData: Uint8List.fromList(sharedKey.keyData),
          peerIds: sharedKey.peerIds,
        );

        final decrypted = receiverService.decrypt(
          encryptedMessage: encrypted.message,
          sharedKey: receiverKey,
        );

        expect(decrypted, equals(originalText));
      });

      test('XOR is symmetric', () {
        final plaintext = 'Test XOR symmetry';
        
        final encrypted = service.encrypt(
          plaintext: plaintext,
          sharedKey: sharedKey,
        );

        // XOR deux fois avec la même clé doit donner le texte original
        final decrypted = service.decrypt(
          encryptedMessage: encrypted.message,
          sharedKey: sharedKey,
          markAsUsed: false,
        );

        expect(decrypted, equals(plaintext));
      });

      test('throws on key ID mismatch', () {
        final encrypted = service.encrypt(
          plaintext: 'Test',
          sharedKey: sharedKey,
        );

        final differentKey = SharedKey(
          id: 'different_key',
          keyData: Uint8List(1000),
          peerIds: ['peer_a', 'peer_b'],
        );

        expect(
          () => service.decrypt(
            encryptedMessage: encrypted.message,
            sharedKey: differentKey,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Long Messages', () {
      test('encryptLong handles messages requiring multiple segments', () {
        // Utiliser une partie de la clé pour créer des trous
        sharedKey.markBitsAsUsed(100, 200);
        sharedKey.markBitsAsUsed(400, 500);

        final longText = 'A' * 50; // 50 caractères = 400 bits sans compression
        
        // Désactiver la compression pour ce test
        final result = service.encryptLong(
          plaintext: longText,
          sharedKey: sharedKey,
          compress: false,
        );

        expect(result.message.ciphertext.length, equals(50));
        // Peut utiliser plusieurs segments
        expect(result.usedSegments.length, greaterThanOrEqualTo(1));
      });

      test('encryptLong decrypts correctly', () {
        final longText = 'This is a longer message that spans multiple bytes';
        
        final result = service.encryptLong(
          plaintext: longText,
          sharedKey: sharedKey,
        );

        final decrypted = service.decrypt(
          encryptedMessage: result.message,
          sharedKey: sharedKey,
          markAsUsed: false,
        );

        expect(decrypted, equals(longText));
      });
    });

    group('Ultra Secure Mode', () {
      test('deleteAfterRead flag is set correctly', () {
        final result = service.encrypt(
          plaintext: 'Secret',
          sharedKey: sharedKey,
          deleteAfterRead: true,
        );

        expect(result.message.deleteAfterRead, isTrue);
      });

      test('secureDelete zeros out key bits', () {
        final result = service.encrypt(
          plaintext: 'Secret',
          sharedKey: sharedKey,
        );

        service.secureDelete(result.message, sharedKey);

        // Les bits doivent être à zéro après suppression
        for (int i = result.usedSegment.startBit; i < result.usedSegment.endBit; i++) {
          final byteIndex = i ~/ 8;
          final bitOffset = i % 8;
          final bit = (sharedKey.keyData[byteIndex] >> bitOffset) & 1;
          expect(bit, equals(0));
        }
      });
    });

    group('canDecrypt', () {
      test('returns true for valid message and key', () {
        final result = service.encrypt(
          plaintext: 'Test',
          sharedKey: sharedKey,
        );

        expect(service.canDecrypt(result.message, sharedKey), isTrue);
      });

      test('returns false for mismatched key ID', () {
        final result = service.encrypt(
          plaintext: 'Test',
          sharedKey: sharedKey,
        );

        final wrongKey = SharedKey(
          id: 'wrong_id',
          keyData: Uint8List(1000),
          peerIds: ['peer_a', 'peer_b'],
        );

        expect(service.canDecrypt(result.message, wrongKey), isFalse);
      });
    });

    group('calculateBitsNeeded', () {
      test('calculates correctly for ASCII', () {
        expect(service.calculateBitsNeeded('A'), equals(8));
        expect(service.calculateBitsNeeded('Hello'), equals(40));
      });

      test('calculates correctly for UTF-8', () {
        // 'é' en UTF-8 = 2 bytes
        expect(service.calculateBitsNeeded('é'), equals(16));
        // '€' en UTF-8 = 3 bytes
        expect(service.calculateBitsNeeded('€'), equals(24));
      });
    });

    // Segment Strategy group removed as segmentation is no longer used
    /*
    group('Segment Strategy', () {
      ...
    });
    */
  });

  group('SharedKey', () {
    test('isBitUsed returns false for fresh key', () {
      final key = SharedKey(
        id: 'test',
        keyData: Uint8List(100),
        peerIds: ['a', 'b'],
      );

      for (int i = 0; i < key.lengthInBits; i++) {
        expect(key.isBitUsed(i), isFalse);
      }
    });

    test('markBitsAsUsed marks correctly', () {
      final key = SharedKey(
        id: 'test',
        keyData: Uint8List(100),
        peerIds: ['a', 'b'],
      );

      key.markBitsAsUsed(10, 20);

      for (int i = 0; i < key.lengthInBits; i++) {
        if (i >= 10 && i < 20) {
          expect(key.isBitUsed(i), isTrue);
        } else {
          expect(key.isBitUsed(i), isFalse);
        }
      }
    });

    test('findAvailableSegment finds correct segment', () {
      final key = SharedKey(
        id: 'test',
        keyData: Uint8List(100),
        peerIds: ['a', 'b'],
      );

      key.markBitsAsUsed(0, 50);

      final segment = key.findAvailableSegment('a', 100);
      expect(segment, isNotNull);
      expect(segment!.startBit, greaterThanOrEqualTo(50));
    });

    test('countAvailableBits returns correct count', () {
      final key = SharedKey(
        id: 'test',
        keyData: Uint8List(100), // 800 bits
        peerIds: ['a', 'b'],
      );

      // Allocation linéaire : tout est disponible pour tout le monde
      expect(key.countAvailableBits('a'), equals(800));

      key.markBitsAsUsed(0, 100);
      expect(key.countAvailableBits('a'), equals(700));
    });

    test('extend adds data correctly', () {
      final key = SharedKey(
        id: 'test',
        keyData: Uint8List.fromList([1, 2, 3]),
        peerIds: ['a'],
      );

      final extended = key.extend(Uint8List.fromList([4, 5, 6]));

      expect(extended.lengthInBytes, equals(6));
      expect(extended.keyData[3], equals(4));
    });

    test('compact removes used bits', () {
      final key = SharedKey(
        id: 'test',
        keyData: Uint8List.fromList([0xFF, 0x00, 0xFF, 0x00]),
        peerIds: ['a'],
      );

      key.markBitsAsUsed(0, 8); // Premier octet
      key.markBitsAsUsed(16, 24); // Troisième octet

      final compacted = key.compact();

      // Devrait rester 16 bits (2 octets)
      expect(compacted.lengthInBits, equals(16));
    });

    test('serialization roundtrip preserves data', () {
      final original = SharedKey(
        id: 'test',
        keyData: Uint8List.fromList([1, 2, 3, 4, 5]),
        peerIds: ['peer1', 'peer2'],
        conversationName: 'Test Conversation',
      );

      original.markBitsAsUsed(0, 10);

      final json = original.toJson();
      final restored = SharedKey.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.keyData, equals(original.keyData));
      expect(restored.peerIds, equals(original.peerIds));
      expect(restored.conversationName, equals(original.conversationName));
      
      for (int i = 0; i < 10; i++) {
        expect(restored.isBitUsed(i), isTrue);
      }
    });
  });
}
