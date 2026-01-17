import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:onetime/convo/encrypted_message.dart';
import 'package:onetime/convo/message_storage.dart';
import 'package:onetime/services/format_service.dart';

import '../signin/auth_service.dart';
import '../services/conversation_service.dart';
import '../services/conversation_pseudo_service.dart';
import '../services/unread_message_service.dart';
import '../signin/pseudo_storage.dart';
import '../convo/conversation.dart';
import '../key_exchange/key_exchange_sync_service.dart';
import '../convo/message_service.dart';
import 'profile_screen.dart';
import '../convo_new/new_conversation_screen.dart';
import '../convo/conversation_detail_screen.dart';
import '../convo_new/join_conversation_screen.dart';

/// Écran d'accueil après connexion.
class HomeScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  
  const HomeScreen({super.key, this.onThemeModeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final PseudoStorageService _pseudoService = PseudoStorageService();
  final GlobalKey<_ConversationsListScreenState> _conversationsKey = GlobalKey();
  String? _myPseudo;

  @override
  void initState() {
    super.initState();
    _loadMyPseudo();
    _cleanupOldSessions();
  }

  Future<void> _cleanupOldSessions() async {
    final userId = _authService.currentUserId;
    if (userId != null) {
      // Nettoyage des sessions d'échange de clés expirées
      await KeyExchangeSyncService().cleanupOldSessions(userId);
    }
  }

  Future<void> _loadMyPseudo() async {
    final pseudo = await _pseudoService.getMyPseudo();
    if (mounted) {
      setState(() {
        _myPseudo = pseudo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _myPseudo ?? 'Chargement...';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              '1 time',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_myPseudo != null) ...[
              Text(
                ' : ',
                style: TextStyle(color: Colors.grey[600]),
              ),
              Flexible(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Bouton pour rejoindre une conversation (scanner QR)
          IconButton(
            onPressed: () => _joinConversation(context),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Rejoindre une conversation',
          ),
          // Bouton de rafraîchissement
          IconButton(
            onPressed: () => _conversationsKey.currentState?.refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
          // Icône de profil
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(onThemeModeChanged: widget.onThemeModeChanged)),
            ),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profil',
          ),
        ],
      ),
      body: ConversationsListScreen(key: _conversationsKey, userId: _authService.currentUserId ?? ''),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewConversation(context),
        tooltip: 'Créer une conversation',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _createNewConversation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewConversationScreen()),
    );
  }

  void _joinConversation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinConversationScreen()),
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
  late ConversationService _conversationService;
  Stream<List<Conversation>>? _conversationsStream;


  @override
  void initState() {
    super.initState();
    _initService();

    // Start background service only when we have a valid userId
    if (widget.userId.isNotEmpty) {
      try {
        final getIt = GetIt.instance;
        if (!getIt.isRegistered<MessageService>()) {
          final svc = MessageService(localUserId: widget.userId);
          getIt.registerSingleton<MessageService>(svc);
          svc.startWatchingUserConversations();
        }

        final svc = GetIt.instance.get<MessageService>();

        // One-shot: fetch current conversations and ask the background service
        // to rescan them so any pending messages are processed immediately.
        _conversationService = ConversationService(localUserId: widget.userId);
        _conversationService.watchUserConversations().first.then((convs) {
          for (final c in convs) {
            svc.startForConversation(c.id);
          }
        }).catchError((_) {});
      } catch (e) {
        // Do not crash UI if background init fails
      }
    }
  }

  // @override
  // void didUpdateWidget(covariant ConversationsListScreen oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //
  //   // If userId changed, recreate or stop the background service accordingly
  //   if (oldWidget.userId != widget.userId) {
  //     // If we registered a singleton, stop it on disposal of widget tree
  //     try {
  //       final getIt = GetIt.instance;
  //       if (getIt.isRegistered<BackgroundMessageService>()) {
  //         final svc = getIt.get<BackgroundMessageService>();
  //         svc.stopWatchingUserConversations();
  //         svc.stopAll();
  //         getIt.unregister<BackgroundMessageService>();
  //       }
  //     } catch (_) {}
  //
  //     if (widget.userId.isNotEmpty) {
  //       try {
  //         final getIt = GetIt.instance;
  //         if (!getIt.isRegistered<BackgroundMessageService>()) {
  //           final svc = BackgroundMessageService(localUserId: widget.userId);
  //           getIt.registerSingleton<BackgroundMessageService>(svc);
  //           svc.startWatchingUserConversations();
  //         }
  //
  //         final svc = GetIt.instance.get<BackgroundMessageService>();
  //
  //         // One-shot: fetch current conversations and ask the background service
  //         // to rescan them so any pending messages are processed immediately.
  //         _conversationService = ConversationService(localUserId: widget.userId);
  //         _conversationService.watchUserConversations().first.then((convs) {
  //           for (final c in convs) {
  //             svc.startForConversation(c.id);
  //           }
  //         }).catchError((_) {});
  //       } catch (e) {
  //         // Do not crash UI if background init fails
  //       }
  //     }
  //   }
  // }

  // @override
  // void dispose() {
  //   // If we registered a singleton, stop it on disposal of widget tree
  //   try {
  //     final getIt = GetIt.instance;
  //     if (getIt.isRegistered<BackgroundMessageService>()) {
  //       final svc = getIt.get<BackgroundMessageService>();
  //       svc.stopWatchingUserConversations();
  //       svc.stopAll();
  //       getIt.unregister<BackgroundMessageService>();
  //     }
  //   } catch (_) {}
  //   super.dispose();
  // }

  void _initService() {
    _conversationService = ConversationService(localUserId: widget.userId);
    _conversationsStream = _conversationService.watchUserConversations().asyncMap((conversations) async {
      final messageStorage = MessageStorageService();
      
      final withTimes = await Future.wait(conversations.map((c) async {
        final lastTime = await messageStorage.getLastMessageTimestamp(c.id);
        return MapEntry(c, lastTime ?? c.createdAt);
      }));
      
      // Sort descending
      withTimes.sort((a, b) => b.value.compareTo(a.value));
      
      return withTimes.map((e) => e.key).toList();
    });
  }

  /// Méthode publique pour rafraîchir les conversations
  void refresh() {
    setState(() {
      _initService();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return const Center(child: Text('Non connecté'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        refresh();
      },
      child: StreamBuilder<List<Conversation>>(
        stream: _conversationsStream,
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: refresh,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 200),
                _EmptyConversations(),
              ],
            );
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
      ),
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

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  final ConversationPseudoService _convPseudoService = ConversationPseudoService();
  final MessageStorageService _messageStorage = MessageStorageService();
  final UnreadMessageService _unreadService = UnreadMessageService();
  String _displayName = '';
  String _lastMessageText = '';
  DateTime? _lastMessageTime;
  int _unreadCount = 0;
  StreamSubscription<String>? _pseudoSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Listen for pseudo updates
    _pseudoSubscription = _convPseudoService.pseudoUpdates.listen((conversationId) {
      if (conversationId == widget.conversation.id) {
        _loadDisplayName();
      }
    });
  }

  @override
  void didUpdateWidget(_ConversationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id ||
        oldWidget.conversation.state != widget.conversation.state) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _pseudoSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadDisplayName(),
      _loadLastMessage(),
      _loadUnreadCount(),
    ]);
  }

  Future<void> _loadDisplayName() async {
    final pseudos = await _convPseudoService.getPseudos(widget.conversation.id);
    final displayNames = <String>[];
    
    for (final peerId in widget.conversation.peerIds) {
      if (peerId != widget.currentUserId) {
        displayNames.add(pseudos[peerId] ?? peerId.substring(0, 8));
      }
    }
    
    if (mounted) {
      setState(() {
        _displayName = displayNames.isEmpty 
            ? widget.conversation.displayName 
            : displayNames.join(', ');
      });
    }
  }

  Future<void> _loadLastMessage() async {
    final messages = await _messageStorage.getConversationMessages(widget.conversation.id);
    
    if (messages.isNotEmpty) {
      final lastMsg = messages.last;
      String text;
      
      if (lastMsg.contentType == MessageContentType.text) {
        text = lastMsg.textContent ?? '';
        
        // Check if it's a pseudo exchange message - don't show it
        if (PseudoExchangeMessage.isPseudoExchange(text)) {
          // Don't show pseudo messages as last message
          if (mounted) {
            setState(() {
              _lastMessageText = '';
              _lastMessageTime = null;
            });
          }
          return;
        }
        
        // Limiter à 50 caractères
        if (text.length > 50) {
          text = '${text.substring(0, 47)}...';
        }
      } else if (lastMsg.contentType == MessageContentType.image) {
        text = '📷 Image';
      } else {
        text = '📎 ${lastMsg.fileName ?? "Fichier"}';
      }
      
      if (mounted) {
        setState(() {
          _lastMessageText = text;
          _lastMessageTime = lastMsg.createdAt;
        });
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    final count = await _unreadService.getUnreadCountExcludingUser(
      widget.conversation.id,
      widget.currentUserId,
    );
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName.isEmpty ? widget.conversation.displayName : _displayName;
    
    return ListTile(
      leading: null, // Avatar removed
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              _lastMessageText.isEmpty ? 'Aucun message' : _lastMessageText,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: _unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _unreadCount.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            FormatService.formatTimeRemaining(_lastMessageTime ?? widget.conversation.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      onTap: widget.onTap,
    );
  }
}
