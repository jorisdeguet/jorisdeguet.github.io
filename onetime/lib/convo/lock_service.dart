import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onetime/convo/conversation_lock.dart';
import 'package:onetime/services/app_logger.dart';

/// Exception lancée quand un lock ne peut pas être acquis après plusieurs tentatives
class LockAcquisitionException implements Exception {
  final String message;
  LockAcquisitionException(this.message);

  @override
  String toString() => message;
}

/// Service pour gérer les locks sur les conversations dans Firestore
class LockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLogger _log = AppLogger();

  /// Durée maximale d'attente pour acquérir un lock (en millisecondes)
  static const List<int> _retryDelaysMs = [1000, 2000, 4000, 10000];

  /// Collection des locks pour une conversation
  CollectionReference<Map<String, dynamic>> _locksRef(String conversationId) =>
      _firestore.collection('conversations')
          .doc(conversationId)
          .collection('locks');

  /// Acquiert un lock sur le prochain index d'octet disponible
  ///
  /// Stratégie de retry avec délais exponentiels : 1s, 2s, 4s, 10s
  /// Lance une [LockAcquisitionException] si le lock ne peut pas être acquis
  Future<ConversationLock> acquireLock({
    required String conversationId,
    required int byteIndex,
    required String userId,
  }) async {
    _log.d('LockService', 'Attempting to acquire lock on byte $byteIndex for conversation $conversationId');

    for (int attempt = 0; attempt < _retryDelaysMs.length; attempt++) {
      try {
        final lock = await _tryAcquireLock(
          conversationId: conversationId,
          byteIndex: byteIndex,
          userId: userId,
        );

        if (lock != null) {
          _log.i('LockService', 'Lock acquired on byte $byteIndex (attempt ${attempt + 1})');
          return lock;
        }

        // Lock non acquis, attendre avant de réessayer
        if (attempt < _retryDelaysMs.length - 1) {
          final delay = _retryDelaysMs[attempt];
          _log.d('LockService', 'Lock busy, waiting ${delay}ms before retry...');
          await Future.delayed(Duration(milliseconds: delay));
        }
      } catch (e) {
        _log.e('LockService', 'Error during lock acquisition attempt ${attempt + 1}: $e');
        if (attempt == _retryDelaysMs.length - 1) {
          rethrow;
        }
      }
    }

    throw LockAcquisitionException(
      'Impossible d\'acquérir le lock après ${_retryDelaysMs.length} tentatives. '
      'Un autre participant est en cours d\'envoi, veuillez patienter.'
    );
  }

  /// Tente d'acquérir un lock (une seule tentative)
  /// Retourne le lock si acquis, null sinon
  Future<ConversationLock?> _tryAcquireLock({
    required String conversationId,
    required int byteIndex,
    required String userId,
  }) async {
    final lockDocId = byteIndex.toString();
    final lockDocRef = _locksRef(conversationId).doc(lockDocId);

    try {
      // Utiliser une transaction pour garantir l'atomicité
      return await _firestore.runTransaction<ConversationLock?>((transaction) async {
        final doc = await transaction.get(lockDocRef);

        if (doc.exists) {
          // Un lock existe déjà
          final existingLock = ConversationLock.fromFirestore(
            byteIndex,
            doc.data()!,
          );

          // Vérifier si le lock est expiré
          if (existingLock.isExpired()) {
            _log.w('LockService', 'Lock on byte $byteIndex expired, stealing it');
            // Le lock est expiré, on peut le prendre
            final newLock = ConversationLock(
              byteIndex: byteIndex,
              lockerId: userId,
            );
            transaction.set(lockDocRef, newLock.toFirestore());
            return newLock;
          } else {
            // Le lock est toujours valide
            _log.d('LockService', 'Lock on byte $byteIndex held by ${existingLock.lockerId}');
            return null;
          }
        } else {
          // Aucun lock n'existe, on peut le créer
          final newLock = ConversationLock(
            byteIndex: byteIndex,
            lockerId: userId,
          );
          transaction.set(lockDocRef, newLock.toFirestore());
          return newLock;
        }
      });
    } catch (e) {
      _log.e('LockService', 'Error in transaction: $e');
      rethrow;
    }
  }

  /// Libère un lock
  Future<void> releaseLock({
    required String conversationId,
    required int byteIndex,
    required String userId,
  }) async {
    _log.d('LockService', 'Releasing lock on byte $byteIndex for conversation $conversationId');

    final lockDocId = byteIndex.toString();
    final lockDocRef = _locksRef(conversationId).doc(lockDocId);

    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(lockDocRef);

        if (doc.exists) {
          final lock = ConversationLock.fromFirestore(byteIndex, doc.data()!);

          // Vérifier que c'est bien nous qui détenons le lock
          if (lock.lockerId == userId) {
            transaction.delete(lockDocRef);
            _log.i('LockService', 'Lock released on byte $byteIndex');
          } else {
            _log.w('LockService', 'Cannot release lock on byte $byteIndex: owned by ${lock.lockerId}, not $userId');
          }
        } else {
          _log.w('LockService', 'Lock on byte $byteIndex does not exist, nothing to release');
        }
      });
    } catch (e) {
      _log.e('LockService', 'Error releasing lock: $e');
      rethrow;
    }
  }

  /// Nettoie tous les locks expirés d'une conversation
  /// Utile pour le nettoyage périodique
  Future<void> cleanupExpiredLocks(String conversationId) async {
    _log.d('LockService', 'Cleaning up expired locks for conversation $conversationId');

    try {
      final snapshot = await _locksRef(conversationId).get();

      for (final doc in snapshot.docs) {
        final lock = ConversationLock.fromFirestore(
          int.parse(doc.id),
          doc.data(),
        );

        if (lock.isExpired()) {
          await doc.reference.delete();
          _log.d('LockService', 'Deleted expired lock on byte ${lock.byteIndex}');
        }
      }

      _log.i('LockService', 'Cleanup completed for conversation $conversationId');
    } catch (e) {
      _log.e('LockService', 'Error during cleanup: $e');
    }
  }
}
