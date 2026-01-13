import 'dart:async';

import '../models/encrypted_message.dart';
import '../models/key_segment.dart';
import '../models/shared_key.dart';
import 'crypto_service.dart';

/// Service de messagerie via Firebase pour One-Time Pad.
/// 
/// Gère:
/// - L'envoi de messages chiffrés
/// - La réception et synchronisation des messages
/// - Les locks transactionnels sur les segments de clé
/// - La suppression sécurisée (mode ultra-secure)
/// - La confirmation des indices de clé lus (sans les bits)
abstract class FirebaseMessageService {
  /// ID du peer local
  final String localPeerId;
  
  /// Service de crypto local
  final CryptoService cryptoService;

  FirebaseMessageService({
    required this.localPeerId,
    required this.cryptoService,
  });

  // ==================== LOCKS TRANSACTIONNELS ====================

  /// Acquiert un lock sur un segment de clé avant envoi.
  /// 
  /// Le lock empêche les autres peers d'utiliser le même segment.
  /// Expire automatiquement après [timeout].
  Future<KeySegmentLock?> acquireLock({
    required String keyId,
    required int startBit,
    required int endBit,
    Duration timeout = const Duration(seconds: 30),
  });

  /// Libère un lock précédemment acquis.
  Future<void> releaseLock(KeySegmentLock lock);

  /// Vérifie si un segment est actuellement locké.
  Future<bool> isSegmentLocked({
    required String keyId,
    required int startBit,
    required int endBit,
  });

  /// Écoute les changements de locks pour une clé.
  Stream<List<KeySegmentLock>> watchLocks(String keyId);

  // ==================== MESSAGES ====================

  /// Envoie un message chiffré.
  /// 
  /// [message] - Le message déjà chiffré
  /// [conversationId] - ID de la conversation (= keyId généralement)
  Future<void> sendMessage({
    required EncryptedMessage message,
    required String conversationId,
  });

  /// Récupère les messages d'une conversation.
  Future<List<EncryptedMessage>> getMessages({
    required String conversationId,
    int? limit,
    DateTime? since,
  });

  /// Écoute les nouveaux messages en temps réel.
  Stream<EncryptedMessage> watchNewMessages(String conversationId);

  /// Marque un message comme lu.
  Future<void> markAsRead(String messageId, String conversationId);

  /// Supprime un message (mode ultra-secure).
  Future<void> deleteMessage(String messageId, String conversationId);

  // ==================== SEGMENTS UTILISÉS ====================

  /// Enregistre qu'un segment a été utilisé.
  /// 
  /// Permet aux autres peers de savoir quels segments sont consommés.
  Future<void> recordUsedSegment(KeySegment segment);

  /// Récupère tous les segments utilisés pour une clé.
  Future<List<KeySegment>> getUsedSegments(String keyId);

  /// Écoute les nouveaux segments utilisés.
  Stream<KeySegment> watchUsedSegments(String keyId);

  // ==================== CONFIRMATION D'ÉCHANGE DE CLÉ ====================

  /// Confirme qu'un segment de clé a été lu (échange initial).
  /// 
  /// IMPORTANT: N'envoie que l'INDEX, jamais les bits de clé.
  Future<void> confirmKeySegmentRead({
    required String sessionId,
    required int segmentIndex,
  });

  /// Écoute les confirmations de lecture de segments.
  Stream<({String peerId, int segmentIndex})> watchKeySegmentConfirmations(
    String sessionId,
  );

  // ==================== SYNCHRONISATION DE CLÉ ====================

  /// Synchronise le bitmap d'utilisation de la clé.
  /// 
  /// Permet de réindexer la clé localement pour enlever les segments utilisés.
  Future<void> syncKeyUsage({
    required String keyId,
    required List<KeySegment> usedSegments,
  });

  /// Récupère l'état d'utilisation actuel d'une clé.
  Future<KeyUsageState> getKeyUsageState(String keyId);
}

/// État d'utilisation d'une clé partagée
class KeyUsageState {
  final String keyId;
  final List<KeySegment> usedSegments;
  final DateTime lastUpdated;

  KeyUsageState({
    required this.keyId,
    required this.usedSegments,
    required this.lastUpdated,
  });

  /// Calcule le nombre total de bits utilisés
  int get totalBitsUsed {
    int total = 0;
    for (final seg in usedSegments) {
      total += seg.lengthInBits;
    }
    return total;
  }
}

/// Service de messagerie avec workflow complet
class SecureMessageService {
  final FirebaseMessageService firebaseService;
  final CryptoService cryptoService;
  final String localPeerId;

  SecureMessageService({
    required this.firebaseService,
    required this.cryptoService,
    required this.localPeerId,
  });

  /// Envoie un message de manière sécurisée avec lock transactionnel.
  Future<EncryptedMessage> sendSecureMessage({
    required String plaintext,
    required SharedKey sharedKey,
    bool ultraSecure = false,
  }) async {
    final bitsNeeded = cryptoService.calculateBitsNeeded(plaintext);
    
    // Trouver un segment disponible
    final segment = sharedKey.findAvailableSegment(localPeerId, bitsNeeded);
    if (segment == null) {
      throw InsufficientKeyException('No available key segment');
    }
    
    // Acquérir un lock
    final lock = await firebaseService.acquireLock(
      keyId: sharedKey.id,
      startBit: segment.startBit,
      endBit: segment.endBit,
    );
    
    if (lock == null) {
      throw Exception('Could not acquire lock on key segment');
    }
    
    try {
      // Chiffrer et envoyer
      final result = cryptoService.encrypt(
        plaintext: plaintext,
        sharedKey: sharedKey,
        deleteAfterRead: ultraSecure,
      );
      
      await firebaseService.sendMessage(
        message: result.message,
        conversationId: sharedKey.id,
      );
      
      // Enregistrer le segment utilisé
      await firebaseService.recordUsedSegment(result.usedSegment);
      
      return result.message;
    } finally {
      // Toujours libérer le lock
      await firebaseService.releaseLock(lock);
    }
  }

  /// Reçoit et déchiffre un message.
  Future<String> receiveAndDecrypt({
    required EncryptedMessage message,
    required SharedKey sharedKey,
  }) async {
    final plaintext = cryptoService.decrypt(
      encryptedMessage: message,
      sharedKey: sharedKey,
    );
    await firebaseService.markAsRead(message.id, sharedKey.id);
    return plaintext;
  }
}
