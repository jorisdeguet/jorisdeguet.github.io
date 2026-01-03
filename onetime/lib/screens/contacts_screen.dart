import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contacts_service.dart';
import 'contact_picker_screen.dart';

/// Écran de gestion des contacts de l'application.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsService _contactsService = ContactsService();
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _contactsService.loadAppContacts();
      setState(() => _contacts = contacts);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    final query = _searchQuery.toLowerCase();
    return _contacts.where((c) {
      return c.displayName.toLowerCase().contains(query) ||
             (c.email?.toLowerCase().contains(query) ?? false) ||
             (c.phoneNumber?.contains(query) ?? false);
    }).toList();
  }

  Future<void> _addContact() async {
    final result = await Navigator.push<Contact>(
      context,
      MaterialPageRoute(builder: (_) => const ContactPickerScreen()),
    );

    if (result != null) {
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.displayName} ajouté')),
        );
      }
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le contact'),
        content: Text('Supprimer ${contact.displayName} de vos contacts ?'),
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
      await _contactsService.removeContact(contact.id);
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${contact.displayName} supprimé')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
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
                    ? _EmptyState(
                        searchQuery: _searchQuery,
                        onAddContact: _addContact,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        child: ListView.builder(
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            return _ContactTile(
                              contact: contact,
                              onDelete: () => _deleteContact(contact),
                              onTap: () => _showContactDetails(contact),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
    );
  }

  void _showContactDetails(Contact contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ContactDetailsSheet(contact: contact),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String searchQuery;
  final VoidCallback onAddContact;

  const _EmptyState({required this.searchQuery, required this.onAddContact});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty
                ? 'Aucun contact'
                : 'Aucun résultat pour "$searchQuery"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          if (searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ajoutez des contacts depuis votre répertoire',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Ajouter un contact'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ContactTile({
    required this.contact,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: contact.photoUrl != null
            ? NetworkImage(contact.photoUrl!)
            : null,
        child: contact.photoUrl == null
            ? Text(contact.initials)
            : null,
      ),
      title: Row(
        children: [
          Text(contact.displayName),
          if (contact.isAppUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'OneTime',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        contact.email ?? contact.phoneNumber ?? '',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contact.hasSharedKey)
            const Icon(Icons.key, color: Colors.amber, size: 20),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('Créer une clé partagée'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to key exchange
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Envoyer un message'),
              enabled: contact.hasSharedKey,
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to chat
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactDetailsSheet extends StatelessWidget {
  final Contact contact;

  const _ContactDetailsSheet({required this.contact});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: contact.photoUrl != null
                  ? NetworkImage(contact.photoUrl!)
                  : null,
              child: contact.photoUrl == null
                  ? Text(contact.initials, style: const TextStyle(fontSize: 24))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              contact.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            if (contact.email != null)
              _DetailRow(icon: Icons.email, value: contact.email!),
            if (contact.phoneNumber != null)
              _DetailRow(icon: Icons.phone, value: contact.phoneNumber!),
            _DetailRow(
              icon: Icons.calendar_today,
              value: 'Ajouté le ${_formatDate(contact.addedAt)}',
            ),
            if (contact.hasSharedKey)
              _DetailRow(
                icon: Icons.key,
                value: 'Clé partagée active',
                color: Colors.amber,
              ),
            if (contact.isAppUser)
              _DetailRow(
                icon: Icons.verified,
                value: 'Utilisateur OneTime',
                color: Colors.green,
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const _DetailRow({
    required this.icon,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Text(value),
        ],
      ),
    );
  }
}
