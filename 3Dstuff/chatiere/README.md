# Chatière d'hiver

Fenêtre coulissante de sous-sol dans une margelle. Le panneau gris avec un trou
hexagonal bouché par une serviette laisse passer beaucoup d'air.
Embrasure intérieure : 368 mm (14,5 po) de haut, environ 305 mm (12 po) de profondeur.

Concepts :

- **[A. SAS](A-sas/)** : une boîte en contreplaqué sur l'appui forme un sas, avec un volet dans la fenêtre. Côté pièce, un module imprimé à **porte relevable** s'ouvre quand le chat pose les pattes sur un rebord (section 13 du README de A).
- **[B. Battant](B-battant/)** : à la place de la porte relevable, dans la même encoche, un module imprimé à **battant pivotant** sur un axe vertical.

| | A. Porte relevable | B. Battant pivotant |
|---|---|---|
| Principe | Le chat appuie sur un rebord, deux leviers en bascule montent la porte. | Le chat pousse un battant qui tourne autour d'un axe vertical, un peu à droite du milieu. |
| Pièces | 9 : cadre, couvercle, porte, 2 leviers, 2 coulisseaux, 2 rebords | 3 : cadre, couvercle, battant |
| Passage | 130 × 110, un seul passage, rien à pousser | 210 × 125 divisé par le battant : 89 mm de large en sortant du sas, 112 mm en venant de la pièce |
| Seuil au-dessus du plancher | 33 mm | 30 mm (réglable) |
| Taille réelle | 252 × 282 × 24 : **ne tient pas sur un plateau de 260** | 253 × 184 × 24 : tient |
| Étanchéité | Feutre sur les deux faces de la porte | Butées à recouvrement sur les quatre côtés de chaque moitié, feutre |
| Retour | Poids de la porte, élastiques en appoint | Un élastique en haut ; le vent du dehors le referme aussi |
| Pour le chat | Il faut qu'il pose les pattes sur le rebord ; la porte ne touche pas son dos | Il pousse de la tête, comme une chatière classique, mais **toujours sur sa droite** |
| Points faibles | Hauteur, nombre de pièces, frottements à régler | Passages plus étroits ; si le chat pousse du mauvais côté, le battant ne bouge pas |

La vitre de 411 × 309 sert de façade, sans la couper. La fuite estimée passe d'environ 90 W avec la serviette à environ 15 W.

Deux autres concepts ont été étudiés puis abandonnés : un panneau isolé dans la coulisse, et une contre-fenêtre qui fermait toute l'embrasure. Ils restent dans l'historique git (commit 8cdf705).

À retenir :

- Presque tout le gain vient du remplacement de la serviette par **un volet bien jointé** (aimants, joint brosse, paroi étanche). Un deuxième volet en série protège surtout des rafales et de la neige.
- **Verre** : vérifier s'il est trempé (marque gravée dans un coin). Le verre trempé et le verre double (thermos) ne se coupent pas.
- **Matière** :
  - le volet dans la fenêtre doit être en **PETG**, car le froid, le soleil et le givre abîment le PLA ;
  - le module de porte, à l'intérieur, peut être en PLA.
