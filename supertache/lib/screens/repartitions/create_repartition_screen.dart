import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/repartition.dart';
import '../../models/enseignant.dart';
import '../../services/tache_service.dart';
import '../../services/groupe_service.dart';
import '../../services/enseignant_service.dart';
import '../../services/repartition_service.dart';
import '../../services/genetic_algorithm_service.dart';
import 'manual_repartition_screen.dart';

class CreateRepartitionScreen extends StatefulWidget {
  final String tacheId;

  CreateRepartitionScreen({required this.tacheId});

  @override
  _CreateRepartitionScreenState createState() => _CreateRepartitionScreenState();
}

class _CreateRepartitionScreenState extends State<CreateRepartitionScreen> {
  final TacheService _tacheService = TacheService();
  final GroupeService _groupeService = GroupeService();
  final EnseignantService _enseignantService = EnseignantService();
  final RepartitionService _repartitionService = RepartitionService();
  final GeneticAlgorithmService _geneticService = GeneticAlgorithmService();

  bool _isLoading = false;
  int _currentGeneration = 0;
  double _bestFitness = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nouvelle répartition'),
      ),
      drawer: _buildDrawer(context),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choisissez le type de répartition',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 32),
            _buildMethodCard(
              context,
              icon: Icons.person,
              title: 'Répartition manuelle',
              description: 'Créez et modifiez une répartition en attribuant manuellement les groupes aux enseignants.',
              color: Colors.blue,
              onTap: _createManualRepartition,
            ),
            SizedBox(height: 16),
            _buildMethodCard(
              context,
              icon: Icons.auto_awesome,
              title: 'Répartition automatique',
              description: 'Utilisez un algorithme génétique pour générer automatiquement une répartition optimisée.',
              color: Colors.purple,
              onTap: _createGeneticRepartition,
            ),
            if (_isLoading) ...[
              SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Génération en cours...'),
                    if (_currentGeneration > 0) ...[
                      SizedBox(height: 8),
                      Text(
                        'Génération $_currentGeneration: Meilleur fitness = ${_bestFitness.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
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

  Widget _buildMethodCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 64, color: color),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createManualRepartition() async {
    // Récupérer tous les groupes de la tâche pour les initialiser comme non alloués
    final groupes = await _groupeService.getGroupesForTacheFuture(widget.tacheId);
    final groupeIds = groupes.map((g) => g.id).toList();
    
    // Créer une répartition vide
    final newRepartition = Repartition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tacheId: widget.tacheId,
      nom: 'Répartition manuelle ${DateTime.now().toString().substring(0, 16)}',
      dateCreation: DateTime.now(),
      allocations: {},
      groupesNonAlloues: groupeIds,
      estValide: false,
      methode: 'manuelle',
    );

    final repartitionId = await _repartitionService.createRepartition(newRepartition);

    // Aller à l'écran de répartition manuelle
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ManualRepartitionScreen(
          tacheId: widget.tacheId,
          repartitionId: repartitionId,
        ),
      ),
    );
  }

  void _createGeneticRepartition() async {
    setState(() {
      _isLoading = true;
      _currentGeneration = 0;
      _bestFitness = 0.0;
    });

    try {
      // Récupérer les données
      final tache = await _tacheService.getTache(widget.tacheId);
      if (tache == null) {
        throw Exception('Tâche non trouvée');
      }

      final groupes = await _groupeService.getGroupesForTache(widget.tacheId).first;
      final enseignants = await Future.wait(
        tache.enseignantEmails.map((email) => _enseignantService.getEnseignantByEmail(email)),
      );

      final enseignantsList = enseignants.whereType<Enseignant>().toList();

      // S'assurer que l'utilisateur connecté est dans la liste
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final currentUserEmail = currentUser.email!;
        final isCurrentUserIncluded = enseignantsList.any((e) => e.email == currentUserEmail);
        
        if (!isCurrentUserIncluded) {
          final currentEnseignant = await _enseignantService.getEnseignantByEmail(currentUserEmail);
          if (currentEnseignant != null) {
            enseignantsList.add(currentEnseignant);
          } else {
            // Créer un enseignant pour l'utilisateur actuel
            enseignantsList.add(Enseignant(
              id: currentUser.uid,
              email: currentUserEmail,
            ));
          }
        }
      }

      if (groupes.isEmpty) {
        throw Exception('Aucun groupe trouvé pour cette tâche');
      }

      if (enseignantsList.isEmpty) {
        throw Exception('Aucun enseignant trouvé pour cette tâche');
      }

      // Générer la répartition avec l'algorithme génétique
      final repartition = await _geneticService.generateRepartition(
        tacheId: widget.tacheId,
        groupes: groupes,
        enseignants: enseignantsList,
        onProgress: (generation, fitness) {
          setState(() {
            _currentGeneration = generation;
            _bestFitness = fitness;
          });
        },
      );

      // Sauvegarder la répartition
      await _repartitionService.createRepartition(repartition);

      setState(() => _isLoading = false);

      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            repartition.estValide
                ? 'Répartition valide générée avec succès!'
                : 'Répartition générée (non optimale)',
          ),
          backgroundColor: repartition.estValide ? Colors.green : Colors.orange,
        ),
      );

      // Retourner à la liste
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
