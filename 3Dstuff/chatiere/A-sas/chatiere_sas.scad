// =====================================================================
//  Chatière d'hiver — concept A « SAS » (vestibule à deux volets)
//  Pièces imprimées paramétriques + aperçu assemblé.
//  Unités : mm.  Imprimante visée : plateau 260 x 260 x 260.
//
//  Repère de l'assemblage :
//    X = largeur (le long de la fenêtre, 0 = côté gauche, côté pièce/volet intérieur)
//    Y = profondeur (0 = plan avant du bois, la vitre est en Y < 0 ; Y croît vers la fenêtre)
//    Z = hauteur (0 = dessus de l'appui en bois)
//
//  Choisir la pièce avec `part` (ou en ligne de commande : -D 'part="cadre"').
// =====================================================================

part = "assembled"; // [assembled, cadre, contre_cadre, battant, kit_charniere, kit_aimant, sabot, pince, pince_droite, capuchon]
couvercle_ouvert = false;   // aperçu : soulève le couvercle

$fn = 48;
eps = 0.01;

// ---------- Vitre ----------
verre_l = 411;      // largeur (posée en paysage)
verre_h = 309;      // hauteur
verre_e = 4;        // épaisseur — À MESURER (thermos/vitrage scellé : 16 à 25)
double_vitrage = true;  // ajoute une feuille de polycarbonate côté pièce
pc_e = 2;           // épaisseur polycarbonate (≈ 0.093 po)
espaceur_e = 6;     // ruban mousse double-face servant d'espaceur (lame d'air)

// ---------- Caisson bois ----------
bois_e = 12;        // contreplaqué 1/2 po
prof = 275;         // profondeur des côtés et du couvercle
rebord_prof = 60;   // profondeur du rebord PVC blanc devant la fenêtre — À MESURER
rebord_h = 15;      // hauteur de ce rebord au-dessus de l'appui — À MESURER
patin_h = 5;        // patins caoutchouc/feutre sous le plancher
mousse_dos = 15;    // joint mousse épais entre le caisson et la fenêtre
niche_h = 368;      // hauteur libre de l'embrasure (vérification)

// ---------- Volet (mêmes paramètres pour les deux volets) ----------
ouv_l = 160;        // ouverture de passage, largeur
ouv_h = 170;        // ouverture de passage, hauteur
collier_ep = 8;     // épaisseur de paroi du collier (tunnel)
collier_long = bois_e + 2; // longueur du collier = épaisseur de la paroi traversée + 2
                    // (pour le panneau gris de la fenêtre : son épaisseur + 2)
bride_marge = 20;   // largeur de la bride autour du collier
bride_e = 4;        // épaisseur de la bride
contre_e = 3;       // épaisseur du contre-cadre
jeu_lat = 2.5;      // jeu battant / montant
jeu_bas = 3;        // jeu battant / seuil
tige_d = 4.2;       // trou pour tige filetée #8-32 ou M4
charn_off = 7;      // axe de charnière sous le haut de l'ouverture
tube_d = 9;         // tube de charnière du battant
aimant_d = 6;       // aimant néodyme disque 6 x 3
aimant_h = 3;
aimant_y = 14;      // hauteur de l'axe des aimants au-dessus du seuil
brosse_l = 5.2;     // rainure pour coupe-froid à poils (dos ~4.8 mm)
brosse_p = 4;       // profondeur de cette rainure
joint_l = 3;        // rainure de joint sous la bride (cordon mousse/EPDM 3-4 mm)
joint_p = 1.6;
vis_d = 3.8;        // vis à bois #6
vis_tete = 7.5;
battant_e = 2.4;    // épaisseur de la plaque du battant imprimé

// ---------- Fixation de la vitre ----------
pince_long = 30;    // hauteur d'une pince
pince_ep = 3;
pince_levre = 7;    // recouvrement de la vitre
sabot_l = 40;       // largeur d'un sabot
sabot_e = 3;        // semelle du sabot (vitre posée dessus)
sabot_levre = 12;

