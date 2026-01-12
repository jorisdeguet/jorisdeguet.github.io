import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/encrypted_message.dart';
import '../models/conversation.dart';
import 'conversation_service.dart';
import 'message_storage_service.dart';
import 'key_storage_service.dart';
import 'crypto_service.dart';
import 'compression_service.dart';
import 'auth_service.dart';
import 'unread_message_service.dart';

/// Service qui synchronise automatiquement les messages en arrière-plan
/// Décrypte et stocke les nouveaux messages comme non lus
class BackgroundMessageSyncService {
  final AuthService _authService = AuthService();
  final MessageStorageService _messageStorage = MessageStorageService();
  final KeyStorageService _keyStorage = KeyStorageService();
  final CompressionService _compressionService = CompressionService();
  final UnreadMessageService _unreadService = UnreadMessageService();
  
  final Map<String, StreamSubscription<List<Conversation>>> _conversationSubscriptions = {};
  final Map<String, StreamSubscription<List<EncryptedMessage>>> _messageSubscriptions = {};
  final Set<String> _processedMessageIds = {};

  String get _currentUserId => _authService.currentUserId ?? '';

  /// Démarre la synchronisation en arrière-plan pour toutes les conversations
  Future<void> startSync() async {
    if (_currentUserId.isEmpty) {
      debugPrint('[BgSync] No user ID, cannot start sync');
      return;
    }

    debugPrint('[BgSync] Starting background message sync for user $_currentUserId');

    final conversationService = ConversationService(localUserId: _currentUserId);
    
    // Écouter les conversations de l'utilisateur
    _conversationSubscriptions['main'] = conversationService
        .watchUserConversations()
        .listen(_onConversationsChanged);
  }

  /// Arrête toutes les synchronisations
  Future<void> stopSync() async {
    debugPrint('[BgSync] Stopping background sync');
    
    // Cancel all subscriptions
    for (final sub in _conversationSubscriptions.values) {
      await sub.cancel();
    }
    _conversationSubscriptions.clear();
    
    for (final sub in _messageSubscriptions.values) {
      await sub.cancel();
    }
    _messageSubscriptions.clear();
    
    _processedMessageIds.clear();
  }

  /// Callback quand les conversations changent
  void _onConversationsChanged(List<Conversation> conversations) {
    debugPrint('[BgSync] Conversations updated: ${conversations.length} total');

    // Pour chaque conversation, écouter les nouveaux messages
    for (final conversation in conversations) {
      _listenToConversationMessages(conversation);
    }

    // Nettoyer les abonnements pour les conversations supprimées
    final currentConvIds = conversations.map((c) => c.id).toSet();
    final obsoleteKeys = _messageSubscriptions.keys
        .where((key) => !currentConvIds.contains(key))
        .toList();
    
    for (final key in obsoleteKeys) {
      debugPrint('[BgSync] Removing subscription for deleted conversation $key');
      _messageSubscriptions[key]?.cancel();
      _messageSubscriptions.remove(key);
    }
  }

  /// Écoute les messages d'une conversation
  void _listenToConversationMessages(Conversation conversation) {
    // Si on écoute déjà cette conversation, skip
    if (_messageSubscriptions.containsKey(conversation.id)) {
      return;
    }

    debugPrint('[BgSync] Starting to listen for messages in ${conversation.id}');

    final conversationService = ConversationService(localUserId: _currentUserId);
    
    _messageSubscriptions[conversation.id] = conversationService
        .watchMessages(conversation.id)
        .listen((messages) => _onMessagesChanged(conversation.id, messages));
  }

  /// Callback quand de nouveaux messages arrivent
  Future<void> _onMessagesChanged(String conversationId, List<EncryptedMessage> messages) async {
    if (messages.isEmpty) return;

    debugPrint('[BgSync] Messages updated for $conversationId: ${messages.length} total');

    // Filtrer les nouveaux messages (pas encore traités)
    final newMessages = messages
        .where((msg) => !_processedMessageIds.contains(msg.id))
        .where((msg) => msg.senderId != _currentUserId) // Ignorer mes propres messages
        .toList();

    if (newMessages.isEmpty) {
      return;
    }

    debugPrint('[BgSync] Processing ${newMessages.length} new messages');

    for (final message in newMessages) {
      await _processNewMessage(conversationId, message);
    }
  }

