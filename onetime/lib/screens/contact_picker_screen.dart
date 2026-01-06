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
  final TextEditingController _searchController = TextEditingController();

  List<PhoneContact> _phoneContacts = [];
  List<Contact> _existingContacts = [];
  Set<String> _appUserIds = {};
  
  bool _isLoading = true;
  bool _hasPermission = false;
  String _searchQuery = '';
  String? _errorMessage;
  bool _isAddingManualContact = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Extrait les chiffres d'une chaîne
  String _extractDigits(String input) {
    return input.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Vérifie si la recherche contient au moins 5 chiffres
  bool get _hasEnoughDigits => _extractDigits(_searchQuery).length >= 5;

  /// Vérifie si la recherche ressemble à un numéro de téléphone (contient principalement des chiffres)
  bool get _isPhoneNumberSearch {
    if (_searchQuery.isEmpty) return false;
    final digits = _extractDigits(_searchQuery);
    // Si plus de 60% sont des chiffres, c'est probablement un numéro de téléphone
    return digits.length >= 5 && digits.length >= _searchQuery.replaceAll(' ', '').length * 0.6;
  }

  /// Contacts qui correspondent aux chiffres saisis (auto-suggestions)
  List<PhoneContact> get _suggestedContacts {
    if (!_hasEnoughDigits) return [];

    final digits = _extractDigits(_searchQuery);
    return _phoneContacts.where((c) {
      return c.phones.any((phone) {
        final phoneDigits = _extractDigits(phone);
        return phoneDigits.contains(digits);
      });
    }).toList();
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
    
    // Filtrer ceux déjà ajoutés (par numéro normalisé)
    contacts = contacts.where((pc) {
      if (pc.phones.isEmpty) return false;
      final normalizedPhone = Contact.normalizePhoneNumber(pc.phones.first);
      return !_existingContacts.any((c) => c.id == normalizedPhone);
    }).toList();
    
    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      contacts = contacts.where((c) {
        return c.displayName.toLowerCase().contains(query) ||
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

  /// Ajoute un contact manuellement par numéro de téléphone
  Future<void> _addManualContact(String phoneNumber) async {
    setState(() => _isAddingManualContact = true);

    try {
      final normalizedPhone = Contact.normalizePhoneNumber(phoneNumber);

      // Vérifier si le contact existe déjà
      final existingContact = await _contactsService.findContactByPhone(normalizedPhone);
      if (existingContact != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ce contact existe déjà')),
          );
        }
        return;
      }

      // Vérifier si c'est un utilisateur de l'app
      final isUser = await _contactsService.isAppUser(normalizedPhone);

      // Créer le contact avec le numéro comme nom par défaut
      final contact = Contact(
        id: normalizedPhone,
        displayName: phoneNumber, // On garde le format saisi comme nom
        phoneNumber: normalizedPhone,
        isAppUser: isUser,
      );

      await _contactsService.addContact(contact);

      if (mounted) {
        Navigator.pop(context, contact);
      }
    } on ContactsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingManualContact = false);
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
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher ou entrer un numéro...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            keyboardType: TextInputType.text,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Option d'ajout manuel par numéro de téléphone
        if (_isPhoneNumberSearch && _extractDigits(_searchQuery).length >= 6)
          _ManualAddOption(
            phoneNumber: _searchQuery,
            isLoading: _isAddingManualContact,
            onAdd: () => _addManualContact(_searchQuery),
          ),

        // Suggestions basées sur les chiffres (si >= 5 chiffres)
        if (_hasEnoughDigits && _suggestedContacts.isNotEmpty)
          _SuggestedContactsSection(
            contacts: _suggestedContacts,
            appUserIds: _appUserIds,
            existingContacts: _existingContacts,
            onContactTap: _importContact,
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
        contact.phones.isNotEmpty ? contact.phones.first : '',
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

/// Widget pour afficher l'option d'ajout manuel par numéro
class _ManualAddOption extends StatelessWidget {
  final String phoneNumber;
  final bool isLoading;
  final VoidCallback onAdd;

  const _ManualAddOption({
    required this.phoneNumber,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phone, color: Colors.blue[800], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajouter ce numéro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                Text(
                  phoneNumber,
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ],
            ),
          ),
          isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: onAdd,
                  icon: Icon(Icons.add_circle, color: Colors.blue[800]),
                  tooltip: 'Ajouter ce numéro',
                ),
        ],
      ),
    );
  }
}

/// Section des contacts suggérés basés sur les chiffres saisis
class _SuggestedContactsSection extends StatelessWidget {
  final List<PhoneContact> contacts;
  final Set<String> appUserIds;
  final List<Contact> existingContacts;
  final Function(PhoneContact) onContactTap;

  const _SuggestedContactsSection({
    required this.contacts,
    required this.appUserIds,
    required this.existingContacts,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    // Filtrer les contacts déjà ajoutés (par numéro normalisé)
    final availableContacts = contacts.where((pc) {
      if (pc.phones.isEmpty) return false;
      final normalizedPhone = Contact.normalizePhoneNumber(pc.phones.first);
      return !existingContacts.any((c) => c.id == normalizedPhone);
    }).take(5).toList(); // Limiter à 5 suggestions

    if (availableContacts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            children: availableContacts.map((contact) {
              final isAppUser = appUserIds.contains(contact.id);
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: isAppUser ? Colors.green[100] : Colors.grey[200],
                  child: Text(
                    _getInitials(contact.displayName),
                    style: TextStyle(
                      fontSize: 12,
                      color: isAppUser ? Colors.green[800] : Colors.grey[700],
                    ),
                  ),
                ),
                title: Text(contact.displayName, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  contact.phones.isNotEmpty ? contact.phones.first : '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: isAppUser
                    ? Icon(Icons.verified, size: 18, color: Colors.green[700])
                    : const Icon(Icons.add_circle_outline, size: 18),
                onTap: () => onContactTap(contact),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
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