// ---------- Dérivés ----------
pile = verre_e + (double_vitrage ? espaceur_e + pc_e : 0); // épaisseur de l'empilement vitré
col_L = ouv_l + 2*collier_ep;
col_H = ouv_h + 2*collier_ep;
bride_L = col_L + 2*bride_marge;
bride_H = col_H + 2*bride_marge;
prof_tot = bride_e + collier_long;
zc = prof_tot/2;                                  // axe de charnière (local)
z_plaque = zc - tube_d/2 + battant_e/2;           // plan médian du battant (local)
bat_L = ouv_l - 2*jeu_lat;
bat_H = ouv_h - charn_off - jeu_bas;              // de l'axe au bas du battant
caisson_h = verre_h;                              // hauteur bois = hauteur vitre
cote_h = caisson_h - 2*bois_e;
plancher_prof = prof + mousse_dos - rebord_prof;  // le plancher s'arrête devant le rebord PVC

assert(bride_L <= 260 && bride_H <= 260, "Le cadre dépasse le plateau 260 mm");
assert(patin_h + verre_h < niche_h, "Le caisson ne rentre pas sous l'embrasure");

echo(str("Cadre de volet : ", bride_L, " x ", bride_H, " x ", prof_tot, " mm"));
echo(str("Battant : ", bat_L, " x ", bat_H, " mm"));
echo(str("Caisson : ", verre_l, " L x ", prof + pile, " P x ", patin_h + caisson_h, " H mm ; jeu sous l'embrasure ",
         niche_h - patin_h - caisson_h, " mm"));
echo(str("Intérieur : ", verre_l - 2*bois_e, " x ", prof, " x ", cote_h, " mm"));
echo(str("Trou dans la paroi pour le collier : ", col_L + 1, " x ", col_H + 1, " mm"));

// =====================================================================
//  Utilitaires
// =====================================================================
module plaque_arrondie(l, h, e, r = 6) {
    hull() for (sx = [-1, 1], sy = [-1, 1])
        translate([sx*(l/2 - r), sy*(h/2 - r), 0]) cylinder(r = r, h = e);
}

module trou_fraise(long = 20) {   // trou de vis fraisé, tête en z = 0, vers +z
    translate([0, 0, -eps]) cylinder(d = vis_d, h = long);
    translate([0, 0, -eps]) cylinder(d1 = vis_tete, d2 = vis_d, h = (vis_tete - vis_d)/2);
}

function pos_vis(decal = 0) = [
    for (sx = [-1, 1], sy = [-1, 1]) [sx*(col_L/2 + bride_marge*0.62), sy*(col_H/2 + bride_marge*0.62) - sy*decal],
    for (sx = [-1, 1]) [sx*(col_L/2 + bride_marge*0.62), decal]
];

// =====================================================================
//  CADRE DE VOLET : bride + collier (tunnel) ; rainures coupe-froid à
//  poils sur les montants, le seuil et le linteau ; logements d'aimants ;
//  trous d'axe ; rainure de joint sous la bride.
//  Impression : bride à plat sur le plateau, sans support.
// =====================================================================
module cadre() {
    difference() {
        union() {
            plaque_arrondie(bride_L, bride_H, bride_e);
            translate([-col_L/2, -col_H/2, 0]) cube([col_L, col_H, prof_tot]);
        }
        // ouverture de passage
        translate([-ouv_l/2, -ouv_h/2, -1]) cube([ouv_l, ouv_h, prof_tot + 2]);
        // axe de charnière
        translate([0, ouv_h/2 - charn_off, zc]) rotate([0, 90, 0])
            cylinder(d = tige_d, h = col_L + 2, center = true);
        // rainures à poils dans les montants (au-dessus des aimants, sous l'axe)
        y0 = -ouv_h/2 + aimant_y + aimant_d/2 + 3;
        y1 =  ouv_h/2 - charn_off - tube_d/2 - 1;
        for (s = [-1, 1])
            translate([s*(ouv_l/2 + brosse_p/2 - eps), (y0 + y1)/2, z_plaque])
                cube([brosse_p + 2*eps, y1 - y0, brosse_l], center = true);
        // rainure à poils du seuil (plan du battant)
        translate([0, -ouv_h/2 - brosse_p/2 + eps, z_plaque])
            cube([ouv_l, brosse_p + 2*eps, brosse_l], center = true);
        // rainure à poils du linteau (frotte sur le tube de charnière)
        translate([0, ouv_h/2 + brosse_p/2 - eps, zc])
            cube([ouv_l, brosse_p + 2*eps, brosse_l], center = true);
        // logements d'aimants dans les montants (axe horizontal)
        for (s = [-1, 1])
            translate([s*(ouv_l/2 + (aimant_h + 0.2)/2 - eps), -ouv_h/2 + aimant_y, zc])
                rotate([0, 90, 0]) cylinder(d = aimant_d + 0.3, h = aimant_h + 0.2 + 2*eps, center = true);
        // rainure de joint (face de la bride côté paroi, z = bride_e)
        translate([0, 0, bride_e - joint_p]) linear_extrude(joint_p + eps) difference() {
            square([col_L + 2*(4 + joint_l), col_H + 2*(4 + joint_l)], center = true);
            square([col_L + 2*4, col_H + 2*4], center = true);
        }
        // vis de fixation (tête côté visible z = 0)
        for (p = pos_vis()) translate([p[0], p[1], 0]) trou_fraise(bride_e + 1);
    }
}

