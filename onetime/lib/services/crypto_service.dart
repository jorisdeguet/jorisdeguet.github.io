import 'dart:typed_data';
import 'dart:convert';

import 'package:onetime/convo/encrypted_message.dart';

import '../key_exchange/key_interval.dart';
import '../key_exchange/shared_key.dart';
import '../convo/compression_service.dart';

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
  /// Retourne le message chiffré et l'intervalle utilisé pour mise à jour
  ({EncryptedMessage message, KeyInterval usedSegment}) encrypt({
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
    
    final bytesNeeded = dataToEncrypt.length;

    // Trouver un segment disponible en octets
    final seg = sharedKey.findAvailableSegmentByBytes(localPeerId, bytesNeeded);
    if (seg == null) {
      throw InsufficientKeyException(
        'Not enough key bytes available. Needed: $bytesNeeded bytes',
      );
    }

    // Extract key bytes directly
    final keyBytes = sharedKey.extractKeyBytes(seg.startByte, seg.lengthBytes).sublist(0, bytesNeeded);

    // XOR des données avec la clé
    final ciphertext = _xor(dataToEncrypt, keyBytes);

    // Marquer les octets comme utilisés
    sharedKey.markBytesAsUsed(seg.startByte, seg.startByte + seg.lengthBytes);

    // Compute byte-aligned metadata for message segment
    final startByte = seg.startByte;
    final lengthBytes = seg.lengthBytes;

    // Créer le message chiffré
    final encryptedMessage = EncryptedMessage(
      id: _generateMessageId(),
      keyId: sharedKey.id,
      senderId: localPeerId,
      // keySegment now uses bytes: (startByte, lengthBytes)
      keySegment: (startByte: startByte, lengthBytes: lengthBytes),
      ciphertext: ciphertext,
      isCompressed: isCompressed,
      contentType: MessageContentType.text,
    );

    // Créer l'intervalle utilisé pour tracking
    final usedSegment = KeyInterval(
      conversationId: sharedKey.id,
      startIndex: startByte,
      endIndex: startByte + lengthBytes,
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
  /// Retourne le message chiffré et l'intervalle utilisé pour mise à jour
  ({EncryptedMessage message, KeyInterval usedSegment}) encryptBinary({
    required Uint8List data,
    required SharedKey sharedKey,
    required MessageContentType contentType,
    String? fileName,
    String? mimeType,
    bool deleteAfterRead = false,
  }) {
    final bytesNeeded = data.length;

    // Find contiguous bytes segment
    final seg = sharedKey.findAvailableSegmentByBytes(localPeerId, bytesNeeded);
    if (seg == null) {
      throw InsufficientKeyException('Not enough key bytes available. Needed: $bytesNeeded bytes');
    }

    final keyBytes = sharedKey.extractKeyBytes(seg.startByte, seg.lengthBytes).sublist(0, bytesNeeded);

    // XOR des données avec la clé
    final ciphertext = _xor(data, keyBytes);

    // Marquer les octets comme utilisés
    sharedKey.markBytesAsUsed(seg.startByte, seg.startByte + seg.lengthBytes);

    // Compute byte-aligned metadata for message segment
    final startByte = seg.startByte;
    final lengthBytes = seg.lengthBytes;

    // Créer le message chiffré
    final encryptedMessage = EncryptedMessage(
      id: _generateMessageId(),
      keyId: sharedKey.id,
      senderId: localPeerId,
      // keySegment now uses bytes: (startByte, lengthBytes)
      keySegment: (startByte: startByte, lengthBytes: lengthBytes),
      ciphertext: ciphertext,
      isCompressed: false,
      contentType: contentType,
      fileName: fileName,
      mimeType: mimeType,
    );
    
    // Créer l'intervalle utilisé pour tracking
    final usedSegment = KeyInterval(
      conversationId: sharedKey.id,
      startIndex: startByte,
      endIndex: startByte + lengthBytes,
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

    // Extraire le segment unique
    if (encryptedMessage.keySegment == null) {
      // Not encrypted
      return encryptedMessage.ciphertext;
    }
    final seg = encryptedMessage.keySegment!;
    final keyBytes = sharedKey.extractKeyBytes(seg.startByte, seg.lengthBytes);

    // XOR pour déchiffrer
    final decryptedData = _xor(encryptedMessage.ciphertext, keyBytes);

    // Marquer comme utilisé si demandé
    if (markAsUsed) {
      sharedKey.markBytesAsUsed(seg.startByte, seg.startByte + seg.lengthBytes);
    }

    return decryptedData;
  }

  /// Chiffre un long message qui peut nécessiter plusieurs segments.
  /// 
  /// Utile quand un seul segment contigu n'est pas disponible.
  ({EncryptedMessage message, List<KeyInterval> usedSegments}) encryptLong({
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
    
    // Option A: Do not support long messages across multiple segments.
    // If compressed data doesn't fit in a single contiguous segment, throw.
    final totalBytesNeeded = dataToEncrypt.length;
    final seg = sharedKey.findAvailableSegmentByBytes(localPeerId, totalBytesNeeded);
    if (seg == null) {
      throw InsufficientKeyException('Not enough contiguous key bytes for a single-segment message. Needed: $totalBytesNeeded bytes');
    }

    final keyBytes = sharedKey.extractKeyBytes(seg.startByte, seg.lengthBytes).sublist(0, totalBytesNeeded);
    final ciphertext = _xor(dataToEncrypt, keyBytes);

    // Mark used
    sharedKey.markBytesAsUsed(seg.startByte, seg.startByte + seg.lengthBytes);

    final startByte = seg.startByte;
    final lengthBytes = seg.lengthBytes;

    final usedSegments = <KeyInterval>[KeyInterval(
      conversationId: sharedKey.id,
      startIndex: startByte,
      endIndex: startByte + lengthBytes,
    )];

    final encryptedMessage = EncryptedMessage(
      id: _generateMessageId(),
      keyId: sharedKey.id,
      senderId: localPeerId,
      keySegment: (startByte: startByte, lengthBytes: lengthBytes),
      ciphertext: ciphertext,
      isCompressed: isCompressed,
    );
    
    return (message: encryptedMessage, usedSegments: usedSegments);
  }

  /// Déchiffre un message.
  /// 
  /// [encryptedMessage] - Le message chiffré
  /// [sharedKey] - La clé partagée
  /// [markAsUsed] - Si true, marque les octets de clé comme utilisés
  String decrypt({
    required EncryptedMessage encryptedMessage,
    required SharedKey sharedKey,
    bool markAsUsed = true,
  }) {
    // Vérifier que la clé correspond
    if (encryptedMessage.keyId != sharedKey.id) {
      throw ArgumentError('Key ID mismatch');
    }
    
    // Extract key bytes from the single segment
    if (encryptedMessage.keySegment == null) {
      return '';
    }
    final seg = encryptedMessage.keySegment!;
    final keyBytes = sharedKey.extractKeyBytes(seg.startByte, seg.lengthBytes);

    // XOR pour déchiffrer
    final decryptedData = _xor(encryptedMessage.ciphertext, keyBytes);

    // Décompresser si nécessaire
    String result;
    if (encryptedMessage.isCompressed) {
      result = _compressionService.smartDecompress(decryptedData, true);
    } else {
      result = utf8.decode(decryptedData);
    }
    
    // Marquer comme utilisé SEULEMENT si le déchiffrement a réussi
    if (markAsUsed) {
      sharedKey.markBytesAsUsed(seg.startByte, seg.startByte + seg.lengthBytes);
    }
    
    return result;
  }

  /// Vérifie si un message peut être déchiffré sans utiliser la clé.
  /// 
  /// Retourne true si tous les segments nécessaires sont disponibles.
  bool canDecrypt(EncryptedMessage message, SharedKey sharedKey) {
    if (message.keyId != sharedKey.id) return false;
    final seg = message.keySegment;
    if (seg == null) return true;
    for (int i = seg.startByte; i < seg.startByte + seg.lengthBytes; i++) {
      if (i >= sharedKey.lengthInBytes) return false;
    }
    return true;
  }

  /// Efface les octets de clé utilisés pour un message (mode ultra-secure).
  ///
  /// Après cet appel, le message ne pourra plus jamais être déchiffré.
  void secureDelete(EncryptedMessage message, SharedKey sharedKey) {
    final seg = message.keySegment;
    if (seg != null) {
      for (int i = seg.startByte; i < seg.startByte + seg.lengthBytes; i++) {
        // Mettre à zéro l'octet
        sharedKey.keyData[i] = 0;
      }
    }
  }

  /// Calcule le nombre d'octets nécessaires pour un message.
  ///
  /// [compress] - Si true, calcule avec compression
  int calculateBytesNeeded(String plaintext, {bool compress = true}) {
    if (compress) {
      final compressed = _compressionService.smartCompress(plaintext);
      return compressed.data.length;
    }
    return utf8.encode(plaintext).length;
  }

  /// XOR de deux tableaux d'octets
  Uint8List _xor(Uint8List data, Uint8List key) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i];
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
  final KeyInterval? segment;
  final String? errorMessage;

  SegmentReservationResult.success(this.segment) 
      : success = true, errorMessage = null;
  
  SegmentReservationResult.failure(this.errorMessage)
      : success = false, segment = null;
}
