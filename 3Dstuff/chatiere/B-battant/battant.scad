// =====================================================================
//  Chatière d'hiver — concept A « SAS » : module à battant pivotant
//
//  Variante plus simple du module à porte relevable (porte_rebord.scad).
//  Un battant rectangulaire tourne autour d'un axe VERTICAL au milieu de
//  l'ouverture, comme une porte tambour à un seul vantail.
//
//  Le chat passe toujours sur SA droite :
//   - depuis le sas, il pousse la moitié droite (vue du sas) vers la pièce ;
//   - depuis la pièce, il pousse l'autre moitié vers le sas.
//  Dans les deux cas le battant tourne dans le MÊME sens. Il peut donc
//  s'appuyer sur des butées à recouvrement qui font l'étanchéité :
//   - moitié droite : butée côté sas (la peau du cadre) ;
//   - moitié gauche : butée côté pièce (le cadre en U du couvercle).
//  Un élastique, en haut à droite côté pièce, ramène le battant sur ses butées.
//
//  Trois pièces, sans vis :
//   - CADRE (face côté sas sur le plateau) : peau avec collerette et butée,
//     toute l'épaisseur du mur, paliers de l'axe ouverts vers l'arrière,
//     poche et poteau pour l'élastique, quatre tétons pour le couvercle ;
//   - BATTANT (à plat) : deux tourillons octogonaux sur l'axe, un téton
//     d'élastique sur la face arrière ;
//   - COUVERCLE (face côté pièce sur le plateau) : peau avec collerette,
//     butée en U de la moitié gauche, deux taquets qui ferment les paliers.
//     Il s'emboîte à force sur les tétons du cadre.
//
//  Repère : comme porte_rebord.scad (X le long du mur vu du sas, Z hauteur,
//  Y épaisseur, y = 0 face côté sas). L'axe est en x = 0.
// =====================================================================

part = "assembled"; // [assembled, eclate, cadre, couvercle, battant, planche]
echelle = 1;          // 1 = réel ; 0.4 = maquette
part_gauche = 0.55;   // part du battant à gauche de l'axe (vu du sas) : le vent du dehors le referme
angle = 0;            // aperçu : rotation du battant (0 fermé, 90 grand ouvert ; négatif = bloqué par les butées)
coupe = false;        // aperçu : sans couvercle

/* [Cotes réelles (multipliées par echelle)] */
ouv_l_r = 210;        // ouverture totale : deux passages d'environ 100 mm
ouv_h_r = 125;        // juste assez pour un chat adulte
r_coin_r = 12;
z_bas_r = 30;         // seuil de l'ouverture au-dessus du plancher du sas
epais_r = 23.6;       // épaisseur du module (comme porte_rebord.scad)
contreplaque = 12;
densite = 1.24;

E = echelle;
$fn = E < 0.7 ? 32 : 48;
eps = 0.01;
reel = E >= 0.7;

ouv_l  = ouv_l_r * E;
ouv_h  = ouv_h_r * E;
r_coin = r_coin_r * E;
z_bas  = z_bas_r * E;
z_haut = z_bas + ouv_h;
recouv = 8 * E;                    // recouvrement des butées
bordure = max(2, 3 * E);           // bord plein (haut)
bordure_s = max(5, 8 * E);         // côtés : place pour les tétons du couvercle
colle  = 5 * E;
peau_e = max(1.2, 3 * E);
batt_e = max(2.4, 4 * E);          // épaisseur du battant
feutre_e = reel ? 1 : 0;
jeu    = max(0.3, 0.6 * E);
tour_l = max(3, 5 * E);            // longueur des tourillons
// tourillon octogonal : méplats dessus/dessous à l'impression, épaisseur = celle du battant
tour_rc = batt_e / 2 / cos(22.5);
g_ax   = batt_e + jeu;             // zone de l'axe où les butées changent de côté
tet_d  = max(3, 5 * E);            // téton d'élastique du battant, poteau du cadre
tet_l  = max(4, 8 * E);
poche_h = max(8, 12 * E);
pion_d = max(2.4, 4 * E);          // tétons cadre -> couvercle
serrage = 0.15;                    // jeu des trous des tétons (emboîtement à force)

epais  = max(epais_r * E, peau_e * 2 + feutre_e * 2 + batt_e + 2 * jeu + max(2, 3 * E));
y_cv   = epais - peau_e;
y_pf   = peau_e + feutre_e + jeu / 2;          // face avant du battant
y_ax   = y_pf + batt_e / 2;                    // axe
y_lip  = y_pf + batt_e + feutre_e + jeu / 2;   // butée du couvercle

porte_l = ouv_l + 2 * recouv;
x_ax   = porte_l * (part_gauche - 0.5);         // axe, décalé vers la droite (vu du sas)
f_b    = z_bas - recouv;                       // bas du battant
f_t    = z_haut + recouv;                      // haut du battant
cav_x  = porte_l / 2 + jeu;
L2     = cav_x + bordure_s;
H      = f_t + jeu + max(poche_h, tour_l + jeu) + bordure;
colle_h = reel ? max(2, min(colle, 258 - H)) : colle;