// Contre-cadre : se visse de l'autre côté de la paroi, autour du collier.
// Trous décalés pour ne pas croiser les vis de la bride.
module contre_cadre() {
    difference() {
        plaque_arrondie(bride_L, bride_H, contre_e);
        translate([0, 0, -1]) linear_extrude(contre_e + 2) square([col_L + 1, col_H + 1], center = true);
        for (p = pos_vis(decal = 25)) translate([p[0], p[1], 0]) trou_fraise(contre_e + 1);
    }
}

// =====================================================================
//  BATTANT imprimé (PETG). Repère : axe de charnière sur l'axe X,
//  plaque vers -Y, face d'impression en z = 0 (tube et bossages vers +z).
// =====================================================================
module battant() {
    zt = tube_d/2;                              // axe du tube
    ya = -(ouv_h - charn_off - aimant_y);       // hauteur des aimants (relative à l'axe)
    difference() {
        union() {
            // tube de charnière
            translate([0, 0, zt]) rotate([0, 90, 0]) cylinder(d = tube_d, h = bat_L, center = true);
            // plaque
            translate([-bat_L/2, -bat_H, 0]) cube([bat_L, bat_H, battant_e]);
            // raidisseurs : cadre périphérique + nervure centrale
            translate([0, 0, battant_e]) linear_extrude(1.6) difference() {
                translate([-bat_L/2, -bat_H]) square([bat_L, bat_H]);
                translate([-bat_L/2 + 4, -bat_H + 4]) square([bat_L - 8, bat_H - 8]);
            }
            translate([-1.5, -bat_H, battant_e]) cube([3, bat_H, 1.6]);
            // bossages d'aimants aux coins inférieurs
            for (s = [-1, 1]) translate([s*(bat_L/2 - 5), ya, 0])
                translate([-5, -7, 0]) cube([10, 14, tube_d]);
        }
        translate([0, 0, zt]) rotate([0, 90, 0]) cylinder(d = tige_d + 0.4, h = bat_L + 2, center = true);
        for (s = [-1, 1])
            translate([s*(bat_L/2 - (aimant_h + 0.2)/2 + eps), ya, z_bossage()])
                rotate([0, 90, 0]) cylinder(d = aimant_d + 0.3, h = aimant_h + 0.2 + 2*eps, center = true);
    }
}
// centre des aimants du battant = hauteur de l'axe ; aligné sur les aimants du cadre (zc)
function z_bossage() = tube_d/2;

