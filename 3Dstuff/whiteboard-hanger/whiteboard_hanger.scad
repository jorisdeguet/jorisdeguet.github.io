// =============================================================================
//  whiteboard_hanger.scad — Crochet pour suspendre un tableau blanc sous une
//                           tablette appuyée contre un mur
//  Unités : millimètres
// =============================================================================
//
//  Profil (vue de côté, mur à gauche, X = vers la pièce, Y = vers le haut) :
//
//        ┌──────────────┐  ← languette posée SUR la tablette (tab_len, tab_t)
//        │┌─────────────┴──────── tablette ───
//        ││  (shelf_t)
//        ││  ← bande mince (strip_t = 0.8) coincée entre mur et tablette
//        │└─────────────────────────────────
//        │ \  ← rampe à 45° : la bande s'épaissit SOUS la tablette
//        │  │
//        │  │  ← descente (drop_len, épaisseur below_t)
//        │  │
//        │  │ ┌─┐ ← lèvre (lip_h)
//        │  │ │ │
//        │  └─┘ │ ← fond du crochet : le haut du tableau repose ici
//        └──────┘   (largeur intérieure = board_t + board_clear)
//       mur
//
//  Tout est orthogonal (pas de courbes), avec de petits goussets à 45°
//  (fillet) dans les angles intérieurs pour la solidité.
//
//  IMPRESSION : couché sur le côté — le PROFIL est à plat sur le plateau et
//  la pièce est extrudée vers le haut sur `width` mm. Les lignes de couche
//  sont alors parallèles au profil : aucun pli ne se fend entre deux couches.
//  part = "print" exporte la pièce dans cette orientation (count exemplaires).
//  part = "preview" la montre en place, avec mur, tablette et tableau fantômes.
// =============================================================================

part  = "print";   // "print" = à plat, prêt à trancher ; "preview" = en place
count = 2;         // nombre d'exemplaires sur le plateau (mode print)

// ── Pièce ────────────────────────────────────────────────────────────────────
width       = 20;    // largeur du crochet (= hauteur d'impression)

// Bande contre le mur
strip_t     = 0.8;   // épaisseur de la partie coincée entre mur et tablette
                     // (≥ 2 lignes d'extrusion avec une buse de 0.4)

// Tablette et languette du haut
shelf_t     = 25.4;  // épaisseur de la tablette (1 po)
shelf_clear = 0.5;   // jeu vertical : la partie épaisse commence ce jeu sous la tablette
tab_len     = 25;    // longueur de la languette posée sur la tablette (depuis le mur)
tab_t       = 2.0;   // épaisseur de la languette
tab_lip_h   = 0;     // rebord descendant au bout de la languette (0 = aucun).
                     // Pour enserrer l'avant de la tablette :
                     //   tab_len = strip_t + profondeur de la tablette + jeu + tab_t

// Descente et crochet du bas
drop_len    = 60;    // du dessous de la tablette au fond intérieur du crochet
below_t     = 3.5;   // épaisseur de la bande sous la tablette (rigidité)
board_t     = 15;    // épaisseur du tableau (ou de son cadre)
board_clear = 1.0;   // jeu entre le tableau et la lèvre
hook_t      = 4.0;   // épaisseur du fond et de la lèvre du crochet
lip_h       = 12;    // hauteur de la lèvre (au-dessus du fond intérieur)

// Renforts
fillet      = 2.5;   // gousset à 45° dans les angles intérieurs du crochet et
                     // de la descente (0 = angles vifs)
top_fillet  = 0;     // gousset sous la languette (contre l'arête de la tablette :
                     // laisser 0 si l'arête de la tablette est vive)

// ── Fantômes (aperçu seulement) ───────────────────────────────────────────────
shelf_depth = 250;   // profondeur de la tablette
board_h     = 200;   // hauteur du tableau montrée dans l'aperçu
ghost_len   = 120;   // longueur des fantômes le long du mur

// ── Cotes dérivées (profil 2D) ────────────────────────────────────────────────
y_thin_bot = -(shelf_t + shelf_clear);          // fin de la partie mince
y_ramp_bot = y_thin_bot - (below_t - strip_t);  // fin de la rampe à 45°
y_floor    = -(shelf_t + drop_len);             // fond intérieur du crochet
y_floor_bot= y_floor - hook_t;
x_lip_in   = below_t + board_t + board_clear;
x_lip_out  = x_lip_in + hook_t;
y_lip_top  = y_floor + lip_h;

assert(below_t >= strip_t, "below_t doit être ≥ strip_t");
assert(y_floor < y_ramp_bot - fillet,
       "drop_len trop court : augmenter drop_len ou réduire shelf_clear/below_t");
assert(tab_len >= strip_t + tab_t, "tab_len trop court");

// ── Profil ───────────────────────────────────────────────────────────────────
module rect(x0, y0, x1, y1) translate([x0, y0]) square([x1 - x0, y1 - y0]);

// gousset triangulaire dans un angle intérieur ; sx, sy = sens des deux bras
module gusset(x, y, s, sx, sy)
    if (s > 0) polygon([[x, y], [x + sx * s, y], [x, y + sy * s]]);

module profile() {
    union() {
        // languette du haut, posée sur la tablette
        rect(0, 0, tab_len, tab_t);
        if (tab_lip_h > 0) rect(tab_len - tab_t, -tab_lip_h, tab_len, 0);
        // bande mince entre mur et tablette
        rect(0, y_thin_bot, strip_t, 0);
        // rampe à 45° vers l'épaisseur below_t
        polygon([[0, y_thin_bot], [strip_t, y_thin_bot],
                 [below_t, y_ramp_bot], [0, y_ramp_bot]]);
        // descente
        rect(0, y_floor_bot, below_t, y_ramp_bot);
        // fond et lèvre du crochet
        rect(0, y_floor_bot, x_lip_out, y_floor);
        rect(x_lip_in, y_floor_bot, x_lip_out, y_lip_top);

        // renforts
        gusset(below_t,  y_floor,  fillet,  1, 1);   // descente / fond
        gusset(x_lip_in, y_floor,  fillet, -1, 1);   // fond / lèvre
        gusset(strip_t,  0,        top_fillet,  1, -1);  // bande / languette
        if (tab_lip_h > 0)
            gusset(tab_len - tab_t, 0, top_fillet, -1, -1); // languette / rebord
    }
}

module hanger() linear_extrude(height = width) profile();

// ── Mise en place ─────────────────────────────────────────────────────────────
// profil X → Y monde (vers la pièce), profil Y → Z monde, largeur → X monde
module in_place() rotate([90, 0, 90]) children();

if (part == "print") {
    // à plat : profil sur le plateau, exemplaires côte à côte
    pitch = max(tab_len, x_lip_out) + 5;
    for (i = [0 : count - 1])
        translate([i * pitch, -y_floor_bot, 0]) hanger();
} else {
    color("SteelBlue") in_place() hanger();
    // mur
    %translate([-ghost_len / 2, -10, y_floor - board_h - 20])
        cube([ghost_len + width, 10, board_h + shelf_t + drop_len + 60]);
    // tablette
    %translate([-ghost_len / 2, strip_t, -shelf_t])
        cube([ghost_len + width, shelf_depth, shelf_t]);
    // tableau, son bord du haut posé dans le crochet
    %translate([-ghost_len / 2, below_t, y_floor - board_h])
        cube([ghost_len + width, board_t, board_h]);
}
