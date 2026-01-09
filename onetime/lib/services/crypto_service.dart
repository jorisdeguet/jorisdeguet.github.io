import 'dart:typed_data';
import 'dart:convert';

import '../models/shared_key.dart';
import '../models/encrypted_message.dart';
import '../models/key_segment.dart';
import 'compression_service.dart';

/// Service de chiffrement/déchiffrement One-Time Pad.
/// 
/// Gère l'utilisation de la clé locale pour chiffrer et déchiffrer
/// les messages en s'assurant qu'un segment de clé n'est utilisé qu'une fois.
/// 
/// Supporte la compression optionnelle des messages avant chiffrement
/// pour économiser les bits de clé.
class CryptoService {
  /// ID du peer local
  final String localPeerId;
  
  /// Service de compression
  final CompressionService _compressionService = CompressionService();

  CryptoService({required this.localPeerId});

  /// Chiffre un message avec One-Time Pad.
  /// 
  /// [plaintext] - Le message en clair
  /// [sharedKey] - La clé partagée à utiliser
  /// [deleteAfterRead] - Mode ultra-secure, suppression après lecture
  /// [compress] - Compresser le message avant chiffrement (défaut: true)
  /// 
  /// Retourne le message chiffré et le segment utilisé pour mise à jour
  ({EncryptedMessage message, KeySegment usedSegment}) encrypt({
    required String plaintext,
    required SharedKey sharedKey,
    bool deleteAfterRead = false,
    bool compress = true,
  }) {
    // Préparer les données à chiffrer
    Uint8List dataToEncrypt;
    bool isCompressed = false;
    
    if (compress) {
      final compressed = _compressionService.smartCompress(plaintext);
      dataToEncrypt = compressed.data;
      isCompressed = compressed.isCompressed;
    } else {
      dataToEncrypt = Uint8List.fromList(utf8.encode(plaintext));
    }
    
    final bitsNeeded = dataToEncrypt.length * 8;
    
    // Trouver un segment disponible dans la portion du peer
    final segment = sharedKey.findAvailableSegment(localPeerId, bitsNeeded);
    if (segment == null) {
      throw InsufficientKeyException(
        'Not enough key bits available. Needed: $bitsNeeded bits',
      );
    }
    
    // Extraire les bits de clé
    final keyBits = sharedKey.extractKeyBits(segment.startBit, segment.endBit);
    
    // XOR des données avec la clé
    final ciphertext = _xor(dataToEncrypt, keyBits);
    
    // Marquer les bits comme utilisés
    sharedKey.markBitsAsUsed(segment.startBit, segment.endBit);
    
    // Créer le message chiffré
    final encryptedMessage = EncryptedMessage(
      id: _generateMessageId(),
      keyId: sharedKey.id,
      senderId: localPeerId,
      keySegments: [(startBit: segment.startBit, endBit: segment.endBit)],
      ciphertext: ciphertext,
      deleteAfterRead: deleteAfterRead,
      isCompressed: isCompressed,
      contentType: MessageContentType.text,
    );

    // Créer le segment utilisé pour tracking
    final usedSegment = KeySegment(
      keyId: sharedKey.id,
      startBit: segment.startBit,
      endBit: segment.endBit,
      usedByPeerId: localPeerId,
    );

    return (message: encryptedMessage, usedSegment: usedSegment);
  }

  /// Chiffre des données binaires (images, fichiers) avec One-Time Pad.
  ///
  /// [data] - Les données binaires à chiffrer
  /// [sharedKey] - La clé partagée à utiliser
  /// [contentType] - Type de contenu (image ou fichier)
  /// [fileName] - Nom du fichier
  /// [mimeType] - Type MIME du fichier
  /// [deleteAfterRead] - Mode ultra-secure, suppression après lecture
  ///
  /// Retourne le message chiffré et le segment utilisé pour mise à jour
  ({EncryptedMessage message, KeySegment usedSegment}) encryptBinary({
    required Uint8List data,
    required SharedKey sharedKey,
    required MessageContentType contentType,
    String? fileName,
    String? mimeType,
    bool deleteAfterRead = false,
  }) {
    final bitsNeeded = data.length * 8;

    // Trouver un segment disponible dans la portion du peer
    final segment = sharedKey.findAvailableSegment(localPeerId, bitsNeeded);
    if (segment == null) {
      throw InsufficientKeyException(
        'Not enough key bits available. Needed: $bitsNeeded bits',
      );
    }

    // Extraire les bits de clé
    final keyBits = sharedKey.extractKeyBits(segment.startBit, segment.endBit);

    // XOR des données avec la clé
    final ciphertext = _xor(data, keyBits);

    // Marquer les bits comme utilisés
    sharedKey.markBitsAsUsed(segment.startBit, segment.endBit);

    // Créer le message chiffré
    final encryptedMessage = EncryptedMessage(
      id: _generateMessageId(),
      keyId: sharedKey.id,
      senderId: localPeerId,
      keySegments: [(startBit: segment.startBit, endBit: segment.endBit)],
      ciphertext: ciphertext,
      deleteAfterRead: deleteAfterRead,
      isCompressed: false,
      contentType: contentType,
      fileName: fileName,
      mimeType: mimeType,
    );
    
    // Créer le segment utilisé pour tracking
    final usedSegment = KeySegment(
      keyId: sharedKey.id,
      startBit: segment.startBit,
      endBit: segment.endBit,
      usedByPeerId: localPeerId,
    );
    
    return (message: encryptedMessage, usedSegment: usedSegment);
  }

