import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/repartition_service.dart';
import '../services/groupe_service.dart';
import '../services/ci_calculator_service.dart';
import '../models/tache.dart';
import '../models/groupe.dart';
import '../models/enseignant.dart';
import '../models/repartition.dart';
import '../widgets/app_drawer.dart';
import 'taches/create_tache_screen.dart';
import 'taches/view_tache_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

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
              // Répartitions disponibles
              _RepartitionsPreview(tacheId: tache.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepartitionsPreview extends StatelessWidget {
  final String tacheId;

  const _RepartitionsPreview({required this.tacheId});

  @override
  Widget build(BuildContext context) {
    final repartitionService = RepartitionService();
    final firestoreService = Provider.of<FirestoreService>(context);
    final groupeService = GroupeService();

    return FutureBuilder<Tache?>(
      future: firestoreService.getTache(tacheId),
      builder: (context, tacheSnapshot) {
        if (!tacheSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final tache = tacheSnapshot.data!;

        return FutureBuilder<List<Groupe>>(
          future: groupeService.getGroupesForTacheFuture(tacheId),
          builder: (context, groupesSnapshot) {
            if (!groupesSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final groupes = groupesSnapshot.data!;

            return StreamBuilder<List<Repartition>>(
              stream: repartitionService.getRepartitionsForTache(tacheId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Aucune répartition disponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final repartitions = snapshot.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: repartitions.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              right: 12,
                              left: index == 0 ? 0 : 0,
                            ),
                            child: _RepartitionDetailCard(
                              repartition: repartitions[index],
                              groupes: groupes,
                              tache: tache,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RepartitionDetailCard extends StatelessWidget {
  final Repartition repartition;
  final List<Groupe> groupes;
  final Tache tache;

  const _RepartitionDetailCard({
    required this.repartition,
    required this.groupes,
    required this.tache,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    return FutureBuilder<List<Enseignant>>(
      future: firestoreService.getEnseignantsByIds(tache.enseignantIds),
      builder: (context, enseignantsSnapshot) {
        if (!enseignantsSnapshot.hasData) {
          return const SizedBox(
            width: 200,
            child: Card(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final enseignants = enseignantsSnapshot.data!;
        final ciMoyenne = _calculateAverageCI(repartition, groupes, enseignants);
        final moyennePreparation = _calculateAveragePreparation(repartition, groupes);
        final nbGroupesNonAlloues = repartition.groupesNonAlloues.length;

        return Card(
          elevation: 4,
          margin: EdgeInsets.zero,
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: repartition.estAutomatique
                  ? Colors.purple.shade50
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: repartition.estAutomatique
                    ? Colors.purple.shade200
                    : theme.dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre avec icône
                Row(
                  children: [
                    Icon(
                      repartition.estAutomatique
                          ? Icons.auto_awesome
                          : repartition.estValide
                              ? Icons.check_circle
                              : Icons.warning,
                      size: 18,
                      color: repartition.estAutomatique
                          ? Colors.purple
                          : repartition.estValide
                              ? Colors.green
                              : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        repartition.nom.length > 18
                            ? '${repartition.nom.substring(0, 18)}...'
                            : repartition.nom,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // CI Moyenne
                Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 14,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CI moyenne',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${ciMoyenne.toStringAsFixed(1)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Moyenne de préparation
                Row(
                  children: [
                    Icon(
                      Icons.school,
                      size: 14,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cours/prof (moy)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${moyennePreparation.toStringAsFixed(1)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Groupes non alloués
                Row(
                  children: [
                    Icon(
                      Icons.group_off,
                      size: 14,
                      color: nbGroupesNonAlloues > 0
                          ? Colors.orange
                          : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Non alloués',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '$nbGroupesNonAlloues',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: nbGroupesNonAlloues > 0
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateAverageCI(
    Repartition repartition,
    List<Groupe> groupes,
    List<Enseignant> enseignants,
  ) {
    if (enseignants.isEmpty) return 0.0;

    final ciCalculator = CICalculatorService();
    final groupeMap = {for (var g in groupes) g.id: g};

    double totalCI = 0.0;

    for (var enseignant in enseignants) {
      final groupeIds = repartition.allocations[enseignant.id] ?? [];
      final enseignantGroupes = groupeIds
          .map((id) => groupeMap[id])
          .whereType<Groupe>()
          .toList();

      totalCI += ciCalculator.calculateCI(enseignantGroupes);
    }

    return totalCI / enseignants.length;
  }

  double _calculateAveragePreparation(
    Repartition repartition,
    List<Groupe> groupes,
  ) {
    if (repartition.allocations.isEmpty) return 0.0;

    final groupeMap = {for (var g in groupes) g.id: g};
    int totalCourses = 0;
    int countProfs = 0;

    for (var entry in repartition.allocations.entries) {
      final groupeIds = entry.value;
      if (groupeIds.isNotEmpty) {
        final coursDistincts = groupeIds
            .map((id) => groupeMap[id]?.cours)
            .whereType<String>()
            .toSet();
        totalCourses += coursDistincts.length;
        countProfs++;
      }
    }

    return countProfs > 0 ? totalCourses / countProfs : 0.0;
  }
}
