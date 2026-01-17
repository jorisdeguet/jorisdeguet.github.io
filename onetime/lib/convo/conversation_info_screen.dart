import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onetime/key_exchange/key_storage.dart';
import 'conversation.dart';
import '../key_exchange/shared_key.dart';
import '../services/conversation_service.dart';
import '../services/conversation_pseudo_service.dart';
import '../signin/auth_service.dart';
import '../services/format_service.dart';

class ConversationInfoScreen extends StatefulWidget {
  final Conversation conversation;
  final SharedKey? sharedKey;
  final VoidCallback? onDelete;
  final VoidCallback? onExtendKey;
  final VoidCallback? onTruncateKey;

  const ConversationInfoScreen({
    super.key,
    required this.conversation,
    this.sharedKey,
    this.onDelete,
    this.onExtendKey,
    this.onTruncateKey,
  });

  @override
  State<ConversationInfoScreen> createState() => _ConversationInfoScreenState();
}

class _ConversationInfoScreenState extends State<ConversationInfoScreen> {
  final ConversationPseudoService _convPseudoService = ConversationPseudoService();
  final KeyStorageService _keyStorageService = KeyStorageService();
  final AuthService _authService = AuthService();
  late final ConversationService _conversationService;
  
  Map<String, String> _displayNames = {};
  bool _isLoading = false;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.currentUserId ?? '';
    _conversationService = ConversationService(localUserId: _currentUserId);
    _loadDisplayNames();
  }

  Future<void> _loadDisplayNames() async {
    final names = await _convPseudoService.getPseudos(widget.conversation.id);
    if (mounted) {
      setState(() {
        _displayNames = names;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Infos conversation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infos conversation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec nom de conversation
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.orange.withAlpha(30),
                    child: Text(
                      widget.conversation.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.conversation.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Créée le ${FormatService.formatDate(widget.conversation.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Participants
            Text(
              'Participants (${widget.conversation.peerIds.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.conversation.peerIds.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final peerId = widget.conversation.peerIds[index];
                  final pseudo = _displayNames[peerId];
                  
                  // Key Debug Info
                  String debugInfo = '';
                  if (widget.sharedKey != null && peerId.isNotEmpty) {
                    try {
                      // Check if peer exists in key first to avoid ArgumentError
                      final availableBytes = widget.sharedKey!.countAvailableBytes(peerId);
                      debugInfo = '\n[Local] Clé: ${FormatService.formatBytes(availableBytes)} dispos (sur ${FormatService.formatBytes(widget.sharedKey!.lengthInBytes)})';
                    } catch (e) {
                      debugInfo = '\n[Local] Erreur lecture clé';
                    }
                  }
                  
                  // Add Remote Key Info from Firestore
                  if (widget.conversation.keyDebugInfo.containsKey(peerId)) {
                    final info = widget.conversation.keyDebugInfo[peerId] as Map<String, dynamic>;
                    final remoteBytes = info['availableBytes'];
                    final remoteStart = info['firstAvailableByte'];
                    final remoteEnd = info['lastAvailableByte'];
                    final lastUpdate = info['updatedAt'] != null
                        ? FormatService.formatTime(DateTime.parse(info['updatedAt']))
                        : '?';
                        
                    debugInfo += '\n[Remote $lastUpdate] Clé: ${FormatService.formatBytes(remoteBytes ?? 0)} dispos ($remoteStart-$remoteEnd)';
                  }
                  
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (pseudo ?? peerId).substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(pseudo ?? peerId),
                    subtitle: Text(
                      (pseudo != null ? peerId : '') + debugInfo,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Informations sur la clé
            Text(
              'Chiffrement et Sécurité',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            //
            // // Actions
            // if (widget.conversation.hasKey && widget.conversation.isKeyLow || !widget.conversation.hasKey)
            //   SizedBox(
            //     width: double.infinity,
            //     child: ElevatedButton.icon(
            //       onPressed: () {
            //         Navigator.pop(context); // Close info screen
            //         widget.onExtendKey?.call();
            //       },
            //       icon: Icon(widget.conversation.hasKey ? Icons.add : Icons.key),
            //       label: Text(
            //         widget.conversation.hasKey
            //             ? 'Étendre la clé (${keyRemainingPercent.toStringAsFixed(0)}% restant)'
            //             : 'Créer une clé de chiffrement',
            //       ),
            //       style: ElevatedButton.styleFrom(
            //         padding: const EdgeInsets.all(16),
            //         backgroundColor: Colors.green,
            //         foregroundColor: Colors.white,
            //       ),
            //     ),
            //   ),
            //
            // if (widget.conversation.hasKey && !widget.conversation.isKeyLow)
            //   SizedBox(
            //     width: double.infinity,
            //     child: OutlinedButton.icon(
            //       onPressed: () {
            //         Navigator.pop(context); // Close info screen
            //         widget.onExtendKey?.call();
            //       },
            //       icon: const Icon(Icons.add_link),
            //       label: const Text('Allonger la clé de chiffrement'),
            //       style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
            //     ),
            //   ),
            //

            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Supprimer la conversation'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
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
              Navigator.pop(context); // Close dialog
              _deleteConversation();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversation() async {
    setState(() => _isLoading = true);
    
    try {
      await _conversationService.deleteConversation(widget.conversation.id);

      // Supprimer la clé locale si elle existe
      await _keyStorageService.deleteKey(widget.conversation.id);

      if (mounted) {
        Navigator.pop(context); // Close info screen
        widget.onDelete?.call(); // Callback to close detail screen
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation supprimée')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}