  /// Déchiffre un message binaire et retourne les données brutes
  Uint8List decryptBinary({
    required EncryptedMessage encryptedMessage,
    required SharedKey sharedKey,
    bool markAsUsed = true,
  }) {
    // Vérifier que la clé correspond
    if (encryptedMessage.keyId != sharedKey.id) {
      throw ArgumentError('Key ID mismatch');
    }

    // Extraire les bits de clé utilisés pour ce message
    final totalBits = encryptedMessage.totalBitsUsed;
    final keyBits = _extractMultipleSegments(
      sharedKey,
      encryptedMessage.keySegments,
      totalBits,
    );

    // XOR pour déchiffrer
    final decryptedData = _xor(encryptedMessage.ciphertext, keyBits);

    // Marquer comme utilisé si demandé
    if (markAsUsed) {
      for (final seg in encryptedMessage.keySegments) {
        sharedKey.markBitsAsUsed(seg.startBit, seg.endBit);
      }
    }

    return decryptedData;
  }

  /// Chiffre un long message qui peut nécessiter plusieurs segments.
  /// 
  /// Utile quand un seul segment contigu n'est pas disponible.
  ({EncryptedMessage message, List<KeySegment> usedSegments}) encryptLong({
    required String plaintext,
    required SharedKey sharedKey,
    bool deleteAfterRead = false,
    bool compress = true,
  }) {
    // Préparer les données à chiffrer
    Uint8List dataToEncrypt;
    bool isCompressed = false;
    
    if (compress) {
      final compressed = _compressionService.smartCompress(plaintext);
      dataToEncrypt = compressed.data;
      isCompressed = compressed.isCompressed;
    } else {
      dataToEncrypt = Uint8List.fromList(utf8.encode(plaintext));
    }
    
    final totalBitsNeeded = dataToEncrypt.length * 8;
    
    // Collecter les segments disponibles
    final segments = <({int startBit, int endBit})>[];
    final usedSegments = <KeySegment>[];
    int bitsCollected = 0;
    
    // Allocation linéaire: on cherche dans toute la clé
    int searchStart = 0;
    final totalKeyBits = sharedKey.lengthInBits;
    
    while (bitsCollected < totalBitsNeeded && searchStart < totalKeyBits) {
      // Chercher le prochain bit disponible
      while (searchStart < totalKeyBits && sharedKey.isBitUsed(searchStart)) {
        searchStart++;
      }
      
      if (searchStart >= totalKeyBits) break;
      
      // Trouver la fin du segment disponible
      int segmentEnd = searchStart;
      while (segmentEnd < totalKeyBits && 
             !sharedKey.isBitUsed(segmentEnd) &&
             (segmentEnd - searchStart) < (totalBitsNeeded - bitsCollected)) {
        segmentEnd++;
      }
      
      if (segmentEnd > searchStart) {
        segments.add((startBit: searchStart, endBit: segmentEnd));
        bitsCollected += segmentEnd - searchStart;
        
        usedSegments.add(KeySegment(
          keyId: sharedKey.id,
          startBit: searchStart,
          endBit: segmentEnd,
          usedByPeerId: localPeerId,
        ));
      }
      
      searchStart = segmentEnd + 1;
    }
    
    if (bitsCollected < totalBitsNeeded) {
      throw InsufficientKeyException(
        'Not enough key bits. Needed: $totalBitsNeeded, Available: $bitsCollected',
      );
    }
    
    // Extraire et concaténer les bits de clé
    final keyBits = _extractMultipleSegments(sharedKey, segments, totalBitsNeeded);
    
    // XOR
    final ciphertext = _xor(dataToEncrypt, keyBits);
    
    // Marquer tous les segments comme utilisés
    for (final seg in segments) {
      sharedKey.markBitsAsUsed(seg.startBit, seg.endBit);
    }
    
    final encryptedMessage = EncryptedMessage(
      id: _generateMessageId(),
      keyId: sharedKey.id,
      senderId: localPeerId,
      keySegments: segments,
      ciphertext: ciphertext,
      deleteAfterRead: deleteAfterRead,
      isCompressed: isCompressed,
    );
    
    return (message: encryptedMessage, usedSegments: usedSegments);
  }

