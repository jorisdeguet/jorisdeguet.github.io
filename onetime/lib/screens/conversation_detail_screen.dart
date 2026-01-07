import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/conversation.dart';
import '../models/encrypted_message.dart';
import '../models/shared_key.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
import '../services/media_service.dart';
import '../services/pseudo_storage_service.dart';
import '../widgets/media_confirm_dialog.dart';
import 'key_exchange_screen.dart';

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
  final PseudoStorageService _pseudoService = PseudoStorageService();
  late final ConversationService _conversationService;
  late final CryptoService _cryptoService;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = false;
  SharedKey? _sharedKey;

  // Cache des pseudos pour affichage
  Map<String, String> _displayNames = {};

  @override
  void initState() {
    super.initState();
    final userId = _authService.currentUserId ?? '';
    _conversationService = ConversationService(localUserId: userId);
    _cryptoService = CryptoService(localPeerId: userId);
    _loadSharedKey();
    _loadDisplayNames();
  }

  /// Charge les noms d'affichage des participants
  Future<void> _loadDisplayNames() async {
    final names = await _pseudoService.getDisplayNames(widget.conversation.peerIds);
    if (mounted) {
      setState(() {
        _displayNames = names;
      });
    }
  }

  /// Callback appelé quand un message pseudo est reçu
  void _onPseudoReceived(String oderId, String pseudo) async {
    await _pseudoService.setPseudo(oderId, pseudo);
    // Recharger les noms d'affichage
    _loadDisplayNames();
  }

  Future<void> _loadSharedKey() async {
    debugPrint('[ConversationDetail] Loading shared key for ${widget.conversation.id}');
    final key = await _keyStorageService.getKey(widget.conversation.id);
    if (mounted) {
      setState(() {
        _sharedKey = key;
      });
      debugPrint('[ConversationDetail] Shared key loaded: ${key != null ? "${key.lengthInBits} bits" : "NOT FOUND"}');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentUserId => _authService.currentUserId ?? '';

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

      // Mettre à jour les bits utilisés dans le stockage local
      await _keyStorageService.updateUsedBits(
        widget.conversation.id,
        result.usedSegment.startBit,
        result.usedSegment.endBit,
      );

      debugPrint('[ConversationDetail] Message encrypted: ${message.totalBitsUsed} bits used');

      debugPrint('[ConversationDetail] Calling conversationService.sendMessage...');
      await _conversationService.sendMessage(
        conversationId: widget.conversation.id,
        message: message,
        messagePreview: messagePreview,
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

    final result = await _mediaService.pickImage(
      source: source,
      quality: ImageQuality.medium,
    );

    if (result == null) return;

    final availableBits = _sharedKey!.countAvailableBits(_currentUserId);

    if (!mounted) return;

    final confirmation = await MediaConfirmDialog.show(
      context: context,
      mediaResult: result,
      availableKeyBits: availableBits,
      mediaService: _mediaService,
    );

    if (confirmation == null) return;

    await _sendMedia(confirmation.result);
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

    final result = await _mediaService.pickFile();

    if (result == null) return;

    final availableBits = _sharedKey!.countAvailableBits(_currentUserId);

    if (!mounted) return;

    final confirmation = await MediaConfirmDialog.show(
      context: context,
      mediaResult: result,
      availableKeyBits: availableBits,
      mediaService: _mediaService,
    );

    if (confirmation == null) return;

    await _sendMedia(confirmation.result);
  }

  /// Envoie un média chiffré
  Future<void> _sendMedia(MediaPickResult media) async {
    setState(() => _isLoading = true);

    try {
      final result = _cryptoService.encryptBinary(
        data: media.data,
        sharedKey: _sharedKey!,
        contentType: media.contentType,
        fileName: media.fileName,
        mimeType: media.mimeType,
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showConversationInfo(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.conversation.displayName,
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
                        ? _getKeyColor(widget.conversation.keyRemainingPercent)
                        : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.conversation.remainingKeyFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.conversation.hasKey
                          ? _getKeyColor(widget.conversation.keyRemainingPercent)
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
            child: StreamBuilder<List<EncryptedMessage>>(
              stream: _conversationService.watchMessages(widget.conversation.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
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
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == _currentUserId;
                    final senderName = _displayNames[message.senderId] ?? message.senderId;
                    return _MessageBubble(
                      message: message,
                      isMine: isMine,
                      senderName: senderName,
                      sharedKey: _sharedKey,
                      onPseudoReceived: _onPseudoReceived,
                    );
                  },
                );
              },
            ),
          ),

          // Barre de saisie
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
                        hintText: 'Message chiffré...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConversationInfoSheet(
        conversation: widget.conversation,
        onDelete: _deleteConversation,
        onExtendKey: _startKeyExchange,
      ),
    );
  }

  Future<void> _deleteConversation() async {
    try {
      await _conversationService.deleteConversation(widget.conversation.id);

      // Supprimer la clé locale si elle existe
      await _keyStorageService.deleteKey(widget.conversation.id);

      if (mounted) {
        // Fermer le bottom sheet d'info d'abord
        Navigator.pop(context);
        // Puis fermer l'écran de conversation et retourner à l'écran d'accueil
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation supprimée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}

class _MessageBubble extends StatefulWidget {
  final EncryptedMessage message;
  final bool isMine;
  final String? senderName;
  final SharedKey? sharedKey;
  final void Function(String oderId, String pseudo)? onPseudoReceived;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
    this.sharedKey,
    this.onPseudoReceived,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _pseudoProcessed = false;

  /// Déchiffre un message texte
  String _decryptTextMessage() {
    // Si pas de segments de clé, le message est en clair
    if (!widget.message.isEncrypted) {
      try {
        return utf8.decode(widget.message.ciphertext);
      } catch (e) {
        return String.fromCharCodes(widget.message.ciphertext);
      }
    }

    // Si on n'a pas la clé, afficher un placeholder
    if (widget.sharedKey == null) {
      return '🔒 [Clé manquante pour déchiffrer]';
    }

    // Déchiffrer avec la clé
    try {
      final cryptoService = CryptoService(localPeerId: '');
      final decrypted = cryptoService.decrypt(
        encryptedMessage: widget.message,
        sharedKey: widget.sharedKey!,
      );

      // Vérifier si c'est un message pseudo
      if (!_pseudoProcessed && PseudoExchangeMessage.isPseudoExchange(decrypted)) {
        _pseudoProcessed = true;
        final pseudoMsg = PseudoExchangeMessage.fromJson(decrypted);
        if (pseudoMsg != null && widget.onPseudoReceived != null) {
          // Appeler le callback après le build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onPseudoReceived!(pseudoMsg.oderId, pseudoMsg.pseudo);
          });
        }
        return '👤 ${pseudoMsg?.pseudo ?? "Pseudo reçu"}';
      }

      return decrypted;
    } catch (e) {
      debugPrint('[_MessageBubble] Decryption error: $e');
      return '🔒 [Erreur de déchiffrement]';
    }
  }

  /// Déchiffre des données binaires (image/fichier)
  Uint8List? _decryptBinaryMessage() {
    if (!widget.message.isEncrypted || widget.sharedKey == null) {
      return widget.message.ciphertext;
    }

    try {
      final cryptoService = CryptoService(localPeerId: '');
      return cryptoService.decryptBinary(
        encryptedMessage: widget.message,
        sharedKey: widget.sharedKey!,
      );
    } catch (e) {
      debugPrint('[_MessageBubble] Binary decryption error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final decryptedText = _decryptTextMessage();

    return Text(
      decryptedText,
      style: TextStyle(
        color: widget.isMine ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final imageData = _decryptBinaryMessage();

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

class _ConversationInfoSheet extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onDelete;
  final VoidCallback? onExtendKey;

  const _ConversationInfoSheet({
    required this.conversation,
    this.onDelete,
    this.onExtendKey,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Participants
            Text(
              'Participants',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conversation.peerIds.map((peerId) {
                // Utiliser un affichage raccourci de l'ID
                final shortId = peerId.length > 8
                    ? peerId.substring(0, 8)
                    : peerId;
                return Chip(
                  avatar: CircleAvatar(
                    child: Text(
                      peerId.length >= 2
                          ? peerId.substring(0, 2).toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  label: Text(shortId),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Informations générales
            _InfoRow(
              icon: Icons.people,
              label: 'Nombre de participants',
              value: '${conversation.peerIds.length}',
            ),
            _InfoRow(
              icon: Icons.message,
              label: 'Messages',
              value: '${conversation.messageCount}',
            ),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Créée le',
              value: _formatDate(conversation.createdAt),
            ),

            const SizedBox(height: 24),

            // Informations sur la clé
            Text(
              'Chiffrement',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),

            if (conversation.hasKey) ...[
              _InfoRow(
                icon: Icons.key,
                label: 'Clé totale',
                value: _formatBytes(conversation.totalKeyBits ~/ 8),
              ),
              _InfoRow(
                icon: Icons.data_usage,
                label: 'Clé restante',
                value: conversation.remainingKeyFormatted,
              ),
              _InfoRow(
                icon: Icons.percent,
                label: 'Utilisation',
                value: '${conversation.keyUsagePercent.toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 16),
              // Barre de progression de la clé
              LinearProgressIndicator(
                value: conversation.keyUsagePercent / 100,
                backgroundColor: Colors.grey[200],
                color: _getKeyColor(conversation.keyRemainingPercent),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_open, color: Colors.orange[800]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pas de clé de chiffrement',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          Text(
                            'Les messages ne sont pas chiffrés de bout en bout.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Actions
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),

            // Bouton pour étendre/créer la clé
            if (conversation.hasKey && conversation.isKeyLow || !conversation.hasKey)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onExtendKey?.call();
                  },
                  icon: Icon(conversation.hasKey ? Icons.add : Icons.key),
                  label: Text(
                    conversation.hasKey
                        ? 'Étendre la clé (${conversation.keyRemainingPercent.toStringAsFixed(0)}% restant)'
                        : 'Créer une clé de chiffrement',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            if (conversation.hasKey && conversation.isKeyLow)
              const SizedBox(height: 8),

            // Bouton de suppression
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text('Supprimer la conversation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la conversation ?'),
        content: const Text(
          'Cette action est irréversible. La conversation et tous ses messages seront supprimés pour tous les participants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getKeyColor(double percent) {
    if (percent > 50) return Colors.green;
    if (percent > 20) return Colors.orange;
    return Colors.red;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
