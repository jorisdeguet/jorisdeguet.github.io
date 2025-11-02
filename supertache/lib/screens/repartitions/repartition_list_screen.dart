import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/repartition.dart';
import '../../models/groupe.dart';
import '../../services/repartition_service.dart';
import '../../services/groupe_service.dart';
import '../../widgets/repartition_summary_card.dart';
import 'repartition_detail_screen.dart';
import 'create_repartition_screen.dart';
import 'generate_repartitions_screen.dart';
import 'view_generated_solutions_screen.dart';
import 'live_generation_screen.dart';

class RepartitionListScreen extends StatelessWidget {
  final String tacheId;
  final RepartitionService _repartitionService = RepartitionService();
  final GroupeService _groupeService = GroupeService();

  RepartitionListScreen({required this.tacheId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Répartitions'),
      ),
      drawer: _buildDrawer(context),
      body: StreamBuilder<List<Repartition>>(
        stream: _repartitionService.getRepartitionsForTache(tacheId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final repartitions = snapshot.data ?? [];

          return Column(
            children: [
              // Boutons de génération
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GenerateRepartitionsScreen(
                                tacheId: tacheId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Générer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveGenerationScreen(
                                tacheId: tacheId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.science),
                        label: const Text('Mode Live'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bouton pour voir les solutions générées (si présentes)
              if (repartitions.any((r) => r.estAutomatique))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewGeneratedSolutionsScreen(
                              tacheId: tacheId,
                              generationId: 'gen_${tacheId}_latest',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Comparer les solutions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),

              if (repartitions.any((r) => r.estAutomatique))
                const SizedBox(height: 16),

              // Liste des répartitions
              if (repartitions.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Aucune répartition',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Créez une nouvelle répartition',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: repartitions.length,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final repartition = repartitions[index];
                      return _buildRepartitionCard(context, repartition);
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateRepartitionScreen(tacheId: tacheId),
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Nouvelle répartition',
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('Accueil'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Mon profil'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.school),
            title: Text('Catalogue des cours'),
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamed(context, '/cours');
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Déconnexion'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildRepartitionCard(BuildContext context, Repartition repartition) {
    return FutureBuilder<List<Groupe>>(
      future: _groupeService.getGroupesForTacheFuture(tacheId),
      builder: (context, groupeSnapshot) {
        if (!groupeSnapshot.hasData) {
          return Card(
            child: ListTile(
              title: Text(repartition.nom),
              subtitle: const Text('Chargement...'),
            ),
          );
        }

        return RepartitionSummaryCard(
          repartition: repartition,
          groupes: groupeSnapshot.data!,
          isCompact: false,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RepartitionDetailScreen(
                  tacheId: tacheId,
                  repartitionId: repartition.id,
                ),
              ),
            );
          },
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteRepartition(context, repartition),
          ),
        );
      },
    );
  }


  Future<void> _deleteRepartition(BuildContext context, Repartition repartition) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer cette répartition ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      await _repartitionService.deleteRepartition(repartition.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Répartition supprimée')),
      );
    }
  }
}