// =====================================================================
//  KIT pour battant en polycarbonate transparent (recommandé)
//  - barre de charnière : tube + fente où se pince la feuille (2 vis M3)
//  - porte-aimant : se glisse sur le coin inférieur de la feuille
// =====================================================================
module kit_charniere() {
    fente = pc_e + 0.3;
    l = bat_L;
    difference() {
        union() {
            translate([0, 0, tube_d/2]) rotate([0, 90, 0]) cylinder(d = tube_d, h = l, center = true);
            translate([-l/2, -16, 0]) cube([l, 16, fente + 4]);
        }
        translate([0, 0, tube_d/2]) rotate([0, 90, 0]) cylinder(d = tige_d + 0.4, h = l + 2, center = true);
        translate([-l/2 - 1, -16 - eps, 2]) cube([l + 2, 12, fente]);
        for (x = [-l/3, 0, l/3]) translate([x, -9, -1]) cylinder(d = 3.2, h = 20);
    }
}

module kit_aimant() {
    fente = pc_e + 0.3;
    difference() {
        translate([-14, -7, 0]) cube([14, 14, tube_d]);
        // fente pour la feuille (même plan que dans kit_charniere), ouverte côté intérieur (+x)
        translate([-8, -7 - 1, 2]) cube([9, 16, fente]);
        // aimant sur la face extérieure (x = -14)
        translate([-14 + (aimant_h + 0.2)/2 - eps, 0, z_bossage()])
            rotate([0, 90, 0]) cylinder(d = aimant_d + 0.3, h = aimant_h + 0.2 + 2*eps, center = true);
    }
}

// =====================================================================
//  SABOT de vitre : semelle glissée sous le plancher (vissée par dessous),
//  lèvre avant qui retient le bas de la vitre. Profil YZ extrudé sur X.
//  Imprimer couché sur le flanc (profil à plat).
// =====================================================================
module sabot() {
    yav = -(pile + pince_ep);
    difference() {
        rotate([90, 0, 90]) linear_extrude(sabot_l) polygon([
            [yav, 0], [35, 0], [35, sabot_e], [-pile, sabot_e],
            [-pile, sabot_e + sabot_levre], [yav, sabot_e + sabot_levre]]);
        for (y = [12, 26]) translate([sabot_l/2, y, 0]) trou_fraise(sabot_e + 1);
    }
}

// =====================================================================
//  PINCE latérale : se visse sur la face extérieure d'un côté, la lèvre
//  recouvre l'avant de la vitre. Profil XY extrudé sur Z (imprimer à plat).
//  Version gauche ; pince_droite = miroir.
// =====================================================================
module pince() {
    yav = -(pile + pince_ep);
    difference() {
        linear_extrude(pince_long) polygon([
            [-pince_ep, yav], [pince_levre, yav], [pince_levre, -pile],
            [0, -pile], [0, 26], [-pince_ep, 26]]);
        translate([-pince_ep, 14, pince_long/2]) rotate([0, 90, 0]) trou_fraise(pince_ep + 1);
    }
}

module capuchon() {   // bout de tige (coller sur la tige filetée)
    difference() {
        cylinder(d = 9, h = 5);
        translate([0, 0, 1.2]) cylinder(d = tige_d - 0.1, h = 5);
    }
}

// =====================================================================
//  Sous-ensemble volet (cadre + battant + tige + contre-cadre),
//  en repère local du cadre ; paroi entre z = bride_e et z = bride_e + ep_paroi
// =====================================================================
module volet_assemble(ep_paroi = bois_e, angle = 0) {
    color("SteelBlue") cadre();
    color("LightSkyBlue", 0.75)
        translate([0, ouv_h/2 - charn_off, zc]) rotate([angle, 0, 0])
            translate([0, 0, -tube_d/2]) battant();
    color("Silver") translate([0, ouv_h/2 - charn_off, zc]) rotate([0, 90, 0])
        cylinder(d = 4, h = col_L + 6, center = true);
    color("SteelBlue", 0.8) translate([0, 0, bride_e + ep_paroi]) contre_cadre();
}

// =====================================================================
//  ASSEMBLAGE
// =====================================================================
module assemblage() {
    z0 = patin_h;
    lev = couvercle_ouvert ? 90 : 0;
    y_fen = prof + mousse_dos;                 // plan intérieur de la fenêtre

