import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/enseignant.dart';
import '../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUserId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Mon profil'),
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<Enseignant?>(
        future: firestoreService.getEnseignant(currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final enseignant = snapshot.data;
          if (enseignant == null) {
            return const Center(child: Text('Profil non trouvé'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    enseignant.email.isNotEmpty ? enseignant.email[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 48, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle: Text(enseignant.email),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.badge),
                          title: const Text('Identifiant'),
                          subtitle: Text(enseignant.displayName),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Se déconnecter'),
                    onTap: () async {
                      await authService.signOut();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
