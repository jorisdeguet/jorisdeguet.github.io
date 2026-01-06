import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/encrypted_message.dart';
import '../models/shared_key.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import '../services/crypto_service.dart';
import '../services/key_storage_service.dart';
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
  late final ConversationService _conversationService;
  late final CryptoService _cryptoService;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = false;
  SharedKey? _sharedKey;

  @override
  void initState() {
    super.initState();
    final userId = _authService.currentPhoneNumber ?? '';
    _conversationService = ConversationService(localUserId: userId);
    _cryptoService = CryptoService(localPeerId: userId);
    _loadSharedKey();
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

  String get _currentUserId => _authService.currentPhoneNumber ?? '';

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    debugPrint('[ConversationDetail] _sendMessage: "$text"');
    debugPrint('[ConversationDetail] conversationId: ${widget.conversation.id}');
    debugPrint('[ConversationDetail] hasKey: ${widget.conversation.hasKey}');
    debugPrint('[ConversationDetail] sharedKey loaded: ${_sharedKey != null}');
    debugPrint('[ConversationDetail] currentUserId: $_currentUserId');

    setState(() => _isLoading = true);
    _messageController.clear();

    try {
      EncryptedMessage message;
      String messagePreview;

      if (_sharedKey != null) {
        // Chiffrement avec One-Time Pad
        debugPrint('[ConversationDetail] Encrypting message with OTP...');

        try {
          final result = _cryptoService.encrypt(
            plaintext: text,
            sharedKey: _sharedKey!,
            compress: true,
          );

          message = result.message;
          messagePreview = '🔒 Message chiffré';

          // Mettre à jour les bits utilisés dans le stockage local
          await _keyStorageService.updateUsedBits(
            widget.conversation.id,
            result.usedSegment.startBit,
            result.usedSegment.endBit,
          );

          debugPrint('[ConversationDetail] Message encrypted: ${message.totalBitsUsed} bits used');
        } catch (e) {
          debugPrint('[ConversationDetail] Encryption failed: $e');
          // Si le chiffrement échoue (pas assez de clé), envoyer en clair avec avertissement
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Chiffrement impossible: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      } else {
        // Message non chiffré
        debugPrint('[ConversationDetail] Sending unencrypted message (no key)...');

        final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_$_currentUserId';
        message = EncryptedMessage(
          id: messageId,
          keyId: '',
          senderId: _currentUserId,
          keySegments: [],
          ciphertext: Uint8List.fromList(utf8.encode(text)),
          isCompressed: false,
          deleteAfterRead: false,
        );
        messagePreview = text;
      }

      debugPrint('[ConversationDetail] Calling conversationService.sendMessage...');
      await _conversationService.sendMessage(
        conversationId: widget.conversation.id,
        message: message,
        messagePreview: messagePreview,
      );

      debugPrint('[ConversationDetail] Message sent successfully!');
      if (mounted) {
        if (_sharedKey == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Message envoyé sans chiffrement'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
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

  void _startKeyExchange() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KeyExchangeScreen(
          peerIds: widget.conversation.peerIds,
          peerNames: widget.conversation.peerNames,
          conversationName: widget.conversation.name,
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
                    return _MessageBubble(
                      message: message,
                      isMine: isMine,
                      senderName: widget.conversation.peerNames[message.senderId],
                      sharedKey: _sharedKey,
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
      builder: (context) => _ConversationInfoSheet(
        conversation: widget.conversation,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final EncryptedMessage message;
  final bool isMine;
  final String? senderName;
  final SharedKey? sharedKey;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
    this.sharedKey,
  });

  String _decryptMessage() {
    // Si pas de segments de clé, le message est en clair
    if (!message.isEncrypted) {
      try {
        return utf8.decode(message.ciphertext);
      } catch (e) {
        return String.fromCharCodes(message.ciphertext);
      }
    }

    // Si on n'a pas la clé, afficher un placeholder
    if (sharedKey == null) {
      return '🔒 [Clé manquante pour déchiffrer]';
    }

    // Déchiffrer avec la clé
    try {
      final cryptoService = CryptoService(localPeerId: '');
      return cryptoService.decrypt(
        encryptedMessage: message,
        sharedKey: sharedKey!,
      );
    } catch (e) {
      debugPrint('[_MessageBubble] Decryption error: $e');
      return '🔒 [Erreur de déchiffrement: $e]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final decryptedText = _decryptMessage();

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMine ? const Radius.circular(4) : null,
            bottomLeft: !isMine ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            Text(
              decryptedText,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (message.isEncrypted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: isMine ? Colors.white70 : Colors.grey[600],
                  ),
                ],
                if (message.isCompressed) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.compress,
                    size: 12,
                    color: isMine ? Colors.white70 : Colors.grey[600],
                  ),
                ],
                if (message.deleteAfterRead) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.timer,
                    size: 12,
                    color: isMine ? Colors.white70 : Colors.grey[600],
                  ),
                ],
              ],
            ),
          ],
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

  const _ConversationInfoSheet({required this.conversation});

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
                final name = conversation.peerNames[peerId] ?? peerId;
                return Chip(
                  avatar: CircleAvatar(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  label: Text(name),
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
          ],
        ),
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
