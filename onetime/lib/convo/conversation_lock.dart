/// Représente un lock sur un index d'octet dans une conversation.
/// Le lock est identifié par l'index d'octet qu'il verrouille.
class ConversationLock {
  /// L'index d'octet verrouillé (utilisé comme ID du document)
  final int byteIndex;

  /// ID de l'utilisateur qui détient le lock
  final String lockerId;

  /// Date de création du lock
  final DateTime createdAt;

  ConversationLock({
    required this.byteIndex,
    required this.lockerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Vérifie si le lock est expiré (> 5 minutes)
  bool isExpired() {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    return diff.inMinutes >= 5;
  }

  /// Sérialise pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'lockerId': lockerId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Désérialise depuis Firestore
  factory ConversationLock.fromFirestore(int byteIndex, Map<String, dynamic> data) {
    return ConversationLock(
      byteIndex: byteIndex,
      lockerId: data['lockerId'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
    );
  }
}
