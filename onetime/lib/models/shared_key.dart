import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

/// Représente une clé partagée entre plusieurs pairs pour le chiffrement One-Time Pad.
/// 
/// L'allocation est linéaire : tous les pairs partagent l'espace entier de la clé.
class SharedKey {
  /// Identifiant unique de la clé partagée
  final String id;
  
  /// Les données binaires de la clé
  final Uint8List keyData;
  
  /// Liste des IDs des pairs partageant cette clé (triés par ordre croissante)
  final List<String> peerIds;
  
  /// Bitmap des bits déjà utilisés (1 = utilisé, 0 = disponible)
  Uint8List _usedBitmap;
  
  /// Date de création de la clé
  final DateTime createdAt;
  
  /// Offset de départ de la clé (en bits)
  /// Indique combien de bits ont été tronqués au début de la clé.
  final int startOffset;

  SharedKey({
    required this.id,
    required this.keyData,
    required this.peerIds,
    Uint8List? usedBitmap,
    DateTime? createdAt,
    this.startOffset = 0,
  }) : _usedBitmap = usedBitmap ?? Uint8List((keyData.length * 8 + 7) ~/ 8),
       createdAt = createdAt ?? DateTime.now() {
    // S'assurer que les peers sont triés
    peerIds.sort();

    // Ensure the used bitmap has the expected size matching keyData.
    final expectedBitmapSize = (keyData.length * 8 + 7) ~/ 8;
    if (_usedBitmap.length != expectedBitmapSize) {
      final resized = Uint8List(expectedBitmapSize);
      // copy existing bytes up to the min length
      final copyLen = min(_usedBitmap.length, expectedBitmapSize);
      if (copyLen > 0) {
        resized.setRange(0, copyLen, _usedBitmap.sublist(0, copyLen));
      }
      _usedBitmap = resized;
    }
  }

  /// Longueur totale logique de la clé en bits (incluant l'offset)
  int get lengthInBits => startOffset + (keyData.length * 8);
  
  /// Longueur de la clé en octets
  int get lengthInBytes => keyData.length;
  
  /// Nombre de pairs partageant cette clé
  int get peerCount => peerIds.length;

  // Helper to check bitmap index access and throw descriptive error if invalid
  void _checkBitmapIndex(int byteIndex, int bitIndex) {
    if (byteIndex < 0 || byteIndex >= _usedBitmap.length) {
      throw StateError('Bitmap access out of range: byteIndex=$byteIndex, bitIndex=$bitIndex, bitmapLength=${_usedBitmap.length}, keyBytes=${keyData.length}, startOffset=$startOffset');
    }
    if (byteIndex >= keyData.length) {
      throw StateError('Key data access out of range: byteIndex=$byteIndex, keyBytes=${keyData.length}, startOffset=$startOffset');
    }
  }

  /// Vérifie si un bit est déjà utilisé
  bool isBitUsed(int bitIndex) {
    if (bitIndex < startOffset || bitIndex >= lengthInBits) {
      if (bitIndex < startOffset) return true; // Considéré comme utilisé si tronqué
      throw RangeError('Bit index $bitIndex out of range [0, $lengthInBits[');
    }
    
    final relativeIndex = bitIndex - startOffset;
    final byteIndex = relativeIndex ~/ 8;
    final bitOffset = relativeIndex % 8;
    _checkBitmapIndex(byteIndex, bitIndex);
    return (_usedBitmap[byteIndex] & (1 << bitOffset)) != 0;
  }

  /// Marque un segment de bits comme utilisé
  void markBitsAsUsed(int startBit, int endBit) {
    for (int i = startBit; i < endBit; i++) {
      if (i < startOffset) continue; // Ignorer si tronqué
      
      final relativeIndex = i - startOffset;
      final byteIndex = relativeIndex ~/ 8;
      final bitOffset = relativeIndex % 8;
      _checkBitmapIndex(byteIndex, i);
      _usedBitmap[byteIndex] |= (1 << bitOffset);
    }
  }

