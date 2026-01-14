import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/conversation.dart';
import '../models/encrypted_message.dart';
import '../models/shared_key.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
import '../services/media_service.dart';
import '../services/message_storage_service.dart';
import '../services/conversation_pseudo_service.dart';
import '../services/unread_message_service.dart';
import '../services/pseudo_storage_service.dart';
import '../l10n/app_localizations.dart';
import 'key_exchange_screen.dart';
import 'media_send_screen.dart';
import 'conversation_info_screen.dart';

import '../services/format_service.dart';
import '../services/app_logger.dart';

/// Wrapper pour afficher un message (local déchiffré ou Firestore chiffré)
class _DisplayMessage {
  final String id;
  final String senderId;
  final DateTime createdAt;
  final MessageContentType contentType;
  
  // Données locales déchiffrées
  final String? textContent;
  final Uint8List? binaryContent;
  final String? fileName;
  final String? mimeType;
  
  // Données Firestore (si pas encore déchiffré)
  final EncryptedMessage? firestoreMessage;
  
  final bool isCompressed;
  final bool deleteAfterRead;
  
  /// True si le message est chargé localement (déchiffré)
  final bool isLocal;

  _DisplayMessage({
    required this.id,
    required this.senderId,
    required this.createdAt,
    required this.contentType,
    this.textContent,
    this.binaryContent,
    this.fileName,
    this.mimeType,
    this.firestoreMessage,
    this.isCompressed = false,
    this.deleteAfterRead = false,
    this.isLocal = false,
  });

  /// Crée depuis un message local déchiffré
  factory _DisplayMessage.fromLocal(DecryptedMessageData local) {
    return _DisplayMessage(
      id: local.id,
      senderId: local.senderId,
      createdAt: local.createdAt,
      contentType: local.contentType,
      textContent: local.textContent,
      binaryContent: local.binaryContent,
      fileName: local.fileName,
      mimeType: local.mimeType,
      isCompressed: local.isCompressed,
      deleteAfterRead: local.deleteAfterRead,
      isLocal: true,
    );
  }

  /// Crée depuis un message Firestore (à traiter)
  factory _DisplayMessage.fromFirestore(EncryptedMessage firestore) {
    return _DisplayMessage(
      id: firestore.id,
      senderId: firestore.senderId,
      createdAt: firestore.createdAt,
      contentType: firestore.contentType,
      fileName: firestore.fileName,
      mimeType: firestore.mimeType,
      firestoreMessage: firestore,
      isCompressed: firestore.isCompressed,
      isLocal: false,
    );
  }
}

