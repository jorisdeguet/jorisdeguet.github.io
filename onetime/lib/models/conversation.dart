/// Représente une conversation entre plusieurs pairs.
class Conversation {
  /// ID unique de la conversation (= ID de la clé partagée)
  final String id;
  
  /// Liste des IDs des participants
  final List<String> peerIds;
  
  /// Noms d'affichage des participants (pour l'UI)
  final Map<String, String> peerNames;
  
  /// Nom de la conversation (optionnel)
  final String? name;
  
  /// Date de création
  final DateTime createdAt;
  
  /// Date du dernier message
  DateTime lastMessageAt;
  
  /// Aperçu du dernier message (texte déchiffré)
  String? lastMessagePreview;
  
  /// ID de l'expéditeur du dernier message
  String? lastMessageSenderId;
  
  /// Taille de la clé partagée en bits (0 = pas de clé)
  final int totalKeyBits;
  
  /// Bits de clé utilisés
  int usedKeyBits;
  
  /// Nombre de messages dans la conversation
  int messageCount;

  Conversation({
    required this.id,
    required this.peerIds,
    Map<String, String>? peerNames,
    this.name,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    required this.totalKeyBits,
    this.usedKeyBits = 0,
    this.messageCount = 0,
  }) : peerNames = peerNames ?? {},
       createdAt = createdAt ?? DateTime.now(),
       lastMessageAt = lastMessageAt ?? DateTime.now();

  /// La conversation a-t-elle une clé de chiffrement ?
  bool get hasKey => totalKeyBits > 0;

  /// La conversation est-elle non chiffrée ?
  bool get isUnencrypted => totalKeyBits == 0;

  /// Nom à afficher (nom personnalisé ou liste des pairs)
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    
    final names = peerIds
        .map((id) => peerNames[id] ?? id.substring(0, 8))
        .toList();
    
    if (names.length <= 3) {
      return names.join(', ');
    }
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  /// Bits de clé restants
  int get remainingKeyBits => totalKeyBits - usedKeyBits;
  
  /// Bytes de clé restants
  int get remainingKeyBytes => remainingKeyBits ~/ 8;
  
  /// Clé restante formatée (KB ou MB)
  String get remainingKeyFormatted {
    if (!hasKey) return 'Pas de clé';
    final bytes = remainingKeyBytes;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  /// Pourcentage de clé utilisée
  double get keyUsagePercent => hasKey ? (usedKeyBits / totalKeyBits) * 100 : 0;

  /// Pourcentage de clé restante
  double get keyRemainingPercent => hasKey ? 100 - keyUsagePercent : 0;

  /// Aperçu du dernier message avec expéditeur
  String get lastMessageDisplay {
    if (lastMessagePreview == null) return 'Aucun message';
    
    final senderName = lastMessageSenderId != null 
        ? peerNames[lastMessageSenderId] ?? 'Inconnu'
        : '';
    
    final preview = lastMessagePreview!.length > 50
        ? '${lastMessagePreview!.substring(0, 47)}...'
        : lastMessagePreview!;
    
    if (senderName.isNotEmpty) {
      return '$senderName: $preview';
    }
    return preview;
  }

  /// Met à jour avec un nouveau message
  void updateWithMessage({
    required String preview,
    required String senderId,
    required int bitsUsed,
  }) {
    lastMessagePreview = preview;
    lastMessageSenderId = senderId;
    lastMessageAt = DateTime.now();
    usedKeyBits += bitsUsed;
    messageCount++;
  }

  /// Sérialise pour Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'peerIds': peerIds,
      'peerNames': peerNames,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessagePreview': lastMessagePreview,
      'lastMessageSenderId': lastMessageSenderId,
      'totalKeyBits': totalKeyBits,
      'usedKeyBits': usedKeyBits,
      'messageCount': messageCount,
    };
  }

  /// Désérialise depuis Firebase
  factory Conversation.fromFirestore(Map<String, dynamic> data) {
    return Conversation(
      id: data['id'] as String,
      peerIds: List<String>.from(data['peerIds'] as List),
      peerNames: Map<String, String>.from(data['peerNames'] as Map? ?? {}),
      name: data['name'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      lastMessageAt: DateTime.parse(data['lastMessageAt'] as String),
      lastMessagePreview: data['lastMessagePreview'] as String?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      totalKeyBits: data['totalKeyBits'] as int,
      usedKeyBits: data['usedKeyBits'] as int? ?? 0,
      messageCount: data['messageCount'] as int? ?? 0,
    );
  }

  /// Sérialise pour stockage local
  Map<String, dynamic> toJson() => toFirestore();
  
  /// Désérialise depuis stockage local
  factory Conversation.fromJson(Map<String, dynamic> json) => 
      Conversation.fromFirestore(json);

  Conversation copyWith({
    String? name,
    Map<String, String>? peerNames,
    String? lastMessagePreview,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    int? usedKeyBits,
    int? messageCount,
  }) {
    return Conversation(
      id: id,
      peerIds: peerIds,
      peerNames: peerNames ?? this.peerNames,
      name: name ?? this.name,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      totalKeyBits: totalKeyBits,
      usedKeyBits: usedKeyBits ?? this.usedKeyBits,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}

/// Métadonnées de la clé locale (stockée séparément des données de clé)
class LocalKeyMetadata {
  /// ID de la conversation/clé
  final String keyId;
  
  /// Chemin du fichier binaire de la clé
  final String keyFilePath;
  
  /// Taille de la clé en bytes
  final int sizeBytes;
  
  /// Bitmap d'utilisation (chemin fichier)
  final String usageBitmapPath;
  
  /// Date de création locale
  final DateTime createdAt;

  LocalKeyMetadata({
    required this.keyId,
    required this.keyFilePath,
    required this.sizeBytes,
    required this.usageBitmapPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get sizeBits => sizeBytes * 8;

  Map<String, dynamic> toJson() {
    return {
      'keyId': keyId,
      'keyFilePath': keyFilePath,
      'sizeBytes': sizeBytes,
      'usageBitmapPath': usageBitmapPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalKeyMetadata.fromJson(Map<String, dynamic> json) {
    return LocalKeyMetadata(
      keyId: json['keyId'] as String,
      keyFilePath: json['keyFilePath'] as String,
      sizeBytes: json['sizeBytes'] as int,
      usageBitmapPath: json['usageBitmapPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