// élastique : téton du battant (x_b, z_b), poteau du cadre (x_a, z_a)
x_b = max(tet_d + g_ax, 25 * E);
z_b = f_t - max(tet_d, 10 * E);
x_a = porte_l / 2 - max(tet_d, 30 * E);
z_a = f_t + jeu + poche_h / 2;
d_b = batt_e / 2 + tet_l * 0.7;                // téton du battant, en avant de l'axe vers la pièce
y_a = (y_ax + y_cv) / 2 - y_ax;
function portee_el(a) = norm([x_a - x_ax - (x_b * cos(a) - d_b * sin(a)), y_a - (x_b * sin(a) + d_b * cos(a))]);

m_batt = porte_l * (f_t - f_b) * batt_e / 1000 * densite;
passage_d = ouv_l / 2 - x_ax - g_ax;          // côté droit (vu du sas) : le chat qui sort du sas
passage_g = ouv_l / 2 + x_ax - g_ax;
// vent du dehors (pression côté sas) : couple de fermeture / couple d'ouverture
vent = pow(porte_l / 2 + x_ax, 2) / pow(porte_l / 2 - x_ax, 2);

echo(str("[echelle ", E, "] corps ", 2 * L2, " x ", H, " x ", epais, " mm ; avec collerettes ",
         2 * (L2 + colle), " x ", H + colle_h));
echo(str("Ouverture ", ouv_l, " x ", ouv_h, " de z = ", z_bas, " à ", z_haut, " ; passages de ", passage_d, " (droite, vu du sas) et ", passage_g,
         " ; battant ", porte_l, " x ", f_t - f_b, " x ", batt_e, " (", round(m_batt), " g)"));
echo(str("Élastique : ", round(portee_el(0)), " mm fermé, ", round(portee_el(90)), " mm à 90° (allongement ",
         round((portee_el(90) / portee_el(0) - 1) * 100), " %)"));
echo(str("Vent du dehors : couple de fermeture ", round(vent * 100) / 100, " fois le couple d'ouverture"));
if (reel) echo(str("Encoche dans le contreplaqué : ", 2 * L2 + 1, " x ", H + 0.5, " mm depuis le bas"));
assert(!reel || 2 * (L2 + colle) <= 258, "Le cadre dépasse le plateau de 260 mm.");
assert(!reel || H + colle_h <= 258, "Le cadre est trop haut pour le plateau.");
assert(part_gauche > 0.5, "La moitié gauche doit être la plus grande pour que le vent referme le battant.");
assert(f_b - tour_l - bordure_b() > 0, "Pas de place sous le battant pour le palier du bas.");
function bordure_b() = max(1.5, 2 * E);

// ---------------------------------------------------------------------
module rect2(x0, z0, x1, z1) translate([x0, z0]) square([x1 - x0, z1 - z0]);
module rrect2(x0, z0, x1, z1, r) translate([x0 + r, z0 + r]) offset(r = r) square([x1 - x0 - 2 * r, z1 - z0 - 2 * r]);
module en_place(y0) translate([0, y0, 0]) rotate([90, 0, 0]) mirror([0, 0, 1]) children();
module couche(y0, e) en_place(y0) linear_extrude(e) children();

module corps2() rect2(-L2, 0, L2, H);
module collerette2() hull() {
    rect2(-L2 - colle, 0, L2 + colle, 1);
    for (s = [-1, 1]) translate([s * (L2 + colle - 3 * E), H + colle_h - 3 * E]) circle(r = 3 * E);
}
module cavite2() rect2(-cav_x, f_b - jeu, cav_x, f_t + jeu);
module battant2() rrect2(-porte_l / 2, f_b, porte_l / 2, f_t, r_coin + recouv);
// peau du sas : la moitié gauche passe en entier, la moitié droite s'appuie (recouvrement)
module ouv_sas2() { rect2(-cav_x, f_b - jeu, x_ax + g_ax, f_t + jeu); rrect2(x_ax - r_coin, z_bas, ouv_l / 2, z_haut, r_coin); }
// peau de la pièce : l'inverse, plus l'accès à la poche de l'élastique
module poche2() rect2(x_ax + x_b - tet_d, f_t, x_a + tet_d, f_t + jeu + poche_h);
module ouv_piece2() { rect2(x_ax - g_ax, f_b - jeu, cav_x, f_t + jeu); rrect2(-ouv_l / 2, z_bas, x_ax + r_coin, z_haut, r_coin); poche2(); }
function pions() = [for (s = [-1, 1], k = [0.2, 0.8]) [s * (cav_x + bordure_s / 2), f_b + k * (f_t - f_b)]];

// paliers : fente ronde au bout, ouverte vers l'arrière (y = y_cv)
module palier(z0, z1, r) hull() {
    translate([x_ax, y_ax, z0]) cylinder(r = r, h = z1 - z0);
    translate([x_ax - r, y_ax, z0]) cube([2 * r, y_cv - y_ax + eps, z1 - z0]);
}
pal_h = [f_t + jeu - eps, f_t + tour_l + jeu];         // palier du haut
pal_b = [f_b - tour_l - eps, f_b - jeu + eps];         // palier du bas : le battant repose sur le bout du tourillon

