import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tache.dart';
import '../../models/groupe.dart';
import '../../models/enseignant.dart';
import '../../models/enseignant_preferences.dart';
import '../../models/repartition.dart';
import '../../services/firestore_service.dart';
import '../../services/genetic_algorithm_service.dart';
import '../../services/population_generator_service.dart';
import '../../services/score_repartition_service.dart';
import '../../services/groupe_service.dart';
import '../../services/repartition_service.dart';

class LiveGenerationScreen extends StatefulWidget {
  final String tacheId;

  const LiveGenerationScreen({
    Key? key,
    required this.tacheId,
  }) : super(key: key);

  @override
  State<LiveGenerationScreen> createState() => _LiveGenerationScreenState();
}

class _LiveGenerationScreenState extends State<LiveGenerationScreen> {
  bool _isGenerating = false;
  List<TacheSolution> _topSolutions = [];

  Tache? _tache;
  List<Groupe> _groupes = [];
  List<Enseignant> _enseignants = [];
  Map<String, EnseignantPreferences> _preferences = {};
  List<Repartition> _existingRepartitions = [];

  // Controllers pour différents actions
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


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
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
    final repartitionService = RepartitionService();

    final tache = await firestoreService.getTache(widget.tacheId);
    if (tache == null) return;

    final groupes = await groupeService.getGroupesForTacheFuture(widget.tacheId);
    // Utiliser les emails au lieu des IDs pour récupérer tous les enseignants
    final enseignants = await firestoreService.getEnseignantsByEmailsForTask(tache.enseignantEmails);

    // Récupérer les IDs réels des enseignants pour les préférences
    final enseignantIds = enseignants.map((e) => e.id).toList();
    final preferencesMap = await firestoreService.getAllEnseignantPreferences(enseignantIds);
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

    // Construire des seeds depuis les répartitions existantes
    final seeds = <TacheSolution>[];
    for (var r in _existingRepartitions) {
      seeds.add(TacheSolution(allocations: r.allocations, groupesNonAlloues: r.groupesNonAlloues));
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

  Future<void> _showGenerateByPreferencesDialog(BuildContext context) async {
    final countController = TextEditingController(text: '5');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Générer des répartitions par préférences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Combien de répartitions voulez-vous générer en saturant les préférences des enseignants ?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              decoration: const InputDecoration(
                labelText: 'Nombre de répartitions',
                border: OutlineInputBorder(),
                hintText: '5',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final count = int.tryParse(countController.text) ?? 5;
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nombre valide')),
      );
      return;
    }

    if (_tache == null) return;

    // Générer les répartitions
    final popGenerator = PopulationGeneratorService();
    final repartitions = popGenerator.createRepartitionsByPreferences(
      groupes: _groupes,
      enseignants: _enseignants,
      preferences: _preferences,
      tacheId: widget.tacheId,
      ciMin: _tache!.ciMin,
      ciMax: _tache!.ciMax,
      count: count,
    );

    // Sauvegarder les répartitions
    final repartitionService = RepartitionService();
    for (var repartition in repartitions) {
      await repartitionService.createRepartition(repartition);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count répartition(s) générée(s) avec succès !')),
      );
      // Recharger les données pour afficher les nouvelles répartitions
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tache != null ? 'Répartitions - ${_tache!.nom}' : 'Répartitions'),
      ),
      body: _tache == null
          ? const Center(child: CircularProgressIndicator())
          : isMobile
              ? _buildMobileLayout(theme)
              : _buildDesktopLayout(theme),
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildExistingRepartitionsSection(theme),
          const Divider(thickness: 2),
          _buildActionsPanel(theme),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      children: [
        // Section gauche: répartitions existantes
        Expanded(
          flex: 2,
          child: _buildExistingRepartitionsSection(theme),
        ),
        const VerticalDivider(thickness: 2),
        // Section droite: actions
        Expanded(
          flex: 1,
          child: _buildActionsPanel(theme),
        ),
      ],
    );
  }

  Widget _buildExistingRepartitionsSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Répartitions actuelles (${_existingRepartitions.length})',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_existingRepartitions.isEmpty)
            Center(
              child: Text(
                'Aucune répartition actuellement',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _existingRepartitions.length,
                itemBuilder: (context, index) {
                  final repartition = _existingRepartitions[index];
                  return _buildRepartitionCard(repartition, theme);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepartitionCard(Repartition repartition, ThemeData theme) {
    final enseignantIdToName = {for (var e in _enseignants) e.id: e.displayName};
    final groupeIdToLabel = {for (var g in _groupes) g.id: '${g.cours}-${g.numeroGroupe}'};

    final repartitionString = repartition.toHumanReadableString(enseignantIdToName, groupeIdToLabel);
    final nbGroupesNonAlloues = repartition.groupesNonAlloues.length;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Action: modifier cette répartition
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repartition.nom,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    repartitionString,
                    style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Non alloués: $nbGroupesNonAlloues',
                    style: theme.textTheme.bodySmall,
                  ),
                  Tooltip(
                    message: 'Copier la répartition',
                    child: IconButton(
                      icon: const Icon(Icons.content_copy, size: 16),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Répartition "${repartition.nom}" copiée')),
                        );
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actions',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              label: 'Créer une répart manuelle',
              icon: Icons.add_box,
              onPressed: () {
                // TODO: Implémenter création manuelle
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Créer répart manuelle - À implémenter')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              label: 'Créer en saturant les préférences',
              icon: Icons.favorite,
              onPressed: () => _showGenerateByPreferencesDialog(context),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              label: 'Générer répartition (algo génétique)',
              icon: Icons.auto_awesome_outlined,
              onPressed: _isGenerating ? null : _startGeneration,
              isLoading: _isGenerating,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              label: 'Modifier cette répartition',
              icon: Icons.edit,
              onPressed: _existingRepartitions.isEmpty ? null : () {
                // TODO: Implémenter modification
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modifier répart - À implémenter')),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              label: 'Démarrer algo depuis ces répart',
              icon: Icons.repeat,
              onPressed: _existingRepartitions.isEmpty ? null : () {
                // TODO: Implémenter démarrage depuis répartitions existantes
                _startGeneration();
              },
            ),
            if (_topSolutions.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Meilleures solutions générées',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildGeneratedSolutionsList(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ) : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildGeneratedSolutionsList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_topSolutions.length, (index) {
        final solution = _topSolutions[index];
        final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : '🥉';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(medal, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Score: ${solution.fitness?.toStringAsFixed(1) ?? '?'}',
                            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${solution.groupesNonAlloues.length} groupes non alloués',
                            style: theme.textTheme.labelSmall,
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
      }),
    );
  }
}
