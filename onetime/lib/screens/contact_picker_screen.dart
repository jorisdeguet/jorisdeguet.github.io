import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contacts_service.dart';

/// Écran de sélection de contacts depuis le répertoire téléphone.
class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  final ContactsService _contactsService = ContactsService();
  
  List<PhoneContact> _phoneContacts = [];
  List<Contact> _existingContacts = [];
  Set<String> _appUserIds = {};
  
  bool _isLoading = true;
  bool _hasPermission = false;
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    
    try {
      // Demander la permission
      _hasPermission = await _contactsService.requestPermission();
      
      if (!_hasPermission) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Permission d\'accès aux contacts refusée';
        });
        return;
      }

      // Charger les contacts existants de l'app
      _existingContacts = await _contactsService.loadAppContacts();
      
      // Charger les contacts du téléphone
      _phoneContacts = await _contactsService.getPhoneContacts();
      
      // Identifier les utilisateurs de l'app
      final appUsers = await _contactsService.findAppUsersInContacts(_phoneContacts);
      _appUserIds = appUsers.map((c) => c.id).toSet();
      
    } catch (e) {
      _errorMessage = 'Erreur: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<PhoneContact> get _filteredContacts {
    var contacts = _phoneContacts;
    
    // Filtrer ceux déjà ajoutés
    contacts = contacts.where((pc) {
      return !_existingContacts.any((c) => c.id == 'phone_${pc.id}');
    }).toList();
    
    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      contacts = contacts.where((c) {
        return c.displayName.toLowerCase().contains(query) ||
               c.emails.any((e) => e.toLowerCase().contains(query)) ||
               c.phones.any((p) => p.contains(query));
      }).toList();
    }
    
    // Trier: utilisateurs de l'app en premier
    contacts.sort((a, b) {
      final aIsAppUser = _appUserIds.contains(a.id);
      final bIsAppUser = _appUserIds.contains(b.id);
      if (aIsAppUser && !bIsAppUser) return -1;
      if (!aIsAppUser && bIsAppUser) return 1;
      return a.displayName.compareTo(b.displayName);
    });
    
    return contacts;
  }

  Future<void> _importContact(PhoneContact phoneContact) async {
    setState(() => _isLoading = true);
    
    try {
      final contact = await _contactsService.importPhoneContact(phoneContact);
      if (mounted) {
        Navigator.pop(context, contact);
      }
    } on ContactsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un contact'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des contacts...'),
          ],
        ),
      );
    }

    if (!_hasPermission) {
      return _PermissionDenied(onRetry: _initialize);
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info banner pour utilisateurs de l'app
        if (_appUserIds.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.green[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_appUserIds.length} contact(s) utilisent déjà OneTime',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ),
              ],
            ),
          ),

        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher...',
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
          child: _filteredContacts.isEmpty
              ? _EmptyState(searchQuery: _searchQuery)
              : ListView.builder(
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final isAppUser = _appUserIds.contains(contact.id);
                    
                    return _PhoneContactTile(
                      contact: contact,
                      isAppUser: isAppUser,
                      onTap: () => _importContact(contact),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  final VoidCallback onRetry;

  const _PermissionDenied({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Accès aux contacts requis',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Pour ajouter des contacts depuis votre répertoire, '
              'veuillez autoriser l\'accès aux contacts.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String searchQuery;

  const _EmptyState({required this.searchQuery});

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
                ? 'Tous vos contacts ont été ajoutés'
                : 'Aucun résultat pour "$searchQuery"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneContactTile extends StatelessWidget {
  final PhoneContact contact;
  final bool isAppUser;
  final VoidCallback onTap;

  const _PhoneContactTile({
    required this.contact,
    required this.isAppUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: contact.photoUrl != null
            ? NetworkImage(contact.photoUrl!)
            : null,
        backgroundColor: isAppUser ? Colors.green[100] : null,
        child: contact.photoUrl == null
            ? Text(
                _getInitials(contact.displayName),
                style: TextStyle(
                  color: isAppUser ? Colors.green[800] : null,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(child: Text(contact.displayName)),
          if (isAppUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 14, color: Colors.green[800]),
                  const SizedBox(width: 4),
                  Text(
                    'OneTime',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      subtitle: Text(
        contact.emails.isNotEmpty 
            ? contact.emails.first 
            : contact.phones.isNotEmpty 
                ? contact.phones.first 
                : '',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: onTap,
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}
