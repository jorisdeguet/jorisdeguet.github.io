import 'package:flutter/material.dart';
import '../../widgets/pixel_card.dart';

/// Écran de démonstration du thème rétro 8-bits
class RetroThemeDemoScreen extends StatelessWidget {
  const RetroThemeDemoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RETRO 8-BITS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Titre principal
          const Text(
            'SUPERTACHE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Exemples de cartes pixelisées
          PixelSection(
            title: 'STATISTIQUES',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: const [
                          Icon(Icons.people, size: 32),
                          SizedBox(height: 8),
                          Text(
                            '25',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('PROFS'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: const [
                          Icon(Icons.group, size: 32),
                          SizedBox(height: 8),
                          Text(
                            '48',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('GROUPES'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const PixelBadge(text: 'ACTIF'),
              const PixelBadge(
                text: 'EN COURS',
                backgroundColor: Colors.white,
                textColor: Colors.black,
              ),
              const PixelBadge(text: 'TERMINE'),
            ],
          ),
          const SizedBox(height: 24),

          // Barre de progression
          const Text('PROGRESSION', style: TextStyle(fontSize: 10)),
          const SizedBox(height: 8),
          const PixelProgressBar(value: 0.65),
          const SizedBox(height: 24),

          // Boutons
          PixelButton(
            text: 'COMMENCER',
            icon: Icons.play_arrow,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('BOUTON PRESSE!')),
              );
            },
          ),
          const SizedBox(height: 16),

          PixelButton(
            text: 'OPTIONS',
            icon: Icons.settings,
            backgroundColor: Colors.white,
            textColor: Colors.black,
            onPressed: () {},
          ),
          const SizedBox(height: 24),

          // Liste avec cartes pixelisées
          const Text(
            'TACHES',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          PixelCard(
            onTap: () {},
            child: const Row(
              children: [
                Icon(Icons.check_box, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TACHE 1',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'DESCRIPTION',
                        style: TextStyle(fontSize: 7),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
          PixelCard(
            child: const Row(
              children: [
                Icon(Icons.check_box_outline_blank, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TACHE 2',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'EN ATTENTE',
                        style: TextStyle(fontSize: 7),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

