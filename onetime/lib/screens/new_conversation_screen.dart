import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/conversation_service.dart';
import 'key_exchange_screen.dart';

/// Écran de création d'une nouvelle conversation.
/// 1. Crée une conversation dans Firestore
/// 2. Affiche un QR code avec l'ID de la conversation
/// 3. Les participants scannent pour rejoindre
/// 4. Le créateur valide la liste des participants
/// 5. Passage à l'échange de clé
class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _conversationId;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _currentUserId => _authService.currentUserId ?? '';
  String get _currentPseudo => _authService.currentPseudo ?? '';

  /// Crée la conversation et affiche le QR code
  Future<void> _createConversation() async {
    if (_currentUserId.isEmpty) {
      setState(() => _errorMessage = 'Non connecté');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final conversationService = ConversationService(localUserId: _currentUserId);
      
      // Créer la conversation avec seulement le créateur
      final conversation = await conversationService.createConversation(
        peerIds: [], // Vide pour l'instant, les autres rejoindront
        peerNames: {_currentUserId: _currentPseudo},
        totalKeyBits: 0, // Pas de clé pour l'instant
        name: _nameController.text.isEmpty ? null : _nameController.text,
      );

      setState(() {
        _conversationId = conversation.id;
        _isCreating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isCreating = false;
      });
    }
  }

  /// Stream des participants de la conversation
  Stream<List<Map<String, String>>> _watchParticipants() {
    if (_conversationId == null) return const Stream.empty();

    return _firestore
        .collection('conversations')
        .doc(_conversationId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <Map<String, String>>[];
          
          final data = doc.data()!;
          final peerIds = List<String>.from(data['peerIds'] as List? ?? []);
          final peerNames = Map<String, String>.from(data['peerNames'] as Map? ?? {});
          
          return peerIds.map((id) => {
            'id': id,
            'name': peerNames[id] ?? id.substring(0, 8),
          }).toList();
        });
  }

  /// Finalise la liste des participants et passe à l'échange de clé
  Future<void> _finalizeParticipants() async {
    if (_conversationId == null) return;

    try {
      // Récupérer la conversation actuelle
      final doc = await _firestore.collection('conversations').doc(_conversationId).get();
      if (!doc.exists) {
        setState(() => _errorMessage = 'Conversation non trouvée');
        return;
      }

      final data = doc.data()!;
      final peerIds = List<String>.from(data['peerIds'] as List? ?? []);
      final peerNames = Map<String, String>.from(data['peerNames'] as Map? ?? {});

      if (peerIds.length < 2) {
        setState(() => _errorMessage = 'Il faut au moins 2 participants');
        return;
      }

      // Mettre la conversation en état "exchanging" pour notifier les autres participants
      final conversationService = ConversationService(localUserId: _currentUserId);
      await conversationService.startKeyExchange(_conversationId!);
      debugPrint('[NewConversation] Conversation state set to exchanging');

      if (mounted) {
        // Passer à l'écran d'échange de clé
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => KeyExchangeScreen(
              peerIds: peerIds,
              peerNames: peerNames,
              conversationName: _nameController.text.isEmpty ? null : _nameController.text,
              existingConversationId: _conversationId,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_conversationId == null ? 'Nouvelle conversation' : 'Invitation'),
      ),
      body: _conversationId == null
          ? _buildCreationForm()
          : _buildQrCodeView(),
    );
  }

  Widget _buildCreationForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.group_add, size: 48, color: Colors.deepPurple),
                  const SizedBox(height: 16),
                  Text(
                    'Créer une conversation',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Réunissez les participants physiquement.\n'
                    'Un QR code sera généré pour qu\'ils rejoignent.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Nom de la conversation (optionnel)
          TextField(
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
          const SizedBox(height: 24),

          // Bouton créer
          ElevatedButton.icon(
            onPressed: _isCreating ? null : _createConversation,
            icon: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code),
            label: Text(_isCreating ? 'Création...' : 'Générer le QR code'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrCodeView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // QR Code
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _conversationId!,
                  version: QrVersions.auto,
                  size: 250,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Instructions
          const Text(
            'Les participants scannent ce QR code\npour rejoindre la conversation',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Liste des participants
          StreamBuilder<List<Map<String, String>>>(
            stream: _watchParticipants(),
            builder: (context, snapshot) {
              final participants = snapshot.data ?? [];
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Participants (${participants.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const Divider(),
                      if (participants.isEmpty)
                        const Text(
                          'En attente de participants...',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: participants.map((p) {
                            final isMe = p['id'] == _currentUserId;
                            return Chip(
                              avatar: CircleAvatar(
                                backgroundColor: isMe ? Colors.green : Colors.grey[300],
                                child: Text(
                                  p['name']![0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              label: Text(p['name']!),
                              backgroundColor: isMe ? Colors.green[50] : null,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Bouton pour finaliser
          StreamBuilder<List<Map<String, String>>>(
            stream: _watchParticipants(),
            builder: (context, snapshot) {
              final participants = snapshot.data ?? [];
              final canFinalize = participants.length >= 2;

              return ElevatedButton.icon(
                onPressed: canFinalize ? _finalizeParticipants : null,
                icon: const Icon(Icons.check),
                label: Text(
                  canFinalize
                      ? 'Valider les participants (${participants.length})'
                      : 'En attente de participants...',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: canFinalize ? Colors.green : null,
                ),
              );
            },
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

