import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/encrypted_message.dart';

/// Service de gestion des conversations sur Firebase.
class ConversationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String localUserId;

  ConversationService({required this.localUserId});

  /// Collection des conversations
  CollectionReference<Map<String, dynamic>> get _conversationsRef =>
      _firestore.collection('conversations');

  /// Collection des messages d'une conversation
  CollectionReference<Map<String, dynamic>> _messagesRef(String conversationId) =>
      _conversationsRef.doc(conversationId).collection('messages');

  // ==================== CONVERSATIONS ====================

  /// Crée une nouvelle conversation (en état "joining")
  Future<Conversation> createConversation({
    required List<String> peerIds,
    int totalKeyBits = 0,
    ConversationState state = ConversationState.joining,
  }) async {
    debugPrint('[ConversationService] createConversation: peerIds=$peerIds, state=$state');

    // S'assurer que l'utilisateur local est inclus
    final allPeers = {...peerIds, localUserId}.toList()..sort();
    
    final conversationId = _generateConversationId();
    
    final conversation = Conversation(
      id: conversationId,
      peerIds: allPeers,
      state: state,
      totalKeyBits: totalKeyBits,
    );

    await _conversationsRef.doc(conversationId).set(conversation.toFirestore());
    debugPrint('[ConversationService] Conversation created: $conversationId');

    return conversation;
  }

  /// Change l'état d'une conversation
  Future<void> setConversationState(String conversationId, ConversationState state) async {
    debugPrint('[ConversationService] setConversationState: $conversationId -> $state');
    await _conversationsRef.doc(conversationId).update({
      'state': state.name,
    });
  }

  /// Passe la conversation en mode "exchanging" (échange de clé en cours)
  Future<void> startKeyExchange(String conversationId) async {
    await setConversationState(conversationId, ConversationState.exchanging);
  }

  /// Passe la conversation en mode "ready" (prête à utiliser)
  Future<void> markConversationReady(String conversationId, int totalKeyBits) async {
    debugPrint('[ConversationService] markConversationReady: $conversationId, totalKeyBits=$totalKeyBits');
    await _conversationsRef.doc(conversationId).update({
      'state': ConversationState.ready.name,
      'totalKeyBits': totalKeyBits,
    });
  }

  /// Récupère une conversation par ID
  Future<Conversation?> getConversation(String id) async {
    final doc = await _conversationsRef.doc(id).get();
    if (!doc.exists) return null;
    return Conversation.fromFirestore(doc.data()!);
  }

  /// Récupère toutes les conversations de l'utilisateur
  Future<List<Conversation>> getUserConversations() async {
    final query = await _conversationsRef
        .where('peerIds', arrayContains: localUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs
        .map((doc) => Conversation.fromFirestore(doc.data()))
        .toList();
  }

  /// Stream des conversations de l'utilisateur
  Stream<List<Conversation>> watchUserConversations() {
    return _conversationsRef
        .where('peerIds', arrayContains: localUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conversation.fromFirestore(doc.data()))
            .toList());
  }

  /// Stream d'une conversation spécifique
  Stream<Conversation?> watchConversation(String conversationId) {
    return _conversationsRef.doc(conversationId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Conversation.fromFirestore(doc.data()!);
    });
  }

  /// Met à jour une conversation après envoi de message
  Future<void> updateConversationWithMessage({
    required String conversationId,
    required int bitsUsed,
  }) async {
    debugPrint('[ConversationService] updateConversationWithMessage: conversationId=$conversationId');
    try {
      await _conversationsRef.doc(conversationId).update({
        'usedKeyBits': FieldValue.increment(bitsUsed),
      });
      debugPrint('[ConversationService] updateConversationWithMessage: SUCCESS');
    } catch (e, stackTrace) {
      debugPrint('[ConversationService] updateConversationWithMessage ERROR: $e');
      debugPrint('[ConversationService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Renomme une conversation
  Future<void> renameConversation(String conversationId, String newName) async {
    // Cette fonctionnalité n'est plus supportée dans le modèle
    // await _conversationsRef.doc(conversationId).update({'name': newName});
  }

  /// Met à jour les bits de clé d'une conversation existante
  /// Met à jour les bits de clé d'une conversation existante et la marque comme prête
  Future<void> updateConversationKey({
    required String conversationId,
    required int totalKeyBits,
    bool addToExisting = false,
  }) async {
    debugPrint('[ConversationService] updateConversationKey: $conversationId, $totalKeyBits bits, addToExisting=$addToExisting');

    if (addToExisting) {
      // Ajouter aux bits existants (extension de clé)
      await _conversationsRef.doc(conversationId).update({
        'totalKeyBits': FieldValue.increment(totalKeyBits),
        'state': ConversationState.ready.name,
      });
    } else {
      // Remplacer les bits (premier échange)
      await _conversationsRef.doc(conversationId).update({
        'totalKeyBits': totalKeyBits,
        'usedKeyBits': 0,
        'state': ConversationState.ready.name,
      });
    }
  }

  /// Met à jour les infos de debug de la clé pour un utilisateur
  Future<void> updateKeyDebugInfo({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> info,
  }) async {
    debugPrint('[ConversationService] updateKeyDebugInfo: $conversationId, user=$userId');
    // Utiliser dot notation pour mettre à jour un champ spécifique de la map
    await _conversationsRef.doc(conversationId).update({
      'keyDebugInfo.$userId': info,
    });
  }

  /// Supprime une conversation (et tous ses messages)
  Future<void> deleteConversation(String conversationId) async {
    debugPrint('[ConversationService] deleteConversation: $conversationId');

    // Supprimer tous les messages d'abord
    final messages = await _messagesRef(conversationId).get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    // Supprimer les sessions d'échange de clé associées
    final sessions = await _firestore
        .collection('key_exchange_sessions')
        .where('conversationId', isEqualTo: conversationId)
        .get();
    for (final doc in sessions.docs) {
      await doc.reference.delete();
    }

    // Supprimer la conversation
    await _conversationsRef.doc(conversationId).delete();

    debugPrint('[ConversationService] Conversation deleted: $conversationId');
  }

  // ==================== MESSAGES ====================

  /// Envoie un message chiffré
  Future<void> sendMessage({
    required String conversationId,
    required EncryptedMessage message,
    required String messagePreview,
    String? plaintextDebug,
  }) async {
    debugPrint('[ConversationService] sendMessage: conversationId=$conversationId');
    debugPrint('[ConversationService] sendMessage: messageId=${message.id}');
    debugPrint('[ConversationService] sendMessage: senderId=${message.senderId}');

    try {
      // Ajouter le message
      debugPrint('[ConversationService] Adding message to Firestore...');
      final messageData = message.toJson();
      
      // Ajouter le plaintext si le debug est activé
      if (AppConfig.plaintextMessageFirestore && plaintextDebug != null) {
        messageData['plaintextDebug'] = plaintextDebug;
        debugPrint('[ConversationService] DEBUG: Plaintext added to Firestore');
      }
      
      await _messagesRef(conversationId).doc(message.id).set(messageData);
      debugPrint('[ConversationService] Message added successfully');

      // Mettre à jour la conversation
      debugPrint('[ConversationService] Updating conversation...');
      await updateConversationWithMessage(
        conversationId: conversationId,
        bitsUsed: message.totalBitsUsed,
      );
      debugPrint('[ConversationService] Conversation updated successfully');
    } catch (e, stackTrace) {
      debugPrint('[ConversationService] ERROR in sendMessage: $e');
      debugPrint('[ConversationService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Récupère les messages d'une conversation
  Future<List<EncryptedMessage>> getMessages({
    required String conversationId,
    int? limit,
    DateTime? before,
  }) async {
    Query<Map<String, dynamic>> query = _messagesRef(conversationId)
        .orderBy('createdAt', descending: true);

    if (before != null) {
      query = query.where('createdAt', isLessThan: before.toIso8601String());
    }
    
    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => EncryptedMessage.fromJson(doc.data()))
        .toList();
  }

  /// Stream des messages d'une conversation
  Stream<List<EncryptedMessage>> watchMessages(String conversationId) {
    return _messagesRef(conversationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EncryptedMessage.fromJson(doc.data()))
            .toList());
  }

  /// Marque un message comme lu par l'utilisateur local
  Future<void> markMessageAsRead(String conversationId, String messageId) async {
    await _messagesRef(conversationId).doc(messageId).update({
      'readBy': FieldValue.arrayUnion([localUserId]),
    });
  }

  /// Marque un message comme transféré par l'utilisateur local
  /// Supprime le contenu (ciphertext) si tous les participants l'ont transféré
  /// IMPORTANT: N'appelez cette méthode qu'APRÈS avoir sauvegardé le message localement
  Future<void> markMessageAsTransferred({
    required String conversationId,
    required String messageId,
    required List<String> allParticipants,
  }) async {
    final docRef = _messagesRef(conversationId).doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;

      final data = doc.data()!;
      final transferredBy = List<String>.from(data['transferredBy'] as List? ?? []);

      if (!transferredBy.contains(localUserId)) {
        transferredBy.add(localUserId);
      }

      // Vérifier si tous les participants ont transféré
      final allTransferred = allParticipants.every((p) => transferredBy.contains(p));

      if (allTransferred) {
        // Supprimer le contenu chiffré (garder les métadonnées pour le statut de lecture)
        // SÉCURITÉ: Le ciphertext n'est supprimé que si TOUS les participants l'ont téléchargé
        transaction.update(docRef, {
          'transferredBy': transferredBy,
          'ciphertext': '', // Vider le ciphertext
        });
        debugPrint('[ConversationService] Message $messageId ciphertext deleted (all transferred)');
      } else {
        transaction.update(docRef, {
          'transferredBy': transferredBy,
        });
      }
    });
  }

  /// Marque un message comme lu et vérifie si on peut le supprimer complètement
  Future<void> markMessageAsReadAndCleanup({
    required String conversationId,
    required String messageId,
    required List<String> allParticipants,
  }) async {
    final docRef = _messagesRef(conversationId).doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;

      final data = doc.data()!;
      final readBy = List<String>.from(data['readBy'] as List? ?? []);

      if (!readBy.contains(localUserId)) {
        readBy.add(localUserId);
      }

      // Vérifier si tous les participants ont lu
      final allRead = allParticipants.every((p) => readBy.contains(p));

      if (allRead) {
        // Supprimer complètement le message
        transaction.delete(docRef);
        debugPrint('[ConversationService] Message $messageId deleted (all read)');
      } else {
        transaction.update(docRef, {
          'readBy': readBy,
        });
      }
    });
  }

  /// Supprime un message (mode ultra-secure)
  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _messagesRef(conversationId).doc(messageId).delete();
  }

  // ==================== UTILITAIRES ====================

  String _generateConversationId() {
    return 'conv_${DateTime.now().millisecondsSinceEpoch}_$localUserId';
  }
}
