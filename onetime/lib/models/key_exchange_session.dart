
/// Modèle représentant une session d'échange de clé dans Firestore.
///
/// Cette session permet de synchroniser l'état entre:
/// - Le participant source qui affiche les QR codes
/// - Les participants qui scannent les QR codes
class KeyExchangeSessionModel {
  /// ID unique de la session
  final String id;

  /// ID de la conversation associée (si existante)
  final String? conversationId;

  /// Liste des participants (IDs utilisateur)
  final List<String> participants;

  /// ID du participant source (celui qui affiche les QR codes)
  final String sourceId;

  /// Taille totale de la clé en bits
  final int totalKeyBits;

  /// Nombre total de segments
  final int totalSegments;

  /// Index du segment actuellement affiché par la source
  int currentSegmentIndex;

  /// Map: segmentIndex -> liste des participants ayant scanné ce segment
  final Map<int, List<String>> scannedBy;

  /// Status de la session
  KeyExchangeStatus status;

  /// Date de création
  final DateTime createdAt;

  /// Date de dernière mise à jour
  DateTime updatedAt;

  KeyExchangeSessionModel({
    required this.id,
    this.conversationId,
    required this.participants,
    required this.sourceId,
    required this.totalKeyBits,
    required this.totalSegments,
    this.currentSegmentIndex = 0,
    Map<int, List<String>>? scannedBy,
    this.status = KeyExchangeStatus.inProgress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : scannedBy = scannedBy ?? {},
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Les autres participants (sans la source)
  List<String> get otherParticipants =>
      participants.where((p) => p != sourceId).toList();

  /// Vérifie si tous les autres participants ont scanné un segment donné
  bool allParticipantsScannedSegment(int segmentIndex) {
    final scanned = scannedBy[segmentIndex] ?? [];
    return otherParticipants.every((p) => scanned.contains(p));
  }

  /// Vérifie si un participant a scanné un segment
  bool hasParticipantScannedSegment(String participantId, int segmentIndex) {
    return scannedBy[segmentIndex]?.contains(participantId) ?? false;
  }

  /// Nombre de participants ayant scanné le segment courant
  int get currentSegmentScannedCount {
    final scanned = scannedBy[currentSegmentIndex] ?? [];
    return scanned.where((p) => p != sourceId).length;
  }

  /// Vérifie si l'échange est terminé
  bool get isComplete =>
      status == KeyExchangeStatus.completed ||
      (currentSegmentIndex >= totalSegments &&
       allParticipantsScannedSegment(totalSegments - 1));

  /// Sérialise pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'conversationId': conversationId,
      'participants': participants,
      'sourceId': sourceId,
      'totalKeyBits': totalKeyBits,
      'totalSegments': totalSegments,
      'currentSegmentIndex': currentSegmentIndex,
      'scannedBy': scannedBy.map((k, v) => MapEntry(k.toString(), v)),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Désérialise depuis Firestore
  factory KeyExchangeSessionModel.fromFirestore(Map<String, dynamic> data) {
    final scannedByRaw = data['scannedBy'] as Map<String, dynamic>? ?? {};
    final scannedBy = <int, List<String>>{};
    scannedByRaw.forEach((key, value) {
      scannedBy[int.parse(key)] = List<String>.from(value as List);
    });

    return KeyExchangeSessionModel(
      id: data['id'] as String,
      conversationId: data['conversationId'] as String?,
      participants: List<String>.from(data['participants'] as List),
      sourceId: data['sourceId'] as String,
      totalKeyBits: data['totalKeyBits'] as int,
      totalSegments: data['totalSegments'] as int,
      currentSegmentIndex: data['currentSegmentIndex'] as int? ?? 0,
      scannedBy: scannedBy,
      status: KeyExchangeStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => KeyExchangeStatus.inProgress,
      ),
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }

  KeyExchangeSessionModel copyWith({
    int? currentSegmentIndex,
    Map<int, List<String>>? scannedBy,
    KeyExchangeStatus? status,
  }) {
    return KeyExchangeSessionModel(
      id: id,
      conversationId: conversationId,
      participants: participants,
      sourceId: sourceId,
      totalKeyBits: totalKeyBits,
      totalSegments: totalSegments,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      scannedBy: scannedBy ?? Map.from(this.scannedBy),
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Status d'une session d'échange de clé
enum KeyExchangeStatus {
  /// En attente de participants
  waiting,

  /// Échange en cours
  inProgress,

  /// Échange terminé avec succès
  completed,

  /// Échange annulé
  cancelled,
}