  /// Trouve le prochain segment disponible de la taille demandée dans le segment du peer
  /// En mode linéaire, on cherche dans toute la clé, mais on ne peut pas utiliser
  /// les bits déjà marqués comme utilisés par d'autres (ou par nous-même).
  ({int startBit, int endBit})? findAvailableSegment(String peerId, int bitsNeeded) {
    // Allocation linéaire : on cherche depuis le début de la clé (après l'offset)
    
    int consecutiveAvailable = 0;
    int segmentStart = 0;
    
    // On commence à chercher après l'offset
    for (int i = startOffset; i < lengthInBits; i++) {
      // isBitUsed gère l'offset en interne, mais ici on itère sur les indices absolus
      // Pour optimiser, on pourrait accéder directement au bitmap
      
      final relativeIndex = i - startOffset;
      final byteIndex = relativeIndex ~/ 8;
      final bitOffset = relativeIndex % 8;
      // If bitmap is unexpectedly short, treat as used to avoid returning invalid segments
      if (byteIndex >= _usedBitmap.length) {
        consecutiveAvailable = 0;
        continue;
      }
      final isUsed = (_usedBitmap[byteIndex] & (1 << bitOffset)) != 0;

      if (!isUsed) {
        if (consecutiveAvailable == 0) {
          segmentStart = i;
        }
        consecutiveAvailable++;
        if (consecutiveAvailable >= bitsNeeded) {
          return (startBit: segmentStart, endBit: segmentStart + bitsNeeded);
        }
      } else {
        consecutiveAvailable = 0;
      }
    }
    
    return null; // Pas assez de bits disponibles
  }

  /// Extrait les bits de la clé pour un segment donné
  Uint8List extractKeyBits(int startBit, int endBit) {
    final bitsNeeded = endBit - startBit;
    final bytesNeeded = (bitsNeeded + 7) ~/ 8;
    final result = Uint8List(bytesNeeded);
    
    for (int i = 0; i < bitsNeeded; i++) {
      final sourceBitIndex = startBit + i;
      
      if (sourceBitIndex < startOffset) {
        throw StateError('Cannot extract bits from truncated part of key');
      }
      
      final relativeIndex = sourceBitIndex - startOffset;
      final sourceByteIndex = relativeIndex ~/ 8;
      final sourceBitOffset = relativeIndex % 8;
      
      final targetByteIndex = i ~/ 8;
      final targetBitOffset = i % 8;
      
      _checkBitmapIndex(sourceByteIndex, sourceBitIndex);
      if ((keyData[sourceByteIndex] & (1 << sourceBitOffset)) != 0) {
        result[targetByteIndex] |= (1 << targetBitOffset);
      }
    }
    
    return result;
  }

  /// Compte les bits disponibles dans toute la clé (allocation linéaire)
  int countAvailableBits(String peerId) {
    int count = 0;
    // On compte seulement dans la partie non tronquée
    for (int i = startOffset; i < lengthInBits; i++) {
      final relativeIndex = i - startOffset;
      final byteIndex = relativeIndex ~/ 8;
      final bitOffset = relativeIndex % 8;
      if (byteIndex >= _usedBitmap.length) continue; // defensive
      if ((_usedBitmap[byteIndex] & (1 << bitOffset)) == 0) {
        count++;
      }
    }
    return count;
  }

