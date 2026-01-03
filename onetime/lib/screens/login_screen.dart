import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

/// Écran de connexion avec authentification fédérée.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signIn(Future<dynamic> Function() signInMethod, String providerName) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await signInMethod();
      if (result != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Erreur de connexion avec $providerName');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                  'OneTime Pad',
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

                // Boutons de connexion
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  // Google
                  _AuthButton(
                    onPressed: () => _signIn(_authService.signInWithGoogle, 'Google'),
                    icon: Icons.g_mobiledata,
                    label: 'Continuer avec Google',
                    backgroundColor: Colors.white,
                    textColor: Colors.black87,
                    borderColor: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),

                  // Apple
                  _AuthButton(
                    onPressed: () => _signIn(_authService.signInWithApple, 'Apple'),
                    icon: Icons.apple,
                    label: 'Continuer avec Apple',
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 12),

                  // Facebook
                  _AuthButton(
                    onPressed: () => _signIn(_authService.signInWithFacebook, 'Facebook'),
                    icon: Icons.facebook,
                    label: 'Continuer avec Facebook',
                    backgroundColor: const Color(0xFF1877F2),
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 12),

                  // Microsoft
                  _AuthButton(
                    onPressed: () => _signIn(_authService.signInWithMicrosoft, 'Microsoft'),
                    icon: Icons.window,
                    label: 'Continuer avec Microsoft',
                    backgroundColor: const Color(0xFF00A4EF),
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 12),

                  // GitHub
                  _AuthButton(
                    onPressed: () => _signIn(_authService.signInWithGitHub, 'GitHub'),
                    icon: Icons.code,
                    label: 'Continuer avec GitHub',
                    backgroundColor: const Color(0xFF24292E),
                    textColor: Colors.white,
                  ),
                ],

                const SizedBox(height: 32),

                // Texte légal
                Text(
                  'En continuant, vous acceptez nos\nConditions d\'utilisation et Politique de confidentialité',
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
}

/// Bouton d'authentification stylisé
class _AuthButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const _AuthButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor ?? backgroundColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
