import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final _populationController = TextEditingController(text: '100');

  // Contrôles de fitness weights
  final _wCiController = TextEditingController(text: '30');
  final _wCiPenaltyController = TextEditingController(text: '5');
  final _wCours2Controller = TextEditingController(text: '-10');
  final _wCours3Controller = TextEditingController(text: '-30');
  final _wCours4pController = TextEditingController(text: '-100');
  final _wCoursWishController = TextEditingController(text: '10');
  final _wCoursAvoidController = TextEditingController(text: '-100');
  final _wColWishController = TextEditingController(text: '1');
  final _wColAvoidController = TextEditingController(text: '-5');
  final _wUnallocController = TextEditingController(text: '-50');

  // Répartitions existantes pour la tâche
  List<Repartition> _existingRepartitions = [];

  // Options de suggestion
  bool _includeExistingSeeds = true;
  bool _includeTextSeed = true;

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
    _populationController.dispose();
    _wCiController.dispose();
    _wCiPenaltyController.dispose();
    _wCours2Controller.dispose();
    _wCours3Controller.dispose();
    _wCours4pController.dispose();
    _wCoursWishController.dispose();
    _wCoursAvoidController.dispose();
    _wColWishController.dispose();
    _wColAvoidController.dispose();
    _wUnallocController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final groupeService = GroupeService();
    final enseignantService = EnseignantService();
    final repartitionService = RepartitionService();

    final tache = await firestoreService.getTache(widget.tacheId);
    if (tache == null) return;

    final groupes = await groupeService.getGroupesForTacheFuture(widget.tacheId);
    final enseignants = await enseignantService.getEnseignantsByIds(tache.enseignantIds);
    final preferencesMap = await firestoreService.getAllEnseignantPreferences(tache.enseignantIds);
    final existing = await repartitionService.getRepartitionsForTacheFuture(widget.tacheId);

    setState(() {
      _tache = tache;
      _groupes = groupes;
      _enseignants = enseignants;
      _preferences = preferencesMap;
      _existingRepartitions = existing;
    });
  }

  Future<void> _startGeneration() async {
    if (_tache == null) return;

    final generations = int.tryParse(_generationsController.text) ?? 100;
    final popSize = int.tryParse(_populationController.text) ?? 100;

    setState(() {
      _isGenerating = true;
      _currentGeneration = 0;
      _topSolutions = [];
    });

    // Construire les poids depuis les champs
    final weights = FitnessWeights(
      wCiBonus: double.tryParse(_wCiController.text) ?? 30,
      wCiPenaltyPerUnit: double.tryParse(_wCiPenaltyController.text) ?? 5,
      wCours2Penalty: double.tryParse(_wCours2Controller.text) ?? -10,
      wCours3Penalty: double.tryParse(_wCours3Controller.text) ?? -30,
      wCours4PlusPenalty: double.tryParse(_wCours4pController.text) ?? -100,
      wCoursWishBonus: double.tryParse(_wCoursWishController.text) ?? 10,
      wCoursAvoidPenalty: double.tryParse(_wCoursAvoidController.text) ?? -100,
      wColWishBonus: double.tryParse(_wColWishController.text) ?? 1,
      wColAvoidPenalty: double.tryParse(_wColAvoidController.text) ?? -5,
      wUnallocatedPenalty: double.tryParse(_wUnallocController.text) ?? -50,
    );

    // Construire des seeds (population initiale) depuis:
    // - les répartitions existantes
    // - la solution saisie en texte (si valide)
    final seeds = <TacheSolution>[];
    if (_includeExistingSeeds) {
      for (var r in _existingRepartitions) {
        seeds.add(TacheSolution(allocations: r.allocations, groupesNonAlloues: r.groupesNonAlloues));
      }
    }

    if (_includeTextSeed) {
      final text = _solutionController.text.trim();
      if (text.isNotEmpty) {
        // Construire les maps de parsing
        final nameToId = <String, String>{};
        for (var e in _enseignants) {
          final key = e.email.split('@').first.toLowerCase();
          nameToId[key] = e.id;
        }
        final labelToGroupId = <String, String>{};
        for (var g in _groupes) {
          labelToGroupId['${g.cours}-${g.numeroGroupe}'] = g.id;
        }
        final allocations = Repartition.parseHumanReadableString(text, nameToId, labelToGroupId);
        if (allocations != null && allocations.isNotEmpty) {
          seeds.add(TacheSolution(allocations: allocations, groupesNonAlloues: []));
        }
      }
    }

    final geneticService = GeneticAlgorithmService(
      maxGenerations: generations,
      populationSize: popSize,
      weights: weights,
    );

    try {
      await geneticService.generateSolutions(
        groupes: _groupes,
        enseignants: _enseignants,
        preferences: _preferences,
        ciMin: _tache!.ciMin,
        ciMax: _tache!.ciMax,
        nbSolutionsFinales: 5,
        seedSolutions: seeds,
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
    final groupeIdToLabel = <String, String>{};

    for (var ens in _enseignants) {
      enseignantIdToName[ens.id] = ens.email.split('@').first;
    }

    for (var groupe in _groupes) {
      groupeIdToLabel[groupe.id] = '${groupe.cours}-${groupe.numeroGroupe}';
    }

    final repartition = solution.toRepartition('temp', widget.tacheId);
    return repartition.toHumanReadableString(enseignantIdToName, groupeIdToLabel);
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
                // Tableau des répartitions existantes
                if (_existingRepartitions.isNotEmpty)
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildExistingRepartitionsTable(context),
                    ),
                  ),

                // Contrôles + progression + top 3
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildControls(theme),
                      const Divider(height: 1),
                      Expanded(child: _buildTopSolutionsList(theme)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildExistingRepartitionsTable(BuildContext context) {
    // Mapping pour string
    final enseignantIdToName = {for (var e in _enseignants) e.id: e.email};
    final groupeIdToLabel = {for (var g in _groupes) g.id: '${g.cours}-${g.numeroGroupe}'};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Répartitions existantes (${_existingRepartitions.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nom')),
                    DataColumn(label: Text('String')),
                    DataColumn(label: Text('Groupes non alloués')),
                  ],
                  rows: _existingRepartitions.map((r) {
                    final s = r.toHumanReadableString(enseignantIdToName, groupeIdToLabel);
                    return DataRow(cells: [
                      DataCell(Text(r.nom, overflow: TextOverflow.ellipsis)),
                      DataCell(SizedBox(width: 600, child: SelectableText(s))),
                      DataCell(Text('${r.groupesNonAlloues.length}')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Taille de population',
                    border: OutlineInputBorder(),
                  ),
                  controller: _populationController,
                  keyboardType: TextInputType.number,
                  enabled: !_isGenerating,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _startGeneration,
                icon: Icon(_isGenerating ? Icons.stop : Icons.play_arrow),
                label: Text(_isGenerating ? 'En cours...' : 'Démarrer'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _includeExistingSeeds,
                    onChanged: _isGenerating
                        ? null
                        : (v) => setState(() => _includeExistingSeeds = v),
                  ),
                  const SizedBox(width: 4),
                  const Text('Inclure les répartitions existantes comme seeds'),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _includeTextSeed,
                    onChanged: _isGenerating
                        ? null
                        : (v) => setState(() => _includeTextSeed = v),
                  ),
                  const SizedBox(width: 4),
                  const Text('Inclure la solution texte comme seed'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Poids de la fonction de fitness'),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _numField('Bonus CI dans plage', _wCiController),
                  _numField('Pénalité par unité hors CI', _wCiPenaltyController),
                  _numField('2 cours à préparer', _wCours2Controller),
                  _numField('3 cours à préparer', _wCours3Controller),
                  _numField('4+ cours à préparer', _wCours4pController),
                  _numField('Cours souhaités', _wCoursWishController),
                  _numField('Cours évités', _wCoursAvoidController),
                  _numField('Collègues souhaités', _wColWishController),
                  _numField('Collègues évités', _wColAvoidController),
                  _numField('Non alloués (par groupe)', _wUnallocController),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController c) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }

  Widget _buildTopSolutionsList(ThemeData theme) {
    if (_topSolutions.isEmpty) {
      return Center(
        child: Text(
          'Lancez la génération pour voir les meilleures solutions',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
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
                Text('Format compact:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SelectableText(
                  solutionString,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
