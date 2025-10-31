import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/tache.dart';
import '../../models/groupe.dart';
import '../../models/enseignant.dart';
import '../../widgets/app_drawer.dart';

class ViewTacheScreen extends StatelessWidget {
  final String tacheId;

  const ViewTacheScreen({super.key, required this.tacheId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Détails de la tâche'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<Tache?>(
        future: firestoreService.getTache(tacheId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Tâche non trouvée'));
          }

          final tache = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // En-tête
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tache.nom,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: tache.type == SessionType.automne
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${tache.type == SessionType.automne ? "Automne" : "Hiver"} ${tache.year}',
                              style: TextStyle(
                                color: tache.type == SessionType.automne
                                    ? Colors.orange.shade900
                                    : Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Créée le ${_formatDate(tache.dateCreation)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Enseignants
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Enseignants (${tache.enseignantEmails.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Enseignant>>(
                        future: firestoreService.getEnseignantsByEmails(tache.enseignantEmails),
                        builder: (context, ensSnapshot) {
                          if (ensSnapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          final enseignants = ensSnapshot.data ?? [];
                          return Column(
                            children: tache.enseignantEmails.map((email) {
                              final enseignant = enseignants.firstWhere(
                                (e) => e.email == email,
                                orElse: () => Enseignant(
                                  id: '',
                                  nom: '',
                                  prenom: '',
                                  email: email,
                                ),
                              );

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    enseignant.prenom.isNotEmpty
                                        ? enseignant.prenom.substring(0, 1)
                                        : '?',
                                  ),
                                ),
                                title: Text(
                                  enseignant.nom.isNotEmpty
                                      ? enseignant.nomComplet
                                      : 'Compte non créé',
                                ),
                                subtitle: Text(email),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Groupes
              StreamBuilder<List<Groupe>>(
                stream: firestoreService.getGroupesByTache(tacheId),
                builder: (context, groupeSnapshot) {
                  if (groupeSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final groupes = groupeSnapshot.data ?? [];
                  final ciTotale = tache.calculateCITotale(groupes);

                  return Column(
                    children: [
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                icon: Icons.group,
                                label: 'Groupes',
                                value: '${groupes.length}',
                              ),
                              _StatItem(
                                icon: Icons.people,
                                label: 'Étudiants',
                                value: '${groupes.fold(0, (sum, g) => sum + g.nombreEtudiants)}',
                              ),
                              _StatItem(
                                icon: Icons.assessment,
                                label: 'CI Totale',
                                value: ciTotale.toStringAsFixed(2),
                                valueColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.list, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Liste des groupes',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: groupes.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final groupe = groupes[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text('${groupe.cours} - ${groupe.numeroGroupe}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${groupe.nombreEtudiants} étudiants'),
                                      Text(
                                        '${groupe.heuresTheorie}h théo • ${groupe.heuresPratique}h prat',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('CI', style: TextStyle(fontSize: 11)),
                                      Text(
                                        groupe.ci.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la tâche'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cette tâche et tous ses groupes ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final firestoreService = Provider.of<FirestoreService>(context, listen: false);
              await firestoreService.deleteTache(tacheId);
              if (context.mounted) {
                Navigator.pop(context); // Fermer le dialog
                Navigator.pop(context); // Retourner à la liste
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tâche supprimée')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
