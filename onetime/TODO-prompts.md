# TODO
- implanter un mode payant pour débloquer:
  - envoi de fichier de plus de 1 Mo
  - nombre illimité de messages stockés (avant lecture de tous)
- Placer le séparateur de message dans le gros blob de messages
- Optimiser encodage QR (binaire au lieu de JSON/Base64) pour 3x plus de données
- Augmenter taille QR à 2048-2953 bytes (version 40)

# Done
## 2026-01-12: Renommage collection Firestore
- ✅ Renommé collection `key_exchange_sessions` en `kex` pour plus de concision
- ✅ Mis à jour firestore.rules
- ✅ Mis à jour conversation_service.dart
- ✅ Mis à jour key_exchange_sync_service.dart
- ✅ Mis à jour les tests firestore.rules.test.js

## 2026-01-12: Synchronisation en arrière-plan des messages
- ✅ Création du service `BackgroundMessageSyncService` pour décorréler le transfert de la lecture
- ✅ Auto-décryptage des messages entrants en arrière-plan
- ✅ Marquage comme "transféré" (pas "lu") lors du décryptage automatique
- ✅ Stockage local des messages non lus
- ✅ Affichage des compteurs de messages non lus dans HomeScreen
- ✅ Titre de conversation en gras quand messages non lus
- ✅ Badge avec le nombre de messages non lus
- ✅ Marquage comme "lu" uniquement à l'ouverture de la conversation
- ✅ Intégration dans main.dart (démarrage à l'authentification, arrêt à la déconnexion)

## 2026-01-11: Améliorations UX et Export/Import
- ✅ Export/Import de conversations vers un autre appareil
- ✅ Export d'une conversation unique (conversation info screen)
- ✅ Export/Import de toutes les conversations (profile screen)
- ✅ Indicateurs d'état des messages améliorés (cloud avec contenu, cloud sans contenu, local)
- ✅ Fermeture automatique de la caméra quand un peer termine son scan
- ✅ Affichage des barres de progression de tous les peers triées par avancement
- ✅ Fix permission denied lors de la suppression de conversation
- ✅ Vérification de la persistence des données d'image avant suppression cloud

## 2026-01-09: App ID Change
- ✅ Renamed package to `org.deguet.jo.onetime` (Android & iOS)

## 2026-01-08: Polissage UI et Securité
- ✅ Key Truncation: suppression des bits utilisés pour forward secrecy
- ✅ Règles Firestore strictes (participants uniquement)
- ✅ Fix scroll infini et bouton redondant dans le chat
- ✅ UX Scan QR: feedback haptique et anti-rebond

## 2026-01-07: Suppression du numéro de téléphone
- ✅ Remplacement du numéro de téléphone par un UUID généré aléatoirement
- ✅ Écran de login simplifié: demande uniquement le pseudo
- ✅ AuthService génère un ID unique (uuid v4) au lieu de normaliser un numéro
- ✅ UserProfile mis à jour: initiales basées sur les 2 premiers caractères de l'UUID
- ✅ ProfileScreen: affiche l'ID court (8 premiers caractères) au lieu du numéro
- ✅ HomeScreen: affiche le shortId dans l'AppBar
- ✅ ConversationDetailScreen: affichage mis à jour pour les IDs utilisateur
- ✅ Ajout du package uuid (4.5.2) aux dépendances
- ✅ Mise à jour de tous les commentaires faisant référence aux numéros de téléphone

## 2026-01-07: Mode Torrent pour échange de clés
- ✅ Implémenté mode "torrent-like" avec rotation rapide (100ms) des QR codes
- ✅ Affiche uniquement les segments non-complets (skip automatique des segments scannés par tous)
- ✅ Génération de tous les segments à l'avance (pas un par un)
- ✅ Indicateur visuel du segment actuel (badge "3/10" sur le QR)
- ✅ Timer périodique avec recherche circulaire du prochain segment incomplet
- ✅ Arrêt automatique quand tous les segments sont complets
- ✅ Instructions mises à jour pour indiquer le mode torrent actif