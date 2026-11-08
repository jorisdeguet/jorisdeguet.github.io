// =============================================================================
//  test_ajustement.scad — Coupon de réglage des jeux (≈ 20 min d'impression)
//
//  Suit le réglage `fixation` de horaire_lego.scad (ou redéfini ci-dessous) :
//   • tasseau / pions : un bout de base (1 journée × 4 demi-heures, style `base_style`)
//     et 4 blocs d'une heure avec des jeux lèvre/rainure différents.
//   • plots   : une petite base 4 × 2 plots et 5 blocs 2 × 2.
//  Le jeu est gravé sur chaque bloc en centièmes de mm (« 30 » = 0,30 mm).
//  → Garder celui qui s'accroche franchement sans forcer et reporter la
//    valeur dans jeu_tasseau (ou jeu_plot).
//  • Une poche + plaquette pour vérifier jeu_poche.
// =============================================================================
include <horaire_lego.scad>

// fixation   = "plots";
jeux_tasseau = [0.15, 0.25, 0.35, 0.45];
jeux_plot    = [-0.10, 0.00, 0.10, 0.20, 0.30];

module etiquette(v, s = 3.5) linear_extrude(texte_h + 0.01)
    text(str(round(v * 100)), size = s, font = police, halign = "center", valign = "center");

if (fixation != "plots") {
    // Bout de base : 1 journée × 4 rangées, cadre de 5 mm
    nr = 4; m = 5; lz = jour_l * pas; md = montant_demi();
    difference() {
        linear_extrude(base_e) rrect(lz + 2 * m, nr * pas + 2 * m, 2);
        if (base_style == "grille")
            translate([m + md, m, -1]) cube([lz - 2 * md, nr * pas, base_e + 2]);
    }
    for (j = [0 : nr - 1]) {
        if (base_style == "grille" && fixation == "tasseau")
            translate([m, m + j * pas + tas_y0(), 0]) cube([lz, tas_t, base_e]);
        if (fixation == "tasseau")
            translate([m + tas_retrait / 2, m + j * pas + tas_y0(), base_e - 0.01])
                levre(lz - tas_retrait);
        else
            for (x = pions_x(jour_l))
                translate([m + x, m + j * pas + tas_y0(), base_e - 0.01]) levre(pion_l);
    }
    // Blocs d'une heure
    for (k = [0 : len(jeux_tasseau) - 1])
        translate([lz + 2 * m + 5 + (k % 2) * (lz + 3), floor(k / 2) * (2 * pas + 3), 0]) {
            plaque_fixee(jour_l, 2, bloc_h, jeu = jeux_tasseau[k]);
            translate([lz / 2, pas, bloc_h - 0.01]) etiquette(jeux_tasseau[k], 5);
        }
} else {
    linear_extrude(base_e) rrect(4 * pas, 2 * pas, 1.5);
    for (i = [0 : 3], j = [0 : 1]) translate([(i + 0.5) * pas, (j + 0.5) * pas, base_e]) plot();
    for (k = [0 : len(jeux_plot) - 1])
        translate([k * (2 * pas + 3), 2 * pas + 5, 0]) {
            plaque_fixee(2, 2, bloc_h, jeu = jeux_plot[k]);
            translate([pas - jeu_bloc / 2, pas - jeu_bloc / 2, bloc_h - 0.01]) etiquette(jeux_plot[k]);
        }
}

// Poche de plaquette + plaquette
translate([0, 6 * pas, 0]) {
    difference() {
        cube([plaquette_l + 8, plaquette_w + 6, 4]);
        translate([4, 3, 4]) poche_plaquette(plaquette_e);
    }
    translate([plaquette_l + 14, 0, 0]) plaquette("E-211");
}
