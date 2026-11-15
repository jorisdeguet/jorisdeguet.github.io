# Chatière d'hiver — Concept C : « contre-fenêtre » qui ferme toute la niche

> On ne touche pas à la fenêtre coulissante ni au panneau gris à trou hexagonal.
> On construit **un deuxième mur isolé et étanche** en travers de la niche, côté pièce,
> avec du vitrage pour la lumière et **une seule bonne chatière**. La niche devient un
> **sas tampon** froid entre l'extérieur et le sous-sol.

Fichiers :

| Fichier | Rôle |
|---|---|
| `contre_fenetre.scad` | OpenSCAD paramétrique : pièces imprimées + vue `assembled` |
| `apercu_interieur.png` / `apercu_exterieur.png` | rendus de la vue assemblée (niche 850 mm, double vitrage) |

Toutes les pièces imprimées tiennent dans 260 × 260 × 260 mm (vérifié au rendu, voir § 8).

---

## 1. Principe et croquis

```
COUPE VERTICALE (vue de côté)                     FACE (vue depuis le sous-sol, niche 850 mm)

  extérieur │ sas (niche)       │ pièce             ┌──────────────────────────────────────────┐
  (puits)   │                   │                   │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ traverse 1×3 ▓▓▓▓▓▓▓▓▓▓▓▓▓│
            │ linteau ──────────┼─┐                 │▓┌──────────────────┐▓┌─────────────────┐▓│
   fenêtre ─┤                   │█│ ← contre-       │▓│                  │▓│  XPS 1-1/2 po   │▓│
   coulis-  │                   │█│   fenêtre       │▓│  verre 411×309   │▓│  ┌───────────┐  │▓│
   sante +  │   ~305 mm d'appui │█│   (cadre 1×3,   │▓│  (double : les 2 │▓│  │ chatière  │  │▓│
   panneau  │   = zone d'atter- │█│   64 mm de      │▓│  carreaux en     │▓│  │ 160 × 170 │  │▓│
   à trou ──┤   rissage du chat │█│   profondeur)   │▓│  sandwich)       │▓│  │ aimants   │  │▓│
   hexa     │                   │▒│ ← chatière      │▓└──────────────────┘▓│  └───────────┘  │▓│
            │═══════ appui ═════╧═╧══               │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ traverse 1×3 ▓▓▓▓▓▓▓▓▓▓▓▓▓│
                                                    └──────────────────────────────────────────┘
   coupe-froid mousse compressé tout autour du cadre ┘   chatière du même côté que le trou hexagonal
```

- **Cadre** en 1×3 (19 × 64 mm réels) posé de chant : 19 mm vus de face, 64 mm de profondeur.
- **Pose en compression** : le cadre est 3 mm plus petit que la niche de chaque côté ; un
  coupe-froid en mousse le serre contre les joues, l'appui et le linteau. Aucune vis dans
  le mur → on le retire au printemps.
