import 'dart:async';
import 'dart:convert';
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
      deleteAfterRead: firestore.deleteAfterRead,
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
    _loadSharedKey();
    _loadDisplayNames();
    _checkIfPseudoSent();
    
    // Listen for pseudo updates
    _pseudoSubscription = _convPseudoService.pseudoUpdates.listen((conversationId) {
      if (conversationId == widget.conversation.id) {
        _loadDisplayNames();
      }
    });
    
    // Mark all messages as read when opening conversation
    _unreadService.markAllAsRead(widget.conversation.id);
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
    debugPrint('[ConversationDetail] onPseudoReceived called: $userId -> $pseudo');
    
    // Check if pseudo already matches to avoid infinite loop
    final current = _displayNames[userId];
    if (current == pseudo) {
      debugPrint('[ConversationDetail] Pseudo unchanged, skipping');
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
      final segment = _sharedKey!.getSegmentForPeer(_currentUserId);
      
      // Trouver le premier et dernier index disponible
      int firstAvailable = -1;
      int lastAvailable = -1;
      
      for (int i = segment.startBit; i < segment.endBit; i++) {
        if (!_sharedKey!.isBitUsed(i)) {
          if (firstAvailable == -1) firstAvailable = i;
          lastAvailable = i;
        }
      }
      
      await _conversationService.updateKeyDebugInfo(
        conversationId: widget.conversation.id,
        userId: _currentUserId,
        info: {
          'availableBits': availableBits,
          'firstAvailableIndex': firstAvailable,
          'lastAvailableIndex': lastAvailable,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[ConversationDetail] Key debug info updated in Firestore');
    } catch (e) {
      debugPrint('[ConversationDetail] Error updating key debug info: $e');
    }
  }

  /// Callback quand des bits de clé sont utilisés (après déchiffrement)
  void _onKeyUsed() {
    // Sauvegarder la clé avec le bitmap mis à jour
    if (_sharedKey != null) {
      debugPrint('[ConversationDetail] _onKeyUsed called - saving key bitmap');
      _keyStorageService.saveKey(widget.conversation.id, _sharedKey!).then((_) {
        debugPrint('[ConversationDetail] Key bitmap saved after message decryption');
        // Mettre à jour les infos de debug dans Firestore
        _updateKeyDebugInfo();
      }).catchError((e) {
        debugPrint('[ConversationDetail] ERROR saving key bitmap: $e');
      });
    } else {
      debugPrint('[ConversationDetail] _onKeyUsed called but _sharedKey is null!');
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
      debugPrint('[ConversationDetail] Processing new message ${message.id}');

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
              deleteAfterRead: message.deleteAfterRead,
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

          debugPrint('[ConversationDetail] Text message processed and saved locally');
        } catch (e) {
          debugPrint('[ConversationDetail] Error processing text message: $e');
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
              deleteAfterRead: message.deleteAfterRead,
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

          debugPrint('[ConversationDetail] Binary message processed and saved locally');
        } catch (e) {
          debugPrint('[ConversationDetail] Error processing binary message: $e');
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
            debugPrint('[ConversationDetail] Error processing message in stream: $e');
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
    debugPrint('[ConversationDetail] Loading shared key for ${widget.conversation.id}');
    final key = await _keyStorageService.getKey(widget.conversation.id);
    if (mounted) {
      setState(() {
        _sharedKey = key;
      });
      debugPrint('[ConversationDetail] Shared key loaded: ${key != null ? "${key.lengthInBits} bits" : "NOT FOUND"}');
      
      // Update debug info immediately after loading key
      if (key != null) {
        _updateKeyDebugInfo();
      }
      
      // Si pas de clé, naviguer directement vers l'écran d'échange
      if (key == null && !widget.conversation.hasKey) {
        debugPrint('[ConversationDetail] No shared key found, navigating to key exchange');
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
          deleteAfterRead: message.deleteAfterRead,
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

      debugPrint('[ConversationDetail] Pseudo message sent successfully');
    } catch (e, stackTrace) {
      debugPrint('[ConversationDetail] ERROR sending pseudo: $e');
      debugPrint('[ConversationDetail] Stack trace: $stackTrace');
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

    debugPrint('[ConversationDetail] _sendMessage: "$text"');
    debugPrint('[ConversationDetail] conversationId: ${widget.conversation.id}');
    debugPrint('[ConversationDetail] currentUserId: $_currentUserId');

    setState(() => _isLoading = true);
    _messageController.clear();

    try {
      // Chiffrement avec One-Time Pad
      debugPrint('[ConversationDetail] Encrypting message with OTP...');

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
          deleteAfterRead: message.deleteAfterRead,
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

      debugPrint('[ConversationDetail] Message encrypted: ${message.totalBitsUsed} bits used');

      debugPrint('[ConversationDetail] Calling conversationService.sendMessage...');
      await _conversationService.sendMessage(
        conversationId: widget.conversation.id,
        message: message,
        messagePreview: messagePreview,
        plaintextDebug: AppConfig.plaintextMessageFirestore ? text : null,
      );

      // Mark as transferred immediately (we sent it)
      await _conversationService.markMessageAsTransferred(
        conversationId: widget.conversation.id,
        messageId: message.id,
        allParticipants: widget.conversation.peerIds,
      );

      debugPrint('[ConversationDetail] Message sent successfully!');
    } catch (e, stackTrace) {
      debugPrint('[ConversationDetail] ERROR sending message: $e');
      debugPrint('[ConversationDetail] Stack trace: $stackTrace');
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
  Future<void> _sendMedia(MediaPickResult media) async {
    setState(() => _isLoading = true);

    try {
      if (AppConfig.verboseCryptoLogs) {
        debugPrint('=== ENCRYPT BINARY DEBUG ===');
        debugPrint('[Encrypt Binary] Content type: ${media.contentType}');
        debugPrint('[Encrypt Binary] Original data length: ${media.data.length} bytes');
        debugPrint('[Encrypt Binary] MIME type: ${media.mimeType}');
        debugPrint('[Encrypt Binary] Shared key length: ${_sharedKey!.lengthInBits} bits');
      }

      final result = _cryptoService.encryptBinary(
        data: media.data,
        sharedKey: _sharedKey!,
        contentType: media.contentType,
        fileName: media.fileName,
        mimeType: media.mimeType,
      );

      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Encrypt Binary] Encrypted data length: ${result.message.ciphertext.length} bytes');
        debugPrint('[Encrypt Binary] Key segments used: ${result.message.keySegments.length}');
        for (var i = 0; i < result.message.keySegments.length; i++) {
          final seg = result.message.keySegments[i];
          debugPrint('[Encrypt Binary]   Segment $i: ${seg.startBit}-${seg.endBit}');
        }
        debugPrint('=== END ENCRYPT BINARY DEBUG ===');
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

      debugPrint('[ConversationDetail] Media sent: ${message.totalBitsUsed} bits used');
    } catch (e) {
      debugPrint('[ConversationDetail] ERROR sending media: $e');
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
          conversationName: widget.conversation.name,
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
    // Calcul de la clé restante basé sur SharedKey si disponible (plus précis)
    final remainingKeyFormatted = _sharedKey != null
        ? FormatService.formatBytes(_sharedKey!.countAvailableBits(_currentUserId) ~/ 8)
        : widget.conversation.remainingKeyFormatted;
        
    // Pourcentage basé sur SharedKey si disponible
    final keyRemainingPercent = _sharedKey != null
        ? (1 - (_sharedKey!.countAvailableBits(_currentUserId) / _sharedKey!.lengthInBits)) * 100
        : widget.conversation.keyRemainingPercent; // Inversé car keyUsagePercent est usage
        
    final displayKeyPercent = _sharedKey != null
         ? (_sharedKey!.countAvailableBits(_currentUserId) / _sharedKey!.lengthInBits) * 100
         : widget.conversation.keyRemainingPercent;

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
      body: Column(
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
    );
  }

  Color _getKeyColor(double percent) {
    if (percent > 50) return Colors.green;
    if (percent > 20) return Colors.orange;
    return Colors.red;
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
  bool _pseudoProcessed = false;
  String? _cachedDecryptedText;
  Uint8List? _cachedDecryptedBinary;
  bool _isPseudoMessage = false;

  @override
  void initState() {
    super.initState();
    // Déchiffrer une seule fois lors de l'initialisation
    if (widget.message.contentType == MessageContentType.text) {
      _decryptAndCheckPseudo();
    } else if (widget.message.contentType == MessageContentType.image) {
      _decryptBinaryAndMarkBits();
    }
  }

  /// Déchiffre le message et vérifie si c'est un pseudo (une seule fois)
  void _decryptAndCheckPseudo() {
    try {
      final decrypted = _decryptTextMessage();
      _cachedDecryptedText = decrypted;
      
      debugPrint('[_MessageBubble] Text decrypt result: ${decrypted.length} chars');
      debugPrint('[_MessageBubble] sharedKey: ${widget.sharedKey != null}, encrypted: ${widget.message.isEncrypted}, isMine: ${widget.isMine}');
      
      // Marquer les bits comme utilisés après déchiffrement réussi
      if (widget.sharedKey != null && widget.message.isEncrypted && !widget.isMine) {
        debugPrint('[_MessageBubble] Marking bits as used for text message: ${widget.message.keySegments.length} segments');
        for (final seg in widget.message.keySegments) {
          widget.sharedKey!.markBitsAsUsed(seg.startBit, seg.endBit);
          debugPrint('[_MessageBubble] Marked bits ${seg.startBit}-${seg.endBit}');
        }
        // Sauvegarder le bitmap après marquage
        debugPrint('[_MessageBubble] Calling onKeyUsed callback');
        widget.onKeyUsed?.call();
      } else {
        debugPrint('[_MessageBubble] NOT marking bits - condition not met');
      }
      
      // Vérifier si c'est un message pseudo
      if (PseudoExchangeMessage.isPseudoExchange(decrypted)) {
        _isPseudoMessage = true;
        if (!_pseudoProcessed) {
          _pseudoProcessed = true;
          final pseudoMsg = PseudoExchangeMessage.fromJson(decrypted);
          if (pseudoMsg != null && widget.onPseudoReceived != null) {
            debugPrint('[MessageBubble] Processing pseudo message once: ${pseudoMsg.pseudo}');
            // Appeler le callback après le build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onPseudoReceived!(pseudoMsg.oderId, pseudoMsg.pseudo);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[_MessageBubble] Error during decrypt and check: $e');
      _cachedDecryptedText = '🔒 [Erreur]';
    }
  }

  /// Déchiffre les données binaires et marque les bits (une seule fois)
  void _decryptBinaryAndMarkBits() {
    try {
      final decrypted = _decryptBinaryMessage();
      _cachedDecryptedBinary = decrypted;
      
      debugPrint('[_MessageBubble] Binary decrypt result: ${decrypted != null ? "${decrypted.length} bytes" : "null"}');
      debugPrint('[_MessageBubble] sharedKey: ${widget.sharedKey != null}, encrypted: ${widget.message.isEncrypted}, isMine: ${widget.isMine}');
      
      // Marquer les bits comme utilisés après déchiffrement réussi
      if (decrypted != null && widget.sharedKey != null && widget.message.isEncrypted && !widget.isMine) {
        debugPrint('[_MessageBubble] Marking bits as used for binary message: ${widget.message.keySegments.length} segments');
        for (final seg in widget.message.keySegments) {
          widget.sharedKey!.markBitsAsUsed(seg.startBit, seg.endBit);
          debugPrint('[_MessageBubble] Marked bits ${seg.startBit}-${seg.endBit}');
        }
        // Sauvegarder le bitmap après marquage
        debugPrint('[_MessageBubble] Calling onKeyUsed callback');
        widget.onKeyUsed?.call();
      } else {
        debugPrint('[_MessageBubble] NOT marking bits - condition not met');
      }
    } catch (e) {
      debugPrint('[_MessageBubble] Error during binary decrypt: $e');
      _cachedDecryptedBinary = null;
    }
  }

  /// Déchiffre un message texte
  String _decryptTextMessage() {
    if (AppConfig.verboseCryptoLogs) {
      debugPrint('=== DECRYPT DEBUG ===');
      debugPrint('[Decrypt] Message ID: ${widget.message.id}');
      debugPrint('[Decrypt] Sender: ${widget.message.senderId}');
      debugPrint('[Decrypt] Is encrypted: ${widget.message.isEncrypted}');
      debugPrint('[Decrypt] Total bits used: ${widget.message.totalBitsUsed}');
    }

    // Si pas de segments de clé, le message est en clair
    if (!widget.message.isEncrypted) {
      try {
        final plaintext = utf8.decode(widget.message.ciphertext);
        if (AppConfig.verboseCryptoLogs) {
          debugPrint('[Decrypt] Unencrypted message: $plaintext');
          debugPrint('=== END DECRYPT DEBUG ===');
        }
        return plaintext;
      } catch (e) {
        return String.fromCharCodes(widget.message.ciphertext);
      }
    }

    // Si on n'a pas la clé, afficher un placeholder
    if (widget.sharedKey == null) {
      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt] ERROR: No shared key available');
        debugPrint('=== END DECRYPT DEBUG ===');
      }
      return '🔒 [Clé manquante pour déchiffrer]';
    }

    // Déchiffrer avec la clé
    try {
      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt] Shared key length: ${widget.sharedKey!.lengthInBits} bits');
        debugPrint('[Decrypt] Key segments: ${widget.message.keySegments.length}');
        for (var i = 0; i < widget.message.keySegments.length; i++) {
          final seg = widget.message.keySegments[i];
          debugPrint('[Decrypt]   Segment $i: ${seg.startBit}-${seg.endBit} (${seg.endBit - seg.startBit + 1} bits)');
        }
      }

      final cryptoService = CryptoService(localPeerId: '');
      final decrypted = cryptoService.decrypt(
        encryptedMessage: widget.message,
        sharedKey: widget.sharedKey!,
        markAsUsed: false, // Ne pas marquer à la réception - seul l'envoyeur marque
      );

      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt] SUCCESS: Decrypted text: $decrypted');
        debugPrint('=== END DECRYPT DEBUG ===');
      }

      return decrypted;
    } catch (e, stackTrace) {
      debugPrint('[_MessageBubble] Decryption error: $e');
      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt] ERROR during decryption: $e');
        debugPrint('[Decrypt] Stack trace: $stackTrace');
        debugPrint('=== END DECRYPT DEBUG ===');
      }
      return '🔒 [Erreur de déchiffrement]';
    }
  }

  /// Déchiffre des données binaires (image/fichier)
  Uint8List? _decryptBinaryMessage() {
    if (AppConfig.verboseCryptoLogs) {
      debugPrint('=== DECRYPT BINARY DEBUG ===');
      debugPrint('[Decrypt Binary] Message ID: ${widget.message.id}');
      debugPrint('[Decrypt Binary] Content type: ${widget.message.contentType}');
      debugPrint('[Decrypt Binary] Is encrypted: ${widget.message.isEncrypted}');
      debugPrint('[Decrypt Binary] Ciphertext length: ${widget.message.ciphertext.length} bytes');
    }

    if (!widget.message.isEncrypted || widget.sharedKey == null) {
      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt Binary] Returning unencrypted data');
        debugPrint('=== END DECRYPT BINARY DEBUG ===');
      }
      return widget.message.ciphertext;
    }

    try {
      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt Binary] Shared key length: ${widget.sharedKey!.lengthInBits} bits');
        debugPrint('[Decrypt Binary] Key segments: ${widget.message.keySegments.length}');
        for (var i = 0; i < widget.message.keySegments.length; i++) {
          final seg = widget.message.keySegments[i];
          debugPrint('[Decrypt Binary]   Segment $i: ${seg.startBit}-${seg.endBit}');
        }
      }

      final cryptoService = CryptoService(localPeerId: '');
      final decrypted = cryptoService.decryptBinary(
        encryptedMessage: widget.message,
        sharedKey: widget.sharedKey!,
        markAsUsed: false, // Ne pas marquer à la réception - seul l'envoyeur marque
      );

      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt Binary] SUCCESS: Decrypted ${decrypted.length} bytes');
        debugPrint('=== END DECRYPT BINARY DEBUG ===');
      }

      return decrypted;
    } catch (e, stackTrace) {
      debugPrint('[_MessageBubble] Binary decryption error: $e');
      if (AppConfig.verboseCryptoLogs) {
        debugPrint('[Decrypt Binary] ERROR: $e');
        debugPrint('[Decrypt Binary] Stack trace: $stackTrace');
        debugPrint('=== END DECRYPT BINARY DEBUG ===');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si c'est un message pseudo, ne pas l'afficher
    if (_isPseudoMessage) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: widget.isMine
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: widget.isMine ? const Radius.circular(4) : null,
            bottomLeft: !widget.isMine ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isMine && widget.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            _buildContent(context),
            const SizedBox(height: 4),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (widget.message.contentType) {
      case MessageContentType.image:
        return _buildImageContent(context);
      case MessageContentType.file:
        return _buildFileContent(context);
      case MessageContentType.text:
        return _buildTextContent(context);
    }
  }

  Widget _buildTextContent(BuildContext context) {
    // Utiliser le texte déchiffré en cache au lieu de re-déchiffrer
    final decryptedText = _cachedDecryptedText ?? _decryptTextMessage();

    return Text(
      decryptedText,
      style: TextStyle(
        color: widget.isMine ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    // Utiliser les données déchiffrées en cache au lieu de re-déchiffrer
    final imageData = _cachedDecryptedBinary ?? _decryptBinaryMessage();

    if (imageData == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image,
            color: widget.isMine ? Colors.white70 : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            'Image non déchiffrable',
            style: TextStyle(
              color: widget.isMine ? Colors.white70 : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _showFullScreenImage(context, imageData),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          imageData,
          fit: BoxFit.cover,
          width: 200,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 150,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 48),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFileContent(BuildContext context) {
    final fileName = widget.message.fileName ?? 'Fichier';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file,
          color: widget.isMine ? Colors.white : Colors.grey[700],
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            fileName,
            style: TextStyle(
              color: widget.isMine ? Colors.white : Colors.black87,
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(widget.message.createdAt),
          style: TextStyle(
            fontSize: 10,
            color: widget.isMine ? Colors.white70 : Colors.grey[600],
          ),
        ),
        if (widget.message.isEncrypted) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.lock,
            size: 12,
            color: widget.isMine ? Colors.white70 : Colors.grey[600],
          ),
        ],
        if (widget.message.contentType == MessageContentType.image) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.image,
            size: 12,
            color: widget.isMine ? Colors.white70 : Colors.grey[600],
          ),
        ],
        if (widget.message.contentType == MessageContentType.file) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.attach_file,
            size: 12,
            color: widget.isMine ? Colors.white70 : Colors.grey[600],
          ),
        ],
        if (widget.message.isCompressed) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.compress,
            size: 12,
            color: widget.isMine ? Colors.white70 : Colors.grey[600],
          ),
        ],
        if (widget.message.deleteAfterRead) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.timer,
            size: 12,
            color: widget.isMine ? Colors.white70 : Colors.grey[600],
          ),
        ],
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, Uint8List imageData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(imageData),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}



