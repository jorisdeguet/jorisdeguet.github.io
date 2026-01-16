import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

import 'key_interval.dart';
import 'key_history.dart';

export 'key_interval.dart';
export 'key_history.dart';

/// Représente une clé partagée entre plusieurs pairs pour le chiffrement One-Time Pad.
///
/// L'allocation est linéaire : tous les pairs partagent l'espace entier de la clé.
/// Cette implémentation force l'alignement sur octet et utilise un simple index
/// `_nextAvailableByte` qui indique le premier octet libre (allocation linéaire).
class SharedKey {
  /// Identifiant unique de la clé partagée
  final String id;

  /// Les données binaires de la clé
  final Uint8List keyData;

  /// Liste des IDs des pairs partageant cette clé (triés par ordre croissante)
  final List<String> peerIds;

  /// Index du premier octet libre (relatif à `keyData`, 0-based).
  /// Tous les octets < _nextAvailableByte sont considérés comme consommés.
  int _nextAvailableByte;

  /// Date de création de la clé
  final DateTime createdAt;

  /// Offset de départ de la clé (en octets)
  /// Indique combien d'octets ont été tronqués au début de la clé.
  final int startOffset;

  /// Historique des opérations sur la clé (extensions et consommations)
  final KeyHistory history;

  SharedKey({
    required this.id,
    required this.keyData,
    required this.peerIds,
    DateTime? createdAt,
    this.startOffset = 0,
    KeyHistory? history,
    int? nextAvailableByte,
  })  : _nextAvailableByte = nextAvailableByte ?? startOffset,
        history = history ?? KeyHistory(conversationId: id),
        createdAt = createdAt ?? DateTime.now() {
    // S'assurer que les peers sont triés
    peerIds.sort();

    // Normaliser _nextAvailableByte
    final int maxIndex = keyData.length;

    // Ensure within bounds
    _nextAvailableByte = _nextAvailableByte.clamp(startOffset, startOffset + maxIndex);

    // If we loade State matches the actual stored key size. This
    // avoids inconsistencies where the key bytes are non-empty but history
    // is empty which would make operators like + fail due to mismatched bounds.
    if (this.history.isEmpty) {
      final totalEnd = startOffset + keyData.length;
      if (totalEnd > 0) {
        // record an initial extension from 0 to totalEnd
        this.history.recordExtension(
          segment: KeyInterval(conversationId: id, startIndex: 0, endIndex: totalEnd),
          reason: 'migrated',
        );
      }
    }
  }

  /// Public getter for next available byte index
  int get nextAvailableByte => _nextAvailableByte;

  /// Retourne l'intervalle actuel de la clé sous forme de KeyInterval.
  /// startIndex = nextAvailableByte (premier octet disponible)
  /// endIndex = startOffset + keyData.length (fin de la clé)
  KeyInterval get interval => KeyInterval(
    conversationId: id,
    startIndex: _nextAvailableByte,
    endIndex: startOffset + keyData.length,
  );

  /// Retourne l'intervalle total de la clé (depuis startOffset jusqu'à la fin)
  KeyInterval get totalInterval => KeyInterval(
    conversationId: id,
    startIndex: startOffset,
    endIndex: startOffset + keyData.length,
  );

  /// Longueur totale logique de la clé en octets (incluant l'offset)
  int get lengthInBytes => startOffset + keyData.length;

  /// Longueur totale logique en bits (compatibilité)
  int get lengthInBits => lengthInBytes * 8;

  /// Nombre de pairs partageant cette clé
  int get peerCount => peerIds.length;

  void _checkByteIndex(int byteIndex) {
    if (byteIndex < 0 || byteIndex >= keyData.length) {
      throw StateError('Byte index out of range: $byteIndex (keyData length=${keyData.length})');
    }
  }

  /// Vérifie si un octet est déjà utilisé
  bool isByteUsed(int byteIndex) {
    // If requested index is logically before the available data region, consider used
    if (byteIndex < startOffset) return true;
    _checkByteIndex(byteIndex);
    // Compare against nextAvailableByte (which is absolute relative to keyData)
    return byteIndex < _nextAvailableByte;
  }

  /// Wrapper compatibilité : vérifie si un bit est utilisé en regardant l'octet contenant le bit.
  bool isBitUsed(int bitIndex) {
    final byteIndex = bitIndex ~/ 8;
    return isByteUsed(byteIndex);
  }

  /// Marque un intervalle d'octets comme utilisé (endByte exclusive)
  /// En mode allocation linéaire, on avance simplement `_nextAvailableByte`.
  void markBytesAsUsed(int startByte, int endByte) {
    if (endByte <= startByte) return;
    final e = min(endByte, startOffset + keyData.length);
    // Advance nextAvailableByte to cover the newly used end
    _nextAvailableByte = max(_nextAvailableByte, e);
    // Clamp
    _nextAvailableByte = _nextAvailableByte.clamp(startOffset, startOffset + keyData.length);
  }

