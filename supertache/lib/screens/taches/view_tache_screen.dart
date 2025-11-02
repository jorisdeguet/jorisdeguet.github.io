import 'package:flutter/material.dart';
import '../repartitions/repartition_list_screen.dart';

import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/tache.dart';
import '../../models/groupe.dart';
import '../../models/enseignant.dart';
import '../../widgets/app_drawer.dart';

class ViewTacheScreen extends StatefulWidget {
  final String tacheId;

  const ViewTacheScreen({super.key, required this.tacheId});

  @override
  State<ViewTacheScreen> createState() => _ViewTacheScreenState();
}

class _ViewTacheScreenState extends State<ViewTacheScreen> {
  bool _enseignantsExpanded = false;

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
        future: firestoreService.getTache(widget.tacheId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Tâche non trouvée'));
          }

          final tache = snapshot.data!;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 600;
              
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

                  // Bouton pour créer une répartition
                  Card(
                    color: Colors.purple.shade50,
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/tache/${widget.tacheId}/repartitions',
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.grid_on, color: Colors.purple.shade700),
                            const SizedBox(width: 12),
                            Text(
                              'Gérer les répartitions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward, color: Colors.purple.shade700),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Layout en 2 colonnes sur grand écran
                  if (isWideScreen)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildEnseignantsCard(context, tache)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildGroupesCard(context, tache)),
                      ],
                    )
                  else ...[
                    _buildEnseignantsCard(context, tache),
                    const SizedBox(height: 16),
                    _buildGroupesCard(context, tache),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEnseignantsCard(BuildContext context, Tache tache) {
    final firestoreService = Provider.of<FirestoreService>(context);
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _enseignantsExpanded = !_enseignantsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Enseignants (${tache.enseignantEmails.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Icon(
                    _enseignantsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          if (_enseignantsExpanded) ...[
            const Divider(height: 1),
            FutureBuilder<List<Enseignant>>(
              future: firestoreService.getEnseignantsByEmails(tache.enseignantEmails),
              builder: (context, ensSnapshot) {
                if (ensSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final enseignants = ensSnapshot.data ?? [];
                
                // Créer une liste complète avec tous les emails
                final enseignantsList = tache.enseignantEmails.map((email) {
                  final enseignant = enseignants.firstWhere(
                    (e) => e.email == email,
                    orElse: () => Enseignant(
                      id: '',
                      email: email,
                    ),
                  );
                  return enseignant;
                }).toList();
                
                // Trier par nom de famille (dérivé de l'email)
                enseignantsList.sort((a, b) {
                  final nameA = a.displayName.split('.').last.toLowerCase();
                  final nameB = b.displayName.split('.').last.toLowerCase();
                  return nameA.compareTo(nameB);
                });

                return Column(
                  children: [
                    ...enseignantsList.map((enseignant) {
                      final isCreated = enseignant.id.isNotEmpty;
                      return ListTile(
                        tileColor: !isCreated ? Colors.orange.shade50 : null,
                        title: Text(enseignant.email),
                        subtitle: !isCreated 
                            ? const Text(
                                'Compte non créé',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.orange,
                                ),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmRemoveEnseignant(
                            context,
                            tache,
                            enseignant.email,
                          ),
                        ),
                      );
                    }),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Ajouter un enseignant'),
                      onTap: () => _showAddEnseignantDialog(context, tache),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupesCard(BuildContext context, Tache tache) {
    final firestoreService = Provider.of<FirestoreService>(context);
    
    return StreamBuilder<List<Groupe>>(
      stream: firestoreService.getGroupesByTache(widget.tacheId),
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
                        Expanded(
                          child: Text(
                            'Liste des groupes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ajouter un groupe',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _showAddGroupeDialog(context, widget.tacheId),
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${groupe.heuresTheorie.toInt()}T / ${groupe.heuresPratique.toInt()}P',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDeleteGroupe(context, groupe.id),
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
              await firestoreService.deleteTache(widget.tacheId);
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

  void _confirmRemoveEnseignant(BuildContext context, Tache tache, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer l\'enseignant'),
        content: Text(
          'Voulez-vous retirer $email de cette tâche ?',
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
              final updatedEmails = List<String>.from(tache.enseignantEmails)
                ..remove(email);
              
              final updatedTache = tache.copyWith(enseignantEmails: updatedEmails);
              await firestoreService.updateTache(updatedTache);
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enseignant retiré')),
                );
                setState(() {}); // Forcer le rebuild
              }
            },
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  void _showAddEnseignantDialog(BuildContext context, Tache tache) {
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un enseignant'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'enseignant@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim().toLowerCase();
              
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez entrer un email')),
                );
                return;
              }
              
              if (!email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email invalide')),
                );
                return;
              }
              
              if (tache.enseignantEmails.contains(email)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cet enseignant est déjà dans la liste')),
                );
                return;
              }
              
              final firestoreService = Provider.of<FirestoreService>(context, listen: false);
              final updatedEmails = List<String>.from(tache.enseignantEmails)
                ..add(email);
              
              final updatedTache = tache.copyWith(enseignantEmails: updatedEmails);
              await firestoreService.updateTache(updatedTache);
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enseignant ajouté')),
                );
                setState(() {}); // Forcer le rebuild
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showAddGroupeDialog(BuildContext context, String tacheId) {
    final coursCtrl = TextEditingController();
    final numeroCtrl = TextEditingController();
    final etudiantsCtrl = TextEditingController();
    final theorieCtrl = TextEditingController();
    final pratiqueCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un groupe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: coursCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code du cours (ex: 420-1B3-EM) ou 420-XXX-EM',
                ),
              ),
              TextField(
                controller: numeroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numéro de groupe (ex: 1010, 1-2, 5a)',
                ),
              ),
              TextField(
                controller: etudiantsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre d\'étudiants',
                ),
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: theorieCtrl,
                      decoration: const InputDecoration(labelText: 'Heures théorie'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: pratiqueCtrl,
                      decoration: const InputDecoration(labelText: 'Heures pratique'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cours = coursCtrl.text.trim();
              final numero = numeroCtrl.text.trim();
              final etu = int.tryParse(etudiantsCtrl.text.trim());
              final th = double.tryParse(theorieCtrl.text.trim().replaceAll(',', '.'));
              final pr = double.tryParse(pratiqueCtrl.text.trim().replaceAll(',', '.'));

              if (cours.isEmpty || numero.isEmpty || etu == null || th == null || pr == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez remplir tous les champs correctement')),
                );
                return;
              }

              final id = '${tacheId}_g_${DateTime.now().microsecondsSinceEpoch}';
              final groupe = Groupe(
                id: id,
                cours: cours,
                numeroGroupe: numero,
                nombreEtudiants: etu,
                heuresTheorie: th,
                heuresPratique: pr,
                tacheId: tacheId,
              );

              final firestoreService = Provider.of<FirestoreService>(context, listen: false);
              await firestoreService.createGroupe(groupe);

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Groupe ajouté')),
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroupe(BuildContext context, String groupeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final firestoreService = Provider.of<FirestoreService>(context, listen: false);
              await firestoreService.deleteGroupe(groupeId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Groupe supprimé')),
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
