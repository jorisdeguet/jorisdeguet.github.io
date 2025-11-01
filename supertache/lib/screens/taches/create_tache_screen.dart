import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/tache.dart';
import '../../models/groupe.dart';
import '../../widgets/app_drawer.dart';

class CreateTacheScreen extends StatefulWidget {
  const CreateTacheScreen({super.key});

  @override
  State<CreateTacheScreen> createState() => _CreateTacheScreenState();
}

class _CreateTacheScreenState extends State<CreateTacheScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailsController = TextEditingController();
  final _csvController = TextEditingController();
  
  SessionType _selectedType = SessionType.automne;
  int _selectedYear = DateTime.now().year;
  List<String> _parsedEmails = [];
  List<Groupe> _parsedGroupes = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _emailsController.dispose();
    _csvController.dispose();
    super.dispose();
  }

  void _parseEmails() {
    final emails = Tache.parseEmailsFromText(_emailsController.text);
    setState(() {
      _parsedEmails = emails;
    });
  }

  void _parseCSV() {
    final lines = _csvController.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<Groupe> groupes = [];
    final tempTacheId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    for (var i = 0; i < lines.length; i++) {
      final groupe = Groupe.fromCSVLine(lines[i], tempTacheId, i);
      if (groupe != null) {
        groupes.add(groupe);
      }
    }

    setState(() {
      _parsedGroupes = groupes;
    });
  }

  void _addGroupeManually() {
    showDialog(
      context: context,
      builder: (context) => _AddGroupeDialog(
        onAdd: (groupe) {
          setState(() {
            _parsedGroupes.add(groupe);
          });
        },
        tempTacheId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        index: _parsedGroupes.length,
      ),
    );
  }

  Future<void> _createTache() async {
    if (!_formKey.currentState!.validate()) return;
    if (_parsedGroupes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un groupe')),
      );
      return;
    }
    if (_parsedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un enseignant')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final tacheId = 'tache_${DateTime.now().millisecondsSinceEpoch}';

      // Créer la tâche
      final tache = Tache(
        id: tacheId,
        nom: _nomController.text.trim(),
        dateCreation: DateTime.now(),
        type: _selectedType,
        year: _selectedYear,
        startDate: DateTime(
          _selectedYear,
          _selectedType == SessionType.automne ? 8 : 1,
          1,
        ),
        endDate: DateTime(
          _selectedYear,
          _selectedType == SessionType.automne ? 12 : 5,
          31,
        ),
        enseignantEmails: _parsedEmails,
        groupeIds: _parsedGroupes.map((g) => g.id).toList(),
      );

      // Mettre à jour les IDs des groupes avec le vrai ID de tâche
      final groupesWithCorrectId = _parsedGroupes.map((g) {
        return Groupe(
          id: '${tacheId}_groupe_${_parsedGroupes.indexOf(g)}',
          cours: g.cours,
          numeroGroupe: g.numeroGroupe,
          nombreEtudiants: g.nombreEtudiants,
          heuresTheorie: g.heuresTheorie,
          heuresPratique: g.heuresPratique,
          tacheId: tacheId,
        );
      }).toList();

      await firestoreService.createTache(tache);
      await firestoreService.createGroupes(groupesWithCorrectId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tâche créée avec succès')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Créer une tâche'),
        actions: [
          if (_parsedGroupes.isNotEmpty && _parsedEmails.isNotEmpty)
            TextButton.icon(
              onPressed: _isLoading ? null : _createTache,
              icon: const Icon(Icons.check),
              label: const Text('Créer'),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nom et période
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informations générales', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la tâche',
                        hintText: 'Ex: Tâche Automne 2024',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<SessionType>(
                            value: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Période',
                              border: OutlineInputBorder(),
                            ),
                            items: SessionType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type == SessionType.automne ? 'Automne' : 'Hiver'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedType = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Année',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(10, (index) {
                              final year = DateTime.now().year - 2 + index;
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedYear = value);
                              }
                            },
                          ),
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
                        Expanded(
                          child: Text(
                            'Enseignants',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(
                          label: Text('${_parsedEmails.length}'),
                          avatar: const Icon(Icons.person, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Collez une liste de courriels (séparés par espaces, virgules ou nouvelles lignes)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'prof1@exemple.com, prof2@exemple.com',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _parseEmails(),
                    ),
                    if (_parsedEmails.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _parsedEmails.map((email) {
                          return Chip(
                            label: Text(email, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _parsedEmails.remove(email);
                                _emailsController.text = _parsedEmails.join(', ');
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Groupes
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Groupes-cours',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(
                          label: Text('${_parsedGroupes.length}'),
                          avatar: const Icon(Icons.group, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Format CSV: Cours, NuméroGroupe, NbÉtudiants, HeuresThéorie, HeuresPratique',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exemple: Programmation I, 1010, 35, 45, 30',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _csvController,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Collez votre CSV ici...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _parseCSV,
                            icon: const Icon(Icons.preview),
                            label: const Text('Analyser CSV'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _addGroupeManually,
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter manuellement'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Liste des groupes parsés
            if (_parsedGroupes.isNotEmpty)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Aperçu des groupes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _parsedGroupes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final groupe = _parsedGroupes[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text('${groupe.cours} - ${groupe.numeroGroupe}'),
                          subtitle: Text(
                            '${groupe.nombreEtudiants} ét. • ${groupe.heuresTheorie}h théo • ${groupe.heuresPratique}h prat',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${groupe.heuresTheorie.toInt()}T/${groupe.heuresPratique.toInt()}P',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _parsedGroupes.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddGroupeDialog extends StatefulWidget {
  final Function(Groupe) onAdd;
  final String tempTacheId;
  final int index;

  const _AddGroupeDialog({
    required this.onAdd,
    required this.tempTacheId,
    required this.index,
  });

  @override
  State<_AddGroupeDialog> createState() => _AddGroupeDialogState();
}

class _AddGroupeDialogState extends State<_AddGroupeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _coursController = TextEditingController();
  final _numeroController = TextEditingController();
  final _etudiantsController = TextEditingController();
  final _theorieController = TextEditingController();
  final _pratiqueController = TextEditingController();

  @override
  void dispose() {
    _coursController.dispose();
    _numeroController.dispose();
    _etudiantsController.dispose();
    _theorieController.dispose();
    _pratiqueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un groupe'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _coursController,
                decoration: const InputDecoration(
                  labelText: 'Nom du cours',
                  hintText: 'Programmation I',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _numeroController,
                decoration: const InputDecoration(
                  labelText: 'Numéro du groupe',
                  hintText: '1010',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _etudiantsController,
                decoration: const InputDecoration(
                  labelText: 'Nombre d\'étudiants',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _theorieController,
                decoration: const InputDecoration(
                  labelText: 'Heures de théorie',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pratiqueController,
                decoration: const InputDecoration(
                  labelText: 'Heures de pratique',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final groupe = Groupe(
                id: '${widget.tempTacheId}_groupe_${widget.index}',
                cours: _coursController.text.trim(),
                numeroGroupe: _numeroController.text.trim(),
                nombreEtudiants: int.parse(_etudiantsController.text),
                heuresTheorie: double.parse(_theorieController.text),
                heuresPratique: double.parse(_pratiqueController.text),
                tacheId: widget.tempTacheId,
              );
              widget.onAdd(groupe);
              Navigator.pop(context);
            }
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
