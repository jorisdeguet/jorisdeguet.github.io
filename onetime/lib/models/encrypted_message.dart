import 'dart:typed_data';
import 'dart:convert';

/// Représente un message chiffré avec One-Time Pad.
/// 
/// Le message contient les données chiffrées (XOR avec la clé)
/// ainsi que les métadonnées permettant de le déchiffrer.
class EncryptedMessage {
  /// ID unique du message
  final String id;
  
  /// ID de la clé partagée utilisée
  final String keyId;
  
  /// ID de l'expéditeur
  final String senderId;
  
  /// Liste des segments de clé utilisés (permet les longs messages)
  final List<({int startBit, int endBit})> keySegments;
  
  /// Données chiffrées (XOR du message avec la clé)
  final Uint8List ciphertext;
  
  /// Timestamp de création
  final DateTime createdAt;
  
  /// Indique si le message a été lu/déchiffré par le destinataire
  bool isRead;
  
  /// Mode ultra-secure : suppression après lecture
  final bool deleteAfterRead;
  
  /// Indique si le message était compressé avant chiffrement
  final bool isCompressed;

  EncryptedMessage({
    required this.id,
    required this.keyId,
    required this.senderId,
    required this.keySegments,
    required this.ciphertext,
    DateTime? createdAt,
    this.isRead = false,
    this.deleteAfterRead = false,
    this.isCompressed = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Indique si le message est chiffré (a des segments de clé)
  bool get isEncrypted => keySegments.isNotEmpty;

  /// Index du premier bit utilisé (du premier segment), ou 0 si non chiffré
  int get startBit => keySegments.isNotEmpty ? keySegments.first.startBit : 0;
  
  /// Index du dernier bit utilisé (du dernier segment), ou 0 si non chiffré
  int get endBit => keySegments.isNotEmpty ? keySegments.last.endBit : 0;
  
  /// Longueur totale des segments utilisés en bits
  int get totalBitsUsed {
    if (keySegments.isEmpty) return 0;
    return keySegments.fold(0, (sum, seg) => sum + (seg.endBit - seg.startBit));
  }

  /// Sérialise le message pour envoi sur Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'keyId': keyId,
      'senderId': senderId,
      'keySegments': keySegments.map((s) => {
        'startBit': s.startBit,
        'endBit': s.endBit,
      }).toList(),
      'ciphertext': base64Encode(ciphertext),
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'deleteAfterRead': deleteAfterRead,
      'isCompressed': isCompressed,
    };
  }

  /// Désérialise un message depuis Firebase
  factory EncryptedMessage.fromJson(Map<String, dynamic> json) {
    final segmentsList = (json['keySegments'] as List).map((s) {
      final map = s as Map<String, dynamic>;
      return (
        startBit: map['startBit'] as int,
        endBit: map['endBit'] as int,
      );
    }).toList();

    return EncryptedMessage(
      id: json['id'] as String,
      keyId: json['keyId'] as String,
      senderId: json['senderId'] as String,
      keySegments: segmentsList,
      ciphertext: base64Decode(json['ciphertext'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      deleteAfterRead: json['deleteAfterRead'] as bool? ?? false,
      isCompressed: json['isCompressed'] as bool? ?? false,
    );
  }

  /// Copie le message avec modifications
  EncryptedMessage copyWith({
    bool? isRead,
  }) {
    return EncryptedMessage(
      id: id,
      keyId: keyId,
      senderId: senderId,
      keySegments: keySegments,
      ciphertext: ciphertext,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      deleteAfterRead: deleteAfterRead,
      isCompressed: isCompressed,
    );
  }

  @override
  String toString() => 'EncryptedMessage($id from $senderId, ${ciphertext.length} bytes${isCompressed ? ', compressed' : ''})';
}

/// Représente un message en clair (avant chiffrement ou après déchiffrement)
class PlainMessage {
  /// Contenu du message en texte
  final String content;
  
  /// ID de l'expéditeur
  final String senderId;
  
  /// Timestamp
  final DateTime timestamp;

  PlainMessage({
    required this.content,
    required this.senderId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convertit le message en bytes UTF-8
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(content));
  
  /// Crée un message depuis des bytes UTF-8
  factory PlainMessage.fromBytes(Uint8List bytes, String senderId, {DateTime? timestamp}) {
    return PlainMessage(
      content: utf8.decode(bytes),
      senderId: senderId,
      timestamp: timestamp,
    );
  }

  /// Longueur du message en bits
  int get lengthInBits => toBytes().length * 8;
}
