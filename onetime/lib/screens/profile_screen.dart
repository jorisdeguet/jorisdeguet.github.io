import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/key_storage_service.dart';
import '../services/message_storage_service.dart';
import '../services/conversation_pseudo_service.dart';
import '../services/unread_message_service.dart';
import '../services/pseudo_storage_service.dart';
import 'login_screen.dart';

/// Écran de profil utilisateur avec option de déconnexion.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final KeyStorageService _keyStorage = KeyStorageService();
  final MessageStorageService _messageStorage = MessageStorageService();
  final ConversationPseudoService _convPseudoService = ConversationPseudoService();
  final UnreadMessageService _unreadService = UnreadMessageService();
  bool _isLoading = false;

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text(
          'Cette action est irréversible. Toutes vos données seront supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _authService.deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _nukeAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('NUKE - Tout effacer'),
          ],
        ),
        content: const Text(
          '⚠️ ATTENTION ⚠️\n\n'
          'Ceci va EFFACER TOUTES vos données locales:\n'
          '• Toutes les clés de chiffrement\n'
          '• Tous les messages déchiffrés\n'
          '• Tous les pseudos\n'
          '• Tout l\'historique de conversation\n\n'
          'Cette action est IRRÉVERSIBLE et immédiate.\n\n'
          'Êtes-vous ABSOLUMENT SÛR ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('💣 NUKE TOUT'),
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
        
        // Delete global pseudos
        await _convPseudoService.deleteAllPseudos();
        await _unreadService.deleteAllUnreadCounts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('💥 Toutes les données locales ont été effacées'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Return to home
          Navigator.pop(context);
        }
      } catch (e) {
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
  }

  void _copyId() {
    final id = _authService.currentUserId ?? '';
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID copié dans le presse-papier')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUserId;
    final shortId = userId != null && userId.length > 8 
        ? userId.substring(0, 8) 
        : userId ?? '';
    final initials = userId != null && userId.length >= 2
        ? userId.substring(0, 2).toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : userId == null
              ? const Center(child: Text('Non connecté'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Avatar avec initiales
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ID utilisateur
                      Text(
                        shortId,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bouton copier
                      GestureDetector(
                        onTap: _copyId,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fingerprint,
                                size: 16,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Copier l\'ID',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy,
                                size: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Informations
                      _InfoCard(
                        title: 'Informations du compte',
                        children: [
                          _InfoRow(
                            icon: Icons.fingerprint,
                            label: 'ID utilisateur',
                            value: shortId,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Explication sécurité
                      _InfoCard(
                        title: 'Sécurité',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.shield, size: 20, color: Colors.green[600]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Votre identifiant unique est généré automatiquement. '
                                    'Les clés de chiffrement sont échangées en personne via QR code. '
                                    'Tous les messages sont chiffrés avec le One-Time Pad.',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Se déconnecter'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _nukeAllData,
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('💣 NUKE - Effacer toutes les données locales'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _deleteAccount,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Supprimer le compte'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
