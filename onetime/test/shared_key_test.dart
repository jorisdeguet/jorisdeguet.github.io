import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetime/models/shared_key.dart';

void main() {
  group('SharedKey Truncation', () {
    late SharedKey key;
    
    setUp(() {
      // Create a key of 16 bytes (128 bits)
      final keyData = Uint8List(16);
      for (int i = 0; i < 16; i++) keyData[i] = i; // 0, 1, 2, ... 15
      
      key = SharedKey(
        id: 'test-key',
        keyData: keyData,
        peerIds: ['user1', 'user2'],
      );
    });

    test('Initial state is correct', () {
      expect(key.startOffset, 0);
      expect(key.lengthInBits, 128);
      expect(key.lengthInBytes, 16);
      expect(key.usedBitmap.length, 16); // 128 bits -> 16 bytes bitmap
    });

    test('Truncate works correctly', () {
      // Truncate 2 bytes (16 bits)
      final truncated = key.truncate(16);
      
      expect(truncated.startOffset, 16);
      // int get lengthInBits => startOffset + (keyData.length * 8);
      // 16 + (14*8) = 16 + 112 = 128.
      expect(truncated.lengthInBits, 128);
      
      expect(truncated.lengthInBytes, 14); // Physical length
      expect(truncated.keyData.length, 14);
      expect(truncated.keyData[0], 2); // Was at index 2 (byte 2)
      
      // Check bitmap size
      // 14 bytes * 8 = 112 bits -> 14 bytes bitmap
      expect(truncated.usedBitmap.length, 14);
    });

    test('isBitUsed respects offset', () {
      final truncated = key.truncate(16); // Start at 16
      
      // Accessing < 16 should return true (considered used)
      expect(truncated.isBitUsed(0), true);
      expect(truncated.isBitUsed(15), true);
      
      // Accessing >= 16 should check bitmap
      // Relative index = 16 - 16 = 0
      // Bitmap[0] should be 0 (unused)
      expect(truncated.isBitUsed(16), false);
      
      // Mark bit 16 used
      truncated.markBitsAsUsed(16, 17);
      expect(truncated.isBitUsed(16), true);
    });
    
    test('extractKeyBits respects offset', () {
      final truncated = key.truncate(16);
      
      // Extracting from truncated area should throw
      expect(() => truncated.extractKeyBits(0, 8), throwsStateError);
      
      // Extracting from available area
      // Byte at 16 is keyData[2] which is 2
      final extracted = truncated.extractKeyBits(16, 24); // 8 bits
      expect(extracted.length, 1);
      expect(extracted[0], 2);
    });
    
    test('Truncate with non-byte aligned offset', () {
      // truncate(12) -> should truncate 8 bits (1 byte) because "bytesToRemove = bitsToRemove ~/ 8"
      // startOffset=0, newStart=12. bitsToRemove=12. bytesToRemove=1.
      final truncated = key.truncate(12);
      
      expect(truncated.startOffset, 8); // 8 bits truncated
      expect(truncated.keyData.length, 15);
      expect(truncated.keyData[0], 1); // Was at index 1
    });
  });
}
