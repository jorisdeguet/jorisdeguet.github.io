import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/enseignant.dart';
import '../screens/cours/cours_list_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/preferences/enseignant_preferences_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUser = authService.currentUser;
    final currentUserId = currentUser?.uid;

    if (currentUserId == null) {
      return const Drawer(
        child: Center(child: Text('Utilisateur non connecté')),
      );
    }

    return Drawer(
      child: StreamBuilder<Enseignant?>(
        stream: firestoreService.getEnseignantStream(currentUserId),
        builder: (context, snapshot) {
          // Afficher un indicateur de chargement seulement pendant le chargement initial
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final enseignant = snapshot.data;
          // Utiliser l'email de l'utilisateur Firebase si le profil n'existe pas encore
          final displayName = enseignant?.displayName ?? currentUser?.email?.split('@')[0] ?? 'Utilisateur';
          final email = enseignant?.email ?? currentUser?.email ?? '';
          
          final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
          
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
                accountName: Text(
                  displayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(email),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    initial,
                    style: TextStyle(fontSize: 32, color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Accueil'),
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('Catalogue des cours'),
                onTap: () {
                  Navigator.pop(context);
                  // Vérifier si on n'est pas déjà sur l'écran du catalogue
                  if (ModalRoute.of(context)?.settings.name != '/cours') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CoursListScreen(),
                        settings: const RouteSettings(name: '/cours'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Mon profil'),
                onTap: () {
                  Navigator.pop(context);
                  // Vérifier si on n'est pas déjà sur l'écran du profil
                  if (ModalRoute.of(context)?.settings.name != '/profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                        settings: const RouteSettings(name: '/profile'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Mes préférences'),
                onTap: () {
                  Navigator.pop(context);
                  if (ModalRoute.of(context)?.settings.name != '/preferences') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EnseignantPreferencesScreen(),
                        settings: const RouteSettings(name: '/preferences'),
                      ),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  await authService.signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