/// New message bubble that displays _DisplayMessage (local or Firestore)
class _MessageBubbleNew extends StatefulWidget {
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
  State<_MessageBubbleNew> createState() => _MessageBubbleNewState();
}

class _MessageBubbleNewState extends State<_MessageBubbleNew> {
  bool _hasMarkedAsRead = false;

  @override
  void initState() {
    super.initState();
    // Mark as read when displayed (only for received messages)
    if (!widget.isMine && !_hasMarkedAsRead) {
      _hasMarkedAsRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onMessageRead?.call(widget.message.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Time and read status on left for SENT messages
          if (widget.isMine) ...[
            _buildTimeAndStatus(context),
            const SizedBox(width: 8),
          ],
          // Message bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              color: widget.isMine
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: widget.isMine ? const Radius.circular(4) : null,
                bottomLeft: !widget.isMine ? const Radius.circular(4) : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isMine && widget.senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.senderName!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                _buildContent(context),
              ],
            ),
          ),
          // Time and read status on right for RECEIVED messages
          if (!widget.isMine) ...[
            const SizedBox(width: 8),
            _buildTimeAndStatus(context),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.message.isLocal) {
      // Display from local decrypted data
      switch (widget.message.contentType) {
        case MessageContentType.text:
          // Check if this is a pseudo exchange message
          if (widget.message.textContent != null && 
              PseudoExchangeMessage.isPseudoExchange(widget.message.textContent!)) {
            final pseudoMsg = PseudoExchangeMessage.fromJson(widget.message.textContent!);
            if (pseudoMsg != null) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add,
                    size: 20,
                    color: widget.isMine 
                        ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179)
                        : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '😊 ${pseudoMsg.pseudo}', // Add smiley only in display
                      style: TextStyle(
                        color: widget.isMine 
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }
          }
          
          // Regular text message
          return Text(
            widget.message.textContent ?? '',
            style: TextStyle(
              color: widget.isMine 
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
            ),
          );
        case MessageContentType.image:
          return _buildImageFromLocal(context);
        case MessageContentType.file:
          return _buildFileFromLocal(context);
      }
    } else {
      // Display from Firestore (still encrypted, shouldn't happen much)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                widget.isMine 
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Déchiffrement...',
            style: TextStyle(
              color: widget.isMine 
                  ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildImageFromLocal(BuildContext context) {
    if (widget.message.binaryContent == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image,
            color: widget.isMine 
                ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Image non disponible',
            style: TextStyle(
              color: widget.isMine 
                  ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _showFullScreenImage(context, widget.message.binaryContent!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          widget.message.binaryContent!,
          fit: BoxFit.cover,
          width: 200,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 150,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 48),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFileFromLocal(BuildContext context) {
    final fileName = widget.message.fileName ?? 'Fichier';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file,
          color: widget.isMine ? Colors.white : Colors.grey[700],
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            fileName,
            style: TextStyle(
              color: widget.isMine ? Colors.white : Colors.black87,
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeAndStatus(BuildContext context) {
    // Get read status from Firestore message if available
    int totalParticipants = 0;
    int readCount = 0;
    
    if (widget.message.firestoreMessage != null) {
      final msg = widget.message.firestoreMessage!;
      totalParticipants = (msg.readBy.length + msg.transferredBy.length);
      readCount = msg.readBy.length;
    }
    
    String readStatus = '';
    if (widget.isMine && totalParticipants > 0) {
      if (readCount == totalParticipants) {
        readStatus = 'lu';
      } else if (readCount > 0) {
        readStatus = 'lu $readCount/$totalParticipants';
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(widget.message.createdAt),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        if (readStatus.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            readStatus,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final iconColor = widget.isMine 
        ? Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(179)
        : Theme.of(context).colorScheme.onSurfaceVariant;
        
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message.contentType == MessageContentType.image) ...[
          Icon(
            Icons.image,
            size: 12,
            color: iconColor,
          ),
          const SizedBox(width: 4),
        ],
        if (widget.message.contentType == MessageContentType.file) ...[
          Icon(
            Icons.attach_file,
            size: 12,
            color: iconColor,
          ),
          const SizedBox(width: 4),
        ],
        if (widget.message.isCompressed) ...[
          Icon(
            Icons.compress,
            size: 12,
            color: iconColor,
          ),
        ],
        if (widget.message.deleteAfterRead) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.timer,
            size: 12,
            color: iconColor,
          ),
        ],
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, Uint8List imageData) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.memory(imageData),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
