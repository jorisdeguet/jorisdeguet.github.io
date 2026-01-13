import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/encrypted_message.dart';
import 'app_logger.dart';

/// Représente un message déchiffré stocké localement
class DecryptedMessageData {
  final String id;
  final String senderId;
  final DateTime createdAt;
  final MessageContentType contentType;
  
  // Pour les messages texte
  final String? textContent;
  
  // Pour les messages binaires (image/fichier)
  final Uint8List? binaryContent;
  final String? fileName;
  final String? mimeType;
  
  final bool isCompressed;
  final bool deleteAfterRead;

  DecryptedMessageData({
    required this.id,
    required this.senderId,
    required this.createdAt,
    required this.contentType,
    this.textContent,
    this.binaryContent,
    this.fileName,
    this.mimeType,
    this.isCompressed = false,
    this.deleteAfterRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'createdAt': createdAt.toIso8601String(),
      'contentType': contentType.name,
      'textContent': textContent,
      'binaryContent': binaryContent != null ? base64Encode(binaryContent!) : null,
      'fileName': fileName,
      'mimeType': mimeType,
      'isCompressed': isCompressed,
      'deleteAfterRead': deleteAfterRead,
    };
  }

  factory DecryptedMessageData.fromJson(Map<String, dynamic> json) {
    return DecryptedMessageData(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      contentType: MessageContentType.values.firstWhere(
        (t) => t.name == json['contentType'],
        orElse: () => MessageContentType.text,
      ),
      textContent: json['textContent'] as String?,
      binaryContent: json['binaryContent'] != null 
          ? base64Decode(json['binaryContent'] as String)
          : null,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      isCompressed: json['isCompressed'] as bool? ?? false,
      deleteAfterRead: json['deleteAfterRead'] as bool? ?? false,
    );
  }
}

/// Service pour stocker localement les messages déchiffrés
class MessageStorageService {
  static const String _messagePrefix = 'decrypted_msg_';
  final _log = AppLogger();

  /// Sauvegarde un message déchiffré localement
  Future<void> saveDecryptedMessage({
    required String conversationId,
    required DecryptedMessageData message,
  }) async {
    _log.i('MessageStorage', 'Saving decrypted message ${message.id}');

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_messagePrefix${conversationId}_${message.id}';
      
      await prefs.setString(key, jsonEncode(message.toJson()));
      
      // Maintenir une liste des IDs de messages pour cette conversation
      await _addMessageIdToConversation(conversationId, message.id);
      
      _log.i('MessageStorage', 'Message saved successfully');
    } catch (e) {
      _log.e('MessageStorage', 'Error saving message: $e');
      rethrow;
    }
  }

  /// Récupère un message déchiffré
  Future<DecryptedMessageData?> getDecryptedMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_messagePrefix${conversationId}_$messageId';
      final data = prefs.getString(key);
      
      if (data == null) return null;
      
      return DecryptedMessageData.fromJson(jsonDecode(data));
    } catch (e) {
      _log.e('MessageStorage', 'Error getting message: $e');
      return null;
    }
  }

  /// Récupère tous les messages déchiffrés d'une conversation
  Future<List<DecryptedMessageData>> getConversationMessages(String conversationId) async {
    try {
      final messageIds = await _getMessageIdsForConversation(conversationId);
      final messages = <DecryptedMessageData>[];
      
      for (final messageId in messageIds) {
        final message = await getDecryptedMessage(
          conversationId: conversationId,
          messageId: messageId,
        );
        if (message != null) {
          messages.add(message);
        }
      }
      
      // Trier par date
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      return messages;
    } catch (e) {
      _log.e('MessageStorage', 'Error getting conversation messages: $e');
      return [];
    }
  }

  /// Récupère la date du dernier message d'une conversation
  Future<DateTime?> getLastMessageTimestamp(String conversationId) async {
    try {
      final messageIds = await _getMessageIdsForConversation(conversationId);
      if (messageIds.isEmpty) return null;
      
      // On suppose que le dernier ID ajouté est le plus récent
      final lastId = messageIds.last;
      final message = await getDecryptedMessage(
        conversationId: conversationId, 
        messageId: lastId,
      );
      
      return message?.createdAt;
    } catch (e) {
      _log.e('MessageStorage', 'Error getting last message timestamp: $e');
      return null;
    }
  }

  /// Supprime un message déchiffré
  Future<void> deleteDecryptedMessage({
    required String conversationId,
    required String messageId,
  }) async {
    _log.i('MessageStorage', 'Deleting decrypted message $messageId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_messagePrefix${conversationId}_$messageId';
      
      await prefs.remove(key);
      await _removeMessageIdFromConversation(conversationId, messageId);
      
      _log.i('MessageStorage', 'Message deleted successfully');
    } catch (e) {
      _log.e('MessageStorage', 'Error deleting message: $e');
    }
  }

  /// Supprime tous les messages d'une conversation
  Future<void> deleteConversationMessages(String conversationId) async {
    _log.i('MessageStorage', 'Deleting all messages for conversation $conversationId');

    try {
      final messageIds = await _getMessageIdsForConversation(conversationId);
      
      for (final messageId in messageIds) {
        await deleteDecryptedMessage(
          conversationId: conversationId,
          messageId: messageId,
        );
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_messagePrefix}list_$conversationId');
      
      _log.i('MessageStorage', 'All messages deleted');
    } catch (e) {
      _log.e('MessageStorage', 'Error deleting conversation messages: $e');
    }
  }

  /// Ajoute un ID de message à la liste pour une conversation
  Future<void> _addMessageIdToConversation(String conversationId, String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_messagePrefix}list_$conversationId';
    
    final existing = prefs.getStringList(key) ?? [];
    if (!existing.contains(messageId)) {
      existing.add(messageId);
      await prefs.setStringList(key, existing);
    }
  }

  /// Retire un ID de message de la liste pour une conversation
  Future<void> _removeMessageIdFromConversation(String conversationId, String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_messagePrefix}list_$conversationId';
    
    final existing = prefs.getStringList(key) ?? [];
    existing.remove(messageId);
    await prefs.setStringList(key, existing);
  }

  /// Récupère la liste des IDs de messages pour une conversation
  Future<List<String>> _getMessageIdsForConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_messagePrefix}list_$conversationId';
    return prefs.getStringList(key) ?? [];
  }
}