/// Écran de détail d'une conversation (chat).
class ConversationDetailScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationDetailScreen({
    super.key,
    required this.conversation,
  });

  @override
  State<ConversationDetailScreen> createState() => _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
   final AuthService _authService = AuthService();
   final KeyStorageService _keyStorageService = KeyStorageService();
   final AppLogger _log = AppLogger();
   final MediaService _mediaService = MediaService();
   final MessageStorageService _messageStorage = MessageStorageService();
   final ConversationPseudoService _convPseudoService = ConversationPseudoService();
   final UnreadMessageService _unreadService = UnreadMessageService();
   late final ConversationService _conversationService;
   late final CryptoService _cryptoService;
   final _messageController = TextEditingController();
   final _scrollController = ScrollController();

  bool _isLoading = false;
  SharedKey? _sharedKey;
  bool _hasSentPseudo = false;
  /// Track whether we previously had a key for this conversation.
  /// Used to detect the transition "no key -> key available".
  bool _hadKey = false;
  bool _showScrollToBottom = false;

  // Cache des pseudos pour affichage
  Map<String, String> _displayNames = {};
  
  // Track messages being processed to avoid duplicates
  final Set<String> _processingMessages = {};
  
  StreamSubscription<String>? _pseudoSubscription;

  @override
  void initState() {
    super.initState();
    final userId = _authService.currentUserId ?? '';
    _conversationService = ConversationService(localUserId: userId);
    _cryptoService = CryptoService(localPeerId: userId);
    // Load display names immediately (UI-friendly)
    _loadDisplayNames();

    // First determine if we already sent our pseudo locally, then load the key.
    // This ordering avoids racing: we want to know whether to auto-send the pseudo
    // when a key becomes available.
    _checkIfPseudoSent().whenComplete(() {
      _loadSharedKey();
    });

    // Listen for pseudo updates
    _pseudoSubscription = _convPseudoService.pseudoUpdates.listen((conversationId) {
      if (conversationId == widget.conversation.id) {
        _loadDisplayNames();
      }
    });
    
    // Mark all messages as read when opening conversation
    _unreadService.markAllAsRead(widget.conversation.id);

    // Scroll listeners
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >= 
                         _scrollController.position.maxScrollExtent - 100;
      if (isAtBottom && _showScrollToBottom) {
        setState(() => _showScrollToBottom = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _showScrollToBottom = false);
    }
  }

  /// Check if user has already sent their pseudo in this conversation
  Future<void> _checkIfPseudoSent() async {
    final messages = await _messageStorage.getConversationMessages(widget.conversation.id);
    
    // Check if any message from current user is a pseudo message
    for (final msg in messages) {
      if (msg.senderId == _currentUserId && msg.textContent != null) {
        if (PseudoExchangeMessage.isPseudoExchange(msg.textContent!)) {
          if (mounted) {
            setState(() {
              _hasSentPseudo = true;
            });
          }
          return;
        }
      }
    }
  }

  /// Charge les noms d'affichage des participants
  Future<void> _loadDisplayNames() async {
    final names = await _convPseudoService.getPseudos(widget.conversation.id);
    if (mounted) {
      setState(() {
        _displayNames = names;
      });
    }
  }

  /// Callback appelé quand un message pseudo est reçu
  void _onPseudoReceived(String userId, String pseudo) async {
    _log.d('ConversationDetail', 'onPseudoReceived called: $userId -> $pseudo');

    // Check if pseudo already matches to avoid infinite loop
    final current = _displayNames[userId];
    if (current == pseudo) {
      _log.d('ConversationDetail', 'Pseudo unchanged, skipping');
      return;
    }
    
    // Save pseudo in conversation-specific storage
    await _convPseudoService.setPseudo(widget.conversation.id, userId, pseudo);
    
    // Update local cache without triggering full reload
    if (mounted) {
      setState(() {
        _displayNames[userId] = pseudo;
      });
    }
  }

  Future<void> _updateKeyDebugInfo() async {
    if (_sharedKey == null) return;
    
    try {
      final availableBits = _sharedKey!.countAvailableBits(_currentUserId);
      // Allocation linéaire : on scanne toute la clé
      final totalBits = _sharedKey!.lengthInBits;
      
      // Trouver le premier et dernier index disponible
      int firstAvailable = -1;
      int lastAvailable = -1;
      
      for (int i = 0; i < totalBits; i++) {
        if (!_sharedKey!.isBitUsed(i)) {
          if (firstAvailable == -1) firstAvailable = i;
          lastAvailable = i;
        }
      }
      
      // Générer un hash simple pour la détection d'incohérences (first|last|available)
      final consistencyHash = '$firstAvailable|$lastAvailable|$availableBits';

      await _conversationService.updateKeyDebugInfo(
        conversationId: widget.conversation.id,
        userId: _currentUserId,
        info: {
          'availableBits': availableBits,
          'firstAvailableIndex': firstAvailable,
          'lastAvailableIndex': lastAvailable,
          'consistencyHash': consistencyHash,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      _log.d('ConversationDetail', 'Key debug info updated in Firestore');
    } catch (e) {
      _log.e('ConversationDetail', 'Error updating key debug info: $e');
    }
  }

  /// Callback quand des bits de clé sont utilisés (après déchiffrement)
  void _onKeyUsed() {
    // Force UI rebuild to update key usage in app bar
    if (mounted) {
      setState(() {});
    }

    // Sauvegarder la clé avec le bitmap mis à jour
    if (_sharedKey != null) {
      _log.d('ConversationDetail', '_onKeyUsed called - saving key bitmap');
      _keyStorageService.saveKey(widget.conversation.id, _sharedKey!).then((_) {
        _log.i('ConversationDetail', 'Key bitmap saved after message decryption');
        // Mettre à jour les infos de debug dans Firestore
        _updateKeyDebugInfo();
      }).catchError((e) {
        _log.e('ConversationDetail', 'ERROR saving key bitmap: $e');
      });
    } else {
      _log.w('ConversationDetail', '_onKeyUsed called but _sharedKey is null!');
    }
  }

  /// Process a new message from Firestore: decrypt, store locally, mark as transferred
  Future<void> _processNewMessage(EncryptedMessage message) async {
    // Skip if it's our own message (already in local storage from send)
    if (message.senderId == _currentUserId) {
      return;
    }

    // Skip if already being processed
    if (_processingMessages.contains(message.id)) {
      return;
    }

    // Check if already processed
    final existing = await _messageStorage.getDecryptedMessage(
      conversationId: widget.conversation.id,
      messageId: message.id,
    );
    if (existing != null) {
      return; // Already processed
    }

    // Mark as being processed
    _processingMessages.add(message.id);

    try {
      _log.d('ConversationDetail', 'Processing new message ${message.id}');

      // Decrypt the message
      if (message.contentType == MessageContentType.text) {
        try {
          final cryptoService = CryptoService(localPeerId: _currentUserId);
          final decrypted = cryptoService.decrypt(
            encryptedMessage: message,
            sharedKey: _sharedKey!,
            markAsUsed: true,
          );

          // Save decrypted message locally
          await _messageStorage.saveDecryptedMessage(
            conversationId: widget.conversation.id,
            message: DecryptedMessageData(
              id: message.id,
              senderId: message.senderId,
              createdAt: message.createdAt,
              contentType: message.contentType,
              textContent: decrypted,
              isCompressed: message.isCompressed,
            ),
          );

          // Check if this is a pseudo exchange message and notify
          if (PseudoExchangeMessage.isPseudoExchange(decrypted)) {
            final pseudoMsg = PseudoExchangeMessage.fromJson(decrypted);
            if (pseudoMsg != null && message.senderId != _currentUserId) {
              _onPseudoReceived(pseudoMsg.oderId, pseudoMsg.pseudo);
            }
          }

          // Mark key as used
          _onKeyUsed();

          // Mark as transferred on Firestore
          await _conversationService.markMessageAsTransferred(
            conversationId: widget.conversation.id,
            messageId: message.id,
            allParticipants: widget.conversation.peerIds,
          );

          _log.i('ConversationDetail', 'Text message processed and saved locally');
        } catch (e) {
          _log.e('ConversationDetail', 'Error processing text message: $e');
          rethrow;
        }
      } else {
        // Binary message (image/file)
        try {
          final cryptoService = CryptoService(localPeerId: _currentUserId);
          final decrypted = cryptoService.decryptBinary(
            encryptedMessage: message,
            sharedKey: _sharedKey!,
            markAsUsed: true,
          );

          // Save decrypted binary locally
          await _messageStorage.saveDecryptedMessage(
            conversationId: widget.conversation.id,
            message: DecryptedMessageData(
              id: message.id,
              senderId: message.senderId,
              createdAt: message.createdAt,
              contentType: message.contentType,
              binaryContent: decrypted,
              fileName: message.fileName,
              mimeType: message.mimeType,
              isCompressed: message.isCompressed,
            ),
          );

          // Mark key as used
          _onKeyUsed();

          // Mark as transferred on Firestore
          await _conversationService.markMessageAsTransferred(
            conversationId: widget.conversation.id,
            messageId: message.id,
            allParticipants: widget.conversation.peerIds,
          );

          _log.i('ConversationDetail', 'Binary message processed and saved locally');
        } catch (e) {
          _log.e('ConversationDetail', 'Error processing binary message: $e');
          rethrow;
        }
      }
    } finally {
      // Remove from processing set
      _processingMessages.remove(message.id);
    }
  }

  /// Combine local decrypted messages with Firestore messages
  Stream<List<_DisplayMessage>> _getCombinedMessagesStream() async* {
    await for (final firestoreMessages in _conversationService.watchMessages(widget.conversation.id)) {
      // Process new Firestore messages (wait for them to complete)
      final processedIds = <String>{};
      
      for (final msg in firestoreMessages) {
        if (msg.senderId != _currentUserId && _sharedKey != null) {
          // Process the message (AWAIT it now)
          try {
            await _processNewMessage(msg);
            processedIds.add(msg.id);
          } catch (e) {
            _log.e('ConversationDetail', 'Error processing message in stream: $e');
          }
        }
      }

      // Load local messages
      final localMessages = await _messageStorage.getConversationMessages(widget.conversation.id);
      
      // Create a set of local message IDs for quick lookup
      final localIds = localMessages.map((m) => m.id).toSet();
      
      // Combine: local messages + Firestore messages not yet in local storage
      final combined = <_DisplayMessage>[];
      
      // Add all local messages
      for (final local in localMessages) {
        combined.add(_DisplayMessage.fromLocal(local));
      }
      
      // Add Firestore messages that are not in local storage and not being processed
      for (final firestore in firestoreMessages) {
        if (!localIds.contains(firestore.id) && !processedIds.contains(firestore.id)) {
          combined.add(_DisplayMessage.fromFirestore(firestore));
        }
      }
      
      // Sort by timestamp
      combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      yield combined;
    }
  }

  Future<void> _loadSharedKey() async {
    _log.d('ConversationDetail', 'Loading shared key for ${widget.conversation.id}');
    // remember whether we had a key before loading (used to detect transition)
    final prevHadKey = _hadKey || _sharedKey != null;

    final key = await _keyStorageService.getKey(widget.conversation.id);
    if (mounted) {
      setState(() {
        _sharedKey = key;
        _hadKey = key != null;
      });
      _log.i('ConversationDetail', 'Shared key loaded: ${key != null ? "${key.lengthInBits} bits" : "NOT FOUND"}');

      // Update debug info immediately after loading key
      if (key != null) {
        _updateKeyDebugInfo();
      }
      
      // If we just transitioned from no-key to having a key, optionally auto-send pseudo
      if (!prevHadKey && key != null && AppConfig.autoSendPseudoOnKeyAvailable) {
        _log.d('ConversationDetail', 'Detected new key availability. Evaluating auto-send pseudo...');
        // Only auto-send if user hasn't already sent their pseudo and we're not already busy
        if (!_hasSentPseudo && !_isLoading) {
          // Defer a bit to let UI stabilize
          Future.microtask(() async {
            try {
              _log.d('ConversationDetail', 'Auto-sending pseudo (key became available)');
              await _sendMyPseudo();
            } catch (e) {
              _log.e('ConversationDetail', 'Auto-send pseudo failed: $e');
            }
          });
        } else {
          _log.d('ConversationDetail', 'Auto-send skipped (hasSent=$_hasSentPseudo, isLoading=$_isLoading)');
        }
      }

      // Si pas de clé, naviguer directement vers l'écran d'échange
      if (key == null && !widget.conversation.hasKey) {
        _log.d('ConversationDetail', 'No shared key found, navigating to key exchange');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _startKeyExchange();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pseudoSubscription?.cancel();
    // Sauvegarder la clé avant de quitter pour persister les bits utilisés
    if (_sharedKey != null) {
      _keyStorageService.saveKey(widget.conversation.id, _sharedKey!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Handles when the conversation is deleted from Firestore
  Future<void> _handleConversationDeleted(BuildContext context) async {
    if (!mounted) return;

    // Check if user initiated the deletion (if they're not in the conversation anymore)
    final conversationExists = await _conversationService.getConversation(widget.conversation.id);
    if (conversationExists != null) return; // Conversation still exists, false alarm

    // Show dialog asking if user wants to delete locally stored messages
    final shouldDeleteLocal = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Conversation supprimée'),
        content: const Text(
          'Cette conversation a été supprimée par un autre participant.\n\n'
          'Voulez-vous également supprimer les messages déchiffrés stockés localement ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver les messages'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (shouldDeleteLocal == true) {
      await _messageStorage.deleteConversationMessages(widget.conversation.id);
    }

    if (mounted) {
      Navigator.of(context).pop(); // Return to home screen
    }
  }

  String get _currentUserId => _authService.currentUserId ?? '';

  Future<void> _sendMyPseudo() async {
    if (_sharedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'envoyer: pas de clé de chiffrement'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final myPseudo = await PseudoStorageService().getMyPseudo();
      if (myPseudo == null || myPseudo.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez définir votre pseudo dans les paramètres')),
          );
        }
        return;
      }

      final pseudoMessage = PseudoExchangeMessage(
        oderId: _currentUserId,
        pseudo: myPseudo, // No smiley in stored message
      );

      // Chiffrer le message pseudo
      final result = _cryptoService.encrypt(
        plaintext: pseudoMessage.toJson(),
        sharedKey: _sharedKey!,
        compress: true,
      );

      final message = result.message;

      // Store decrypted message locally FIRST
      await _messageStorage.saveDecryptedMessage(
        conversationId: widget.conversation.id,
        message: DecryptedMessageData(
          id: message.id,
          senderId: message.senderId,
          createdAt: message.createdAt,
          contentType: message.contentType,
          textContent: pseudoMessage.toJson(),
          isCompressed: message.isCompressed,
        ),
      );

      // Mettre à jour les bits utilisés
      await _keyStorageService.updateUsedBits(
        widget.conversation.id,
        result.usedSegment.startBit,
        result.usedSegment.endBit,
      );

      // Recharger la clé
      await _loadSharedKey();

      // Envoyer le message
      await _conversationService.sendMessage(
        conversationId: widget.conversation.id,
        message: message,
        messagePreview: '👤 Pseudo partagé',
      );

      // Mark as transferred immediately
      await _conversationService.markMessageAsTransferred(
        conversationId: widget.conversation.id,
        messageId: message.id,
        allParticipants: widget.conversation.peerIds,
      );

      // Update state to show message input
      if (mounted) {
        setState(() {
          _hasSentPseudo = true;
        });
      }

      _log.i('ConversationDetail', 'Pseudo message sent successfully');
    } catch (e, stackTrace) {
      _log.e('ConversationDetail', 'ERROR sending pseudo: $e');
      _log.e('ConversationDetail', 'Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Vérifier qu'on a une clé
    if (_sharedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'envoyer: pas de clé de chiffrement'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _log.d('ConversationDetail', '_sendMessage: "$text"');
    _log.d('ConversationDetail', 'conversationId: ${widget.conversation.id}');
    _log.d('ConversationDetail', 'currentUserId: $_currentUserId');

    setState(() => _isLoading = true);
    _messageController.clear();

    try {
      // Chiffrement avec One-Time Pad
      _log.d('ConversationDetail', 'Encrypting message with OTP...');

      final result = _cryptoService.encrypt(
        plaintext: text,
        sharedKey: _sharedKey!,
        compress: true,
      );

      final message = result.message;
      const messagePreview = '🔒 Message chiffré';

      // Store decrypted message locally FIRST
      await _messageStorage.saveDecryptedMessage(
        conversationId: widget.conversation.id,
        message: DecryptedMessageData(
          id: message.id,
          senderId: message.senderId,
          createdAt: message.createdAt,
          contentType: message.contentType,
          textContent: text,
          isCompressed: message.isCompressed,
        ),
      );

      // Mettre à jour les bits utilisés dans le stockage local
      await _keyStorageService.updateUsedBits(
        widget.conversation.id,
        result.usedSegment.startBit,
        result.usedSegment.endBit,
      );

      // Recharger la clé pour avoir les bits à jour
      await _loadSharedKey();
      
      // Update debug info after sending message
      await _updateKeyDebugInfo();

      _log.d('ConversationDetail', 'Message encrypted: ${message.totalBitsUsed} bits used');

      _log.d('ConversationDetail', 'Calling conversationService.sendMessage...');
      await _conversationService.sendMessage(
        conversationId: widget.conversation.id,
        message: message,
        messagePreview: messagePreview,
      );

      // Mark as transferred immediately (we sent it)
      await _conversationService.markMessageAsTransferred(
        conversationId: widget.conversation.id,
        messageId: message.id,
        allParticipants: widget.conversation.peerIds,
      );

      _log.i('ConversationDetail', 'Message sent successfully!');

      // Scroll to bottom after sending
      if (mounted) {
        // Petit délai pour laisser le temps à l'UI de se mettre à jour
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _scrollToBottom();
        });
      }
    } catch (e, stackTrace) {
      _log.e('ConversationDetail', 'ERROR sending message: $e');
      _log.e('ConversationDetail', 'Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Affiche le menu d'attachement (image/fichier)
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Appareil photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Fichier'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Sélectionne et envoie une image
  Future<void> _pickImage(ImageSource source) async {
    if (_sharedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'envoyer: pas de clé de chiffrement'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Afficher un indicateur de chargement pendant le traitement de l'image
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Traitement de l\'image...'),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await _mediaService.pickImage(
      source: source,
      quality: ImageQuality.medium,
    );

    // Fermer l'indicateur de chargement
    if (mounted) Navigator.of(context).pop();

    if (result == null) return;

    if (!mounted) return;

    // Naviguer vers l'écran complet d'envoi
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaSendScreen(
          mediaResult: result,
          sharedKey: _sharedKey!,
          conversationId: widget.conversation.id,
          currentUserId: _currentUserId,
        ),
      ),
    );

    // Recharger la clé si envoyé avec succès
    if (sent == true && mounted) {
      await _loadSharedKey();
    }
  }

  /// Sélectionne et envoie un fichier
  Future<void> _pickFile() async {
    if (_sharedKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'envoyer: pas de clé de chiffrement'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Afficher un indicateur de chargement pendant le traitement du fichier
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Traitement du fichier...'),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await _mediaService.pickFile();

    // Fermer l'indicateur de chargement
    if (mounted) Navigator.of(context).pop();

    if (result == null) return;

    if (!mounted) return;

    // Naviguer vers l'écran complet d'envoi
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaSendScreen(
          mediaResult: result,
          sharedKey: _sharedKey!,
          conversationId: widget.conversation.id,
          currentUserId: _currentUserId,
        ),
      ),
    );

    // Recharger la clé si envoyé avec succès
    if (sent == true && mounted) {
      await _loadSharedKey();
    }
  }

  /// Envoie un média chiffré (DEPRECATED - utiliser MediaSendScreen)
  // Deprecated: kept for compatibility. Use `MediaSendScreen` instead.
  // ignore: unused_element
  Future<void> _sendMedia(MediaPickResult media) async {
     setState(() => _isLoading = true);

     try {
      if (AppConfig.verboseCryptoLogs) {
        _log.d('EncryptBinary', '=== ENCRYPT BINARY DEBUG ===');
        _log.d('EncryptBinary', '[Encrypt Binary] Content type: ${media.contentType}');
        _log.d('EncryptBinary', '[Encrypt Binary] Original data length: ${media.data.length} bytes');
        _log.d('EncryptBinary', '[Encrypt Binary] MIME type: ${media.mimeType}');
        _log.d('EncryptBinary', '[Encrypt Binary] Shared key length: ${_sharedKey!.lengthInBits} bits');
      }

      final result = _cryptoService.encryptBinary(
        data: media.data,
        sharedKey: _sharedKey!,
        contentType: media.contentType,
        fileName: media.fileName,
        mimeType: media.mimeType,
      );

      if (AppConfig.verboseCryptoLogs) {
        _log.d('EncryptBinary', '[Encrypt Binary] Encrypted data length: ${result.message.ciphertext.length} bytes');
        final seg = result.message.keySegment;
        if (seg != null) {
          _log.d('EncryptBinary', '[Encrypt Binary] Key segment used: ${seg.startBit}-${seg.endBit} (${result.message.totalBitsUsed} bits)');
        } else {
          _log.d('EncryptBinary', '[Encrypt Binary] Key segment used: none');
        }
        _log.d('EncryptBinary', '=== END ENCRYPT BINARY DEBUG ===');
      }

      final message = result.message;
      final messagePreview = media.contentType == MessageContentType.image
          ? '📷 Image'
          : '📎 ${media.fileName}';

      // Mettre à jour les bits utilisés dans le stockage local
      await _keyStorageService.updateUsedBits(
        widget.conversation.id,
        result.usedSegment.startBit,
        result.usedSegment.endBit,
      );

      // Recharger la clé pour avoir les bits à jour
      await _loadSharedKey();

      await _conversationService.sendMessage(
        conversationId: widget.conversation.id,
        message: message,
        messagePreview: messagePreview,
      );

      _log.i('ConversationDetail', 'Media sent: ${message.totalBitsUsed} bits used');
     } catch (e) {
      _log.e('ConversationDetail', 'ERROR sending media: $e');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur: $e')),
         );
       }
     } finally {
       if (mounted) {
         setState(() => _isLoading = false);
       }
     }
   }

  void _startKeyExchange() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KeyExchangeScreen(
          peerIds: widget.conversation.peerIds,
          existingConversationId: widget.conversation.id,
        ),
      ),
    );
  }

  String _getParticipantPseudos() {
    final pseudos = widget.conversation.peerIds
        .where((id) => id != _currentUserId) // Filter out current user
        .map((id) => _displayNames[id] ?? id.substring(0, 8))
        .toList();
    
    if (pseudos.isEmpty) {
      return widget.conversation.displayName;
    }
    
    return pseudos.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Conversation?>(
      stream: _conversationService.watchConversation(widget.conversation.id),
      initialData: widget.conversation,
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleConversationDeleted(context);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final conversation = snapshot.data!;
        return _buildConversationScreen(context, conversation);
      },
    );
  }

  Widget _buildConversationScreen(BuildContext context, Conversation conversation) {
    // Calcul de la clé restante basé sur SharedKey si disponible (plus précis)
    String remainingKeyFormatted = conversation.remainingKeyFormatted;
    double keyRemainingPercent = conversation.keyRemainingPercent;
    double displayKeyPercent = conversation.keyRemainingPercent;

    if (_sharedKey != null) {
      try {
        // Compute once to avoid multiple failing accesses
        final availableBits = _sharedKey!.countAvailableBits(_currentUserId);
        final totalBits = _sharedKey!.lengthInBits;

        if (totalBits > 0) {
          remainingKeyFormatted = FormatService.formatBytes(availableBits ~/ 8);
          keyRemainingPercent = (availableBits / totalBits) * 100;
          displayKeyPercent = keyRemainingPercent;
        } else {
          // Defensive fallback
          remainingKeyFormatted = conversation.remainingKeyFormatted;
          keyRemainingPercent = conversation.keyRemainingPercent;
          displayKeyPercent = conversation.keyRemainingPercent;
        }
      } catch (e, st) {
        // Log the full error and stack to console for debugging
        _log.e('ConversationDetail', 'SharedKey error: $e');
        _log.e('ConversationDetail', 'StackTrace: $st');
        // Also log error details
        _log.e('ConversationDetail', '=== SHARED KEY ERROR ===');
        _log.e('ConversationDetail', 'Error: $e');
        _log.e('ConversationDetail', 'Stack: $st');

        // Fallback to conversation-provided numbers
        remainingKeyFormatted = conversation.remainingKeyFormatted;
        keyRemainingPercent = conversation.keyRemainingPercent;
        displayKeyPercent = conversation.keyRemainingPercent;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showConversationInfo(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getParticipantPseudos(),
                style: const TextStyle(fontSize: 16),
              ),
              Row(
                children: [
                  // Nombre de participants
                  Icon(
                    Icons.people,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.conversation.peerIds.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 12),
                  // Status de la clé
                  Icon(
                    widget.conversation.hasKey ? Icons.lock : Icons.lock_open,
                    size: 12,
                    color: widget.conversation.hasKey
                        ? _getKeyColor(displayKeyPercent)
                        : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    remainingKeyFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.conversation.hasKey
                          ? _getKeyColor(displayKeyPercent)
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (_hasKeyConsistencyIssue())
            IconButton(
              icon: const Icon(Icons.broken_image, color: Colors.red),
              tooltip: 'Incohérence de clé détectée',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attention: Les clés des participants semblent désynchronisées.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          if (!widget.conversation.hasKey)
            IconButton(
              icon: const Icon(Icons.key),
              tooltip: 'Créer une clé',
              onPressed: _startKeyExchange,
            ),
          if (widget.conversation.hasKey)
            IconButton(
              icon: const Icon(Icons.key),
              tooltip: 'Allonger la clé',
              onPressed: _startKeyExchange,
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showConversationInfo(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Bannière pour conversation sans clé
              if (!widget.conversation.hasKey)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange[100],
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[800], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Messages non chiffrés. Créez une clé pour sécuriser vos échanges.',
                          style: TextStyle(color: Colors.orange[800], fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _startKeyExchange,
                        child: Text(
                          'Créer',
                          style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // Barre d'avertissement si peu de clé restante
              if (widget.conversation.hasKey && widget.conversation.keyRemainingPercent < 20)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red[100],
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[800], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Clé bientôt épuisée. Pensez à générer une nouvelle clé.',
                          style: TextStyle(color: Colors.red[800], fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: _startKeyExchange,
                        child: Text(
                          'Ajouter',
                          style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // Liste des messages
              Expanded(
            child: StreamBuilder<List<_DisplayMessage>>(
              stream: _getCombinedMessagesStream(),
              builder: (context, snapshot) {
                // Show loading only if no data yet
                if (snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                
                // Don't filter pseudo messages - show them in the thread
                final visibleMessages = messages;

                if (visibleMessages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun message\nEnvoyez le premier!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Auto-scroll on initial load or new message if already at bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    final maxScroll = _scrollController.position.maxScrollExtent;
                    final currentScroll = _scrollController.position.pixels;
                    final isAtBottom = maxScroll - currentScroll < 100;
                    
                    if (isAtBottom) {
                      _scrollController.jumpTo(maxScroll);
                    } else {
                      // New message arrived while scrolled up
                      // Verify if it is really a new message by checking length or last id
                      // For now, simple logic: if not at bottom, show button
                      setState(() => _showScrollToBottom = true);
                    }
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleMessages.length,
                  itemBuilder: (context, index) {
                    final message = visibleMessages[index];
                    final isMine = message.senderId == _currentUserId;
                    final senderName = _displayNames[message.senderId] ?? message.senderId;
                    
                    return _MessageBubbleNew(
                      message: message,
                      isMine: isMine,
                      senderName: senderName,
                      sharedKey: _sharedKey,
                      onMessageRead: (messageId) async {
                        // Mark as read and potentially delete
                        await _conversationService.markMessageAsReadAndCleanup(
                          conversationId: widget.conversation.id,
                          messageId: messageId,
                          allParticipants: widget.conversation.peerIds,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Barre de saisie ou bouton pseudo
          if (!_hasSentPseudo)
            // Show "Send my pseudo" button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _sharedKey == null ? null : _sendMyPseudo,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.person_add),
                    label: const Text('👋 Envoyer mon pseudo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else
            // Show message input
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Bouton d'attachement (image/fichier)
                    IconButton(
                      onPressed: _isLoading || _sharedKey == null ? null : _showAttachmentMenu,
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Envoyer image/fichier',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).get('conversation_type_message'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.text,
                        enableIMEPersonalizedLearning: false,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _isLoading ? null : _sendMessage,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
          
          // Bouton Scroll To Bottom
          if (_showScrollToBottom)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: Theme.of(context).primaryColor,
                child: const Icon(Icons.arrow_downward, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasKeyConsistencyIssue() {
    if (_sharedKey == null) return false;
    if (widget.conversation.keyDebugInfo.isEmpty) return false;

    // Récupérer mon hash local
    // Note: On recalcule pas ici, on utilise ce qui est dans Firestore si dispo, sinon on suppose OK
    // Pour simplifier, on compare les valeurs dans keyDebugInfo pour tous les pairs
    
    String? referenceHash;
    bool hasMismatch = false;

    widget.conversation.keyDebugInfo.forEach((userId, info) {
      if (info is Map<String, dynamic> && info.containsKey('consistencyHash')) {
        final hash = info['consistencyHash'] as String;
        if (referenceHash == null) {
          referenceHash = hash;
        } else if (referenceHash != hash) {
          hasMismatch = true;
        }
      }
    });

    return hasMismatch;
  }

  Color _getKeyColor(double percent) {
    if (percent > 50) return Colors.green;
    if (percent > 20) return Colors.orange;
    return Colors.red;
  }

  Future<void> _truncateKey() async {
    if (_sharedKey == null) return;
    
    // Calculer l'offset sûr (fin des octets entièrement utilisés au début)
    final usedBitmap = _sharedKey!.usedBitmap;
    int bytesToRemove = 0;
    
    // Compter les octets consécutifs à 0xFF au début
    for (int i = 0; i < usedBitmap.length; i++) {
      if (usedBitmap[i] == 0xFF) {
        bytesToRemove++;
      } else {
        break;
      }
    }
    
    if (bytesToRemove == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune partie de la clé à nettoyer.')),
        );
      }
      return;
    }
    
    final currentOffset = _sharedKey!.startOffset;
    final newOffset = currentOffset + (bytesToRemove * 8);
    
    try {
      final truncatedKey = _sharedKey!.truncate(newOffset);
      await _keyStorageService.saveKey(widget.conversation.id, truncatedKey);
      
      setState(() {
        _sharedKey = truncatedKey;
      });
      
      await _updateKeyDebugInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${bytesToRemove} octets de clé nettoyés.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du nettoyage: $e')),
        );
      }
    }
  }

  void _showConversationInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationInfoScreen(
          conversation: widget.conversation,
          sharedKey: _sharedKey,
          onDelete: () {
            Navigator.pop(context); // Close detail screen
          },
          onExtendKey: _startKeyExchange,
          onTruncateKey: _truncateKey,
        ),
      ),
    );
  }

}

class _MessageBubble extends StatefulWidget {
  final EncryptedMessage message;
  final bool isMine;
  final String? senderName;
  final SharedKey? sharedKey;
  final void Function(String oderId, String pseudo)? onPseudoReceived;
  final VoidCallback? onKeyUsed;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
    this.sharedKey,
    this.onPseudoReceived,
    this.onKeyUsed,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  final AppLogger _log = AppLogger();
  String? _decryptedText;
  Uint8List? _decryptedBinary;
  bool _isPseudoMessage = false;
  String? _pseudoName;

  @override
  void initState() {
    super.initState();
    // Decrypt synchronously (existing crypto service is synchronous)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryDecrypt();
    });
  }

  void _tryDecrypt() {
    try {
      if (widget.message.contentType == MessageContentType.text) {
        if (widget.sharedKey != null && widget.message.isEncrypted) {
          final text = CryptoService(localPeerId: widget.message.senderId)
              .decrypt(encryptedMessage: widget.message, sharedKey: widget.sharedKey!, markAsUsed: false);
          setState(() => _decryptedText = text);

          if (PseudoExchangeMessage.isPseudoExchange(text)) {
            final pseudo = PseudoExchangeMessage.fromJson(text);
            if (pseudo != null) {
              widget.onPseudoReceived?.call(pseudo.oderId, pseudo.pseudo);
              _isPseudoMessage = true;
              _pseudoName = pseudo.pseudo;
            }
          }

          // Mark bits used when we actually consume the key (done by parent callbacks)
          if (!widget.isMine && widget.sharedKey != null && widget.message.isEncrypted) {
            final seg = widget.message.keySegment;
            if (seg != null) {
              widget.sharedKey!.markBitsAsUsed(seg.startBit, seg.endBit);
              widget.onKeyUsed?.call();
            }
          }
        } else if (!widget.message.isEncrypted) {
          // Unencrypted text stored directly
          final text = String.fromCharCodes(widget.message.ciphertext);
          setState(() => _decryptedText = text);
        }
      } else {
        // binary
        if (widget.sharedKey != null && widget.message.isEncrypted) {
          final bin = CryptoService(localPeerId: widget.message.senderId)
              .decryptBinary(encryptedMessage: widget.message, sharedKey: widget.sharedKey!, markAsUsed: false);
          setState(() => _decryptedBinary = bin);

          if (!widget.isMine && widget.sharedKey != null && widget.message.isEncrypted) {
            final seg = widget.message.keySegment;
            if (seg != null) {
              widget.sharedKey!.markBitsAsUsed(seg.startBit, seg.endBit);
              widget.onKeyUsed?.call();
            }
          }
        }
      }
    } catch (e) {
      _log.e('_MessageBubble', 'Decrypt error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!widget.isMine)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                child: Text(widget.senderName?.substring(0, 1) ?? ''),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isMine ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: widget.message.contentType == MessageContentType.text
                  ? (_isPseudoMessage
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            Text(' ${_pseudoName ?? ''}', style: TextStyle(color: widget.isMine ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
                          ],
                        )
                      : SelectableText(_decryptedText ?? (widget.message.isEncrypted ? '🔒 [chiffré]' : String.fromCharCodes(widget.message.ciphertext)),
                          style: TextStyle(color: widget.isMine ? Colors.white : Colors.black87)))
                  : (_decryptedBinary != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_decryptedBinary!, width: 180, fit: BoxFit.cover))
                      : (widget.message.isEncrypted ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) : const SizedBox())),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Adapter widget to display either a local decrypted message (_DisplayMessage)
/// or wrap the encrypted `_MessageBubble` when the message is from Firestore.
class _MessageBubbleNew extends StatelessWidget {
  final _DisplayMessage message;
  final bool isMine;
  final String? senderName;
  final SharedKey? sharedKey;
  final Future<void> Function(String messageId)? onMessageRead;

  const _MessageBubbleNew({
    required this.message,
    required this.isMine,
    this.senderName,
    this.sharedKey,
    this.onMessageRead,
  });

  @override
  Widget build(BuildContext context) {
    // If the message is stored locally (decrypted), present it directly.
    if (message.isLocal) {
      if (message.contentType == MessageContentType.text) {
        // If the local text is a pseudo exchange message, show a concise UI
        if (message.textContent != null && PseudoExchangeMessage.isPseudoExchange(message.textContent!)) {
          final pseudo = PseudoExchangeMessage.fromJson(message.textContent!);
          final pseudoName = pseudo?.pseudo ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMine) CircleAvatar(radius: 14, child: Text((senderName ?? '').substring(0,1))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(' $pseudoName', style: TextStyle(color: isMine ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.black87, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine)
                CircleAvatar(radius: 14, child: Text(senderName?.substring(0,1) ?? '')),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMine ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    message.textContent ?? '',
                    style: TextStyle(
                      color: isMine ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Binary local message (image/file)
      if (message.contentType == MessageContentType.image && message.binaryContent != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine)
                CircleAvatar(radius: 14, child: Text((senderName ?? '').substring(0, 1))),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(message.binaryContent!, width: 180, fit: BoxFit.cover),
              ),
            ],
          ),
        );
      }

      // Fallback simple view for other local messages
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(message.textContent ?? ''),
      );
    }

    // Otherwise it's a Firestore EncryptedMessage: delegate to existing bubble
    final fm = message.firestoreMessage!;
    return _MessageBubble(
      message: fm,
      isMine: isMine,
      senderName: senderName,
      sharedKey: sharedKey,
      onPseudoReceived: (id, pseudo) {},
      onKeyUsed: () {},
    );
  }
}
