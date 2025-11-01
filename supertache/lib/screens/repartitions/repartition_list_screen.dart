import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/repartition.dart';
import '../../services/repartition_service.dart';
import 'repartition_detail_screen.dart';
import 'create_repartition_screen.dart';
import 'generate_repartitions_screen.dart';
import 'view_generated_solutions_screen.dart';

class RepartitionListScreen extends StatelessWidget {
  final String tacheId;
  final RepartitionService _repartitionService = RepartitionService();

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
              // Bouton pour générer automatiquement
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                  label: const Text('Générer automatiquement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
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
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            repartition.estAutomatique
                                ? Icons.auto_awesome
                                : repartition.estValide 
                                    ? Icons.check_circle 
                                    : Icons.warning,
                            color: repartition.estAutomatique
                                ? Colors.purple
                                : repartition.estValide 
                                    ? Colors.green 
                                    : Colors.orange,
                          ),
                          title: Text(repartition.nom),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Créée le ${_formatDate(repartition.dateCreation)}',
                              ),
                              if (repartition.estAutomatique)
                                Text(
                                  'Générée automatiquement',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.purple,
                                  ),
                                ),
                              if (repartition.methode != null)
                                Text(
                                  'Méthode: ${repartition.methode}',
                                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              Text(
                                '${repartition.groupesNonAlloues.length} groupe(s) non alloué(s)',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteRepartition(context, repartition),
                              ),
                            ],
                          ),
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
                        ),
                      );
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
    return '${date.day}/${date.month}/${date.year}';
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
