import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contacts_service.dart';
import '../services/auth_service.dart';
import 'key_exchange_screen.dart';

/// Écran de création d'une nouvelle conversation.
class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final ContactsService _contactsService = ContactsService();
  final AuthService _authService = AuthService();
  
  List<Contact> _contacts = [];
  final Set<String> _selectedContactIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _contactsService.loadAppContacts();
      // Filtrer pour ne garder que les utilisateurs de l'app
      setState(() {
        _contacts = contacts.where((c) => c.isAppUser).toList();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final query = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
             (c.email?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _toggleContact(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
  }

  Future<void> _createConversation() async {
    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un contact')),
      );
      return;
    }

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    // Récupérer les contacts sélectionnés
    final selectedContacts = _contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();

    // Construire la liste des peer IDs (Firebase UIDs)
    final peerIds = selectedContacts
        .where((c) => c.firebaseUid != null)
        .map((c) => c.firebaseUid!)
        .toList();

    // Construire la map des noms
    final peerNames = <String, String>{
      currentUser.uid: currentUser.displayName ?? 'Moi',
    };
    for (final contact in selectedContacts) {
      if (contact.firebaseUid != null) {
        peerNames[contact.firebaseUid!] = contact.displayName;
      }
    }

    // Naviguer vers l'écran d'échange de clé
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => KeyExchangeScreen(
            peerIds: peerIds,
            peerNames: peerNames,
            conversationName: _nameController.text.isEmpty 
                ? null 
                : _nameController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle conversation'),
        actions: [
          TextButton(
            onPressed: _selectedContactIds.isEmpty ? null : _createConversation,
            child: const Text('Suivant'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Nom de la conversation (optionnel)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nom de la conversation (optionnel)',
                hintText: 'Ex: Projet secret',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Contacts sélectionnés
          if (_selectedContactIds.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedContactIds.length,
                itemBuilder: (context, index) {
                  final contactId = _selectedContactIds.elementAt(index);
                  final contact = _contacts.firstWhere((c) => c.id == contactId);
                  return _SelectedContactChip(
                    contact: contact,
                    onRemove: () => _toggleContact(contactId),
                  );
                },
              ),
            ),

          // Recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un contact...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Liste des contacts
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? _EmptyState(hasContacts: _contacts.isNotEmpty)
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          final isSelected = _selectedContactIds.contains(contact.id);
                          return _ContactSelectTile(
                            contact: contact,
                            isSelected: isSelected,
                            onTap: () => _toggleContact(contact.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SelectedContactChip extends StatelessWidget {
  final Contact contact;
  final VoidCallback onRemove;

  const _SelectedContactChip({
    required this.contact,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(contact.initials),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              contact.displayName.split(' ').first,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSelectTile extends StatelessWidget {
  final Contact contact;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContactSelectTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected 
            ? Theme.of(context).primaryColor 
            : null,
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white)
            : Text(contact.initials),
      ),
      title: Text(contact.displayName),
      subtitle: Text(contact.email ?? ''),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasContacts;

  const _EmptyState({required this.hasContacts});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasContacts ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            hasContacts 
                ? 'Aucun résultat'
                : 'Aucun contact OneTime',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (!hasContacts) ...[
            const SizedBox(height: 8),
            Text(
              'Ajoutez des contacts qui utilisent\nOneTime pour créer une conversation',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }
}