  /// Traite un nouveau message: décrypte, stocke, marque comme transféré
  Future<void> _processNewMessage(String conversationId, EncryptedMessage message) async {
    try {
      debugPrint('[BgSync] Processing message ${message.id} from ${message.senderId}');

      // Marquer comme traité immédiatement pour éviter les doublons
      _processedMessageIds.add(message.id);

      // Vérifier si déjà stocké localement
      final existing = await _messageStorage.getDecryptedMessage(
        conversationId: conversationId,
        messageId: message.id,
      );

      if (existing != null) {
        debugPrint('[BgSync] Message ${message.id} already stored locally, skipping');
        return;
      }

      // Charger la clé partagée
      final sharedKey = await _keyStorage.getKey(conversationId);
      if (sharedKey == null) {
        debugPrint('[BgSync] No shared key for conversation $conversationId, skipping message');
        return;
      }

      // Décrypter le message
      final cryptoService = CryptoService(localPeerId: _currentUserId);
      final decrypted = cryptoService.decryptBinary(
        encryptedMessage: message,
        sharedKey: sharedKey,
        markAsUsed: true,
      );

      // Décompresser si nécessaire
      Uint8List plaintext;
      if (message.isCompressed) {
        plaintext = _compressionService.decompress(decrypted);
      } else {
        plaintext = decrypted;
      }

      // Déterminer le type de contenu et stocker
      DecryptedMessageData messageData;

      if (message.contentType == MessageContentType.text) {
        // Message texte
        final text = String.fromCharCodes(plaintext);
        messageData = DecryptedMessageData(
          id: message.id,
          senderId: message.senderId,
          createdAt: message.createdAt,
          contentType: MessageContentType.text,
          textContent: text,
          isCompressed: message.isCompressed,
          deleteAfterRead: message.deleteAfterRead,
        );
      } else {
        // Message binaire (image ou fichier)
        messageData = DecryptedMessageData(
          id: message.id,
          senderId: message.senderId,
          createdAt: message.createdAt,
          contentType: message.contentType,
          binaryContent: plaintext,
          fileName: message.fileName,
          mimeType: message.mimeType,
          isCompressed: message.isCompressed,
          deleteAfterRead: message.deleteAfterRead,
        );
      }

      // Sauvegarder localement
      await _messageStorage.saveDecryptedMessage(
        conversationId: conversationId,
        message: messageData,
      );

      debugPrint('[BgSync] Message ${message.id} decrypted and stored locally');

      // Marquer les bits de clé comme utilisés
      await _keyStorage.updateUsedBits(
        conversationId,
        message.keySegments.first.startBit,
        message.keySegments.last.endBit,
      );

      debugPrint('[BgSync] Key bits marked as used');

      // Marquer comme transféré sur Firestore (mais PAS comme lu)
      final conversationService = ConversationService(localUserId: _currentUserId);
      final conversation = await conversationService.getConversation(conversationId);
      
      if (conversation != null) {
        await conversationService.markMessageAsTransferred(
          conversationId: conversationId,
          messageId: message.id,
          allParticipants: conversation.peerIds,
        );
        
        debugPrint('[BgSync] Message ${message.id} marked as transferred (NOT read yet)');
      }

      // Le message est maintenant stocké localement comme NON LU
      // Il sera marqué comme lu seulement quand l'utilisateur ouvrira la conversation

    } catch (e, stackTrace) {
      debugPrint('[BgSync] Error processing message ${message.id}: $e');
      debugPrint('[BgSync] Stack trace: $stackTrace');
      // Retirer des messages traités pour réessayer plus tard
      _processedMessageIds.remove(message.id);
    }
  }

  /// Récupère le nombre total de messages non lus pour toutes les conversations
  Future<int> getTotalUnreadCount() async {
    if (_currentUserId.isEmpty) return 0;

    try {
      final conversationService = ConversationService(localUserId: _currentUserId);
      final conversations = await conversationService.getUserConversations();
      
      int total = 0;
      for (final conv in conversations) {
        final count = await _unreadService.getUnreadCountExcludingUser(
          conv.id,
          _currentUserId,
        );
        total += count;
      }
      
      return total;
    } catch (e) {
      debugPrint('[BgSync] Error getting total unread count: $e');
      return 0;
    }
  }

  /// Récupère le nombre de messages non lus par conversation
  Future<Map<String, int>> getUnreadCountsByConversation() async {
    if (_currentUserId.isEmpty) return {};

    try {
      final conversationService = ConversationService(localUserId: _currentUserId);
      final conversations = await conversationService.getUserConversations();
      
      final counts = <String, int>{};
      for (final conv in conversations) {
        final count = await _unreadService.getUnreadCountExcludingUser(
          conv.id,
          _currentUserId,
        );
        counts[conv.id] = count;
      }
      
      return counts;
    } catch (e) {
      debugPrint('[BgSync] Error getting unread counts: $e');
      return {};
    }
  }
}
