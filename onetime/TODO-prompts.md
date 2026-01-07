# TODO
- implanter un mode payant pour débloquer:
  - envoi de fichier de plus de 1 Mo
  - nombre illimité de messages stockés (avant lecture de tous)
- Placer le séparateur de message dans le gros blob de messages
- Optimiser encodage QR (binaire au lieu de JSON/Base64) pour 3x plus de données
- Augmenter taille QR à 2048-2953 bytes (version 40)

# Done
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