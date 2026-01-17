import 'package:onetime/convo/message_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// Service pour tracker les messages non lus par conversation
class UnreadMessageService {
  static const String _readMessagesPrefix = 'read_msg_ids_';
  final MessageStorageService _messageStorage = MessageStorageService();
  final _log = AppLogger();

  /// Marque un message comme lu
  Future<void> markMessageAsRead(String conversationId, String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_readMessagesPrefix$conversationId';
      
      final readIds = await _getReadMessageIds(conversationId);
      if (!readIds.contains(messageId)) {
        readIds.add(messageId);
        await prefs.setStringList(key, readIds);
        _log.i('UnreadMsg', 'Marked message $messageId as read');
      }
    } catch (e) {
      _log.e('UnreadMsg', 'Error marking message as read: $e');
    }
  }

  /// Récupère le nombre de messages non lus
  /// = nombre de messages décryptés localement - nombre de messages lus
  Future<int> getUnreadCount(String conversationId) async {
    try {
      // Get all local decrypted messages
      final allMessages = await _messageStorage.getConversationMessages(conversationId);
      
      // Get read message IDs
      final readIds = await _getReadMessageIds(conversationId);
      
      // Count unread = messages not in read set and not sent by me
      // We need userId but we don't have it here, so we'll count all non-read messages
      final unreadCount = allMessages.where((msg) => !readIds.contains(msg.id)).length;
      
      return unreadCount;
    } catch (e) {
      _log.e('UnreadMsg', 'Error getting unread count: $e');
      return 0;
    }
  }

  /// Récupère le nombre de messages non lus (excluant les messages de l'utilisateur)
  Future<int> getUnreadCountExcludingUser(String conversationId, String userId) async {
    try {
      // Get all local decrypted messages
      final allMessages = await _messageStorage.getConversationMessages(conversationId);
      
      // Get read message IDs
      final readIds = await _getReadMessageIds(conversationId);
      
      // Count unread = messages not in read set and not sent by me
      final unreadCount = allMessages.where((msg) => 
        !readIds.contains(msg.id) && msg.senderId != userId
      ).length;
      
      return unreadCount;
    } catch (e) {
      _log.e('UnreadMsg', 'Error getting unread count: $e');
      return 0;
    }
  }

  /// Marque tous les messages comme lus
  Future<void> markAllAsRead(String conversationId) async {
    try {
      // Get all local messages
      final allMessages = await _messageStorage.getConversationMessages(conversationId);
      
      // Mark all as read
      final prefs = await SharedPreferences.getInstance();
      final key = '$_readMessagesPrefix$conversationId';
      final allIds = allMessages.map((m) => m.id).toList();
      await prefs.setStringList(key, allIds);
      
      _log.i('UnreadMsg', 'Marked all ${allIds.length} messages as read for $conversationId');
    } catch (e) {
      _log.e('UnreadMsg', 'Error marking all as read: $e');
    }
  }

  /// Supprime les données de lecture pour une conversation
  Future<void> deleteUnreadCount(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_readMessagesPrefix$conversationId';
      await prefs.remove(key);
    } catch (e) {
      _log.e('UnreadMsg', 'Error deleting unread data: $e');
    }
  }

  /// Supprime tous les compteurs
  Future<void> deleteAllUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_readMessagesPrefix)) {
          await prefs.remove(key);
        }
      }
      
      _log.i('UnreadMsg', 'All unread data deleted');
    } catch (e) {
      _log.e('UnreadMsg', 'Error deleting all unread data: $e');
    }
  }

  /// Récupère les IDs de messages lus
  Future<List<String>> _getReadMessageIds(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_readMessagesPrefix$conversationId';
      return prefs.getStringList(key) ?? [];
    } catch (e) {
      _log.e('UnreadMsg', 'Error getting read message IDs: $e');
      return [];
    }
  }
}