module cadre_monde() {
    difference() {
        union() {
            couche(0, peau_e) difference() { collerette2(); ouv_sas2(); }
            couche(peau_e - eps, y_cv - peau_e + eps) difference() { corps2(); cavite2(); poche2(); }
        }
        for (p = [pal_h, pal_b]) palier(p[0], p[1], tour_rc + jeu);
    }
    // poteau de l'élastique, dans la poche, avec une tête
    translate([x_a, peau_e - eps, z_a]) rotate([-90, 0, 0]) {
        h = y_cv - jeu - peau_e - tet_d * 0.4;
        cylinder(d = tet_d, h = h);
        translate([0, 0, h - eps]) cylinder(d1 = tet_d, d2 = tet_d * 1.6, h = tet_d * 0.3);
    }
    // tétons qui tiennent le couvercle
    for (p = pions()) translate([p[0], y_cv - eps, p[1]]) rotate([-90, 0, 0]) cylinder(d = pion_d, h = peau_e * 0.7);
}

module couvercle_monde() {
    difference() {
        couche(y_cv, peau_e) difference() { collerette2(); ouv_piece2(); }
        for (p = pions()) translate([p[0], y_cv - eps, p[1]]) rotate([-90, 0, 0]) cylinder(d = pion_d + serrage, h = peau_e * 0.7 + jeu);
    }
    // butée en U de la moitié gauche, appuyée sur la face arrière du battant
    couche(y_lip, y_cv - y_lip + eps) difference() {
        intersection() { offset(delta = -jeu / 2) cavite2(); rect2(-cav_x, -1, x_ax - g_ax, H); }
        rrect2(-ouv_l / 2, z_bas, x_ax + r_coin, z_haut, r_coin);
    }
    // taquets qui ferment les paliers derrière les tourillons
    r = tour_rc + jeu / 2;
    for (p = [pal_h, pal_b]) translate([x_ax - r, y_ax + tour_rc + jeu, p[0] + jeu / 2])
        cube([2 * r, y_cv - (y_ax + tour_rc + jeu) + eps, p[1] - p[0] - jeu]);
}

// battant : repère du mur, fermé. Tourillons octogonaux sur l'axe, téton d'élastique à l'arrière.
module battant_monde() {
    couche(y_pf, batt_e) battant2();
    for (z = [[f_t - eps, tour_l + eps], [f_b - tour_l, tour_l + eps]])
        translate([x_ax, y_ax, z[0]]) rotate([0, 0, 22.5]) cylinder(r = tour_rc, h = z[1], $fn = 8);
    translate([x_ax + x_b, y_pf + batt_e - eps, z_b]) rotate([-90, 0, 0]) {
        cylinder(d = tet_d, h = tet_l * 0.75);
        translate([0, 0, tet_l * 0.75 - eps]) cylinder(d1 = tet_d, d2 = tet_d * 1.6, h = tet_l * 0.25);
    }
}
module battant_tourne(a) translate([x_ax, y_ax, 0]) rotate([0, 0, a]) translate([-x_ax, -y_ax, 0]) battant_monde();

module assemblage(ecarte = 0) {
    e = ecarte;
    color("Peru") translate([0, -2 * e, 0]) cadre_monde();
    if (!coupe) color("BurlyWood", 0.85) translate([0, 3 * e, 0]) couvercle_monde();
    color("SteelBlue") battant_tourne(angle);
    // élastique
    color("Red") hull() {
        translate([x_ax, y_ax, 0]) rotate([0, 0, angle]) translate([x_b, d_b, z_b]) sphere(d = max(0.8, 2 * E));
        translate([x_a, y_ax + y_a, z_a]) sphere(d = max(0.8, 2 * E));
    }
    if (reel && !coupe) color("Tan", 0.35) difference() {
        translate([-137.5, peau_e, 0]) cube([275, contreplaque, H + 30]);
        translate([-L2 - 0.5, -1, -1]) cube([2 * L2 + 1, 40, H + 1.5]);
    }
}

module cadre_plat()     rotate([90, 0, 0]) cadre_monde();
module couvercle_plat() translate([0, 0, epais]) rotate([-90, 0, 0]) couvercle_monde();
module battant_plat()   rotate([90, 0, 0]) translate([0, -y_pf, 0]) battant_monde();
module planche() {
    g = 5;
    translate([-(L2 + colle) - g / 2, 0, 0]) cadre_plat();
    translate([(L2 + colle) + g / 2, 0, 0]) couvercle_plat();
    translate([(L2 + colle) + g / 2, f_b - tour_l - g, 0]) battant_plat();   // devant le couvercle, à côté du cadre
}

if      (part == "assembled") assemblage();
else if (part == "eclate")    assemblage(reel ? 15 : 6);
else if (part == "cadre")     cadre_plat();
else if (part == "couvercle") couvercle_plat();
else if (part == "battant")   battant_plat();
else if (part == "planche")   planche();
