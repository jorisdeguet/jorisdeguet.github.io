import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/key_exchange_session.dart';

/// Service pour synchroniser les sessions d'échange de clé via Firestore.
///
/// Permet de:
/// - Créer une session d'échange
/// - Notifier quand un participant a scanné un segment
/// - Écouter les changements de la session en temps réel
/// - Passer au segment suivant quand tous ont scanné
class KeyExchangeSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection des sessions d'échange
  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('key_exchange_sessions');

  /// Crée une nouvelle session d'échange de clé dans Firestore
  Future<KeyExchangeSessionModel> createSession({
    required String sourceId,
    required List<String> participants,
    required int totalKeyBits,
    required int totalSegments,
    String? conversationId,
  }) async {
    final sessionId = 'kex_${DateTime.now().millisecondsSinceEpoch}_$sourceId';

    // S'assurer que la source est dans les participants
    final allParticipants = {...participants, sourceId}.toList()..sort();

    final session = KeyExchangeSessionModel(
      id: sessionId,
      conversationId: conversationId,
      participants: allParticipants,
      sourceId: sourceId,
      totalKeyBits: totalKeyBits,
      totalSegments: totalSegments,
      currentSegmentIndex: 0,
      status: KeyExchangeStatus.inProgress,
    );

    await _sessionsRef.doc(sessionId).set(session.toFirestore());

    return session;
  }

  /// Récupère une session par ID
  Future<KeyExchangeSessionModel?> getSession(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return KeyExchangeSessionModel.fromFirestore(doc.data()!);
  }

  /// Écoute les changements d'une session en temps réel
  Stream<KeyExchangeSessionModel?> watchSession(String sessionId) {
    return _sessionsRef.doc(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return KeyExchangeSessionModel.fromFirestore(snapshot.data()!);
    });
  }

  /// Notifie que le participant courant a scanné un segment
  Future<void> markSegmentScanned({
    required String sessionId,
    required String participantId,
    required int segmentIndex,
  }) async {
    final docRef = _sessionsRef.doc(sessionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Session not found');
      }

      final session = KeyExchangeSessionModel.fromFirestore(snapshot.data()!);

      // Ajouter le participant à la liste des scannés pour ce segment
      final scannedBy = Map<int, List<String>>.from(session.scannedBy);
      final segmentScanned = List<String>.from(scannedBy[segmentIndex] ?? []);

      // Vérifier si le participant est dans la liste des participants
      final participants = List<String>.from(session.participants);
      final participantAdded = !participants.contains(participantId);
      if (participantAdded) {
        participants.add(participantId);
        participants.sort();
      }

      if (!segmentScanned.contains(participantId)) {
        segmentScanned.add(participantId);
        scannedBy[segmentIndex] = segmentScanned;

        final updates = <String, dynamic>{
          'scannedBy': scannedBy.map((k, v) => MapEntry(k.toString(), v)),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        // Ajouter le participant à la liste s'il n'y était pas
        if (participantAdded) {
          updates['participants'] = participants;
        }

        transaction.update(docRef, updates);
      }
    });
  }

  /// Passe au segment suivant (appelé par la source)
  Future<void> moveToNextSegment(String sessionId) async {
    final docRef = _sessionsRef.doc(sessionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Session not found');
      }

      final session = KeyExchangeSessionModel.fromFirestore(snapshot.data()!);
      final newIndex = session.currentSegmentIndex + 1;

      final updates = <String, dynamic>{
        'currentSegmentIndex': newIndex,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Si c'est le dernier segment, marquer comme terminé
      if (newIndex >= session.totalSegments) {
        updates['status'] = KeyExchangeStatus.completed.name;
      }

      transaction.update(docRef, updates);
    });
  }

  /// Marque la session comme terminée
  Future<void> completeSession(String sessionId) async {
    await _sessionsRef.doc(sessionId).update({
      'status': KeyExchangeStatus.completed.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Met à jour le conversationId de la session
  Future<void> setConversationId(String sessionId, String conversationId) async {
    debugPrint('[KeyExchangeSyncService] setConversationId: sessionId=$sessionId, conversationId=$conversationId');
    await _sessionsRef.doc(sessionId).update({
      'conversationId': conversationId,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Annule une session
  Future<void> cancelSession(String sessionId) async {
    await _sessionsRef.doc(sessionId).update({
      'status': KeyExchangeStatus.cancelled.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Supprime une session (nettoyage)
  Future<void> deleteSession(String sessionId) async {
    await _sessionsRef.doc(sessionId).delete();
  }

  /// Trouve les sessions actives pour un participant
  Stream<List<KeyExchangeSessionModel>> watchActiveSessionsForParticipant(
    String participantId,
  ) {
    return _sessionsRef
        .where('participants', arrayContains: participantId)
        .where('status', isEqualTo: KeyExchangeStatus.inProgress.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => KeyExchangeSessionModel.fromFirestore(doc.data()))
            .toList());
  }
}

