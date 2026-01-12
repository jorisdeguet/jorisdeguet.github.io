import 'dart:typed_data';
import 'dart:convert';

/// Type de contenu d'un message
enum MessageContentType {
  text,
  image,
  file,
}

/// Qualité de redimensionnement d'image
enum ImageQuality {
  small(320, 'Petite (~50KB)'),
  medium(800, 'Moyenne (~150KB)'),
  large(1920, 'Grande (~500KB)'),
  original(0, 'Originale');

  final int maxDimension;
  final String label;
  const ImageQuality(this.maxDimension, this.label);
}

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
  
  /// Liste des participants qui ont lu le message
  List<String> readBy;

  /// Liste des participants qui ont transféré/reçu le message
  List<String> transferredBy;
  
  /// Indique si le message était compressé avant chiffrement
  final bool isCompressed;

  /// Type de contenu
  final MessageContentType contentType;

  /// Nom du fichier (pour les fichiers et images)
  final String? fileName;

  /// Type MIME du fichier
  final String? mimeType;

  EncryptedMessage({
    required this.id,
    required this.keyId,
    required this.senderId,
    required this.keySegments,
    required this.ciphertext,
    DateTime? createdAt,
    List<String>? readBy,
    List<String>? transferredBy,
    this.isCompressed = false,
    this.contentType = MessageContentType.text,
    this.fileName,
    this.mimeType,
  }) : createdAt = createdAt ?? DateTime.now(),
       // Le sender est automatiquement inclus dans les listes
       readBy = readBy ?? [senderId],
       transferredBy = transferredBy ?? [senderId];

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

  /// Vérifie si tous les participants ont transféré le message
  bool allTransferred(List<String> participants) {
    return participants.every((p) => transferredBy.contains(p));
  }

  /// Vérifie si tous les participants ont lu le message
  bool allRead(List<String> participants) {
    return participants.every((p) => readBy.contains(p));
  }

  /// Marque le message comme transféré par un participant
  void markTransferredBy(String participantId) {
    if (!transferredBy.contains(participantId)) {
      transferredBy.add(participantId);
    }
  }

  /// Marque le message comme lu par un participant
  void markReadBy(String participantId) {
    if (!readBy.contains(participantId)) {
      readBy.add(participantId);
    }
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
      'readBy': readBy,
      'transferredBy': transferredBy,
      'isCompressed': isCompressed,
      'contentType': contentType.name,
      'fileName': fileName,
      'mimeType': mimeType,
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
      readBy: List<String>.from(json['readBy'] as List? ?? [json['senderId']]),
      transferredBy: List<String>.from(json['transferredBy'] as List? ?? [json['senderId']]),
      isCompressed: json['isCompressed'] as bool? ?? false,
      contentType: MessageContentType.values.firstWhere(
        (t) => t.name == json['contentType'],
        orElse: () => MessageContentType.text,
      ),
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }

  @override
  String toString() => 'EncryptedMessage($id from $senderId, ${ciphertext.length} bytes, ${contentType.name}${isCompressed ? ', compressed' : ''})';
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
