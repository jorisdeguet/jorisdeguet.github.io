import 'dart:typed_data';
import 'dart:convert';

/// Représente une clé partagée entre plusieurs pairs pour le chiffrement One-Time Pad.
/// 
/// La clé est divisée en segments attribués à chaque pair selon leur ID.
/// Pour N pairs, le pair i utilise le segment [i*keyLength/N, (i+1)*keyLength/N[
class SharedKey {
  /// Identifiant unique de la clé partagée
  final String id;
  
  /// Les données binaires de la clé
  final Uint8List keyData;
  
  /// Liste des IDs des pairs partageant cette clé (triés par ordre croissant)
  final List<String> peerIds;
  
  /// Bitmap des bits déjà utilisés (1 = utilisé, 0 = disponible)
  Uint8List _usedBitmap;
  
  /// Date de création de la clé
  final DateTime createdAt;
  
  /// Nom optionnel pour identifier la conversation
  final String? conversationName;

  SharedKey({
    required this.id,
    required this.keyData,
    required this.peerIds,
    Uint8List? usedBitmap,
    DateTime? createdAt,
    this.conversationName,
  }) : _usedBitmap = usedBitmap ?? Uint8List((keyData.length * 8 + 7) ~/ 8),
       createdAt = createdAt ?? DateTime.now() {
    // S'assurer que les peers sont triés
    peerIds.sort();
  }

  /// Longueur de la clé en bits
  int get lengthInBits => keyData.length * 8;
  
  /// Longueur de la clé en octets
  int get lengthInBytes => keyData.length;
  
  /// Nombre de pairs partageant cette clé
  int get peerCount => peerIds.length;

  /// Retourne l'index du segment attribué à un pair donné.
  /// Pour N pairs, le pair à l'index i utilise [i*length/N, (i+1)*length/N[
  ({int startBit, int endBit}) getSegmentForPeer(String peerId) {
    final peerIndex = peerIds.indexOf(peerId);
    if (peerIndex == -1) {
      throw ArgumentError('Peer $peerId not found in this shared key');
    }
    
    final segmentSize = lengthInBits ~/ peerCount;
    final startBit = peerIndex * segmentSize;
    final endBit = (peerIndex == peerCount - 1) 
        ? lengthInBits 
        : (peerIndex + 1) * segmentSize;
    
    return (startBit: startBit, endBit: endBit);
  }

  /// Vérifie si un bit est déjà utilisé
  bool isBitUsed(int bitIndex) {
    if (bitIndex < 0 || bitIndex >= lengthInBits) {
      throw RangeError('Bit index $bitIndex out of range [0, $lengthInBits[');
    }
    final byteIndex = bitIndex ~/ 8;
    final bitOffset = bitIndex % 8;
    return (_usedBitmap[byteIndex] & (1 << bitOffset)) != 0;
  }

  /// Marque un segment de bits comme utilisé
  void markBitsAsUsed(int startBit, int endBit) {
    for (int i = startBit; i < endBit; i++) {
      final byteIndex = i ~/ 8;
      final bitOffset = i % 8;
      _usedBitmap[byteIndex] |= (1 << bitOffset);
    }
  }

  /// Trouve le prochain segment disponible de la taille demandée dans le segment du peer
  ({int startBit, int endBit})? findAvailableSegment(String peerId, int bitsNeeded) {
    final peerSegment = getSegmentForPeer(peerId);
    
    int consecutiveAvailable = 0;
    int segmentStart = peerSegment.startBit;
    
    for (int i = peerSegment.startBit; i < peerSegment.endBit; i++) {
      if (!isBitUsed(i)) {
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
      final sourceByteIndex = sourceBitIndex ~/ 8;
      final sourceBitOffset = sourceBitIndex % 8;
      
      final targetByteIndex = i ~/ 8;
      final targetBitOffset = i % 8;
      
      if ((keyData[sourceByteIndex] & (1 << sourceBitOffset)) != 0) {
        result[targetByteIndex] |= (1 << targetBitOffset);
      }
    }
    
    return result;
  }

  /// Compte les bits disponibles dans le segment d'un peer
  int countAvailableBits(String peerId) {
    final segment = getSegmentForPeer(peerId);
    int count = 0;
    for (int i = segment.startBit; i < segment.endBit; i++) {
      if (!isBitUsed(i)) count++;
    }
    return count;
  }

  /// Ajoute des bits à la fin de la clé (pour l'agrandissement)
  SharedKey extend(Uint8List additionalKeyData) {
    final newKeyData = Uint8List(keyData.length + additionalKeyData.length);
    newKeyData.setRange(0, keyData.length, keyData);
    newKeyData.setRange(keyData.length, newKeyData.length, additionalKeyData);
    
    // Étendre le bitmap d'utilisation
    final newBitmapSize = (newKeyData.length * 8 + 7) ~/ 8;
    final newUsedBitmap = Uint8List(newBitmapSize);
    newUsedBitmap.setRange(0, _usedBitmap.length, _usedBitmap);
    
    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      usedBitmap: newUsedBitmap,
      createdAt: createdAt,
      conversationName: conversationName,
    );
  }

  /// Compacte la clé en supprimant les bits utilisés et réindexant
  SharedKey compact() {
    // Trouver tous les bits non utilisés
    final availableBits = <int>[];
    for (int i = 0; i < lengthInBits; i++) {
      if (!isBitUsed(i)) {
        availableBits.add(i);
      }
    }
    
    // Créer une nouvelle clé avec seulement les bits disponibles
    final newBytesNeeded = (availableBits.length + 7) ~/ 8;
    final newKeyData = Uint8List(newBytesNeeded);
    
    for (int i = 0; i < availableBits.length; i++) {
      final sourceBitIndex = availableBits[i];
      final sourceByteIndex = sourceBitIndex ~/ 8;
      final sourceBitOffset = sourceBitIndex % 8;
      
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
      conversationName: conversationName,
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
      'conversationName': conversationName,
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
      conversationName: json['conversationName'] as String?,
    );
  }

  /// Getter pour le bitmap d'utilisation (lecture seule)
  Uint8List get usedBitmap => Uint8List.fromList(_usedBitmap);
}
