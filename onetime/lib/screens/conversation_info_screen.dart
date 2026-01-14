import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model_remote/conversation.dart';
import '../model_local/shared_key.dart';
import '../services/conversation_service.dart';
import '../services/key_storage_service.dart';
import '../services/conversation_pseudo_service.dart';
import '../services/conversation_export_service.dart';
import '../services/auth_service.dart';
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
  final ConversationExportService _exportService = ConversationExportService();
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
    // Calcul de la clé restante basé sur SharedKey si disponible (plus précis)
    // Utiliser l'ID utilisateur courant pour le calcul
    final remainingKeyFormatted = widget.sharedKey != null && _currentUserId.isNotEmpty && widget.sharedKey!.peerIds.contains(_currentUserId)
        ? FormatService.formatBytes(widget.sharedKey!.countAvailableBits(_currentUserId) ~/ 8)
        : widget.conversation.remainingKeyFormatted;
        
    final totalKeyFormatted = widget.sharedKey != null
        ? FormatService.formatBytes(widget.sharedKey!.lengthInBytes)
        : FormatService.formatBytes(widget.conversation.totalKeyBits ~/ 8);

    final keyUsagePercent = widget.sharedKey != null && _currentUserId.isNotEmpty
        ? (1 - (widget.sharedKey!.countAvailableBits(_currentUserId) / widget.sharedKey!.lengthInBits)) * 100
        : widget.conversation.keyUsagePercent;

    final keyRemainingPercent = 100 - keyUsagePercent;

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
                    backgroundColor: widget.conversation.hasKey
                        ? Theme.of(context).primaryColor.withAlpha(30)
                        : Colors.orange.withAlpha(30),
                    child: Text(
                      widget.conversation.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        color: widget.conversation.hasKey
                            ? Theme.of(context).primaryColor
                            : Colors.orange,
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
                    'Créée le ${_formatDate(widget.conversation.createdAt)}',
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
                      final availableBits = widget.sharedKey!.countAvailableBits(peerId);
                      debugInfo = '\n[Local] Clé: $availableBits bits dispos (sur ${widget.sharedKey!.lengthInBits})';
                    } catch (e) {
                      debugInfo = '\n[Local] Erreur lecture clé';
                    }
                  }
                  
                  // Add Remote Key Info from Firestore
                  if (widget.conversation.keyDebugInfo.containsKey(peerId)) {
                    final info = widget.conversation.keyDebugInfo[peerId] as Map<String, dynamic>;
                    final remoteBits = info['availableBits'];
                    final remoteStart = info['firstAvailableIndex'];
                    final remoteEnd = info['lastAvailableIndex'];
                    final lastUpdate = info['updatedAt'] != null 
                        ? _formatTime(DateTime.parse(info['updatedAt'])) 
                        : '?';
                        
                    debugInfo += '\n[Remote $lastUpdate] Clé: $remoteBits bits dispos ($remoteStart-$remoteEnd)';
                  }
                  
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (pseudo ?? peerId).substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(pseudo ?? peerId),
                    subtitle: Text(
                      (pseudo != null ? '$peerId' : '') + debugInfo,
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (widget.conversation.hasKey) ...[
                      _InfoRow(
                        icon: Icons.vpn_key,
                        label: 'Taille totale de la clé',
                        value: totalKeyFormatted,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.data_usage,
                        label: 'Clé restante',
                        value: remainingKeyFormatted,
                        valueColor: _getKeyColor(keyRemainingPercent),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Utilisation', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text('${keyUsagePercent.toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: keyUsagePercent / 100,
                            backgroundColor: Colors.grey[200],
                            color: _getKeyColor(keyRemainingPercent),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[800], size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aucune clé de chiffrement',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                  ),
                                ),
                                const Text('Les messages ne sont pas sécurisés.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),

            // Actions
            if (widget.conversation.hasKey && widget.conversation.isKeyLow || !widget.conversation.hasKey)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close info screen
                    widget.onExtendKey?.call();
                  },
                  icon: Icon(widget.conversation.hasKey ? Icons.add : Icons.key),
                  label: Text(
                    widget.conversation.hasKey
                        ? 'Étendre la clé (${keyRemainingPercent.toStringAsFixed(0)}% restant)'
                        : 'Créer une clé de chiffrement',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            if (widget.conversation.hasKey && !widget.conversation.isKeyLow)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close info screen
                    widget.onExtendKey?.call();
                  },
                  icon: const Icon(Icons.add_link),
                  label: const Text('Allonger la clé de chiffrement'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
              ),

            if (widget.conversation.hasKey)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showTruncateConfirmation(context),
                    icon: const Icon(Icons.cut),
                    label: const Text('Nettoyer les clés utilisées'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Export conversation
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _exportConversation,
                icon: const Icon(Icons.upload_file),
                label: const Text('Exporter vers un autre appareil'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
              
            const SizedBox(height: 16),
            
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

  void _showTruncateConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer les clés ?'),
        content: const Text(
          'Cette action va supprimer définitivement les parties de la clé qui ont déjà été utilisées. Cela empêche de relire les anciens messages s\'ils sont perdus localement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onTruncateKey?.call();
            },
            child: const Text('Nettoyer'),
          ),
        ],
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

  Future<void> _exportConversation() async {
    setState(() => _isLoading = true);

    try {
      // Export the conversation data
      final exportData = await _exportService.exportConversation(widget.conversation.id);

      if (exportData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'exporter: aucune donnée trouvée'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Convert to JSON string
      final jsonString = _exportService.encodeExportData(exportData);
      
      // Calculate data size for display
      final dataSize = FormatService.formatBytes(exportData.dataSizeBytes);

      if (mounted) {
        setState(() => _isLoading = false);

        // Show dialog with export options
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exporter la conversation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taille des données: $dataSize'),
                const SizedBox(height: 8),
                Text('${exportData.localMessages.length} message(s) local'),
                const SizedBox(height: 16),
                const Text(
                  'Les données d\'export contiennent la clé de chiffrement et tous les messages locaux. Gardez-les en sécurité!',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  // Copy to clipboard
                  Clipboard.setData(ClipboardData(text: jsonString));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copié dans le presse-papiers')),
                  );
                },
                child: const Text('Copier'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'export: $e')),
        );
      }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
