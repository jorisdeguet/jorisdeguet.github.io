# TODO payant
- implanter un mode payant pour débloquer:
  - envoi de fichier de plus de 1 Mo
  - nombre illimité de messages stockés (avant lecture de tous)
- Placer le séparateur de message dans le gros blob de messages
- Optimiser encodage QR (binaire au lieu de JSON/Base64) pour 3x plus de données
- Augmenter taille QR à 2048-2953 bytes (version 40)
- solliciter un don de temps en temps


# TODO core 
- réfléchir aux identifiants 1) conversation a un id généré, la clé partagée a le même id 3) l'id de l'échange de clé est généré 4) l'id du message dans une conversation est son interval start-end
- s'assurer qu'on peut créer supprimer des conversations et qu'on retourne à l'accueil
- marquer correctement les messages / intervalles lus
- avoir un service pour envoi de messages et réception (listener) appelé message_service qui combine background_message_service et les fonctions d'envoi qui sont pour l'instant dans le code de GUI
- s'assurer d'avoir idempotence sur tout
- merger les services comme key_service qui regroupe stockage et manipulation des clés
- focus sur la valeur, dégager le random gen en extra
- centraliser les service dans des singletons gérés par getit 