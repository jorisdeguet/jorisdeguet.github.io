import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/tache.dart';
import '../../models/groupe.dart';
import '../../models/enseignant.dart';
import '../../models/enseignant_preferences.dart';
import '../../services/firestore_service.dart';
import '../../services/genetic_algorithm_service.dart';
import '../../services/groupe_service.dart';
import '../../services/enseignant_service.dart';
import '../../services/repartition_service.dart';

class LiveGenerationScreen extends StatefulWidget {
  final String tacheId;
  final String? initialSolution; // Format String pour démarrer depuis une solution

  const LiveGenerationScreen({
    Key? key,
    required this.tacheId,
    this.initialSolution,
  }) : super(key: key);

  @override
  State<LiveGenerationScreen> createState() => _LiveGenerationScreenState();
}

class _LiveGenerationScreenState extends State<LiveGenerationScreen> {
  bool _isGenerating = false;
  int _currentGeneration = 0;
  List<TacheSolution> _topSolutions = [];

  Tache? _tache;
  List<Groupe> _groupes = [];
  List<Enseignant> _enseignants = [];
  Map<String, EnseignantPreferences> _preferences = {};

  final _solutionController = TextEditingController();
  final _generationsController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.initialSolution != null) {
      _solutionController.text = widget.initialSolution!;
    }
  }

  @override
  void dispose() {
    _solutionController.dispose();
    _generationsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final groupeService = GroupeService();
    final enseignantService = EnseignantService();

    final tache = await firestoreService.getTache(widget.tacheId);
    if (tache == null) return;

    final groupes = await groupeService.getGroupesForTacheFuture(widget.tacheId);
    final enseignants = await enseignantService.getEnseignantsByIds(tache.enseignantIds);
    final preferencesMap = await firestoreService.getAllEnseignantPreferences(tache.enseignantIds);

    setState(() {
      _tache = tache;
      _groupes = groupes;
      _enseignants = enseignants;
      _preferences = preferencesMap;
    });
  }

  Future<void> _startGeneration() async {
    if (_tache == null) return;

    final generations = int.tryParse(_generationsController.text) ?? 100;

    setState(() {
      _isGenerating = true;
      _currentGeneration = 0;
      _topSolutions = [];
    });

    final geneticService = GeneticAlgorithmService(
      maxGenerations: generations,
      populationSize: 100,
    );

    try {
      await geneticService.generateSolutions(
        groupes: _groupes,
        enseignants: _enseignants,
        preferences: _preferences,
        ciMin: _tache!.ciMin,
        ciMax: _tache!.ciMax,
        nbSolutionsFinales: 5,
        onProgress: (generation, topSolutions) {
          if (mounted) {
            setState(() {
              _currentGeneration = generation;
              _topSolutions = topSolutions;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération terminée!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _saveSolutions() async {
    if (_topSolutions.isEmpty) return;

    final repartitionService = RepartitionService();

    for (int i = 0; i < _topSolutions.length; i++) {
      final solution = _topSolutions[i];
      final repartition = solution.toRepartition(
        'repartition_${DateTime.now().millisecondsSinceEpoch}_$i',
        widget.tacheId,
      );

      await repartitionService.createRepartition(repartition);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _solutionToString(TacheSolution solution, int index) {
    if (_enseignants.isEmpty || _groupes.isEmpty) return '';

    final enseignantIdToName = <String, String>{};
    final groupeIdToCours = <String, String>{};

    for (var ens in _enseignants) {
      enseignantIdToName[ens.id] = ens.email.split('@').first;
    }

    for (var groupe in _groupes) {
      groupeIdToCours[groupe.id] = groupe.cours;
    }

    final repartition = solution.toRepartition('temp', widget.tacheId);
    return repartition.toHumanReadableString(enseignantIdToName, groupeIdToCours);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Génération en direct'),
        actions: [
          if (_topSolutions.isNotEmpty && !_isGenerating)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSolutions,
              tooltip: 'Sauvegarder les solutions',
            ),
        ],
      ),
      body: _tache == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Contrôles
                Container(
                  padding: const EdgeInsets.all(16),
                  color: theme.cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Génération d\'algorithme génétique',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _generationsController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de générations',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              enabled: !_isGenerating,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _startGeneration,
                            icon: Icon(_isGenerating ? Icons.stop : Icons.play_arrow),
                            label: Text(_isGenerating ? 'En cours...' : 'Démarrer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _solutionController,
                        decoration: const InputDecoration(
                          labelText: 'Solution initiale (format: nom1(cours-g)nom2(...))',
                          border: OutlineInputBorder(),
                          hintText: 'joris(3N5-1 3N5-2)bob(1P6-1)',
                        ),
                        enabled: !_isGenerating,
                      ),
                      if (_isGenerating)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: _currentGeneration / (int.tryParse(_generationsController.text) ?? 100),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Génération $_currentGeneration / ${_generationsController.text}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Top 3 solutions
                Expanded(
                  child: _topSolutions.isEmpty
                      ? Center(
                          child: Text(
                            'Lancez la génération pour voir les meilleures solutions',
                            style: theme.textTheme.bodyLarge,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _topSolutions.length,
                          itemBuilder: (context, index) {
                            final solution = _topSolutions[index];
                            final solutionString = _solutionToString(solution, index);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: index == 0
                                                ? Colors.amber
                                                : index == 1
                                                    ? Colors.grey.shade400
                                                    : Colors.brown.shade300,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '#${index + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Score: ${solution.fitness?.toStringAsFixed(1) ?? '?'}',
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${solution.groupesNonAlloues.length} groupes non alloués',
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.content_copy),
                                          onPressed: () {
                                            _solutionController.text = solutionString;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Solution copiée')),
                                            );
                                          },
                                          tooltip: 'Copier',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Format compact:',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      solutionString,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

