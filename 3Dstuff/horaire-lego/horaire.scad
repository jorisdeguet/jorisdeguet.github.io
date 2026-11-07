// =============================================================================
//  horaire.scad — Gabarit : copier ce fichier pour chaque prof et remplir
//  la liste « horaire ». Tous les réglages (jeux, dimensions, textes des statuts…)
//  sont dans horaire_lego.scad et peuvent être redéfinis ici, APRÈS l'include.
// =============================================================================
include <horaire_lego.scad>

/* [Pièce à générer] */
// assemblage | tuile | base | eclisse | bloc | blocs | plaquettes | plaque_nom | statut | statuts | module | dispo | plaquette
part   = "assemblage";
index  = 0;   // part = "bloc" : n° du bloc dans horaire ; part = "statut" : 0..3
tuile  = 0;   // part = "tuile" : 0 = bas, 1 = haut

/* [Conception] */
fixation   = "tasseau";   // "tasseau" (accroche à 45°, par gravité) | "plots"
base_style = "grille";    // "grille" (ajourée, économe) | "pleine"

/* [Prof] */
nom        = "Prénom Nom";
sous_titre = "";          // ex. "Bureau E-211" ("" = une seule ligne)
local_statut   = "E-211"; // plaquette de la plaque « Au local »
statut_affiche = 0;       // aperçu : 0 Dispo, 1 Absent, 2 De retour…, 3 Au local

/* [Bloc libre (part = module / dispo / plaquette)] */
duree  = 3;               // 2, 2.5, 3 … (multiple de 0,5 h)
lignes = ["420-XXX-EM"];  // n° de cours (et local, etc.)
plaq   = "Gr. 1010";      // plaquette de groupe (ou local pour « dispo »)

/* [Hidden] */
// Réglages pour VOTRE imprimante (voir test_ajustement.scad) :
// jeu_plot = 0.10;
// lit      = 250;

// [jour, début (h), durée (h), lignes de texte, plaquette, couleur d'aperçu]
//   jour : LUN MAR MER JEU VEN   — début et durée en multiples de 0,5 h
//   plaquette : "" = aucune ; sinon poche + plaquette amovible (≥ 1,5 h),
//               ou texte en relief si le bloc est trop court (1 h)
horaire = [
    [LUN,  8,   3,   ["420-1A1-EM"], "Gr. 1010", "RoyalBlue"],
    [MAR, 13,   2.5, ["420-2B2-EM"], "Gr. 2020", "SeaGreen"],
    [JEU, 10,   2,   ["Dispo"],      "E-211",    "Sienna"],
];

rendu(part, horaire, nom, sous_titre, index, tuile, duree, lignes, plaq);
