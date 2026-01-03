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

/// Implémentation mock pour les tests et le développement
class MockFirebaseMessageService extends FirebaseMessageService {
  final Map<String, List<EncryptedMessage>> _messages = {};
  final Map<String, List<KeySegment>> _usedSegments = {};
  final Map<String, List<KeySegmentLock>> _locks = {};
  final Map<String, Set<int>> _confirmedSegments = {};
  
  final _messageController = StreamController<EncryptedMessage>.broadcast();
  final _segmentController = StreamController<KeySegment>.broadcast();
  final _lockController = StreamController<List<KeySegmentLock>>.broadcast();
  final _confirmController = StreamController<({String peerId, int segmentIndex})>.broadcast();

  MockFirebaseMessageService({
    required super.localPeerId,
    required super.cryptoService,
  });

  @override
  Future<KeySegmentLock?> acquireLock({
    required String keyId,
    required int startBit,
    required int endBit,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Vérifier si déjà locké
    final existingLocks = _locks[keyId] ?? [];
    for (final lock in existingLocks) {
      if (!lock.isExpired &&
          lock.segment.startBit < endBit &&
          lock.segment.endBit > startBit) {
        return null; // Conflit
      }
    }
    
    final lock = KeySegmentLock(
      lockId: 'lock_${DateTime.now().millisecondsSinceEpoch}',
      segment: KeySegment(
        keyId: keyId,
        startBit: startBit,
        endBit: endBit,
        usedByPeerId: localPeerId,
      ),
      expiresAt: DateTime.now().add(timeout),
      status: KeySegmentLockStatus.acquired,
    );
    
    _locks.putIfAbsent(keyId, () => []).add(lock);
    _lockController.add(_locks[keyId]!);
    
    return lock;
  }

  @override
  Future<void> releaseLock(KeySegmentLock lock) async {
    _locks[lock.segment.keyId]?.removeWhere((l) => l.lockId == lock.lockId);
    _lockController.add(_locks[lock.segment.keyId] ?? []);
  }

  @override
  Future<bool> isSegmentLocked({
    required String keyId,
    required int startBit,
    required int endBit,
  }) async {
    final locks = _locks[keyId] ?? [];
    for (final lock in locks) {
      if (!lock.isExpired &&
          lock.segment.startBit < endBit &&
          lock.segment.endBit > startBit) {
        return true;
      }
    }
    return false;
  }

  @override
  Stream<List<KeySegmentLock>> watchLocks(String keyId) {
    return _lockController.stream.where((_) => true);
  }

  @override
  Future<void> sendMessage({
    required EncryptedMessage message,
    required String conversationId,
  }) async {
    _messages.putIfAbsent(conversationId, () => []).add(message);
    _messageController.add(message);
  }

  @override
  Future<List<EncryptedMessage>> getMessages({
    required String conversationId,
    int? limit,
    DateTime? since,
  }) async {
    var messages = _messages[conversationId] ?? [];
    
    if (since != null) {
      messages = messages.where((m) => m.createdAt.isAfter(since)).toList();
    }
    
    if (limit != null && messages.length > limit) {
      messages = messages.sublist(messages.length - limit);
    }
    
    return messages;
  }

  @override
  Stream<EncryptedMessage> watchNewMessages(String conversationId) {
    return _messageController.stream.where((m) => m.keyId == conversationId);
  }

  @override
  Future<void> markAsRead(String messageId, String conversationId) async {
    final messages = _messages[conversationId] ?? [];
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index].isRead = true;
    }
  }

  @override
  Future<void> deleteMessage(String messageId, String conversationId) async {
    _messages[conversationId]?.removeWhere((m) => m.id == messageId);
  }

  @override
  Future<void> recordUsedSegment(KeySegment segment) async {
    _usedSegments.putIfAbsent(segment.keyId, () => []).add(segment);
    _segmentController.add(segment);
  }

  @override
  Future<List<KeySegment>> getUsedSegments(String keyId) async {
    return _usedSegments[keyId] ?? [];
  }

  @override
  Stream<KeySegment> watchUsedSegments(String keyId) {
    return _segmentController.stream.where((s) => s.keyId == keyId);
  }

  @override
  Future<void> confirmKeySegmentRead({
    required String sessionId,
    required int segmentIndex,
  }) async {
    _confirmedSegments.putIfAbsent(sessionId, () => {}).add(segmentIndex);
    _confirmController.add((peerId: localPeerId, segmentIndex: segmentIndex));
  }

  @override
  Stream<({String peerId, int segmentIndex})> watchKeySegmentConfirmations(
    String sessionId,
  ) {
    return _confirmController.stream;
  }

  @override
  Future<void> syncKeyUsage({
    required String keyId,
    required List<KeySegment> usedSegments,
  }) async {
    _usedSegments[keyId] = usedSegments;
  }

  @override
  Future<KeyUsageState> getKeyUsageState(String keyId) async {
    return KeyUsageState(
      keyId: keyId,
      usedSegments: _usedSegments[keyId] ?? [],
      lastUpdated: DateTime.now(),
    );
  }

  void dispose() {
    _messageController.close();
    _segmentController.close();
    _lockController.close();
    _confirmController.close();
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
    
    // Marquer comme lu
    await firebaseService.markAsRead(message.id, sharedKey.id);
    
    // Mode ultra-secure: supprimer après lecture
    if (message.deleteAfterRead) {
      cryptoService.secureDelete(message, sharedKey);
      await firebaseService.deleteMessage(message.id, sharedKey.id);
    }
    
    return plaintext;
  }
}
