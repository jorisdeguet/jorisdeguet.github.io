import '../services/format_service.dart';

/// État d'une conversation
enum ConversationState {
  /// En attente que les participants rejoignent
  joining,
  /// Échange de clé en cours
  exchanging,
  /// Prête à utiliser (clé échangée)
  ready,
}

/// Représente une conversation entre plusieurs pairs.
class Conversation {
  /// ID unique de la conversation (= ID de la clé partagée)
  final String id;
  
  /// Liste des IDs des participants
  final List<String> peerIds;
  
  /// Nom de la conversation (optionnel)
  final String? name;
  
  /// État actuel de la conversation
  ConversationState state;

  /// Date de création
  final DateTime createdAt;
  
  /// Taille de la clé partagée en bits (0 = pas de clé)
  int totalKeyBits;

  /// Bits de clé utilisés
  int usedKeyBits;
  
  /// Infos de debug sur la clé locale des pairs
  /// Map<UserId, Map<String, dynamic>>
  final Map<String, dynamic> keyDebugInfo;
  
  Conversation({
    required this.id,
    required this.peerIds,
    this.name,
    this.state = ConversationState.joining,
    DateTime? createdAt,
    this.totalKeyBits = 0,
    this.usedKeyBits = 0,
    this.keyDebugInfo = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  /// La conversation a-t-elle une clé de chiffrement ?
  bool get hasKey => totalKeyBits > 0;

  /// La conversation est-elle non chiffrée ?
  bool get isUnencrypted => totalKeyBits == 0;

  /// La conversation est-elle prête à utiliser ?
  bool get isReady => state == ConversationState.ready;

  /// L'échange de clé est-il en cours ?
  bool get isExchanging => state == ConversationState.exchanging;

  /// Est-ce que des participants peuvent encore rejoindre ?
  bool get isJoining => state == ConversationState.joining;

  /// La clé est-elle presque épuisée (< 10%) ?
  bool get isKeyLow => hasKey && keyRemainingPercent < 10;

  /// La clé est-elle épuisée ?
  bool get isKeyExhausted => hasKey && remainingKeyBits <= 0;

  /// Nom à afficher (liste des pairs)
  String get displayName {
    // Utiliser les IDs utilisateur (raccourcis)
    final names = peerIds
        .map((id) => id.length > 8 ? id.substring(0, 8) : id)
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
    return FormatService.formatBytes(bytes);
  }

  /// Pourcentage de clé utilisée
  double get keyUsagePercent => hasKey ? (usedKeyBits / totalKeyBits) * 100 : 0;

  /// Pourcentage de clé restante
  double get keyRemainingPercent => hasKey ? 100 - keyUsagePercent : 0;

  /// Met à jour avec l'utilisation de la clé
  void updateKeyUsage(int bitsUsed) {
    usedKeyBits += bitsUsed;
  }

  /// Sérialise pour Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'peerIds': peerIds,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'totalKeyBits': totalKeyBits,
      'usedKeyBits': usedKeyBits,
      'keyDebugInfo': keyDebugInfo,
    };
  }

  /// Désérialise depuis Firebase
  factory Conversation.fromFirestore(Map<String, dynamic> data) {
    return Conversation(
      id: data['id'] as String,
      peerIds: List<String>.from(data['peerIds'] as List),
      state: ConversationState.values.firstWhere(
        (s) => s.name == data['state'],
        orElse: () => ConversationState.joining,
      ),
      createdAt: DateTime.parse(data['createdAt'] as String),
      totalKeyBits: data['totalKeyBits'] as int? ?? 0,
      usedKeyBits: data['usedKeyBits'] as int? ?? 0,
      keyDebugInfo: data['keyDebugInfo'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Sérialise pour stockage local
  Map<String, dynamic> toJson() => toFirestore();
  
  /// Désérialise depuis stockage local
  factory Conversation.fromJson(Map<String, dynamic> json) => 
      Conversation.fromFirestore(json);

  Conversation copyWith({
    int? usedKeyBits,
    Map<String, dynamic>? keyDebugInfo,
  }) {
    return Conversation(
      id: id,
      peerIds: peerIds,
      createdAt: createdAt,
      totalKeyBits: totalKeyBits,
      usedKeyBits: usedKeyBits ?? this.usedKeyBits,
      keyDebugInfo: keyDebugInfo ?? this.keyDebugInfo,
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
