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
  
  /// Taille de la clé partagée en octets (0 = pas de clé)
  int totalKeyBytes;

  /// Octets de clé utilisés
  int usedKeyBytes;

  /// Infos de debug sur la clé locale des pairs
  /// Map<UserId, Map<String, dynamic>>
  final Map<String, dynamic> keyDebugInfo;
  
  Conversation({
    required this.id,
    required this.peerIds,
    this.name,
    this.state = ConversationState.joining,
    DateTime? createdAt,
    this.totalKeyBytes = 0,
    this.usedKeyBytes = 0,
    this.keyDebugInfo = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  /// La conversation a-t-elle une clé de chiffrement ?
  bool get hasKey => totalKeyBytes > 0;

  /// La conversation est-elle prête à utiliser ?
  bool get isReady => state == ConversationState.ready;

  /// L'échange de clé est-il en cours ?
  bool get isExchanging => state == ConversationState.exchanging;

  /// Est-ce que des participants peuvent encore rejoindre ?
  bool get isJoining => state == ConversationState.joining;

  /// La clé est-elle presque épuisée (< 10%) ?
  bool get isKeyLow => hasKey && keyRemainingPercent < 10;

  /// La clé est-elle épuisée ?
  bool get isKeyExhausted => hasKey && remainingKeyBytes <= 0;

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

  /// Octets de clé restants
  int get remainingKeyBytes => totalKeyBytes - usedKeyBytes;

  /// Bits restants (compatibilité)
  int get remainingKeyBits => remainingKeyBytes * 8;

  /// Clé restante formatée (KB ou MB)
  String get remainingKeyFormatted {
    if (!hasKey) return 'Pas de clé';
    final bytes = remainingKeyBytes;
    return FormatService.formatBytes(bytes);
  }

  /// Pourcentage de clé utilisée
  double get keyUsagePercent => hasKey ? (usedKeyBytes / totalKeyBytes) * 100 : 0;

  /// Pourcentage de clé restante
  double get keyRemainingPercent => hasKey ? 100 - keyUsagePercent : 0;

  /// Met à jour avec l'utilisation de la clé
  void updateKeyUsageBytes(int bytesUsed) {
    usedKeyBytes += bytesUsed;
  }

  /// Sérialise pour Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'peerIds': peerIds,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'totalKeyBytes': totalKeyBytes,
      'usedKeyBytes': usedKeyBytes,
      'keyDebugInfo': keyDebugInfo,
    };
  }

  /// Désérialise depuis Firebase
  factory Conversation.fromFirestore(Map<String, dynamic> data) {
    // Support both new byte fields and legacy bit fields
    int totalBytes = 0;
    int usedBytes = 0;
    if (data.containsKey('totalKeyBytes')) {
      totalBytes = data['totalKeyBytes'] as int? ?? 0;
    } else if (data.containsKey('totalKeyBits')) {
      totalBytes = ((data['totalKeyBits'] as int? ?? 0) + 7) ~/ 8;
    }

    if (data.containsKey('usedKeyBytes')) {
      usedBytes = data['usedKeyBytes'] as int? ?? 0;
    } else if (data.containsKey('usedKeyBits')) {
      usedBytes = ((data['usedKeyBits'] as int? ?? 0) + 7) ~/ 8;
    }

    return Conversation(
      id: data['id'] as String,
      peerIds: List<String>.from(data['peerIds'] as List),
      state: ConversationState.values.firstWhere(
        (s) => s.name == data['state'],
        orElse: () => ConversationState.joining,
      ),
      createdAt: DateTime.parse(data['createdAt'] as String),
      totalKeyBytes: totalBytes,
      usedKeyBytes: usedBytes,
      keyDebugInfo: data['keyDebugInfo'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Sérialise pour stockage local
  Map<String, dynamic> toJson() => toFirestore();
  
  /// Désérialise depuis stockage local
  factory Conversation.fromJson(Map<String, dynamic> json) => 
      Conversation.fromFirestore(json);

}

