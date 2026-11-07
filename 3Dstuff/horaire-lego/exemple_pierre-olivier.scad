// =============================================================================
//  exemple_pierre-olivier.scad — Horaire réel (session d'automne 2026),
//  relevé dans https://info.cegepmontpetit.ca/5N6-mobile-2/
//
//  Arrondi à la demi-heure (pas de la grille) :
//    • Centre d'aide 12h00–12h45 (0,75 h)            → bloc de 1 h
//    • Disponibilité 12h00–13h45 (1,75 h)            → bloc « Dispo » de 2 h
//    • Réunion de département mer. 12h–14h            → c'est le « Trou horaire »
//                                                       moulé dans la base
//    • Cours 08h–11h, 12h–15h, 14h–17h (3 h)         → blocs de 3 h, tout rentre
// =============================================================================
include <horaire_lego.scad>

/* [Pièce à générer] */
// assemblage | tuile | base | eclisse | bloc | blocs | plaquettes | plaque_nom | statut | statuts | module | dispo | plaquette
part   = "assemblage";
index  = 0;   // pour part = "bloc" (n° du bloc dans horaire) ou "statut" (0..3)
tuile  = 0;   // pour part = "tuile" (0 = bas, 1 = haut)

/* [Conception] */
fixation   = "tasseau";   // "tasseau" (accroche à 45°, par gravité) | "plots"
base_style = "grille";    // "grille" (ajourée, économe) | "pleine"

/* [Prof] */
nom        = "Pierre-Olivier";
sous_titre = "Bureau E-211";
local_statut   = "E-211";
statut_affiche = 0;   // aperçu : 0 Dispo, 1 Absent, 2 De retour…, 3 Au local

/* [Bloc libre (part = module / dispo / plaquette)] */
duree  = 2.5;
lignes = ["420-5N6-EM"];
plaq   = "Gr. 1010";

/* [Hidden] */
// [jour, début (h), durée (h), lignes de texte, plaquette, couleur d'aperçu]
horaire = [
    [MAR,  8, 3, ["420-4W6-EM", "D-0624"], "Gr. 1010", "MidnightBlue"],
    [MAR, 12, 1, ["Centre d'aide"],        "E-211",    "BlueViolet"],
    [MER, 14, 3, ["420-5N6-EM", "D-0704"], "Gr. 1010", "DarkGoldenrod"],
    [JEU,  8, 3, ["420-5N6-EM", "D-0704"], "Gr. 1010", "DarkGoldenrod"],
    [JEU, 12, 2, ["Dispo"],                "E-211",    "Sienna"],
    [VEN, 10, 1, ["Centre d'aide"],        "D-0008",   "BlueViolet"],
    [VEN, 12, 3, ["420-4W6-EM", "D-0602"], "Gr. 1010", "MidnightBlue"],
];

rendu(part, horaire, nom, sous_titre, index, tuile, duree, lignes, plaq);
