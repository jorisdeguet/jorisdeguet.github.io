import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

/// Contribution d'une session KEX à une clé partagée
class KexContribution {
  final String kexId;
  final int startByte;
  final int endByte;

  KexContribution({required this.kexId, required this.startByte, required this.endByte});

  Map<String, dynamic> toJson() => {
        'kexId': kexId,
        'startByte': startByte,
        'endByte': endByte,
      };

  factory KexContribution.fromJson(Map<String, dynamic> json) => KexContribution(
        kexId: json['kexId'] as String,
        startByte: json['startByte'] as int,
        endByte: json['endByte'] as int,
      );
}

/// Représente une clé partagée entre plusieurs pairs pour le chiffrement One-Time Pad.
///
/// L'allocation est linéaire : tous les pairs partagent l'espace entier de la clé.
/// Cette implémentation force l'alignement sur octet et utilise un bitmap par octet
/// (chaque octet est marqué 0 = libre, 1 = utilisé). Les anciennes API bit-level
/// sont exposées en tant que wrappers pour compatibilité mais l'allocation se fait
/// en octets.
class SharedKey {
  /// Identifiant unique de la clé partagée
  final String id;

  /// Les données binaires de la clé
  final Uint8List keyData;

  /// Liste des IDs des pairs partageant cette clé (triés par ordre croissante)
  final List<String> peerIds;

  /// Bitmap par octet indiquant si l'octet est utilisé (1) ou libre (0)
  Uint8List _usedByteMap;

  /// Date de création de la clé
  final DateTime createdAt;

  /// Offset de départ de la clé (en octets)
  /// Indique combien d'octets ont été tronqués au début de la clé.
  final int startOffset;

  final List<KexContribution>? kexContributions;

  SharedKey({
    required this.id,
    required this.keyData,
    required this.peerIds,
    Uint8List? usedBitmap,
    DateTime? createdAt,
    this.startOffset = 0,
    this.kexContributions,
  })  : _usedByteMap = usedBitmap ?? Uint8List(keyData.length),
        createdAt = createdAt ?? DateTime.now() {
    // S'assurer que les peers sont triés
    peerIds.sort();

    // Ensure the used map has the expected size matching keyData.
    if (_usedByteMap.length != keyData.length) {
      final resized = Uint8List(keyData.length);
      final copyLen = min(_usedByteMap.length, keyData.length);
      if (copyLen > 0) {
        resized.setRange(0, copyLen, _usedByteMap.sublist(0, copyLen));
      }
      _usedByteMap = resized;
    }
  }

  /// Longueur totale logique de la clé en octets (incluant l'offset)
  int get lengthInBytes => startOffset + keyData.length;

  /// Longueur totale logique en bits (compatibilité)
  int get lengthInBits => lengthInBytes * 8;

  /// Nombre de pairs partageant cette clé
  int get peerCount => peerIds.length;

  void _checkByteIndex(int byteIndex) {
    if (byteIndex < 0 || byteIndex >= _usedByteMap.length) {
      throw StateError('Byte index out of range: $byteIndex (map length=${_usedByteMap.length})');
    }
  }

  /// Vérifie si un octet est déjà utilisé
  bool isByteUsed(int byteIndex) {
    if (byteIndex < startOffset) return true; // considéré comme utilisé si tronqué
    _checkByteIndex(byteIndex);
    return _usedByteMap[byteIndex] != 0;
  }

  /// Wrapper compatibilité : vérifie si un bit est utilisé en regardant l'octet contenant le bit.
  bool isBitUsed(int bitIndex) {
    final byteIndex = bitIndex ~/ 8;
    return isByteUsed(byteIndex);
  }