- **Travée vitrée** : un carreau 411 × 309 **non coupé**, tenu par des profilés en U imprimés
  avec ruban mousse (étanches à l'air). Par défaut les **deux carreaux en sandwich** (double
  vitrage maison, lame d'air 12 mm) — voir § 5, c'est ce qui évite la condensation.
- **Travée opaque** : panneau de polystyrène extrudé (XPS) 1-1/2 po, dans lequel on monte le
  cadre-tunnel de chatière imprimé (battant à charnière, 2 aimants, brosses « pile »).
- **Position** : affleurant à la face avant de la niche (`wall_pos = 0`) pour garder les
  305 mm d'appui comme zone d'atterrissage/sas. On peut reculer le mur (paramètre `wall_pos`)
  si on veut une tablette côté pièce.

## 2. Ça rentre ? — hauteur et largeur

**Hauteur (connue, 368 mm)** : 368 − 2 × 3 (coupe-froid) − 2 × 19 (traverses) = **324 mm**
de vide intérieur pour un verre de **309 mm** → il reste 7,5 mm de chaque côté : le profilé
en U a un fond plein de 5,5 mm, le verre s'engage de 8 mm. **Le verre passe sans coupe**,
couché (411 de large × 309 de haut). C'est juste, mais ça marche — à condition que le bois
fasse vraiment 19 mm (sinon le `.scad` lève une erreur `assert`).

**Largeur (INCONNUE)** : le `.scad` choisit la disposition tout seul selon `recess_w` :

| Largeur niche | Double vitrage (défaut) | Simple vitrage | Zone XPS + chatière |
|---|---|---|---|
| < 713 mm | pas de carreau entier → couper le verre ou polycarbonate | idem | toute la largeur |
| 750 mm | 1 travée (2 carreaux en sandwich) | 1 carreau | 261 mm |
| **850 mm** (rendu) | 1 travée | 1 carreau | 361 mm |
| 950 mm | 1 travée | 1 carreau | 461 mm |
| ≥ 1158 mm | 1 travée | **2 carreaux côte à côte** | ≥ 224 mm |

Formules : 1 travée si `W ≥ 713 mm` ; 2 travées côte à côte si `W ≥ 1158 mm`
(= 2·3 + 4·19 + 2·426 + 224). Au vu des photos (fenêtre de sous-sol standard ~32 po),
la niche fait probablement 800–950 mm → **1 travée vitrée + 1 travée XPS/chatière**.

## 3. Check-list de mesures (avant de couper quoi que ce soit)

1. **Largeur de la niche** à 3 hauteurs (bas, milieu, haut) **et** à la profondeur où ira le
   cadre (face avant, si `wall_pos = 0`). Garder la plus petite → `recess_w`.
2. **Hauteur** appui → linteau à gauche, au centre, à droite (on a 368 mm ; vérifier qu'il
   n'y a pas de pente/bosse) → `recess_h` = la plus petite.
3. **Équerrage** : diagonales de la niche en face avant. Écart > 6 mm → le coupe-froid
   plus épais (3/8 po) absorbera, sinon prévoir des cales.
4. **Profondeur utile** : appui de 305 mm, mais noter la marche (appui PVC blanc vs appui
   bois) visible sur la photo → le cadre doit porter sur une surface plane sur toute sa
   profondeur de 64 mm.
5. **Épaisseur réelle des carreaux** (pied à coulisse, 4 coins) → `glass_t`.
   Et **sont-ils trempés ?** (§ 6) — un verre trempé ne se coupe jamais.
6. **Épaisseur réelle du bois** acheté (un « 1×3 » fait 19 × 64, parfois 17,5) → `wood_t`, `wood_d`.
7. **Position du trou hexagonal** (gauche/droite, vu de l'intérieur) → `flap_side`. Sur la
   photo il est **à droite** vu de l'intérieur.
8. **Taille du chat** : hauteur au garrot et largeur d'épaules. 160 × 170 mm convient à un
   chat moyen ; un gros chat → `flap_w = 180`, `flap_h = 190` (reste < 260 mm imprimable).
9. **Hauteur de l'appui côté pièce** depuis le plancher : prévoir un marchepied / une
   tablette si le chat doit sauter (il atterrit sur le bas du cadre, seuil ≈ 50 mm).

## 4. Liste de coupe (exemple niche 850 × 368 mm — recalculer avec l'écho du `.scad`)

Ouvrir le `.scad` : la console affiche toutes les cotes pour la largeur saisie.

| Pièce | Qté | Section | Longueur | Formule |
|---|---|---|---|---|
| Traverse haute / basse | 2 | 1×3 (19 × 64) | **844 mm** | `W − 6` |
| Montant gauche / droit | 2 | 1×3 | **324 mm** | `H − 6 − 2·19` |
| Meneau (entre verre et XPS) | 1 | 1×3 | **324 mm** | idem ; posé à 426 mm du montant côté verre |
| Panneau XPS 1-1/2 po | 1 | 38 mm | **362 × 325 mm** | zone + 1 mm (serrage) |
| Trou dans l'XPS | 1 | — | **171 × 181 mm** | tunnel 170 × 180 + 1 mm |
| Profilés U horizontaux (imprimés) | 4 | — | 213 mm | `zone_g / 2` (2 en haut, 2 en bas) |
| Profilés U verticaux (imprimés, `clip_u_vert`) | 4 | — | 146,5 mm (2 bout à bout par côté) | `(324 − 2·15,5) / 2` |

Bois total : 2 × 844 + 3 × 324 = 2,66 m → **2 planches 1×3 de 8 pi** (une seule suffit si
on accepte un joint ; prendre 2 pour avoir une marge).

> Le profilé vertical fait 293 mm (> 260) : il est imprimé en deux moitiés (`part = "clip_u_vert"`).

## 5. Condensation : pourquoi double vitrage par défaut

Hypothèses : pièce 20 °C / 45 % HR (point de rosée ≈ 7,7 °C) ; sas ≈ −5 °C quand il fait
−10 °C dehors (le trou hexa reste ouvert, le sas est presque à température extérieure) ;
coefficient de surface intérieur hᵢ ≈ 7,7 W/m²K.

Température de la face intérieure du verre : `Ts = Tᵢ − (U / hᵢ) · (Tᵢ − T_sas)`

| Paroi vitrée | U (W/m²K) | Ts face pièce | Verdict |
|---|---|---|---|
| 1 carreau simple | ≈ 5,8 | **≈ +1 °C** | condensation / givre côté pièce tout l'hiver |
| 2 carreaux en sandwich, lame 12 mm | ≈ 2,8 | **≈ +11 °C** | OK jusqu'à ≈ −20 °C dehors à 45 % HR |
| verre + polycarbonate alvéolaire 8 mm | ≈ 2,5 | ≈ +12 °C | OK, moins transparent |

**Règle d'or des contre-fenêtres** : la paroi la plus étanche doit être **côté chaud**, la
plus perméable côté froid. C'est exactement le cas ici : notre mur (étanche) est côté pièce,
et le trou hexagonal ventile le sas vers l'extérieur → l'humidité qui y entre ressort. De
plus, en hiver un sous-sol est en **dépression** (effet cheminée) : l'air va de dehors vers
dedans à travers le sas, donc l'air humide de la maison ne s'y accumule pas.

Points à surveiller :
- **Double vitrage maison** : pas hermétique comme un vrai thermos. L'assembler par **temps
  froid et sec** (air sec piégé), entretoise = coupe-froid à cellules fermées 1/2 po sur le
  pourtour, un trait de silicone sur la tranche (pas sur les faces), un petit sachet de gel de
  silice coincé dans un coin. Si buée entre les vitres : ouvrir, sécher, refermer.
- Ne **pas** fermer le trou hexagonal par un panneau étanche *sans* chatière (le sas
  deviendrait un piège à humidité). Une chatière basique dans le trou (§ 9, scénario 3) est OK.
- Les coupe-froid du cadre restent côté chaud (bois sec) : pas de risque de pourriture.

## 6. Le verre : sans coupe, et si jamais il faut couper

**Sans coupe** : c'est le plan (411 × 309 tient à l'horizontale, cf. § 2).

**Vérifier d'abord si c'est du verre trempé** — un verre trempé **explose en granulés** si on
le raye : poinçon/gravure dans un coin (« tempered », « CAN/CGSB-12.1 ») ; ou regarder le
carreau à travers des lunettes polarisées / devant un écran LCD : des taches ou bandes
irisées = trempé. Trempé → on ne coupe pas, on passe au polycarbonate.

**Couper du verre recuit (float) ordinaire, 3–5 mm** :
1. Coupe-verre à molette carbure **à réservoir d'huile** (type pistolet, ~20–30 $), gants
   anti-coupure, lunettes, une règle de bois serrée par 2 serre-joints, un tapis/carton plat.
2. Nettoyer la ligne (alcool), marquer au feutre de chaque côté.
3. **Un seul passage**, d'un bord à l'autre sans s'arrêter, pression ferme et constante
   (≈ 4–7 kg), on doit entendre un « crrrr » régulier. **Ne jamais repasser** dans le trait.
4. Casser **tout de suite** : trait posé sur un goujon ou le bord de la table, appuyer d'un
   coup sec des deux côtés ; ou pince à détacher (« running pliers », ~15 $). Bandes < 25 mm :
   pince à gruger, petit à petit.
5. Adoucir les arêtes : papier abrasif à l'eau 220 sur une cale, ou pierre à aiguiser, à 45°.
6. S'exercer sur une chute. Alternative zéro risque : les vitreries / certaines quincailleries
   (Home Hardware, BMR, vitrerie locale) coupent pour ~5–15 $.

**Polycarbonate au lieu du verre** (si niche < 713 mm, verre trempé, ou pour la travée chatière) :
- Polycarbonate plein 2–3 mm (Lexan/Makrolon) : incassable, se coupe à la scie fine ou à la
  scie sauteuse lame métal ; ~40–60 $ la feuille 24 × 36 po. Se raye, jaunit un peu au soleil.
- **Polycarbonate alvéolaire 6–8 mm** (« serre ») : U ≈ 3,5, translucide, se coupe au couteau
  utilitaire, très léger ; ~50–70 $ la feuille 4 × 8 pi. Excellent compromis isolant/lumière.
- Acrylique (Plexiglas/Optix) : moins cher, se coupe par rainurage-cassure, mais casse sous
  un choc de chat → bof.
- Régler `glass_t` = épaisseur et `glazing = "simple"` ; les profilés U s'adaptent.

## 7. Nomenclature (prix approximatifs, Canada 2026, Rona/Home Depot/Canadian Tire/Amazon.ca)

| Article | Qté | Prix approx. |
|---|---|---|
| Planche 1×3 × 8 pi, épinette/pin | 2 | 12 $ |
| Panneau XPS 1-1/2 po (Foamular/Styrofoam), 2 × 8 pi ou panneau projet 2 × 2 pi | 1 | 12–30 $ |
| Coupe-froid mousse cellules fermées 3/8 × 3/8 po (ou profilé D EPDM) — périmètre cadre ≈ 2,5 m | 2 rouleaux | 20 $ |
| Ruban mousse mince 1/8 × 1/4 po (vitrage, dans les rainures des profilés) | 1 | 8 $ |
| Coupe-froid à poils (« pile ») 5 mm, autoadhésif | 1 | 10 $ |
| Aimants néodyme Ø6 × 3 mm (lot de 20) | 1 | 10 $ |
| Tige laiton/acier Ø3 mm (ou clou 1/8 po coupé) | 1 | 5 $ |
| Vis #6 × 5/8 po (profilés) + #8 × 2-1/2 po (assemblage du cadre) | — | 10 $ |
| Boulons M4 × 60 + rondelles (cadre-tunnel) | 4 | 5 $ |
| Silicone transparent (double vitrage maison) + sachet gel de silice | 1 | 10 $ |
| Ruban de construction rouge (Tuck Tape) pour joints XPS | 1 | 10 $ |
| 2 poignées de tiroir (pour retirer le cadre) | 2 | 6 $ |
| PETG ≈ 250 g | — | 8 $ |
| **Total** | | **≈ 125–150 $** |
| *Options* : coupe-verre à huile 25 $ ; pince à détacher 15 $ ; polycarbonate 40–70 $ ; chatière commerciale (Cat Mate / PetSafe, à monter dans l'XPS à la place du cadre imprimé) 40–60 $ | | |

## 8. Pièces imprimées (`contre_fenetre.scad`, paramètre `part`)

| `part` | Dimensions (défauts) | Qté | Notes d'impression |
|---|---|---|---|
| `clip_u` / `clip_u_vert` | 213 / 146,5 × 38 × 15,5 mm | 4 + 4 | fond à plat, PETG, 3 parois, 25 % ; rainures internes pour ruban mousse ; patte vissée côté pièce |
| `clip_corner` | 50 × 50 × 38 mm | 4 (mode `clips`) | posé sur une aile ; alternative légère aux profilés continus (étanchéité à compléter au ruban) |
| `flap_frame_main` | 214 × 224 × 46 mm | 1 | bride au plateau ; tunnel, trous de charnière, 2 poches d'aimants latérales, rainures « pile » sur les flancs et le seuil |
| `flap_frame_ring` | 214 × 224 × 4 mm | 1 | anneau de serrage, de l'autre côté de l'XPS |
| `flap` | 156 × 167 × 10 mm | 1 | à plat ; tube de charnière Ø10, bourrelet bas avec 2 poches d'aimants en bout. PETG (le PLA ramollit au soleil derrière une vitre) |

Contrôle : les 6 pièces ont été rendues en STL avec OpenSCAD 2021.01 sans erreur ; boîtes
englobantes ci-dessus, toutes ≤ 260 mm.

Paramètres clés : `recess_w`, `recess_h`, `wood_t`, `wood_d`, `glass_t`, `glazing`
(`double`/`simple`), `glazing_mode` (`continu`/`clips`), `flap_w`, `flap_h`, `panel_t`
(épaisseur XPS), `flap_side`, `wall_pos`. La console affiche la liste de coupe.

**Aimants** : 1 aimant dans chaque bout du bourrelet du battant + 1 dans chaque flanc du
tunnel, en **attraction** (vérifier la polarité avant de coller à la cyano/époxy). Le battant
bat dans les deux sens et revient au centre.

## 9. Bilan air / chaleur (ordres de grandeur)

Hypothèses : ΔT = 30 K (20 °C dedans, −10 °C dehors) ; différence de pression 5 Pa
(effet cheminée du sous-sol + un peu de vent dans le puits) ;
débit `Q = 0,61 · A_fuite · √(2ΔP/ρ)` ; perte = ρ·cp·Q·ΔT ; saison ≈ 4400 degrés-jours
(Montréal) ; électricité ≈ 0,08 $/kWh. Les surfaces de fuite équivalentes sont **estimées**
(fourchette ×2 dans chaque sens).

| Scénario | Fuite équiv. | Débit d'air | Perte moyenne* | Par saison |
|---|---|---|---|---|
| 1. Actuel : serviette dans le trou hexa | ~20 cm² | ~12 m³/h | **~135 W** | ~470 kWh ≈ 38 $ |
| 2. Concept C : contre-fenêtre + **1 chatière magnétique** (trou hexa laissé ouvert) | ~6 cm² (chatière 4 + périmètre 2) | ~4 m³/h | **~45 W** | ~150 kWh ≈ 12 $ |
| 3. Concept C + **2e battant simple dans le trou hexa** (sas à 2 portes) | ~4,8 cm² en série | ~3 m³/h | **~33 W** | ~115 kWh ≈ 9 $ |

\* Fuite d'air + conduction à travers le passage du chat. Passages du chat (10/jour × 3 s
ouvert) : < 1 W en moyenne, négligeable.

Lecture :
- Le gros gain (≈ −70 %) vient de remplacer une serviette par **une** chatière bien jointée
  dans une paroi étanche. Le 2e battant n'ajoute qu'environ −25 % de fuite, mais il **bloque les
  rafales** (qui sinon peuvent décoller un battant magnétique) et garde la neige/les feuilles
  hors du sas. Le chat (~45 cm) tient les deux battants ouverts une seconde : ce n'est pas un
  sas parfait, et ce n'est pas grave.
- **Bonus** : la contre-fenêtre isole aussi toute la surface de la fenêtre (~0,3 m²) : la paroi
  froide passe de « fenêtre + panneau gris + trou » à « double vitrage + XPS (U ≈ 0,7) »,
  soit environ −10 à −15 W supplémentaires.
- En argent, l'économie est modeste (≈ 25–30 $/hiver). Le vrai gain est le **confort** : plus
  de courant d'air froid au sol, plus de serviette mouillée/gelée, un sous-sol plus sec.

## 10. Étapes de construction

1. **Mesurer** (§ 3), saisir `recess_w`, `recess_h`, `glass_t`, `wood_t` dans le `.scad`,
   lire la liste de coupe dans la console. Vérifier si le verre est trempé.
2. **Imprimer** (PETG) : profilés U, cadre-tunnel, anneau, battant. Coller les aimants
   (polarité !), poser le ruban mousse dans les rainures des profilés et le « pile » dans les
   rainures du tunnel.
3. **Couper le bois** à la scie (traverses 844, 3 × 324), poncer. Pré-percer et assembler en
   bout avec 2 vis #8 × 2-1/2 po + colle par jonction ; placer le meneau à 426 mm du montant
   côté verre. Contrôler les diagonales.
4. **Essai à blanc** dans la niche (sans coupe-froid) : jeu ≈ 3 mm partout.
5. **Double vitrage** (si `double`) : nettoyer, entretoise mousse 1/2 po sur le pourtour d'un
   carreau, poser le 2e, silicone sur la tranche, gel de silice dans un coin. Laisser sécher 24 h.
6. **Vitrage** : visser les profilés bas et latéraux (vis #6 dans la patte, côté pièce), poser
   le verre sur 2 petites cales (setting blocks) dans le profilé bas, puis visser les profilés
   hauts. Le ruban mousse doit être comprimé (≈ 40 %).
7. **Travée XPS** : couper le panneau 1 mm plus grand (scie fine / couteau), découper le trou
   du tunnel, l'enfoncer en force ; ruban de construction sur les joints XPS/bois des 2 faces.
8. **Chatière** : glisser le cadre-tunnel côté pièce, l'anneau côté sas, boulonner M4 (serrer
   juste au contact, l'XPS s'écrase). Monter le battant avec la tige Ø3 mm.
9. **Coupe-froid** sur tout le pourtour extérieur du cadre, visser 2 poignées côté pièce.
10. **Poser** : présenter le bas sur l'appui, basculer en place, pousser. Test à la fumée
    (bâton d'encens) par jour venteux sur tout le pourtour et autour du battant.
11. **Retirer la serviette** du trou hexagonal (ou y mettre un battant simple : scénario 3).
    Laisser le chat apprendre : battant relevé avec une pince 2–3 jours, friandise de l'autre côté.
12. **Printemps** : tirer sur les poignées, ranger le cadre à plat ; les profilés et le verre
    restent montés.

## 11. Avantages / inconvénients

**Pour**
- Zéro modification de la fenêtre et du panneau existants ; 100 % réversible (compression).
- Verre utilisé **sans coupe** (si niche ≥ 713 mm) et même les deux carreaux (double vitrage).
- Isole toute la baie, pas seulement le trou ; supprime le courant d'air de la serviette.
- Une seule chatière soignée à fabriquer ; le sas protège le battant du vent et de la neige.
- Paramétrique : s'adapte à la largeur réelle, au chat, au bois, au vitrage.

**Contre**
- Dépend d'une cote encore **inconnue** (largeur) ; hauteur très juste (7,5 mm de jeu).
- Le double vitrage maison peut s'embuer entre les vitres ; le simple vitrage condense à coup sûr.
- La fenêtre devient difficile d'accès en hiver (il faut retirer le cadre pour l'ouvrir/la nettoyer).
- Le chat doit franchir un seuil d'environ 50 mm et 305 mm de sas : petit apprentissage.
- Le sas peut accumuler neige/feuilles si le trou hexa reste totalement ouvert → battant
  simple ou rideau de lanières recommandé.
- Plus de travail de menuiserie qu'une simple chatière dans le panneau.