  /// Wrapper compatibilité : marque des bits comme utilisés en arrondissant aux octets couvrants
  void markBitsAsUsed(int startBit, int endBit) {
    final startByte = (startBit / 8).floor();
    final endByte = ((endBit + 7) / 8).floor(); // exclusive
    markBytesAsUsed(startByte, endByte);
  }

  /// Trouve le prochain segment disponible de la taille demandée en bits (compat)
  /// Cette implémentation force une allocation alignée sur octet.
  ({int startBit, int endBit})? findAvailableSegment(String peerId, int bitsNeeded) {
    if (bitsNeeded <= 0) return null;
    final bytesNeeded = ((bitsNeeded + 7) ~/ 8);
    final res = findAvailableSegmentByBytes(peerId, bytesNeeded);
    if (res == null) return null;
    final startBit = res.startByte * 8;
    final endBit = (res.startByte + res.lengthBytes) * 8;
    return (startBit: startBit, endBit: endBit);
  }

  /// Trouve le prochain segment disponible en octets (allocation linéaire simplifiée)
  /// Retourne tuple (startByte, lengthBytes) ou null si pas assez d'octets.
  ({int startByte, int lengthBytes})? findAvailableSegmentByBytes(String peerId, int bytesNeeded) {
    if (bytesNeeded <= 0) return null;
    final firstFree = max(startOffset, _nextAvailableByte);
    final available = keyData.length - (firstFree - startOffset);
    if (available >= bytesNeeded) {
      return (startByte: firstFree, lengthBytes: bytesNeeded);
    }
    return null;
  }

  /// Extrait des octets contigus depuis la clé locale.
  /// [startByte] est l'index d'octet relatif au keyData (0-based)
  Uint8List extractKeyBytes(int startByte, int lengthBytes) {
    if (startByte < 0 || lengthBytes <= 0) throw RangeError('Invalid byte range');
    if (startByte < startOffset) {
      throw StateError('Cannot extract bytes from truncated part of key');
    }
    final endByte = startByte + lengthBytes;
    if (endByte > keyData.length) {
      throw RangeError('Requested bytes exceed key length');
    }
    return Uint8List.fromList(keyData.sublist(startByte, endByte));
  }

  /// Wrapper compatibilité bit -> octet: extrait des bits (peut être non aligned)
  Uint8List extractKeyBits(int startBit, int endBit) {
    if (endBit <= startBit) return Uint8List(0);
    final startByte = startBit ~/ 8;
    final endByte = ((endBit + 7) ~/ 8);
    final bytes = extractKeyBytes(startByte, endByte - startByte);

    // If startBit is byte-aligned and length is multiple of 8, return directly
    if (startBit % 8 == 0 && ((endBit - startBit) % 8) == 0) {
      return bytes;
    }

    // Otherwise, we need to shift bits to pack the bit-range starting at bit 0
    final bitsNeeded = endBit - startBit;
    final outBytes = Uint8List((bitsNeeded + 7) ~/ 8);
    for (int i = 0; i < bitsNeeded; i++) {
      final sourceBitIndex = startBit + i;
      final rel = sourceBitIndex - (startByte * 8);
      final srcByte = bytes[rel ~/ 8];
      final srcBitOff = rel % 8;
      final bit = (srcByte >> srcBitOff) & 1;
      if (bit == 1) {
        final tgtByteIndex = i ~/ 8;
        final tgtBitOff = i % 8;
        outBytes[tgtByteIndex] |= (1 << tgtBitOff);
      }
    }
    return outBytes;
  }

  /// Marque des octets comme consommés (tous les bits des octets sont marqués utilisés)
  void consumeBytes(int startByte, int lengthBytes) {
    if (lengthBytes <= 0) return;
    markBytesAsUsed(startByte, startByte + lengthBytes);
  }

  /// Consomme un segment de clé spécifié par un KeyInterval.
  /// Équivalent à consumeBytes(segment.startIndex, segment.length).
  void consume(KeyInterval segment) {
    consumeBytes(segment.startIndex, segment.length);
  }

  /// Alloue et consomme un segment de la taille demandée.
  /// Retourne le KeyInterval du segment alloué, ou null si pas assez d'espace.
  KeyInterval? allocateAndConsume(int bytesNeeded) {
    final seg = findAvailableSegmentByBytes('', bytesNeeded);
    if (seg == null) return null;

    final interval = KeyInterval(
      conversationId: id,
      startIndex: seg.startByte,
      endIndex: seg.startByte + seg.lengthBytes,
    );
    consume(interval);
    return interval;
  }

