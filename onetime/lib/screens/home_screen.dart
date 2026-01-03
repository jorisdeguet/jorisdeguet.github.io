import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/conversation_service.dart';
import '../models/conversation.dart';
import 'profile_screen.dart';
import 'contacts_screen.dart';
import 'new_conversation_screen.dart';
import 'conversation_detail_screen.dart';

/// Écran d'accueil après connexion.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profile = _authService.currentUserProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OneTime Pad'),
        actions: [
          // Avatar / Profil
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: profile?.photoUrl != null
                    ? NetworkImage(profile!.photoUrl!)
                    : null,
                child: profile?.photoUrl == null
                    ? Text(
                        profile?.initials ?? '?',
                        style: const TextStyle(fontSize: 14),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ConversationsListScreen(userId: _authService.currentUser?.uid ?? ''),
          const ContactsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _createNewConversation(context),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  void _createNewConversation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewConversationScreen()),
    );
  }
}

/// Liste des conversations
class ConversationsListScreen extends StatefulWidget {
  final String userId;
  
  const ConversationsListScreen({super.key, required this.userId});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  late final ConversationService _conversationService;
  
  @override
  void initState() {
    super.initState();
    _conversationService = ConversationService(localUserId: widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return const Center(child: Text('Non connecté'));
    }

    return StreamBuilder<List<Conversation>>(
      stream: _conversationService.watchUserConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Erreur: ${snapshot.error}'),
              ],
            ),
          );
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return const _EmptyConversations();
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return _ConversationTile(
              conversation: conversation,
              currentUserId: widget.userId,
              onTap: () => _openConversation(context, conversation),
            );
          },
        );
      },
    );
  }

  void _openConversation(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationDetailScreen(conversation: conversation),
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucune conversation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez une clé partagée avec un contact\npour commencer à discuter',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLastMessageMine = conversation.lastMessageSenderId == currentUserId;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withAlpha(30),
        child: Text(
          conversation.displayName.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Clé restante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getKeyColor(conversation.keyRemainingPercent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              conversation.remainingKeyFormatted,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          if (isLastMessageMine)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.done_all, size: 16, color: Colors.grey),
            ),
          Expanded(
            child: Text(
              conversation.lastMessageDisplay,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Text(
            _formatTime(conversation.lastMessageAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Color _getKeyColor(double percent) {
    if (percent > 50) return Colors.green;
    if (percent > 20) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 7) {
      return '${time.day}/${time.month}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}j';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    }
    return 'maintenant';
  }
}