  /// Marque un intervalle d'octets comme utilisé (endByte exclusive)
  void markBytesAsUsed(int startByte, int endByte) {
    if (endByte <= startByte) return;
    final s = startByte < startOffset ? startOffset : startByte;
    for (int b = s; b < endByte && b < _usedByteMap.length; b++) {
      _usedByteMap[b] = 0xFF;
    }
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

  /// Trouve le prochain segment disponible en octets (requiert octets contigus libres)
  /// Retourne tuple (startByte, lengthBytes) ou null si pas assez d'octets.
  ({int startByte, int lengthBytes})? findAvailableSegmentByBytes(String peerId, int bytesNeeded) {
    if (bytesNeeded <= 0) return null;
    final firstByteIndex = startOffset; // startOffset is in bytes now
    int consecutive = 0;
    int startByte = firstByteIndex;

    for (int b = firstByteIndex; b < keyData.length; b++) {
      final isByteFree = _usedByteMap[b] == 0;
      if (isByteFree) {
        if (consecutive == 0) startByte = b;
        consecutive++;
        if (consecutive >= bytesNeeded) {
          return (startByte: startByte, lengthBytes: bytesNeeded);
        }
      } else {
        consecutive = 0;
      }
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

  /// Compte les octets disponibles dans toute la clé (allocation linéaire)
  int countAvailableBytes(String peerId) {
    int count = 0;
    for (int b = startOffset; b < keyData.length; b++) {
      if (_usedByteMap[b] == 0) count++;
    }
    return count;
  }

  /// Compte les bits disponibles (compat)
  int countAvailableBits(String peerId) {
    return countAvailableBytes(peerId) * 8;
  }

  /// Ajoute des octets à la fin de la clé (pour l'agrandissement)
  SharedKey extend(Uint8List additionalKeyData) {
    if (additionalKeyData.isEmpty) return this;

    final newKeyData = Uint8List(keyData.length + additionalKeyData.length);
    newKeyData.setRange(0, keyData.length, keyData);
    newKeyData.setRange(keyData.length, newKeyData.length, additionalKeyData);

    final newUsedMap = Uint8List(newKeyData.length);
    newUsedMap.setRange(0, _usedByteMap.length, _usedByteMap);

    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      usedBitmap: newUsedMap,
      createdAt: createdAt,
      startOffset: startOffset,
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
      );
    }

    final bytesToRemove = newStartOffset - startOffset;
    final actualNewOffset = startOffset + bytesToRemove;

    final newKeyData = keyData.sublist(bytesToRemove);
    final newUsedMap = _usedByteMap.sublist(bytesToRemove);

    return SharedKey(
      id: id,
      keyData: newKeyData,
      peerIds: List.from(peerIds),
      usedBitmap: newUsedMap,
      createdAt: createdAt,
      startOffset: actualNewOffset,
    );
  }

  /// Compacte la clé en supprimant les octets utilisés et réindexant
  SharedKey compact() {
    final availableBytes = <int>[];
    for (int b = startOffset; b < keyData.length; b++) {
      if (_usedByteMap[b] == 0) availableBytes.add(b - startOffset);
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
    );
  }

  /// Sérialise la clé pour stockage local
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyData': base64Encode(keyData),
      'peerIds': peerIds,
      'usedBitmap': base64Encode(_usedByteMap),
      'createdAt': createdAt.toIso8601String(),
      'startOffset': startOffset,
      'kexContributions': kexContributions?.map((c) => c.toJson()).toList(),
    };
  }

  /// Désérialise une clé depuis le stockage local
  factory SharedKey.fromJson(Map<String, dynamic> json) {
    final kexList = (json['kexContributions'] as List?)
        ?.map((e) => KexContribution.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return SharedKey(
      id: json['id'] as String,
      keyData: base64Decode(json['keyData'] as String),
      peerIds: List<String>.from(json['peerIds'] as List),
      usedBitmap: base64Decode(json['usedBitmap'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startOffset: json['startOffset'] as int? ?? 0,
      kexContributions: kexList,
    );
  }

  /// Getter pour le bitmap d'utilisation (lecture seule)
  Uint8List get usedBitmap => Uint8List.fromList(_usedByteMap);
}
