import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/tache.dart';
import '../models/groupe.dart';
import '../widgets/app_drawer.dart';
import 'taches/create_tache_screen.dart';
import 'taches/view_tache_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUserId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toutes les tâches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToCreate(context),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<List<Tache>>(
        stream: firestoreService.getAllTaches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final mesTaches = snapshot.data ?? [];

          if (mesTaches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 24),
                  const Text(
                    'Aucune tâche',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aucune tâche n\'a été créée pour le moment',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToCreate(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer une tâche'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mesTaches.length,
            itemBuilder: (context, index) {
              return _TacheCard(
                tache: mesTaches[index],
                onTap: () => _navigateToTache(context, mesTaches[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreate(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTacheScreen()),
    );
  }

  void _navigateToTache(BuildContext context, Tache tache) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewTacheScreen(tacheId: tache.id),
      ),
    );
  }
}

class _TacheCard extends StatelessWidget {
  final Tache tache;
  final VoidCallback onTap;

  const _TacheCard({
    required this.tache,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tache.nom,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tache.type == SessionType.automne
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tache.type == SessionType.automne ? 'Automne' : 'Hiver',
                      style: TextStyle(
                        color: tache.type == SessionType.automne
                            ? Colors.orange.shade900
                            : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${tache.year}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.group, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${tache.groupeIds.length} groupes',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.people, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${tache.enseignantEmails.length} enseignant(s)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Groupe>>(
                stream: firestoreService.getGroupesByTache(tache.id),
                builder: (context, groupeSnapshot) {
                  if (!groupeSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  
                  final ci = tache.calculateCITotale(groupeSnapshot.data!);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('CI totale:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          ci.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
