import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/kex_session.dart';

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
      _firestore.collection('kex');

  /// Crée une nouvelle session d'échange de clé dans Firestore
  Future<KexSessionModel> createSession({
    required String sourceId,
    required List<String> participants,
    required int totalKeyBits,
    required int totalSegments,
    String? conversationId,
  }) async {
    final sessionId = 'kex_${DateTime.now().millisecondsSinceEpoch}_$sourceId';

    // S'assurer que la source est dans les participants
    final allParticipants = {...participants, sourceId}.toList()..sort();

    final session = KexSessionModel.createInitial(
      id: sessionId,
      conversationId: conversationId,
      sourceId: sourceId,
      participants: allParticipants,
      totalSegments: totalSegments,
    );

    await _sessionsRef.doc(sessionId).set(session.toFirestore());

    return session;
  }

  /// Récupère une session par ID
  Future<KexSessionModel?> getSession(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return KexSessionModel.fromFirestore(doc.data()!);
  }

  /// Écoute les changements d'une session en temps réel
  Stream<KexSessionModel?> watchSession(String sessionId) {
    return _sessionsRef.doc(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return KexSessionModel.fromFirestore(snapshot.data()!);
    });
  }

  /// Notifie que le participant courant a scanné un segment
  Future<void> markSegmentScanned({
    required String sessionId,
    required String participantId,
    required int segmentIndex,
  }) async {
    debugPrint('[KeyExchangeSyncService] ══════════════════════════════════');
    debugPrint('[KeyExchangeSyncService] markSegmentScanned called:');
    debugPrint('[KeyExchangeSyncService]   sessionId: $sessionId');
    debugPrint('[KeyExchangeSyncService]   participantId: ${participantId.substring(0, 8)}...');
    debugPrint('[KeyExchangeSyncService]   segmentIndex: $segmentIndex');
    
    final docRef = _sessionsRef.doc(sessionId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        debugPrint('[KeyExchangeSyncService] ❌ ERROR: Session not found');
        throw Exception('Session not found');
      }

      final session = KexSessionModel.fromFirestore(snapshot.data()!);
      if (!session.hasScanned(participantId, segmentIndex)) {
        session.addScannedSegment(
          participantId: participantId,
          segmentIndex: segmentIndex,
        );
        var updates = session.computeFirestoreUpdatesForSegments();
        transaction.update(docRef, updates);
        debugPrint('[KeyExchangeSyncService] ✅ Transaction update queued');
      } else {
        debugPrint('[KeyExchangeSyncService] ℹ️  Participant already scanned this segment - no update needed');
      }
    });
    
    debugPrint('[KeyExchangeSyncService] ══════════════════════════════════');
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

  /// Met à jour le nombre total de segments (utilisé lors d'une terminaison anticipée)
  Future<void> updateTotalSegments(String sessionId, int totalSegments, int totalKeyBits) async {
    debugPrint('[KeyExchangeSyncService] updateTotalSegments: sessionId=$sessionId, totalSegments=$totalSegments, totalKeyBits=$totalKeyBits');
    await _sessionsRef.doc(sessionId).update({
      'totalSegments': totalSegments,
      'totalKeyBits': totalKeyBits,
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

  /// Nettoie les sessions expirées (plus d'une heure) pour un utilisateur donné
  Future<void> cleanupOldSessions(String userId) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      
      // Trouver les sessions créées ou mises à jour il y a plus d'une heure
      // On filtre aussi par participant car les règles de sécurité ne permettent
      // de lire/supprimer que ses propres sessions.
      final snapshot = await _sessionsRef
          .where('participants', arrayContains: userId)
          .where('createdAt', isLessThan: oneHourAgo.toIso8601String())
          .get();
      
      final batch = _firestore.batch();
      int count = 0;
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;
        // Firestore batch limit is 500
        if (count >= 400) {
          await batch.commit();
          count = 0;
        }
      }
      
      if (count > 0) {
        await batch.commit();
      }
      
      debugPrint('[KeyExchangeSyncService] Cleaned up $count old sessions');
    } catch (e) {
      debugPrint('[KeyExchangeSyncService] Error cleaning up sessions: $e');
    }
  }

  /// Trouve les sessions actives pour un participant
  Stream<List<KexSessionModel>> watchActiveSessionsForParticipant(
    String participantId,
  ) {
    return _sessionsRef
        .where('participants', arrayContains: participantId)
        .where('status', isEqualTo: KeyExchangeStatus.inProgress.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => KexSessionModel.fromFirestore(doc.data()))
            .toList());
  }
}

