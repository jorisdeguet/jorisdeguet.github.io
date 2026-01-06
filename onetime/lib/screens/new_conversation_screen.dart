import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../models/user_profile.dart';
import '../services/contacts_service.dart';
import '../services/conversation_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'conversation_detail_screen.dart';

/// Écran de création d'une nouvelle conversation.
class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final ContactsService _contactsService = ContactsService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  List<PhoneContact> _phoneContacts = [];
  List<UserProfile> _appUsers = []; // Utilisateurs de l'app
  List<UserProfile> _suggestedAppUsers = []; // Suggestions d'utilisateurs de l'app
  final List<_ParticipantEntry> _selectedParticipants = [];
  bool _isLoading = false;
  bool _isSearching = false;
  bool _isCreating = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPhoneContacts();
    _loadAppUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoneContacts() async {
    setState(() => _isLoading = true);
    try {
      final hasPermission = await _contactsService.requestPermission();
      if (hasPermission) {
        _phoneContacts = await _contactsService.getPhoneContacts();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAppUsers() async {
    try {
      final currentPhone = _authService.currentPhoneNumber;
      final users = await _userService.getAllUsers();
      setState(() {
        // Exclure l'utilisateur courant de la liste
        _appUsers = users.where((u) => u.phoneNumber != currentPhone).toList();
      });
    } catch (e) {
      debugPrint('Error loading app users: $e');
    }
  }

  Future<void> _searchAppUsers(String query) async {
    if (query.length < 3) {
      setState(() => _suggestedAppUsers = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final currentPhone = _authService.currentPhoneNumber;
      final users = await _userService.searchUsersByPhone(query);
      setState(() {
        // Exclure l'utilisateur courant et ceux déjà sélectionnés
        _suggestedAppUsers = users.where((u) {
          if (u.phoneNumber == currentPhone) return false;
          if (_selectedParticipants.any((p) => p.phoneNumber == u.phoneNumber)) return false;
          return true;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error searching app users: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  /// Extrait les chiffres d'une chaîne
  String _extractDigits(String input) {
    return input.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Vérifie si la recherche contient au moins 5 chiffres
  bool get _hasEnoughDigits => _extractDigits(_searchQuery).length >= 5;

  /// Vérifie si c'est un numéro de téléphone valide (au moins 6 chiffres)
  bool get _isValidPhoneNumber => _extractDigits(_searchQuery).length >= 6;

  /// Contacts qui correspondent aux chiffres saisis
  List<PhoneContact> get _suggestedContacts {
    if (!_hasEnoughDigits) return [];

    final digits = _extractDigits(_searchQuery);
    return _phoneContacts.where((c) {
      // Ne pas suggérer les contacts déjà ajoutés
      final normalizedPhone = c.phones.isNotEmpty
          ? Contact.normalizePhoneNumber(c.phones.first)
          : '';
      if (_selectedParticipants.any((p) => p.phoneNumber == normalizedPhone)) {
        return false;
      }
      return c.phones.any((phone) {
        final phoneDigits = _extractDigits(phone);
        return phoneDigits.contains(digits);
      });
    }).take(5).toList();
  }

  void _addParticipantFromContact(PhoneContact contact) {
    if (contact.phones.isEmpty) return;

    final normalizedPhone = Contact.normalizePhoneNumber(contact.phones.first);

    // Vérifier si déjà ajouté
    if (_selectedParticipants.any((p) => p.phoneNumber == normalizedPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce contact est déjà ajouté')),
      );
      return;
    }

    setState(() {
      _selectedParticipants.add(_ParticipantEntry(
        phoneNumber: normalizedPhone,
        displayName: contact.displayName,
      ));
      _searchController.clear();
      _searchQuery = '';
      _suggestedAppUsers = [];
    });
  }

  void _addParticipantFromAppUser(UserProfile user) {
    // Vérifier si déjà ajouté
    if (_selectedParticipants.any((p) => p.phoneNumber == user.phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet utilisateur est déjà ajouté')),
      );
      return;
    }

    setState(() {
      _selectedParticipants.add(_ParticipantEntry(
        phoneNumber: user.phoneNumber,
        displayName: user.displayName ?? user.formattedPhoneNumber,
      ));
      _searchController.clear();
      _searchQuery = '';
      _suggestedAppUsers = [];
    });
  }

  void _addParticipantFromNumber(String phoneNumber) {
    final normalizedPhone = Contact.normalizePhoneNumber(phoneNumber);

    // Vérifier si déjà ajouté
    if (_selectedParticipants.any((p) => p.phoneNumber == normalizedPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce numéro est déjà ajouté')),
      );
      return;
    }

    // Chercher si on a un nom pour ce numéro dans les utilisateurs de l'app
    String displayName = normalizedPhone;
    for (final user in _appUsers) {
      if (user.phoneNumber == normalizedPhone) {
        displayName = user.displayName ?? user.formattedPhoneNumber;
        break;
      }
    }

    // Sinon chercher dans les contacts du téléphone
    if (displayName == normalizedPhone) {
      for (final contact in _phoneContacts) {
        for (final phone in contact.phones) {
          if (Contact.normalizePhoneNumber(phone) == normalizedPhone) {
            displayName = contact.displayName;
            break;
          }
        }
      }
    }

    setState(() {
      _selectedParticipants.add(_ParticipantEntry(
        phoneNumber: normalizedPhone,
        displayName: displayName,
      ));
      _searchController.clear();
      _searchQuery = '';
      _suggestedAppUsers = [];
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _selectedParticipants.removeAt(index);
    });
  }

  Future<void> _createConversation() async {
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un participant')),
      );
      return;
    }

    final currentPhoneNumber = _authService.currentPhoneNumber;
    if (currentPhoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non connecté')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Construire la liste des peer IDs
      final peerIds = _selectedParticipants.map((p) => p.phoneNumber).toList();

      // Construire la map des noms
      final peerNames = <String, String>{
        currentPhoneNumber: 'Moi',
      };
      for (final participant in _selectedParticipants) {
        peerNames[participant.phoneNumber] = participant.displayName;
      }

      // Créer la conversation sans clé (totalKeyBits = 0)
      final conversationService = ConversationService(localUserId: currentPhoneNumber);
      final conversation = await conversationService.createConversation(
        peerIds: peerIds,
        peerNames: peerNames,
        totalKeyBits: 0, // Pas de clé pour l'instant
        name: _nameController.text.isEmpty ? null : _nameController.text,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationDetailScreen(conversation: conversation),
          ),
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
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle conversation'),
        actions: [
          TextButton(
            onPressed: _selectedParticipants.isEmpty || _isCreating
                ? null
                : _createConversation,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Créer'),
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

          // Participants sélectionnés
          if (_selectedParticipants.isNotEmpty)
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedParticipants.length,
                itemBuilder: (context, index) {
                  final participant = _selectedParticipants[index];
                  return _SelectedParticipantChip(
                    participant: participant,
                    onRemove: () => _removeParticipant(index),
                  );
                },
              ),
            ),

          // Barre de recherche / saisie de numéro
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Entrer un numéro de téléphone...',
                prefixIcon: const Icon(Icons.phone),
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
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _searchAppUsers(value);
              },
              onSubmitted: (value) {
                if (_isValidPhoneNumber) {
                  _addParticipantFromNumber(value);
                }
              },
            ),
          ),

          // Option d'ajout direct du numéro saisi
          if (_isValidPhoneNumber)
            _AddPhoneNumberOption(
              phoneNumber: _searchQuery,
              onAdd: () => _addParticipantFromNumber(_searchQuery),
            ),

          // Indicateur de recherche
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),

          // Suggestions d'utilisateurs de l'app (prioritaires)
          if (_suggestedAppUsers.isNotEmpty)
            _SuggestedAppUsersList(
              users: _suggestedAppUsers,
              onUserTap: _addParticipantFromAppUser,
            ),

          // Suggestions de contacts du téléphone (secondaires)
          if (_hasEnoughDigits && _suggestedContacts.isNotEmpty && _suggestedAppUsers.isEmpty)
            _SuggestedContactsList(
              contacts: _suggestedContacts,
              onContactTap: _addParticipantFromContact,
            ),

          // Message quand pas de suggestions
          if (_searchQuery.isNotEmpty && !_hasEnoughDigits)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Entrez au moins 5 chiffres pour voir les suggestions',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),

          // État vide initial ou chargement
          if (_searchQuery.isEmpty && _selectedParticipants.isEmpty)
            Expanded(
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_add, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Ajoutez des participants',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Entrez des numéros de téléphone\npour créer une conversation',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Entrée d'un participant
class _ParticipantEntry {
  final String phoneNumber;
  final String displayName;

  _ParticipantEntry({
    required this.phoneNumber,
    required this.displayName,
  });
}

class _SelectedParticipantChip extends StatelessWidget {
  final _ParticipantEntry participant;
  final VoidCallback onRemove;

  const _SelectedParticipantChip({
    required this.participant,
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
                child: Text(_getInitials(participant.displayName)),
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
            width: 70,
            child: Column(
              children: [
                Text(
                  participant.displayName.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatPhoneShort(participant.phoneNumber),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : '?';
  }

  String _formatPhoneShort(String phone) {
    // Afficher les 4 derniers chiffres avec préfixe
    if (phone.length > 6) {
      return '...${phone.substring(phone.length - 4)}';
    }
    return phone;
  }
}

/// Option pour ajouter un numéro de téléphone directement
class _AddPhoneNumberOption extends StatelessWidget {
  final String phoneNumber;
  final VoidCallback onAdd;

  const _AddPhoneNumberOption({
    required this.phoneNumber,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // Afficher le numéro normalisé pour que l'utilisateur voie ce qui sera ajouté
    final normalizedPhone = Contact.normalizePhoneNumber(phoneNumber);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: Colors.blue[50],
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phone, color: Colors.blue[800], size: 20),
          ),
          title: Text(
            'Ajouter ce numéro',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          subtitle: Text(
            normalizedPhone,
            style: TextStyle(color: Colors.blue[600]),
          ),
          trailing: Icon(Icons.add_circle, color: Colors.blue[800]),
          onTap: onAdd,
        ),
      ),
    );
  }
}

/// Liste des contacts suggérés
class _SuggestedContactsList extends StatelessWidget {
  final List<PhoneContact> contacts;
  final Function(PhoneContact) onContactTap;

  const _SuggestedContactsList({
    required this.contacts,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.contacts, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Depuis vos contacts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        ...contacts.map((contact) => ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[300],
            child: Text(_getInitials(contact.displayName)),
          ),
          title: Text(contact.displayName),
          subtitle: Text(
            contact.phones.isNotEmpty ? contact.phones.first : '',
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () => onContactTap(contact),
        )),
      ],
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
        : '?';
  }
}

/// Liste des utilisateurs de l'app suggérés
class _SuggestedAppUsersList extends StatelessWidget {
  final List<UserProfile> users;
  final Function(UserProfile) onUserTap;

  const _SuggestedAppUsersList({
    required this.users,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.verified_user, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Utilisateurs 1Time',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        ...users.map((user) => ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green[100],
            child: Text(
              user.initials,
              style: TextStyle(color: Colors.green[800]),
            ),
          ),
          title: Text(user.name),
          subtitle: Text(
            user.formattedPhoneNumber,
            style: TextStyle(color: Colors.grey[600]),
          ),
          trailing: Icon(Icons.add_circle, color: Colors.green[600]),
          onTap: () => onUserTap(user),
        )),
      ],
    );
  }
}

