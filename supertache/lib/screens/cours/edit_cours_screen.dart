import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../models/cours.dart';
import '../../widgets/app_drawer.dart';

class EditCoursScreen extends StatefulWidget {
  final Cours cours;

  const EditCoursScreen({super.key, required this.cours});

  @override
  State<EditCoursScreen> createState() => _EditCoursScreenState();
}

class _EditCoursScreenState extends State<EditCoursScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _codeSimpleController;
  late TextEditingController _titreController;
  late TextEditingController _theorieController;
  late TextEditingController _laboController;
  
  bool _automne = false;
  bool _hiver = false;
  bool _toute = false;
  bool _ete = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.cours.code);
    _codeSimpleController = TextEditingController(text: widget.cours.codeSimple);
    _titreController = TextEditingController(text: widget.cours.titre);
    _theorieController = TextEditingController(text: widget.cours.heuresTheorie.toString());
    _laboController = TextEditingController(text: widget.cours.heuresLaboratoire.toString());
    
    // Initialiser les checkboxes
    if (widget.cours.sessions.contains('A-H')) {
      _toute = true;
    } else if (widget.cours.sessions.contains('A-É')) {
      _automne = true;
      _ete = true;
    } else {
      _automne = widget.cours.sessions.contains('A');
      _hiver = widget.cours.sessions.contains('H');
      _ete = widget.cours.sessions.contains('É');
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeSimpleController.dispose();
    _titreController.dispose();
    _theorieController.dispose();
    _laboController.dispose();
    super.dispose();
  }

  List<String> _getSessions() {
    if (_toute) return ['A-H'];
    if (_automne && _ete && !_hiver) return ['A-É'];
    
    final sessions = <String>[];
    if (_automne) sessions.add('A');
    if (_hiver) sessions.add('H');
    if (_ete) sessions.add('É');
    return sessions;
  }

  Future<void> _saveCours() async {
    if (!_formKey.currentState!.validate()) return;
    
    final sessions = _getSessions();
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins une session')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedCours = widget.cours.copyWith(
        code: _codeController.text.trim(),
        codeSimple: _codeSimpleController.text.trim(),
        titre: _titreController.text.trim(),
        heuresTheorie: int.parse(_theorieController.text),
        heuresLaboratoire: int.parse(_laboController.text),
        sessions: sessions,
      );

      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      await firestoreService.updateCours(updatedCours);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cours mis à jour')),
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
        title: const Text('Modifier le cours'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveCours,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informations du cours', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Code complet',
                        hintText: '420-1P6',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codeSimpleController,
                      decoration: const InputDecoration(
                        labelText: 'Code simple',
                        hintText: '1P6',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titreController,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        hintText: 'Introduction à la programmation',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pondérations', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _theorieController,
                            decoration: const InputDecoration(
                              labelText: 'Heures théorie',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requis';
                              if (int.tryParse(v) == null) return 'Nombre invalide';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _laboController,
                            decoration: const InputDecoration(
                              labelText: 'Heures laboratoire',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requis';
                              if (int.tryParse(v) == null) return 'Nombre invalide';
                              return null;
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

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sessions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _toute,
                      onChanged: (value) {
                        setState(() {
                          _toute = value ?? false;
                          if (_toute) {
                            _automne = false;
                            _hiver = false;
                            _ete = false;
                          }
                        });
                      },
                      title: const Text('Toute l\'année (Automne et Hiver)'),
                      dense: true,
                    ),
                    if (!_toute) ...[
                      CheckboxListTile(
                        value: _automne,
                        onChanged: (value) => setState(() => _automne = value ?? false),
                        title: const Text('Automne'),
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: _hiver,
                        onChanged: (value) => setState(() => _hiver = value ?? false),
                        title: const Text('Hiver'),
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: _ete,
                        onChanged: (value) => setState(() => _ete = value ?? false),
                        title: const Text('Été'),
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _saveCours,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Enregistrer les modifications'),
              ),
          ],
        ),
      ),
    );
  }
}
