/// Représente un segment de clé utilisé pour chiffrer/déchiffrer un message.
/// 
/// Contient les métadonnées nécessaires pour identifier quel segment
/// de la clé partagée a été utilisé.
class KeySegment {
  /// ID de la clé partagée dont ce segment est extrait
  final String keyId;
  
  /// Index du premier bit (inclus)
  final int startBit;
  
  /// Index du dernier bit (exclus)
  final int endBit;
  
  /// ID du peer qui a utilisé ce segment
  final String usedByPeerId;
  
  /// Timestamp de l'utilisation
  final DateTime usedAt;

  KeySegment({
    required this.keyId,
    required this.startBit,
    required this.endBit,
    required this.usedByPeerId,
    DateTime? usedAt,
  }) : usedAt = usedAt ?? DateTime.now();

  /// Longueur du segment en bits
  int get lengthInBits => endBit - startBit;
  
  /// Longueur du segment en octets (arrondi supérieur)
  int get lengthInBytes => (lengthInBits + 7) ~/ 8;

  /// Vérifie si deux segments se chevauchent
  bool overlapsWith(KeySegment other) {
    if (keyId != other.keyId) return false;
    return startBit < other.endBit && endBit > other.startBit;
  }

  /// Sérialise le segment pour transmission/stockage
  Map<String, dynamic> toJson() {
    return {
      'keyId': keyId,
      'startBit': startBit,
      'endBit': endBit,
      'usedByPeerId': usedByPeerId,
      'usedAt': usedAt.toIso8601String(),
    };
  }

  /// Désérialise un segment
  factory KeySegment.fromJson(Map<String, dynamic> json) {
    return KeySegment(
      keyId: json['keyId'] as String,
      startBit: json['startBit'] as int,
      endBit: json['endBit'] as int,
      usedByPeerId: json['usedByPeerId'] as String,
      usedAt: DateTime.parse(json['usedAt'] as String),
    );
  }

  @override
  String toString() => 'KeySegment($keyId: $startBit-$endBit by $usedByPeerId)';
}

/// Représente une demande de lock sur un segment de clé.
/// Utilisé pour la synchronisation transactionnelle avant envoi.
class KeySegmentLock {
  /// ID unique du lock
  final String lockId;
  
  /// Segment sur lequel le lock est demandé
  final KeySegment segment;
  
  /// Timestamp d'expiration du lock
  final DateTime expiresAt;
  
  /// Statut du lock
  final KeySegmentLockStatus status;

  KeySegmentLock({
    required this.lockId,
    required this.segment,
    required this.expiresAt,
    this.status = KeySegmentLockStatus.pending,
  });

  /// Vérifie si le lock est expiré
  bool get isExpired => DateTime.now().isAfter(expiresAt);

}

/// Statut d'un lock sur un segment de clé
enum KeySegmentLockStatus {
  /// Lock en attente de confirmation
  pending,
  
  /// Lock acquis avec succès
  acquired,
  
  /// Lock refusé (segment déjà utilisé ou locké)
  denied,
  
  /// Lock libéré
  released,
  
  /// Lock expiré
  expired,
}