  /// Déchiffre un message.
  /// 
  /// [encryptedMessage] - Le message chiffré
  /// [sharedKey] - La clé partagée
  /// [markAsUsed] - Si true, marque les bits de clé comme utilisés
  String decrypt({
    required EncryptedMessage encryptedMessage,
    required SharedKey sharedKey,
    bool markAsUsed = true,
  }) {
    // Vérifier que la clé correspond
    if (encryptedMessage.keyId != sharedKey.id) {
      throw ArgumentError('Key ID mismatch');
    }
    
    // Extraire les bits de clé utilisés pour ce message
    final totalBits = encryptedMessage.totalBitsUsed;
    final keyBits = _extractMultipleSegments(
      sharedKey, 
      encryptedMessage.keySegments,
      totalBits,
    );
    
    // XOR pour déchiffrer
    final decryptedData = _xor(encryptedMessage.ciphertext, keyBits);
    
    // Décompresser si nécessaire
    String result;
    if (encryptedMessage.isCompressed) {
      result = _compressionService.smartDecompress(decryptedData, true);
    } else {
      result = utf8.decode(decryptedData);
    }
    
    // Marquer comme utilisé SEULEMENT si le déchiffrement a réussi
    if (markAsUsed) {
      for (final seg in encryptedMessage.keySegments) {
        sharedKey.markBitsAsUsed(seg.startBit, seg.endBit);
      }
    }
    
    return result;
  }

  /// Vérifie si un message peut être déchiffré sans utiliser la clé.
  /// 
  /// Retourne true si tous les segments nécessaires sont disponibles.
  bool canDecrypt(EncryptedMessage message, SharedKey sharedKey) {
    if (message.keyId != sharedKey.id) return false;
    
    for (final seg in message.keySegments) {
      for (int i = seg.startBit; i < seg.endBit; i++) {
        if (i >= sharedKey.lengthInBits) return false;
      }
    }
    return true;
  }

  /// Efface les bits de clé utilisés pour un message (mode ultra-secure).
  /// 
  /// Après cet appel, le message ne pourra plus jamais être déchiffré.
  void secureDelete(EncryptedMessage message, SharedKey sharedKey) {
    // Écraser les bits de clé avec des zéros
    for (final seg in message.keySegments) {
      for (int i = seg.startBit; i < seg.endBit; i++) {
        final byteIndex = i ~/ 8;
        final bitOffset = i % 8;
        // Mettre à zéro
        sharedKey.keyData[byteIndex] &= ~(1 << bitOffset);
      }
    }
    // Les bits sont déjà marqués comme utilisés par decrypt
  }

  /// Calcule le nombre de bits nécessaires pour un message.
  /// 
  /// [compress] - Si true, calcule avec compression
  int calculateBitsNeeded(String plaintext, {bool compress = true}) {
    if (compress) {
      final compressed = _compressionService.smartCompress(plaintext);
      return compressed.data.length * 8;
    }
    return utf8.encode(plaintext).length * 8;
  }

  /// Retourne les statistiques de compression pour un message.
  CompressionStats getCompressionStats(String plaintext) {
    return _compressionService.getStats(plaintext);
  }

  /// XOR de deux tableaux d'octets
  Uint8List _xor(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i];
    }
    return result;
  }

  /// Extrait et concatène plusieurs segments de clé
  Uint8List _extractMultipleSegments(
    SharedKey sharedKey,
    List<({int startBit, int endBit})> segments,
    int totalBitsNeeded,
  ) {
    final bytesNeeded = (totalBitsNeeded + 7) ~/ 8;
    final result = Uint8List(bytesNeeded);
    int targetBitIndex = 0;
    
    for (final seg in segments) {
      for (int i = seg.startBit; i < seg.endBit && targetBitIndex < totalBitsNeeded; i++) {
        final sourceByteIndex = i ~/ 8;
        final sourceBitOffset = i % 8;
        
        final targetByteIndex = targetBitIndex ~/ 8;
        final targetBitOffset = targetBitIndex % 8;
        
        if ((sharedKey.keyData[sourceByteIndex] & (1 << sourceBitOffset)) != 0) {
          result[targetByteIndex] |= (1 << targetBitOffset);
        }
        
        targetBitIndex++;
      }
    }
    
    return result;
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_$localPeerId';
  }
}

/// Exception levée quand la clé n'a pas assez de bits disponibles
class InsufficientKeyException implements Exception {
  final String message;
  InsufficientKeyException(this.message);
  
  @override
  String toString() => 'InsufficientKeyException: $message';
}

/// Résultat d'une tentative de réservation de segment
class SegmentReservationResult {
  final bool success;
  final KeySegment? segment;
  final String? errorMessage;

  SegmentReservationResult.success(this.segment) 
      : success = true, errorMessage = null;
  
  SegmentReservationResult.failure(this.errorMessage)
      : success = false, segment = null;
}