  /// Ajoute des bits à la fin de la clé (pour l'agrandissement)
  /// Allocation linéaire : on ajoute simplement à la fin
  SharedKey extend(Uint8List additionalKeyData) {
    if (additionalKeyData.isEmpty) return this;

    final newKeyData = Uint8List(keyData.length + additionalKeyData.length);
    newKeyData.setRange(0, keyData.length, keyData);
    newKeyData.setRange(keyData.length, newKeyData.length, additionalKeyData);
    
    // Étendre le bitmap d'utilisation
    final newBitmapSize = (newKeyData.length * 8 + 7) ~/ 8;
    final newUsedBitmap = Uint8List(newBitmapSize);
    newUsedBitmap.setRange(0, _usedBitmap.length, _usedBitmap);
    // Les nouveaux bits sont à 0 par défaut (disponibles)
    
    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      usedBitmap: newUsedBitmap,
      createdAt: createdAt,
      startOffset: startOffset,
    );
  }

  /// Tronque le début de la clé jusqu'à l'index donné (exclus)
  /// [newStartOffset] doit être > startOffset et < lengthInBits
  SharedKey truncate(int newStartOffset) {
    if (newStartOffset <= startOffset) return this;
    if (newStartOffset >= lengthInBits) {
      // Tout supprimer
      return SharedKey(
        id: id,
        keyData: Uint8List(0),
        peerIds: List.from(peerIds),
        createdAt: createdAt,
        startOffset: newStartOffset,
      );
    }

    final bitsToRemove = newStartOffset - startOffset;
    final bytesToRemove = bitsToRemove ~/ 8; // On tronque par octet complet
    final actualNewOffset = startOffset + (bytesToRemove * 8);
    
    // On ne garde que les octets complets restants
    final newKeyData = keyData.sublist(bytesToRemove);
    final newUsedBitmap = _usedBitmap.sublist(bytesToRemove);
    
    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      usedBitmap: newUsedBitmap,
      createdAt: createdAt,
      startOffset: actualNewOffset,
    );
  }

  /// Compacte la clé en supprimant les bits utilisés et réindexant
  /// NOTE: Avec l'offset, compact() change de sémantique ou devient obsolète.
  /// Pour l'instant on le garde tel quel mais il recrée une nouvelle clé sans offset.
  SharedKey compact() {
    // Trouver tous les bits non utilisés
    final availableBits = <int>[];
    for (int i = startOffset; i < lengthInBits; i++) {
      // Accès optimisé via indices relatifs
      final relativeIndex = i - startOffset;
      final byteIndex = relativeIndex ~/ 8;
      final bitOffset = relativeIndex % 8;
      
      if (byteIndex >= _usedBitmap.length) continue;
      if ((_usedBitmap[byteIndex] & (1 << bitOffset)) == 0) {
        availableBits.add(i);
      }
    }
    
    // Créer une nouvelle clé avec seulement les bits disponibles
    final newBytesNeeded = (availableBits.length + 7) ~/ 8;
    final newKeyData = Uint8List(newBytesNeeded);
    
    for (int i = 0; i < availableBits.length; i++) {
      final sourceBitIndex = availableBits[i];
      final relativeIndex = sourceBitIndex - startOffset;
      final sourceByteIndex = relativeIndex ~/ 8;
      final sourceBitOffset = relativeIndex % 8;
      
      final targetByteIndex = i ~/ 8;
      final targetBitOffset = i % 8;
      
      if ((keyData[sourceByteIndex] & (1 << sourceBitOffset)) != 0) {
        newKeyData[targetByteIndex] |= (1 << targetBitOffset);
      }
    }
    
    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      createdAt: createdAt,
      // Une clé compactée repart de 0 (nouvelle clé logique)
      startOffset: 0,
    );
  }

  /// Sérialise la clé pour stockage local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyData': base64Encode(keyData),
      'peerIds': peerIds,
      'usedBitmap': base64Encode(_usedBitmap),
      'createdAt': createdAt.toIso8601String(),
      'startOffset': startOffset,
    };
  }

  /// Désérialise une clé depuis le stockage local
  factory SharedKey.fromJson(Map<String, dynamic> json) {
    return SharedKey(
      id: json['id'] as String,
      keyData: base64Decode(json['keyData'] as String),
      peerIds: List<String>.from(json['peerIds'] as List),
      usedBitmap: base64Decode(json['usedBitmap'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startOffset: json['startOffset'] as int? ?? 0,
    );
  }

  /// Getter pour le bitmap d'utilisation (lecture seule)
  Uint8List get usedBitmap => Uint8List.fromList(_usedBitmap);
}
