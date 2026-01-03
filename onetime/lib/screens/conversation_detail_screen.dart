import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/encrypted_message.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';

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
  late final ConversationService _conversationService;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userId = _authService.currentUser?.uid ?? '';
    _conversationService = ConversationService(localUserId: userId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentUserId => _authService.currentUser?.uid ?? '';

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    _messageController.clear();

    try {
      // TODO: Implémenter le chiffrement avec CryptoService
      // Pour l'instant, on simule
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chiffrement et envoi...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.displayName,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Clé: ${widget.conversation.remainingKeyFormatted}',
              style: TextStyle(
                fontSize: 12,
                color: _getKeyColor(widget.conversation.keyRemainingPercent),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showConversationInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre d'avertissement si peu de clé restante
          if (widget.conversation.keyRemainingPercent < 20)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clé bientôt épuisée. Pensez à générer une nouvelle clé.',
                      style: TextStyle(color: Colors.orange[800], fontSize: 12),
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

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
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
            // TODO: Déchiffrer et afficher le message
            Text(
              '[Message chiffré - ${message.ciphertext.length} bytes]',
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
      child: Padding(
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

            _InfoRow(
              icon: Icons.people,
              label: 'Participants',
              value: '${conversation.peerIds.length}',
            ),
            _InfoRow(
              icon: Icons.message,
              label: 'Messages',
              value: '${conversation.messageCount}',
            ),
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
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Créée le',
              value: _formatDate(conversation.createdAt),
            ),

            const SizedBox(height: 24),

            // Barre de progression de la clé
            Text(
              'Utilisation de la clé',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: conversation.keyUsagePercent / 100,
              backgroundColor: Colors.grey[200],
              color: _getKeyColor(conversation.keyRemainingPercent),
            ),
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
