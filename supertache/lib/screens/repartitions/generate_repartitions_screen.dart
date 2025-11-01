import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tache.dart';
import '../../models/groupe.dart';
import '../../models/enseignant.dart';
import '../../models/enseignant_preferences.dart';
import '../../models/repartition.dart';
import '../../services/firestore_service.dart';
import '../../services/genetic_algorithm_service.dart';
import '../../services/groupe_service.dart';
import '../../services/enseignant_service.dart';
import '../../services/repartition_service.dart';
import '../../widgets/app_drawer.dart';

class GenerateRepartitionsScreen extends StatefulWidget {
  final String tacheId;

  const GenerateRepartitionsScreen({
    Key? key,
    required this.tacheId,
  }) : super(key: key);

  @override
  State<GenerateRepartitionsScreen> createState() => _GenerateRepartitionsScreenState();
}

class _GenerateRepartitionsScreenState extends State<GenerateRepartitionsScreen> {
  bool _isGenerating = false;
  bool _isLoading = true;
  int _currentGeneration = 0;
  double _bestFitness = 0.0;
  
  Tache? _tache;
  List<Groupe> _groupes = [];
  List<Enseignant> _enseignants = [];
  List<Repartition> _generatedRepartitions = [];
  
  // Paramètres
  int _nbSolutions = 5;
  int _populationSize = 100;
  int _maxGenerations = 500;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final groupeService = GroupeService();
    final enseignantService = EnseignantService();

    final tache = await firestoreService.getTache(widget.tacheId);
    if (tache == null) {
      setState(() => _isLoading = false);
      return;
    }

    final groupes = await groupeService.getGroupesForTacheFuture(widget.tacheId);
    
    // Créer des enseignants pour tous les emails de la tâche
    final enseignants = <Enseignant>[];
    final enseignantsWithAccounts = await enseignantService.getEnseignantsByEmails(tache.enseignantEmails);
    final enseignantEmailMap = {for (var e in enseignantsWithAccounts) e.email: e};
    
    for (int i = 0; i < tache.enseignantEmails.length; i++) {
      final email = tache.enseignantEmails[i];
      final id = i < tache.enseignantIds.length ? tache.enseignantIds[i] : email;
      
      // Utiliser l'enseignant existant s'il a un compte, sinon créer un objet avec l'email
      if (enseignantEmailMap.containsKey(email)) {
        enseignants.add(enseignantEmailMap[email]!);
      } else {
        enseignants.add(Enseignant(
          id: id,
          email: email,
        ));
      }
    }

    // S'assurer que l'utilisateur connecté est dans la liste
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      final currentUserEmail = currentUser.email!;
      final isCurrentUserIncluded = enseignants.any((e) => e.email == currentUserEmail);

      if (!isCurrentUserIncluded) {
        // Récupérer les infos de l'utilisateur connecté depuis Firestore
        final currentEnseignant = await firestoreService.getEnseignant(currentUser.uid);
        if (currentEnseignant != null) {
          enseignants.add(currentEnseignant);
        } else {
          // Créer un objet enseignant avec les infos de base
          enseignants.add(Enseignant(
            id: currentUser.uid,
            email: currentUserEmail,
          ));
        }
      }
    }

    setState(() {
      _tache = tache;
      _groupes = groupes;
      _enseignants = enseignants;
      _isLoading = false;
    });
  }

  Future<void> _generateRepartitions() async {
    if (_tache == null) return;

    setState(() {
      _isGenerating = true;
      _currentGeneration = 0;
      _bestFitness = 0.0;
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      
      // Charger les préférences des enseignants
      final preferences = await firestoreService.getAllEnseignantPreferences(
        _enseignants.map((e) => e.id).toList(),
      );
      
      // Ajouter des préférences vides pour ceux qui n'en ont pas
      for (var enseignant in _enseignants) {
        if (!preferences.containsKey(enseignant.id)) {
          preferences[enseignant.id] = EnseignantPreferences(
            enseignantId: enseignant.id,
            enseignantEmail: enseignant.email,
          );
        }
      }

      final geneticAlgo = GeneticAlgorithmService(
        populationSize: _populationSize,
        maxGenerations: _maxGenerations,
        mutationRate: 0.3,
        crossoverRate: 0.7,
        eliteCount: 10,
      );

      final solutions = await geneticAlgo.generateSolutions(
        groupes: _groupes,
        enseignants: _enseignants,
        preferences: preferences,
        ciMin: _tache!.ciMin,
        ciMax: _tache!.ciMax,
        nbSolutionsFinales: _nbSolutions,
      );

      // Convertir en répartitions et sauvegarder
      final repartitionService = RepartitionService();
      final generatedRepartitions = <Repartition>[];

      for (int i = 0; i < solutions.length; i++) {
        final id = 'rep_gen_${widget.tacheId}_${DateTime.now().millisecondsSinceEpoch}_$i';
        final repartition = solutions[i].toRepartition(id, widget.tacheId);
        
        await repartitionService.createRepartition(repartition);
        generatedRepartitions.add(repartition);
      }

      setState(() {
        _generatedRepartitions = generatedRepartitions;
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${solutions.length} répartitions générées avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Génération automatique')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_tache == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Génération automatique')),
        body: const Center(child: Text('Tâche non trouvée')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Génération automatique'),
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 32, color: Colors.purple),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Algorithme génétique',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              _tache!.nom,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'L\'algorithme va générer automatiquement plusieurs répartitions optimales en tenant compte des préférences des enseignants et des contraintes de CI.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Statistiques
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.people, color: Colors.blue),
                        const SizedBox(height: 8),
                        Text(
                          '${_enseignants.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Enseignants'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.group, color: Colors.green),
                        const SizedBox(height: 8),
                        Text(
                          '${_groupes.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Groupes'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.assessment, color: Colors.orange),
                        const SizedBox(height: 8),
                        Text(
                          '${_tache!.ciMin.toInt()}-${_tache!.ciMax.toInt()}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Plage CI'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Paramètres
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paramètres de l\'algorithme',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nombre de solutions'),
                            Slider(
                              value: _nbSolutions.toDouble(),
                              min: 3,
                              max: 10,
                              divisions: 7,
                              label: _nbSolutions.toString(),
                              onChanged: _isGenerating
                                  ? null
                                  : (value) {
                                      setState(() => _nbSolutions = value.toInt());
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Taille population'),
                            Slider(
                              value: _populationSize.toDouble(),
                              min: 50,
                              max: 200,
                              divisions: 15,
                              label: _populationSize.toString(),
                              onChanged: _isGenerating
                                  ? null
                                  : (value) {
                                      setState(() => _populationSize = value.toInt());
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Générations max'),
                            Slider(
                              value: _maxGenerations.toDouble(),
                              min: 100,
                              max: 1000,
                              divisions: 18,
                              label: _maxGenerations.toString(),
                              onChanged: _isGenerating
                                  ? null
                                  : (value) {
                                      setState(() => _maxGenerations = value.toInt());
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bouton de génération
          if (!_isGenerating)
            ElevatedButton.icon(
              onPressed: _generateRepartitions,
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Générer les répartitions',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            )
          else
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Génération en cours...',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cela peut prendre quelques minutes',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

          // Résultats
          if (_generatedRepartitions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Répartitions générées',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ..._generatedRepartitions.asMap().entries.map((entry) {
              final index = entry.key;
              final repartition = entry.value;
              
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text('Solution ${index + 1}'),
                  subtitle: Text(
                    'Créée le ${_formatDate(repartition.dateCreation)}',
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/repartition/detail',
                      arguments: repartition.id,
                    );
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