    // --- environnement : appui, rebord PVC, fenêtre, embrasure ---
    color("BurlyWood", 0.35) translate([-150, -40, -20]) cube([verre_l + 300, y_fen + 40, 20]);
    color("White") translate([-150, y_fen - rebord_prof, 0]) cube([verre_l + 300, rebord_prof, rebord_h]);
    color("Gainsboro", 0.5) difference() {          // panneau gris de la fenêtre (simplifié)
        translate([-150, y_fen, rebord_h]) cube([verre_l + 300, 12, niche_h - rebord_h]);
        translate([x_fen() - (col_L + 1)/2, y_fen - 1, z_fen() - (col_H + 1)/2])
            cube([col_L + 1, 14, col_H + 1]);
    }

    // --- caisson bois ---
    color("Tan") {
        // plancher
        translate([0, 0, z0]) cube([verre_l, plancher_prof, bois_e]);
        // côtés
        difference() {
            translate([0, 0, z0 + bois_e]) cube([bois_e, prof, cote_h]);
            translate([-1, y_cote() - (col_L + 1)/2, z_cote() - (col_H + 1)/2])
                cube([bois_e + 2, col_L + 1, col_H + 1]);
        }
        translate([verre_l - bois_e, 0, z0 + bois_e]) cube([bois_e, prof, cote_h]);
        // couvercle
        translate([0, 0, z0 + bois_e + cote_h + lev]) cube([verre_l, prof, bois_e]);
    }
    // joint mousse dos
    color("DimGray") {
        translate([0, prof, z0 + bois_e]) cube([bois_e, mousse_dos, cote_h]);
        translate([verre_l - bois_e, prof, z0 + bois_e]) cube([bois_e, mousse_dos, cote_h]);
        translate([0, prof, z0 + bois_e + cote_h + lev]) cube([verre_l, mousse_dos, bois_e]);
    }

    // --- vitre (+ polycarbonate) ---
    color("PaleTurquoise", 0.35) translate([0, -verre_e, z0]) cube([verre_l, verre_e, verre_h]);
    if (double_vitrage) {
        color("DarkGray") translate([0, -verre_e - espaceur_e, z0]) difference() {
            cube([verre_l, espaceur_e, verre_h]);
            translate([10, -1, 10]) cube([verre_l - 20, espaceur_e + 2, verre_h - 20]);
        }
        color("White", 0.2) translate([0, -pile, z0]) cube([verre_l, pc_e, verre_h]);
    }
    // sabots et pinces
    color("Orange") {
        for (x = [20, verre_l - 20 - sabot_l]) translate([x, 0, z0 - sabot_e]) sabot();
        for (z = [150, 260]) {
            translate([0, 0, z0 + z]) pince();
            translate([verre_l, 0, z0 + z]) mirror([1, 0, 0]) pince();
        }
    }

    // --- volet intérieur dans le côté gauche (sortie vers la pièce) ---
    translate([-bride_e, y_cote(), z_cote()]) rotate([90, 0, 90]) volet_assemble(bois_e, 0);

    // --- volet extérieur dans le panneau gris de la fenêtre ---
    translate([x_fen(), y_fen - bride_e, z_fen()]) rotate([90, 0, 180]) volet_assemble(12, 25);
}
function y_cote() = 30 + bride_L/2;                                     // centre du volet latéral
function z_cote() = patin_h + bois_e + 35 + ouv_h/2;
function x_fen()  = verre_l - bois_e - 15 - bride_L/2;                   // centre du volet fenêtre
function z_fen()  = max(rebord_h + bride_H/2 + 5, patin_h + bois_e + 35 + ouv_h/2);

// =====================================================================
if      (part == "assembled")     assemblage();
else if (part == "cadre")         cadre();
else if (part == "contre_cadre")  contre_cadre();
else if (part == "battant")       battant();
else if (part == "kit_charniere") kit_charniere();
else if (part == "kit_aimant")    kit_aimant();
else if (part == "sabot")         rotate([0, -90, 0]) sabot();     // profil à plat
else if (part == "pince")         pince();
else if (part == "pince_droite")  mirror([1, 0, 0]) pince();
else if (part == "capuchon")      capuchon();
