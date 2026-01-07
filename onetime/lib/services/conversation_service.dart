import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
    required Map<String, String> peerNames,
    int totalKeyBits = 0,
    String? name,
    ConversationState state = ConversationState.joining,
  }) async {
    debugPrint('[ConversationService] createConversation: peerIds=$peerIds, state=$state');

    // S'assurer que l'utilisateur local est inclus
    final allPeers = {...peerIds, localUserId}.toList()..sort();
    
    final conversationId = _generateConversationId();
    
    final conversation = Conversation(
      id: conversationId,
      peerIds: allPeers,
      peerNames: peerNames,
      name: name,
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
        .orderBy('lastMessageAt', descending: true)
        .get();

    return query.docs
        .map((doc) => Conversation.fromFirestore(doc.data()))
        .toList();
  }

  /// Stream des conversations de l'utilisateur
  Stream<List<Conversation>> watchUserConversations() {
    return _conversationsRef
        .where('peerIds', arrayContains: localUserId)
        .orderBy('lastMessageAt', descending: true)
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
    required String messagePreview,
    required String senderId,
    required int bitsUsed,
  }) async {
    debugPrint('[ConversationService] updateConversationWithMessage: conversationId=$conversationId');
    try {
      await _conversationsRef.doc(conversationId).update({
        'lastMessageAt': DateTime.now().toIso8601String(),
        'lastMessagePreview': messagePreview,
        'lastMessageSenderId': senderId,
        'usedKeyBits': FieldValue.increment(bitsUsed),
        'messageCount': FieldValue.increment(1),
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
    await _conversationsRef.doc(conversationId).update({'name': newName});
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
  }) async {
    debugPrint('[ConversationService] sendMessage: conversationId=$conversationId');
    debugPrint('[ConversationService] sendMessage: messageId=${message.id}');
    debugPrint('[ConversationService] sendMessage: senderId=${message.senderId}');

    try {
      // Ajouter le message
      debugPrint('[ConversationService] Adding message to Firestore...');
      await _messagesRef(conversationId).doc(message.id).set(message.toJson());
      debugPrint('[ConversationService] Message added successfully');

      // Mettre à jour la conversation
      debugPrint('[ConversationService] Updating conversation...');
      await updateConversationWithMessage(
        conversationId: conversationId,
        messagePreview: messagePreview.length > 50
            ? '${messagePreview.substring(0, 47)}...'
            : messagePreview,
        senderId: message.senderId,
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

  /// Marque un message comme lu
  Future<void> markMessageAsRead(String conversationId, String messageId) async {
    await _messagesRef(conversationId).doc(messageId).update({'isRead': true});
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
