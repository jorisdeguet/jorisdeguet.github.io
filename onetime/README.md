# One-Time Pad - Secure Messaging Application

Application Flutter pour chiffrement One-Time Pad avec échange de clé local.

## Architecture

### Services

#### 1. RandomKeyGeneratorService
Génération de clés aléatoires avec source d'entropie caméra.
- Utilise les variations RGB entre pixels comme source d'entropie
- XOR avec CSPRNG pour renforcer l'aléatoire
- Tests statistiques intégrés (Chi², fréquence, runs)
- Capacité QR code: ~23200 bits max, 8192 bits recommandé

#### 2. KeyExchangeService
Échange local de clé via QR code.
- Source affiche les QR codes avec les bits de clé
- Lecteurs scannent et confirment via réseau (index uniquement)
- Les bits de clé ne transitent JAMAIS sur le réseau
- Support de l'agrandissement de clé existante

#### 3. CryptoService
Chiffrement/déchiffrement One-Time Pad.
- XOR du message avec la clé
- Gestion automatique des segments par peer
- Support des longs messages (multi-segments)
- Mode ultra-secure avec suppression après lecture

#### 4. FirebaseMessageService
Communication cloud sécurisée.
- Locks transactionnels avant envoi
- Synchronisation des segments utilisés
- Confirmation d'échange de clé (indices seulement)
- Support du mode suppression après lecture

#### 5. AuthService
Authentification fédérée Firebase.
- Google Sign-In
- Apple Sign-In
- Facebook Login
- Microsoft Authentication
- GitHub OAuth
- Gestion du profil et déconnexion

#### 6. ContactsService
Gestion des contacts.
- Import depuis le répertoire téléphone
- Vérification des utilisateurs OneTime
- Stockage local des contacts
- Association avec les clés partagées

### Modèles

#### SharedKey
Clé partagée avec métadonnées.
- Division automatique en segments par peer (ID croissant)
- Bitmap d'utilisation pour éviter réutilisation
- Méthodes d'extension et compaction

#### KeySegment
Représente un segment de clé utilisé.
- Tracking de l'utilisation (peer, timestamp)
- Détection de chevauchement

#### EncryptedMessage
Message chiffré prêt pour transmission.
- Support multi-segments pour longs messages
- Métadonnées pour déchiffrement

#### UserProfile
Profil utilisateur authentifié.
- Informations du provider
- Gestion des initiales/avatar

#### Contact
Contact de l'application.
- Lien avec contacts téléphone
- Statut utilisateur OneTime
- Association clé partagée

### Écrans

#### LoginScreen
Écran de connexion avec boutons pour chaque provider OAuth:
- Google (blanc/gris)
- Apple (noir)
- Facebook (bleu)
- Microsoft (bleu clair)
- GitHub (gris foncé)

#### HomeScreen
Écran principal avec:
- Onglet Messages (conversations)
- Onglet Contacts
- Accès au profil via avatar

#### ProfileScreen
Gestion du profil:
- Avatar et informations
- Badge du provider utilisé
- Dates de création/connexion
- Bouton déconnexion
- Suppression de compte

#### ContactsScreen
Liste des contacts:
- Recherche
- Badge "OneTime" pour utilisateurs de l'app
- Icône clé si clé partagée existe
- Actions: créer clé, envoyer message, supprimer

#### ContactPickerScreen
Import de contacts téléphone:
- Demande de permission
- Mise en avant des utilisateurs OneTime
- Recherche
- Import en un tap

## Protocole d'échange de clé

### Échange initial (2+ personnes)
1. **Source** génère une clé aléatoire
2. **Source** affiche QR codes segment par segment (1024 octets chacun)
3. **Lecteurs** scannent chaque QR code
4. **Lecteurs** confirment via cloud/radio: `{sessionId, peerId, segmentIndex}`
5. **Important**: Seuls les INDEX sont envoyés, jamais les bits

### Agrandissement de clé
1. Créer une session d'extension sur la clé existante
2. Répéter le protocole d'échange pour les nouveaux segments
3. La nouvelle clé est concaténée à l'existante

## Stratégie d'utilisation de la clé

### Pour 2 peers
- Peer avec ID le plus bas: utilise depuis le début
- Peer avec ID le plus haut: utilise depuis la fin

### Pour N peers
- Peers triés par ID croissant
- Peer i utilise le segment `[i*length/N, (i+1)*length/N[`

## Mode Ultra-Secure

1. Message chiffré et envoyé
2. Destinataire déchiffre
3. **Suppression immédiate** de:
   - Message sur le cloud
   - Bits de clé locaux (mis à zéro)
4. Le message ne peut plus jamais être déchiffré

## Configuration Firebase

### firebase_options.dart
Créer le fichier avec FlutterFire CLI:
```bash
flutterfire configure
```

### Providers à activer dans Firebase Console
1. Authentication > Sign-in method
2. Activer: Google, Apple, Facebook, Microsoft, GitHub
3. Configurer les Client IDs pour chaque provider

## Tests

```bash
flutter test
```

Tests inclus:
- Chi² pour uniformité du générateur
- Test de fréquence (proportion 0/1)
- Test des runs (séquences consécutives)
- Chiffrement/déchiffrement
- Gestion des segments

## Capacité QR Code

| Version | Octets max | Bits |
|---------|------------|------|
| 10 | 174 | 1,392 |
| 15 | 412 | 3,296 |
| 20 | 666 | 5,328 |
| 25 | 1,024 | 8,192 |
| 30 | 1,370 | 10,960 |
| 40 | 2,953 | 23,624 |

## Dépendances

```yaml
dependencies:
  # Firebase
  firebase_core: ^3.8.1
  firebase_auth: ^5.3.4
  cloud_firestore: ^5.6.0
  
  # Auth providers
  google_sign_in: ^6.2.2
  sign_in_with_apple: ^6.1.4
  flutter_facebook_auth: ^7.1.1
  
  # Contacts
  flutter_contacts: ^1.1.9+2
  
  # QR Code
  qr_flutter: ^4.1.0
  mobile_scanner: ^6.0.2
  
  # Camera for entropy
  camera: ^0.11.0+2
  
  # Local storage
  shared_preferences: ^2.3.4
```
