import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/key_storage_service.dart';
import '../services/message_storage_service.dart';
import '../services/conversation_pseudo_service.dart';
import '../services/unread_message_service.dart';
import '../services/conversation_export_service.dart';
import '../services/format_service.dart';
import '../l10n/app_localizations.dart';

/// Profile screen with settings
class ProfileScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  
  const ProfileScreen({super.key, this.onThemeModeChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final KeyStorageService _keyStorage = KeyStorageService();
  final MessageStorageService _messageStorage = MessageStorageService();
  final ConversationPseudoService _convPseudoService = ConversationPseudoService();
  final UnreadMessageService _unreadService = UnreadMessageService();
  final ConversationExportService _exportService = ConversationExportService();
  
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  int _totalKeyBytes = 0;
  int _totalMessageBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _calculateStorageUsage();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('theme_mode') ?? 'system';
    setState(() {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == themeModeString,
        orElse: () => ThemeMode.system,
      );
    });
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    setState(() {
      _themeMode = mode;
    });
    widget.onThemeModeChanged?.call(mode);
  }

  Future<void> _calculateStorageUsage() async {
    try {
      final conversationIds = await _keyStorage.listConversationsWithKeys();
      int keyBytes = 0;
      int messageBytes = 0;
      
      for (final convId in conversationIds) {
        // Calculate key size
        final key = await _keyStorage.getKey(convId);
        if (key != null) {
          keyBytes += key.lengthInBytes;
        }
        
        // Calculate message size (approximate)
        final messages = await _messageStorage.getConversationMessages(convId);
        for (final msg in messages) {
          if (msg.textContent != null) {
            messageBytes += msg.textContent!.length;
          }
          if (msg.binaryContent != null) {
            messageBytes += msg.binaryContent!.lengthInBytes;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _totalKeyBytes = keyBytes;
          _totalMessageBytes = messageBytes;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _nukeAllData() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700]),
            const SizedBox(width: 8),
            Text(l10n.get('profile_nuke_title')),
          ],
        ),
        content: Text(l10n.get('profile_nuke_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('💣 NUKE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Delete all local storage
        final conversationIds = await _keyStorage.listConversationsWithKeys();
        
        for (final convId in conversationIds) {
          await _keyStorage.deleteKey(convId);
          await _messageStorage.deleteConversationMessages(convId);
          await _convPseudoService.deletePseudos(convId);
          await _unreadService.deleteUnreadCount(convId);
        }
        
        // Delete global data
        await _convPseudoService.deleteAllPseudos();
        await _unreadService.deleteAllUnreadCounts();

        // Supprimer le compte Firebase (reset complet de l'identité)
        try {
          await _authService.deleteAccount();
        } catch (e) {
          debugPrint('Error deleting account: $e');
          // On continue même si erreur pour finir le nettoyage local
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.get('profile_nuke_success')),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Recalculate storage
          await _calculateStorageUsage();
          
          // Return to home
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.get('error_generic')}: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _exportAllConversations() async {
    setState(() => _isLoading = true);

    try {
      final exports = await _exportService.exportAllConversations();

      if (exports.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune conversation à exporter'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Convert to JSON
      final jsonString = _exportService.encodeExportDataList(exports);
      
      // Calculate total size
      final totalSize = exports.fold<int>(
        0,
        (sum, exp) => sum + exp.dataSizeBytes,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        // Show dialog with export options
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exporter toutes les conversations'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${exports.length} conversation(s)'),
                const SizedBox(height: 8),
                Text('Taille totale: ${FormatService.formatBytes(totalSize)}'),
                const SizedBox(height: 16),
                const Text(
                  'Les données contiennent toutes vos clés de chiffrement et messages. Gardez-les en sécurité!',
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

  Future<void> _importConversations() async {
    // Show dialog with text input
    final controller = TextEditingController();
    
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer des conversations'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Collez les données d\'export (JSON) ci-dessous:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"conversationId": "...", ...}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );

    if (shouldImport != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final jsonString = controller.text.trim();
      if (jsonString.isEmpty) {
        throw Exception('Données vides');
      }

      // Try to decode as single export or list
      List<ConversationExportData> exports;
      if (jsonString.startsWith('[')) {
        exports = _exportService.decodeExportDataList(jsonString);
      } else {
        final single = _exportService.decodeExportData(jsonString);
        exports = single != null ? [single] : [];
      }

      if (exports.isEmpty) {
        throw Exception('Format de données invalide');
      }

      // Import all conversations
      final imported = await _exportService.importConversations(exports);

      if (mounted) {
        setState(() => _isLoading = false);
        await _calculateStorageUsage();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$imported/${exports.length} conversation(s) importée(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'import: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userId = _authService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('profile_title')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : userId == null
              ? Center(child: Text(l10n.get('auth_not_connected')))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dark mode selector
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.brightness_6, size: 20, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.get('settings_theme'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SegmentedButton<ThemeMode>(
                                segments: [
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    label: Text(l10n.get('settings_theme_light')),
                                    icon: const Icon(Icons.light_mode, size: 18),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    label: Text(l10n.get('settings_theme_dark')),
                                    icon: const Icon(Icons.dark_mode, size: 18),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    label: Text(l10n.get('settings_theme_system')),
                                    icon: const Icon(Icons.brightness_auto, size: 18),
                                  ),
                                ],
                                selected: {_themeMode},
                                onSelectionChanged: (Set<ThemeMode> newSelection) {
                                  _saveThemeMode(newSelection.first);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Storage usage
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.storage, size: 20, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.get('settings_storage'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _StorageRow(
                                icon: Icons.key,
                                label: l10n.get('settings_storage_keys'),
                                value: FormatService.formatBytes(_totalKeyBytes),
                              ),
                              const SizedBox(height: 8),
                              _StorageRow(
                                icon: Icons.message,
                                label: l10n.get('settings_storage_messages'),
                                value: FormatService.formatBytes(_totalMessageBytes),
                              ),
                              const Divider(height: 20),
                              _StorageRow(
                                icon: Icons.folder,
                                label: l10n.get('settings_storage_total'),
                                value: FormatService.formatBytes(_totalKeyBytes + _totalMessageBytes),
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Import/Export section
                      Text(
                        'Sauvegarde',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _exportAllConversations,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Exporter toutes les conversations'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _importConversations,
                          icon: const Icon(Icons.download),
                          label: const Text('Importer des conversations'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nuke section
                      Text(
                        l10n.get('settings_danger_zone'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.get('settings_nuke_explanation'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _nukeAllData,
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('💣 NUKE'),
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
}

class _StorageRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool bold;

  const _StorageRow({
    required this.icon,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
