import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/voting/vote_repartitions_screen.dart';
import 'screens/taches/view_tache_screen.dart';
import 'screens/repartitions/repartition_list_screen.dart';
import 'screens/repartitions/view_generated_solutions_screen.dart';
import 'theme/retro_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
      ],
      child: MaterialApp(
        title: 'SuperTâche',
        theme: RetroTheme.theme,
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          // Extraire les paramètres de l'URL
          final uri = Uri.parse(settings.name ?? '');

          // Route: /tache/:tacheId
          if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'tache') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => ViewTacheScreen(tacheId: tacheId),
              settings: settings,
            );
          }

          // Route: /tache/:tacheId/repartitions
          if (uri.pathSegments.length == 3 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'repartitions') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => RepartitionListScreen(tacheId: tacheId),
              settings: settings,
            );
          }

          // Route: /tache/:tacheId/compare
          if (uri.pathSegments.length == 3 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'compare') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => ViewGeneratedSolutionsScreen(
                tacheId: tacheId,
                generationId: 'latest',
              ),
              settings: settings,
            );
          }

          // Route: /tache/:tacheId/vote
          if (uri.pathSegments.length == 3 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'vote') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => VoteRepartitionsScreen(
                tacheId: tacheId,
                generationId: 'latest',
              ),
              settings: settings,
            );
          }

          // Route par défaut
          return null;
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}
