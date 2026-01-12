import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart';
import 'services/key_pre_generation_service.dart';
import 'services/pseudo_storage_service.dart';
import 'services/background_message_sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'l10n/app_localizations.dart';

// Ajout : options générées par FlutterFire CLI
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Utiliser les options générées pour initialiser Firebase (évite le besoin du plist dans le projet iOS)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialiser le service de pré-génération de clés
  KeyPreGenerationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('theme_mode') ?? 'system';
    setState(() {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == themeModeString,
        orElse: () => ThemeMode.system,
      );
    });
  }

  void _updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneTime Pad',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
      ],
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: AuthWrapper(onThemeModeChanged: _updateThemeMode),
    );
  }
}

/// Wrapper qui redirige selon l'état d'authentification
class AuthWrapper extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  
  const AuthWrapper({super.key, this.onThemeModeChanged});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final BackgroundMessageSyncService _bgSync = BackgroundMessageSyncService();
  bool _isLoading = true;
  bool _isSignedIn = false;

  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    // Écouter les changements d'état d'authentification (ex: suppression de compte)
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) => _checkAuth());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _bgSync.stopSync(); // Arrêter la sync en arrière-plan
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final isSignedIn = await _authService.initialize();
    final myPseudo = await PseudoStorageService().getMyPseudo();
    
    if (mounted) {
      setState(() {
        // On considère connecté seulement si Auth Firebase OK ET Pseudo défini
        _isSignedIn = isSignedIn && myPseudo != null && myPseudo.isNotEmpty;
        _isLoading = false;
      });
      
      // Démarrer la synchronisation en arrière-plan si connecté
      if (_isSignedIn) {
        debugPrint('[App] User authenticated, starting background message sync');
        await _bgSync.startSync();
      } else {
        debugPrint('[App] User not authenticated, stopping background sync');
        await _bgSync.stopSync();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isSignedIn) {
      return HomeScreen(onThemeModeChanged: widget.onThemeModeChanged);
    }

    return const LoginScreen();
  }
}