  /// Compte les octets disponibles dans toute la clé (allocation linéaire)
  int countAvailableBytes(String peerId) {
    final firstFree = max(startOffset, _nextAvailableByte);
    return keyData.length - (firstFree - startOffset);
  }

  /// Compte les bits disponibles (compat)
  int countAvailableBits(String peerId) {
    return countAvailableBytes(peerId) * 8;
  }

  /// Ajoute des octets à la fin de la clé (pour l'agrandissement)
  /// [kexId] - ID de la session d'échange pour l'historique (optionnel)
  SharedKey extend(Uint8List additionalKeyData, {String? kexId}) {
    if (additionalKeyData.isEmpty) return this;

    final newKeyData = Uint8List(keyData.length + additionalKeyData.length);
    newKeyData.setRange(0, keyData.length, keyData);
    newKeyData.setRange(keyData.length, newKeyData.length, additionalKeyData);

    // Create extended segment for history
    // baseIndex is taken from history.currentState to ensure consistency
    // between stored history and newly appended bytes (handles migration cases
    // where history and keyData might have diverged).
    final baseIndex = history.currentState.endIndex;
    final extSegment = KeyInterval(
      conversationId: id,
      startIndex: baseIndex,
      endIndex: baseIndex + additionalKeyData.length,
    );

    // Copy history and record extension
    final newHistory = history.copy();
    newHistory.recordExtension(
      segment: extSegment,
      reason: kexId != null ? 'kex id=$kexId' : 'extend',
      kexId: kexId,
    );

    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      createdAt: createdAt,
      startOffset: startOffset,
      history: newHistory,
      nextAvailableByte: _nextAvailableByte,
    );
  }

  /// Tronque le début de la clé jusqu'à l'index donné (exclus)
  /// [newStartOffset] doit être > startOffset et < lengthInBytes
  SharedKey truncate(int newStartOffset) {
    if (newStartOffset <= startOffset) return this;
    if (newStartOffset >= lengthInBytes) {
      // Tout supprimer
      return SharedKey(
        id: id,
        keyData: Uint8List(0),
        peerIds: List.from(peerIds),
        createdAt: createdAt,
        startOffset: newStartOffset,
        history: history.copy(),
        nextAvailableByte: newStartOffset,
      );
    }

    final bytesToRemove = newStartOffset - startOffset;
    final actualNewOffset = startOffset + bytesToRemove;

    final newKeyData = keyData.sublist(bytesToRemove);

    // Adjust nextAvailableByte relative to removed bytes
    int newNextAvailable = (_nextAvailableByte - bytesToRemove).clamp(0, newKeyData.length);

    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      createdAt: createdAt,
      startOffset: actualNewOffset,
      history: history.copy(),
      nextAvailableByte: actualNewOffset + newNextAvailable,
    );
  }

  /// Compacte la clé en supprimant les octets utilisés et réindexant
  SharedKey compact() {
    final availableBytes = <int>[];
    for (int b = startOffset; b < keyData.length; b++) {
      if (b >= _nextAvailableByte) availableBytes.add(b - startOffset);
    }

    final newBytesNeeded = availableBytes.length;
    final newKeyData = Uint8List(newBytesNeeded);
    for (int i = 0; i < availableBytes.length; i++) {
      final srcIndex = availableBytes[i] + startOffset;
      newKeyData[i] = keyData[srcIndex];
    }

    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      createdAt: createdAt,
      startOffset: 0,
      history: history.copy(),
      nextAvailableByte: 0,
    );
  }

  /// Sérialise la clé pour stockage local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyData': base64Encode(keyData),
      'peerIds': peerIds,
      'nextAvailableByte': _nextAvailableByte,
      'createdAt': createdAt.toIso8601String(),
      'startOffset': startOffset,
      'history': history.toJson(),
    };
  }

  /// Désérialise une clé depuis le stockage local
  factory SharedKey.fromJson(Map<String, dynamic> json) {
    final keyData = base64Decode(json['keyData'] as String);
    final startOffset = json['startOffset'] as int? ?? 0;
    final id = json['id'] as String;

    // Charger l'historique si présent
    KeyHistory? history;
    if (json['history'] != null) {
      history = KeyHistory.fromJson(json['history'] as Map<String, dynamic>);
    }

    int? nextAvail = json['nextAvailableByte'] as int? ?? startOffset;

    return SharedKey(
      id: id,
      keyData: Uint8List.fromList(keyData),
      peerIds: List<String>.from(json['peerIds'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startOffset: startOffset,
      history: history,
      nextAvailableByte: nextAvail,
    );
  }
}
