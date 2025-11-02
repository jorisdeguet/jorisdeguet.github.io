import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/voting/vote_repartitions_screen.dart';
import 'screens/taches/view_tache_screen.dart';
import 'screens/taches/create_tache_screen.dart';
import 'screens/repartitions/repartition_detail_screen.dart';
import 'screens/repartitions/create_repartition_screen.dart';
import 'screens/repartitions/manual_repartition_screen.dart';
import 'screens/repartitions/generate_repartitions_screen.dart';
import 'screens/repartitions/live_generation_screen.dart';
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
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.theme,
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '');

          // Route: /login
          if (settings.name == '/login') {
            return MaterialPageRoute(
              builder: (context) => const LoginScreen(),
              settings: settings,
            );
          }

          // Route: /signup
          if (settings.name == '/signup') {
            return MaterialPageRoute(
              builder: (context) => const SignupScreen(),
              settings: settings,
            );
          }

          // Route: /home
          if (settings.name == '/home') {
            return MaterialPageRoute(
              builder: (context) => const HomeScreen(),
              settings: settings,
            );
          }

          // Route: /tache/create
          if (settings.name == '/tache/create') {
            return MaterialPageRoute(
              builder: (context) => const CreateTacheScreen(),
              settings: settings,
            );
          }

          // Route: /tache/:tacheId
          if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'tache') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => ViewTacheScreen(tacheId: tacheId),
              settings: settings,
            );
          }

          // Route: /tache/:tacheId/repartitions/create
          if (uri.pathSegments.length == 4 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'repartitions' &&
              uri.pathSegments[3] == 'create') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => CreateRepartitionScreen(tacheId: tacheId),
              settings: settings,
            );
          }

          // Route: /tache/:tacheId/repartitions/generate
          if (uri.pathSegments.length == 4 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'repartitions' &&
              uri.pathSegments[3] == 'generate') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => GenerateRepartitionsScreen(tacheId: tacheId),
              settings: settings,
            );
          }

          // Route: /tache/:tacheId/repartitions/live
          if (uri.pathSegments.length == 4 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'repartitions' &&
              uri.pathSegments[3] == 'live') {
            final tacheId = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => LiveGenerationScreen(tacheId: tacheId),
              settings: settings,
            );
          }
          // Route: /tache/:tacheId/repartitions/:repartitionId/edit
          if (uri.pathSegments.length == 5 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'repartitions' &&
              uri.pathSegments[4] == 'edit') {
            final tacheId = uri.pathSegments[1];
            final repartitionId = uri.pathSegments[3];
            return MaterialPageRoute(
              builder: (context) => ManualRepartitionScreen(
                tacheId: tacheId,
                repartitionId: repartitionId,
              ),
              settings: settings,
            );
          }


          // Route: /tache/:tacheId/repartitions/:repartitionId
          if (uri.pathSegments.length == 4 &&
              uri.pathSegments[0] == 'tache' &&
              uri.pathSegments[2] == 'repartitions') {
            final tacheId = uri.pathSegments[1];
            final repartitionId = uri.pathSegments[3];
            return MaterialPageRoute(
              builder: (context) => RepartitionDetailScreen(
                tacheId: tacheId,
                repartitionId: repartitionId,
              ),
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
