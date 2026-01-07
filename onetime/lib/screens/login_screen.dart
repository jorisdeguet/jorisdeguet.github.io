import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/pseudo_storage_service.dart';
import 'home_screen.dart';

/// Écran de création de profil (première utilisation).
/// Demande uniquement un pseudo à l'utilisateur.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final PseudoStorageService _pseudoService = PseudoStorageService();
  final _pseudoController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pseudoController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    final pseudo = _pseudoController.text.trim();

    if (pseudo.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer un pseudo');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.createUser();

      // Stocker le pseudo localement (jamais sur le serveur)
      await _pseudoService.setMyPseudo(pseudo);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Titre
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  '1 time',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Messagerie chiffrée inviolable',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),

                // Message d'erreur
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Contenu
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  _buildPhoneEntry(),

                const SizedBox(height: 32),

                // Texte explicatif
                Text(
                  'Votre pseudo est stocké uniquement sur cet appareil.\n'
                  'Il sera partagé de manière chiffrée avec vos contacts.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneEntry() {
    return Column(
      children: [
        Text(
          'Choisissez votre pseudo',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),

        // Champ pseudo
        TextField(
          controller: _pseudoController,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Pseudo',
            hintText: 'Ex: Alice, Bob...',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            helperText: 'Stocké uniquement sur votre appareil',
          ),
          onSubmitted: (_) => _createProfile(),
        ),
        const SizedBox(height: 24),

        // Bouton créer
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _createProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Commencer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }
}
