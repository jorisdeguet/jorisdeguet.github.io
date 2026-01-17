import 'dart:async';

import 'package:onetime/convo/encrypted_message.dart';
import 'package:onetime/convo/message_storage.dart';
import 'package:onetime/key_exchange/key_storage.dart';
import 'package:onetime/services/app_logger.dart';
import 'package:onetime/services/conversation_service.dart';
import 'package:onetime/services/crypto_service.dart';


import 'conversation.dart';

/// Service d'arrière-plan qui écoute Firestore et effectue le déchiffrement
/// centralisé des messages. Il enregistre les résultats localement via
/// MessageStorageService et marque les messages transférés sur Firestore.
class MessageService {
  final String localUserId;
  final ConversationService _conversationService;
  final KeyStorageService _keyStorage = KeyStorageService();
  final MessageStorageService _messageStorage = MessageStorageService();
  final AppLogger _log = AppLogger();

  // Map conversationId -> subscription
  final Map<String, StreamSubscription<List<EncryptedMessage>>> _subscriptions = {};
  // Track messages processing to avoid duplication
  final Map<String, Set<String>> _processing = {};

  // Watcher for user's conversations
  StreamSubscription<List<Conversation>>? _conversationsSub;
  final Set<String> _activeConversations = {};

  MessageService({required this.localUserId})
      : _conversationService = ConversationService(localUserId: localUserId);

  /// Start watching the current user's conversations and automatically
  /// start/stop listeners per conversation.
  void startWatchingUserConversations() {
    if (_conversationsSub != null) return;

    _log.d('BackgroundMessage', 'startWatchingUserConversations');
    _conversationsSub = _conversationService.watchUserConversations().listen((convs) {
      final newIds = convs.map((c) => c.id).toSet();

      // start listeners for newly added conversations
      for (final id in newIds.difference(_activeConversations)) {
        startForConversation(id);
        _activeConversations.add(id);
      }

      // stop listeners for removed conversations
      for (final id in _activeConversations.difference(newIds).toList()) {
        stopForConversation(id);
        _activeConversations.remove(id);
      }
    }, onError: (e) {
      _log.e('BackgroundMessage', 'Error watching user conversations: $e');
    });
  }

  /// Stop watching user conversations and stop all per-conversation listeners.
  Future<void> stopWatchingUserConversations() async {
    _log.d('BackgroundMessage', 'stopWatchingUserConversations');
    try {
      await _conversationsSub?.cancel();
    } catch (_) {}
    _conversationsSub = null;

    // Stop any per-conversation listeners
    for (final id in _activeConversations.toList()) {
      await stopForConversation(id);
    }
    _activeConversations.clear();
  }

  /// Start listening to a conversation's message stream
  void startForConversation(String conversationId) {
    if (_subscriptions.containsKey(conversationId)) return;

    _log.d('BackgroundMessage', 'startForConversation: $conversationId');
    _processing[conversationId] = {};

    final sub = _conversationService.watchMessages(conversationId).listen((msgs) async {
      for (final msg in msgs) {
        // ignore own messages
        if (msg.senderId == localUserId) continue;

        // Quick skip if already processed locally
        final existing = await _messageStorage.getDecryptedMessage(conversationId: conversationId, messageId: msg.id);
        if (existing != null) continue;

        // Avoid concurrent processing
        if (_processing[conversationId]!.contains(msg.id)) continue;
        _processing[conversationId]!.add(msg.id);

        try {
          await _processMessage(conversationId, msg);
        } catch (e) {
          _log.e('BackgroundMessage', 'Error processing ${msg.id}: $e');
        } finally {
          _processing[conversationId]!.remove(msg.id);
        }
      }
    }, onError: (e) {
      _log.e('BackgroundMessage', 'Stream error for $conversationId: $e');
    });

    _subscriptions[conversationId] = sub;
  }

  /// Stop listening a conversation
  Future<void> stopForConversation(String conversationId) async {
    _log.d('BackgroundMessage', 'stopForConversation: $conversationId');
    await _subscriptions[conversationId]?.cancel();
    _subscriptions.remove(conversationId);
    _processing.remove(conversationId);
    // Close message storage controller to free resources for this conv
    try {
      await _messageStorage.closeController(conversationId);
      _log.d('BackgroundMessage', 'Closed MessageStorage controller for $conversationId');
    } catch (e) {
      _log.e('BackgroundMessage', 'Error closing MessageStorage controller for $conversationId: $e');
    }
  }

