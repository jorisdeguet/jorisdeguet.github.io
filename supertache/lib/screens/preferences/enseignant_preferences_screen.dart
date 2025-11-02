import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/enseignant.dart';
import '../../models/enseignant_preferences.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnseignantPreferencesScreen extends StatefulWidget {
  const EnseignantPreferencesScreen({Key? key}) : super(key: key);

  @override
  State<EnseignantPreferencesScreen> createState() => _EnseignantPreferencesScreenState();
}

class _EnseignantPreferencesScreenState extends State<EnseignantPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  
  List<String> _coursSouhaites = [];
  List<String> _coursEvites = [];
  List<String> _coursNeutres = []; // Cours disponibles mais non classés
  List<String> _colleguesSouhaites = [];
  double? _ciMin;
  double? _ciMax;
  
  final _collegueController = TextEditingController();
  final _ciMinController = TextEditingController();
  final _ciMaxController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingCours = true;
  Enseignant? _currentEnseignant;

  // Liste pour l'auto-complétion de tous les collègues (emails)
  List<String> _allCollegueEmails = [];

  // Ensemble de tous les cours disponibles (codes)
  Set<String> _allCoursSet = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _collegueController.dispose();
    _ciMinController.dispose();
    _ciMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    // Charger l'enseignant courant
    final enseignantsList = await firestoreService.getEnseignantsByEmails([user.email!]);
    final enseignant = enseignantsList.isNotEmpty ? enseignantsList.first : null;
    
    if (enseignant == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Charger les préférences depuis Firestore
    final prefs = await firestoreService.getEnseignantPreferences(enseignant.id);
    final effectivePrefs = prefs ?? EnseignantPreferences(
      enseignantId: enseignant.id,
      enseignantEmail: enseignant.email,
    );

    // Charger tous les cours disponibles (remplit _allCoursSet)
    await _loadAllCours(effectivePrefs);

    // Charger tous les collègues possibles (tous les enseignants vus dans la BD)
    List<String> emails = [];
    try {
      emails = await firestoreService.getAllEnseignantEmailsFuture();
    } catch (_) {
      emails = [];
    }
    // Exclure l'enseignant courant
    emails.removeWhere((e) => e == enseignant.email.toLowerCase());

    // Sanitize des listes cours: exclusivité et appartenance au catalogue
    final wishedSet = effectivePrefs.coursSouhaites.where((c) => _allCoursSet.contains(c)).toSet();
    final avoidedSetRaw = effectivePrefs.coursEvites.where((c) => _allCoursSet.contains(c)).toSet();
    final avoidedSet = avoidedSetRaw.difference(wishedSet); // priorité aux souhaités
    final neutralSet = _allCoursSet.difference(wishedSet.union(avoidedSet));

    setState(() {
      _currentEnseignant = enseignant;
      _coursSouhaites = wishedSet.toList()..sort();
      _coursEvites = avoidedSet.toList()..sort();
      _coursNeutres = neutralSet.toList()..sort();
      _colleguesSouhaites = List.from(effectivePrefs.colleguesSouhaites);
      _ciMin = effectivePrefs.ciMin;
      _ciMax = effectivePrefs.ciMax;
      if (_ciMin != null) _ciMinController.text = _ciMin.toString();
      if (_ciMax != null) _ciMaxController.text = _ciMax.toString();
      _allCollegueEmails = emails;
      _isLoading = false;
    });
  }

  Future<void> _loadAllCours(EnseignantPreferences prefs) async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final allCours = await firestoreService.getAllCoursFuture();
      _allCoursSet = allCours.map((c) => c.code).toSet();

      // Calcul provisoire des neutres (sera finalisé dans _loadData)
      final neutres = _allCoursSet
          .where((code) =>
              !prefs.coursSouhaites.contains(code) && 
              !prefs.coursEvites.contains(code))
          .toList()
        ..sort();

      setState(() {
        _coursNeutres = neutres;
        _isLoadingCours = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des cours: $e');
      setState(() {
        _coursNeutres = [];
        _isLoadingCours = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentEnseignant == null) return;

    final updatedPrefs = EnseignantPreferences(
      enseignantId: _currentEnseignant!.id,
      enseignantEmail: _currentEnseignant!.email,
      coursSouhaites: _coursSouhaites,
      coursEvites: _coursEvites,
      colleguesSouhaites: _colleguesSouhaites,
      colleguesEvites: const [], // on ne sauve plus d'évitements de collègues
      ciMin: _ciMin,
      ciMax: _ciMax,
    );

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.saveEnseignantPreferences(updatedPrefs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Préférences sauvegardées'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes Préférences')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentEnseignant == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes Préférences')),
        body: const Center(
          child: Text('Vous devez être connecté comme enseignant'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Préférences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePreferences,
            tooltip: 'Sauvegarder',
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // En-tête
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration de vos préférences',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ces informations aident l\'algorithme à créer des répartitions qui vous conviennent mieux.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Zones de drag-and-drop pour les cours
            _buildCoursDragDropZones(),
            const SizedBox(height: 16),

            // Collègues souhaités (avec auto-complétion)
            _buildColleguesSection(
              title: 'Collègues préférés',
              description: 'Sélectionnez un collègue avec qui vous aimeriez travailler (auto-complétion)',
              items: _colleguesSouhaites,
              controller: _collegueController,
              color: Colors.green,
              onAdd: (value) {
                final email = value.toLowerCase();
                if (email.isEmpty) return;
                setState(() {
                  if (!_colleguesSouhaites.contains(email)) {
                    _colleguesSouhaites.add(email);
                  }
                });
                _collegueController.clear();
              },
              onRemove: (value) {
                setState(() => _colleguesSouhaites.remove(value));
              },
              suggestions: _allCollegueEmails,
            ),
            const SizedBox(height: 16),

            // Plage CI préférée
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assessment, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Plage de CI préférée (optionnel)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Si vide, utilise la plage de la tâche (par défaut 38-46)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ciMinController,
                            decoration: const InputDecoration(
                              labelText: 'CI Minimum',
                              border: OutlineInputBorder(),
                              suffixText: 'unités',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              setState(() {
                                _ciMin = double.tryParse(value);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _ciMaxController,
                            decoration: const InputDecoration(
                              labelText: 'CI Maximum',
                              border: OutlineInputBorder(),
                              suffixText: 'unités',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              setState(() {
                                _ciMax = double.tryParse(value);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursDragDropZones() {
    if (_isLoadingCours) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Classement des cours',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_coursSouhaites.length + _coursEvites.length + _coursNeutres.length} cours au total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Glissez-déposez les cours dans les zones correspondantes. Tous les cours du catalogue sont affichés.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Zone des cours souhaités
            _buildDropZone(
              title: 'Cours souhaités',
              color: Colors.green,
              items: _coursSouhaites,
              onAccept: (cours) {
                setState(() {
                  _coursSouhaites.add(cours);
                  _coursEvites.remove(cours);
                  _coursNeutres.remove(cours);
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Zone des cours neutres
            _buildDropZone(
              title: 'Cours disponibles (neutres)',
              color: Colors.grey,
              items: _coursNeutres,
              isNeutralZone: true,
              onAccept: (cours) {
                setState(() {
                  _coursNeutres.add(cours);
                  _coursSouhaites.remove(cours);
                  _coursEvites.remove(cours);
                  _coursNeutres.sort();
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Zone des cours évités
            _buildDropZone(
              title: 'Cours à éviter',
              color: Colors.red,
              items: _coursEvites,
              onAccept: (cours) {
                setState(() {
                  _coursEvites.add(cours);
                  _coursSouhaites.remove(cours);
                  _coursNeutres.remove(cours);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropZone({
    required String title,
    required Color color,
    required List<String> items,
    required Function(String) onAccept,
    bool isNeutralZone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text('${items.length}'),
              backgroundColor: color.withAlpha(51),
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DragTarget<String>(
          onWillAcceptWithDetails: (details) => !items.contains(details.data),
          onAcceptWithDetails: (details) => onAccept(details.data),
          builder: (context, candidateData, rejectedData) {
            return Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty
                    ? color.withAlpha(26)
                    : Colors.grey.shade50,
                border: Border.all(
                  color: candidateData.isNotEmpty
                      ? color
                      : Colors.grey.shade300,
                  width: candidateData.isNotEmpty ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: items.isEmpty && candidateData.isEmpty
                  ? Center(
                      child: Text(
                        isNeutralZone 
                            ? 'Aucun cours non classé'
                            : 'Glissez un cours ici',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: items.map((cours) {
                        return Draggable<String>(
                          data: cours,
                          feedback: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(16),
                            child: Chip(
                              label: Text(cours),
                              backgroundColor: color.withAlpha(77),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: Chip(
                              label: Text(cours),
                              backgroundColor: color.withAlpha(26),
                            ),
                          ),
                          child: Chip(
                            label: Text(cours),
                            backgroundColor: color.withAlpha(26),
                            deleteIcon: isNeutralZone ? null : const Icon(Icons.close, size: 16),
                            onDeleted: isNeutralZone ? null : () {
                              setState(() {
                                // Retirer le cours de la zone actuelle
                                items.remove(cours);
                                
                                // Le remettre dans la zone neutre
                                if (!_coursNeutres.contains(cours)) {
                                  _coursNeutres.add(cours);
                                  _coursNeutres.sort();
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildColleguesSection({
    required String title,
    required String description,
    required List<String> items,
    required TextEditingController controller,
    required Color color,
    required Function(String) onAdd,
    required Function(String) onRemove,
    List<String>? suggestions,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text('${items.length}'),
                  backgroundColor: color.withAlpha(51),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final query = textEditingValue.text.toLowerCase();
                      if (query.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final pool = suggestions ?? const <String>[];
                      return pool.where((s) => s.toLowerCase().contains(query) && !items.contains(s));
                    },
                    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Ex: prof@college.ca',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () {
                              final value = textController.text.trim();
                              if (value.isNotEmpty) {
                                onAdd(value);
                                textController.clear();
                              }
                            },
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) onAdd(value);
                        },
                      );
                    },
                    onSelected: (String selection) {
                      onAdd(selection);
                    },
                  ),
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  return Chip(
                    label: Text(item, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => onRemove(item),
                    backgroundColor: color.withAlpha(26),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