  /// Stop all listeners
  Future<void> stopAll() async {
    _log.d('BackgroundMessage', 'stopAll');
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
    _processing.clear();
    // Close all controllers in message storage to avoid leaks
    try {
      for (final convId in _activeConversations) {
        await _messageStorage.closeController(convId);
      }
      _log.d('BackgroundMessage', 'Closed MessageStorage controllers for all active conversations');
    } catch (e) {
      _log.e('BackgroundMessage', 'Error closing message storage controllers: $e');
    }
  }

  Future<void> _processMessage(String conversationId, EncryptedMessage msg) async {
    _log.d('BackgroundMessage', 'Processing message ${msg.id} in $conversationId');

    // Load the key
    final key = await _keyStorage.getKey(conversationId);
    if (key == null) {
      _log.w('BackgroundMessage', 'No key for $conversationId; will retry later');
      return;
    }

    try {
      final crypto = CryptoService(localPeerId: localUserId);

      // Compute key segment start/end in bytes (if present)
      final int? keySegmentStartByte = msg.keySegment?.startByte;
      final int? keySegmentEndByte = msg.keySegment != null
          ? (msg.keySegment!.startByte + msg.keySegment!.lengthBytes - 1)
          : null;

      if (msg.contentType == MessageContentType.text) {
        final decrypted = crypto.decrypt(encryptedMessage: msg, sharedKey: key, markAsUsed: true);

        // Save decrypted message locally with key metadata
        await _messageStorage.saveDecryptedMessage(
          conversationId: conversationId,
          message: DecryptedMessageData(
            id: msg.id,
            senderId: msg.senderId,
            createdAt: msg.createdAt,
            contentType: msg.contentType,
            textContent: decrypted,
            isCompressed: msg.isCompressed,
            keyId: msg.keyId,
            keySegmentStart: keySegmentStartByte,
            keySegmentEnd: keySegmentEndByte,
          ),
        );
      } else {
        final decryptedBin = crypto.decryptBinary(encryptedMessage: msg, sharedKey: key, markAsUsed: true);
        await _messageStorage.saveDecryptedMessage(
          conversationId: conversationId,
          message: DecryptedMessageData(
            id: msg.id,
            senderId: msg.senderId,
            createdAt: msg.createdAt,
            contentType: msg.contentType,
            binaryContent: decryptedBin,
            fileName: msg.fileName,
            mimeType: msg.mimeType,
            isCompressed: msg.isCompressed,
            keyId: msg.keyId,
            keySegmentStart: keySegmentStartByte,
            keySegmentEnd: keySegmentEndByte,
          ),
        );
      }

      // Mark as transferred on Firestore
      await _conversationService.markMessageAsTransferred(
        conversationId: conversationId,
        messageId: msg.id,
        allParticipants: key.peerIds,
      );

      // Persist updated key bitmap
      await _keyStorage.saveKey(conversationId, key);

      _log.i('BackgroundMessage', 'Message ${msg.id} processed and stored locally');
    } catch (e, st) {
      _log.e('BackgroundMessage', 'Error decrypting message ${msg.id}: $e');
      _log.e('BackgroundMessage', 'Stack: $st');

      // If decryption failed we should not mark as transferred. Leave for retry.
      rethrow;
    }
  }

  /// Rescan (one-shot) all messages of a conversation and attempt to process any
  /// messages that haven't been decrypted/stored locally yet.
  Future<void> rescanConversation(String conversationId) async {
    // Explanation: added public method to rescan past messages and attempt decryption.
    _log.d('BackgroundMessage', 'rescanConversation: $conversationId');

    try {
      // Fetch messages (ConversationService returns messages ordered descending)
      final messages = await _conversationService.getMessages(conversationId: conversationId);

      // Process oldest first
      final toProcess = messages.reversed.toList();

      for (final msg in toProcess) {
        // ignore own messages
        if (msg.senderId == localUserId) continue;

        // Quick skip if already processed locally
        final existing = await _messageStorage.getDecryptedMessage(conversationId: conversationId, messageId: msg.id);
        if (existing != null) continue;

        // Avoid concurrent processing
        _processing.putIfAbsent(conversationId, () => {});
        if (_processing[conversationId]!.contains(msg.id)) continue;
        _processing[conversationId]!.add(msg.id);

        try {
          await _processMessage(conversationId, msg);
        } catch (e) {
          _log.e('BackgroundMessage', 'Error rescanning ${msg.id}: $e');
        } finally {
          _processing[conversationId]!.remove(msg.id);
        }
      }
    } catch (e, st) {
      _log.e('BackgroundMessage', 'rescanConversation ERROR: $e');
      _log.e('BackgroundMessage', 'Stack: $st');
      rethrow;
    }
  }
}
