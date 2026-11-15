// =====================================================================
//  Chatière d'hiver — concept A « SAS » : module de porte escamotable
//
//  Un MODULE imprimé s'insère dans une encoche du côté gauche du caisson
//  (contreplaqué) : deux collerettes pincent le bois.
//
//   - CADRE (pièce principale, imprimée face sur le plateau) : peau côté sas
//     avec collerette, toute l'épaisseur du mur sur les bords, canaux de la
//     porte et des coulisseaux, poteaux d'élastiques, et quatre petits pivots à
//     tête conique qui dépassent côté pièce.
//   - COUVERCLE (peau côté pièce) : ses quatre trous en serrure passent sur les
//     têtes des pivots, puis il descend de quelques mm et y reste suspendu par
//     son poids, comme un cadre photo sur ses clous. Il porte le pivot du levier
//     et des plots qui tiennent la plaque intermédiaire.
//   - Dedans : la PORTE glisse verticalement et descend dans la poche du bas ;
//     la PLAQUE INTERMÉDIAIRE la sépare du LEVIER ; deux COULISSEAUX traversent
//     le module et portent un REBORD de chaque côté (queue d'aronde).
//     Le chat pose les pattes sur un rebord -> le chariot descend -> le levier,
//     appuyé près de son pivot, fait descendre la porte `rapport` fois plus.
//     Des élastiques remontent le tout.
//   - Aucune vis. Paramètre `echelle` : 1 = taille réelle, 0,4 = maquette
//     (voir porte_rebord_maquette.scad).
//
//  Repère (aperçu `assembled`) :
//    X = le long du mur (0 = centre de l'ouverture), vu depuis le sas
//    Z = hauteur, 0 = dessus du plancher du sas (bas du module)
//    Y = épaisseur : y = 0 face extérieure côté sas, y croît vers la pièce
//  Unités : mm. Plateau visé : 260 x 260.
// =====================================================================

part = "assembled"; // [assembled, eclate, cadre, couvercle, intermediaire, porte, levier, coulisseau, rebord, enjoliveur, planche_1, planche_2]
echelle = 1;          // 1 = réel ; 0.4 = maquette
ouvert = false;       // aperçu : porte ouverte (chariot enfoncé) ou fermée
coupe = false;        // aperçu : sans couvercle ni enjoliveur côté pièce

/* [Cotes réelles (multipliées par echelle)] */
ouv_l_r = 130;        // ouverture (largeur)
ouv_h_r = 110;        // ouverture (hauteur)
r_arche_r = 40;       // rayon des coins hauts (arche)
course_r = 20;        // descente du rebord sous les pattes
bras_r = 160;         // pivot -> pointe du levier
contreplaque = 12;    // épaisseur du côté du caisson (réel)
chat_kg = 4.0;
densite = 1.24;       // PLA

E = echelle;
$fn = E < 0.7 ? 32 : 48;
eps = 0.01;

// ---- cotes dans le plan du mur ----
ouv_l   = ouv_l_r * E;
ouv_h   = ouv_h_r * E;
r_arche = r_arche_r * E;
r_bas   = 5 * E;
course  = course_r * E;
bras    = bras_r * E;
recouv  = 8 * E;
recouv_hb = 5 * E;
bordure = max(2, 4 * E);          // bord plein du cadre
colle   = 5 * E;                  // collerette qui recouvre le contreplaqué
appui   = max(1.2, 3 * E);        // portée de la plaque intermédiaire
levier_l = max(4, 12 * E);
coul_l  = max(5, 12 * E);
tenon_l = max(3.5, 8 * E);
tenon_l2 = tenon_l + max(1.2, 3 * E);
tenon_h = max(2, 5 * E);
tenon_sort = max(4, 10 * E);
rebord_p = max(14, 35 * E);
rebord_e = max(3.5, 8 * E);
h_axe   = 30 * E;
poteau_d = max(2, 5 * E);         // poteaux d'élastiques
pivot_d = max(2.5, 6 * E);        // pivot du levier (sur le couvercle)
axe_ch_d = max(1.6, 3 * E);       // tige des pivots de fixation du couvercle
enj_l   = 12 * E;
enj_h   = max(1.2, 3 * E);

// ---- épaisseurs (minimums imprimables) ----
peau_e  = max(1.2, 3 * E);
porte_e = max(1.2, 3 * E);
feutre_e = E >= 0.7 ? 1 : 0;
jeu     = max(0.3, 0.6 * E);
inter_e = max(0.8, 1.5 * E);
levier_e = max(2, 5 * E);
c_porte = porte_e + 2 * feutre_e + jeu;
c_meca  = levier_e + max(0.5, 1 * E);

y_p1    = peau_e;                  // couche porte
y_int   = y_p1 + c_porte;          // plaque intermédiaire
y_m1    = y_int + inter_e;         // couche mécanisme
y_cv    = y_m1 + c_meca;           // couvercle
epais   = y_cv + peau_e;
y_porte = y_p1 + feutre_e + jeu / 2;
y_levier = y_m1 + (c_meca - levier_e) / 2;

// ---- géométrie du mécanisme ----
porte_l = ouv_l + 2 * recouv;
porte_h = ouv_h + 2 * recouv_hb;
bas_ouv_porte = bordure + max(0.5, 1 * E);       // bas de la porte, ouverte
levee   = porte_h - recouv_hb + max(1, 2 * E);
z_porte_f = bas_ouv_porte + levee;
z_bas   = z_porte_f + recouv_hb;
z_haut  = z_bas + ouv_h;
haut_porte = z_porte_f + porte_h;
poche_x = porte_l / 2 + jeu + appui;            // demi-largeur du logement de la plaque intermédiaire
x_coul  = poche_x + max(1.2, 2 * E) + jeu + coul_l / 2;
rapport = levee / course;
theta   = asin((levee / 2) / bras);
a_bras  = bras / rapport * cos(theta);
P_x     = x_coul + a_bras;
z_pin_f = z_porte_f + h_axe;
P_z     = z_pin_f - levee / 2;
x_pin_min = P_x - bras;
x_pin_max = P_x - bras * cos(theta);
L2      = P_x + levier_l / 2 + 2 * E + jeu + bordure;   // demi-largeur du corps
H       = haut_porte + jeu + bordure + max(3, 4 * E);   // hauteur du corps
z_crochet = H - bordure - max(2, 4 * E) - poteau_d / 2;
x_ch    = (x_coul + coul_l / 2 + jeu + L2 - bordure) / 2;  // pivots de fixation, entre canal et bord

function z_levier(x, ang) = P_z + (P_x - x) * tan(ang);
z_lev_f = z_levier(x_coul, theta);
z_rebord_f = z_bas - 2 * E;
coul_z0 = z_lev_f - levier_l / 2 - max(2, 5 * E);
coul_z1 = z_rebord_f - rebord_e + tenon_h;
coul_h  = coul_z1 - coul_z0;

m_porte = porte_l * porte_h * porte_e / 1000 * densite;
F_elast = (m_porte * 0.00981 + (E >= 0.7 ? 0.5 : 0.05)) * rapport * 1.3;

echo(str("[echelle ", E, "] corps ", 2 * L2, " x ", H, " x ", epais, " mm ; avec collerettes ",
         2 * (L2 + colle), " x ", H + colle));
echo(str("Ouverture ", ouv_l, " x ", ouv_h, " de z = ", z_bas, " à ", z_haut, " ; porte ", porte_l, " x ", porte_h,
         " (", round(m_porte), " g), descend de ", levee));
echo(str("Levier ", bras, " mm, rapport ", round(rapport * 10) / 10, ", rotation ±", round(theta),
         "° ; élastiques ~", round(F_elast * 10) / 10, " N au total"));
if (E >= 0.7) echo(str("Encoche dans le contreplaqué : ", 2 * L2 + 1, " x ", H + 0.5,
                       " mm depuis le bas ; le module dépasse de ", epais - 2 * peau_e - contreplaque, " mm"));

assert(z_haut + enj_l <= H, "L'ouverture est trop haute : réduire ouv_h.");
assert(x_pin_min > -porte_l / 2 + 3 * levier_l / 2, "La pointe du levier sort de la porte : réduire bras.");
assert(E < 0.7 || 2 * (L2 + colle) <= 258, "Le cadre dépasse le plateau de 260 mm.");
assert(E < 0.7 || H + colle <= 258, "Le cadre dépasse le plateau de 260 mm (hauteur).");
assert(chute < course, "Les tenons sortiraient des fentes à la pose du couvercle.");
assert(E < 0.7 || F_elast < chat_kg * 9.81 * 0.6, "Les élastiques sont trop forts pour le chat.");

// ---------------------------------------------------------------------
// Contours 2D (plan X-Z)
// ---------------------------------------------------------------------
module rect2(x0, z0, x1, z1) translate([x0, z0]) square([x1 - x0, z1 - z0]);
module rrect2(x0, z0, x1, z1, r) translate([x0 + r, z0 + r]) offset(r = r) square([x1 - x0 - 2 * r, z1 - z0 - 2 * r]);
module corps2() rect2(-L2, 0, L2, H);
// collerettes : côtés et haut arrondis, bas droit (posé sur le plancher)
module collerette2() hull() {
    rect2(-L2 - colle, 0, L2 + colle, 1);
    for (s = [-1, 1]) translate([s * (L2 + colle - 3 * E), H + colle - 3 * E]) circle(r = 3 * E);
}
module ouverture2(m = 0) offset(delta = m) hull() for (s = [-1, 1]) {
    translate([s * (ouv_l / 2 - r_arche), z_haut - r_arche]) circle(r = r_arche, $fn = 96);
    translate([s * (ouv_l / 2 - r_bas), z_bas + r_bas]) circle(r = r_bas);
}
module canal_porte2() rect2(-porte_l / 2 - jeu, bordure, porte_l / 2 + jeu, haut_porte + jeu);
module poche2() rect2(-poche_x, bordure, poche_x, H - bordure);
module canaux2() for (s = [-1, 1])
    hull() for (z = [coul_z0 - course - 0.5 + coul_l / 2, z_crochet + poteau_d / 2 + jeu + coul_l / 2])
        translate([s * x_coul, z]) circle(d = coul_l + 2 * jeu);
module balayage2() hull() {
    translate([P_x, P_z]) circle(d = levier_l + 4 * E + 2 * jeu);
    for (a = [-theta - 2, 0, theta + 2]) translate([P_x, P_z]) rotate(180 - a) translate([bras, 0]) circle(d = levier_l + 4 * E);
}
module lumiere2() hull() for (x = [x_pin_min, x_pin_max], z = [z_pin_f, z_pin_f - levee])
    translate([x, z]) circle(d = levier_l * 0.45 + 2 * jeu);
module fentes2() for (s = [-1, 1])
    rect2(s * x_coul - tenon_l2 / 2 - jeu, coul_z1 - tenon_h - course - jeu, s * x_coul + tenon_l2 / 2 + jeu, coul_z1 + jeu);
// pivots de fixation du couvercle : tige + tête conique (imprimable sans support)
tete_d  = 2.4 * axe_ch_d;
tete_h  = 0.7 * axe_ch_d + max(0.4, 0.6 * E);
chute   = (tete_d + axe_ch_d) / 2 + 2 * jeu;     // le couvercle se pose `chute` plus haut puis descend
function pivots() = [for (s = [-1, 1], z = [H - bordure - tete_d / 2 - 2 * E, chute + tete_d / 2 + bordure]) [s * x_ch, z]];
// trou en serrure du couvercle : gros trou en bas (passe la tête), fente au-dessus (tient la tige)
module serrure2(p) {
    translate([p[0], p[1] - chute]) circle(d = tete_d + 2 * jeu);
    hull() for (dz = [-chute, 0]) translate([p[0], p[1] + dz]) circle(d = axe_ch_d + 2 * jeu);
}
// plots du couvercle qui tiennent la plaque intermédiaire
function plots() = [[-poche_x + 4 * E, H - bordure - 5 * E], [poche_x - 4 * E, H - bordure - 5 * E],
                    [-poche_x + 4 * E, bordure + 6 * E], [poche_x - 6 * E, bordure + 6 * E]];

// ---------------------------------------------------------------------
// Pièces en place (repère du mur)
// ---------------------------------------------------------------------
module en_place(y0) translate([0, y0, 0]) rotate([90, 0, 0]) mirror([0, 0, 1]) children();
module couche(y0, e) en_place(y0) linear_extrude(e) children();
module bride_y(x, z, d, y0, y1) translate([x, y0, z]) rotate([-90, 0, 0]) cylinder(d = d, h = y1 - y0);

module cadre_monde() {
    difference() {
        union() {
            couche(0, peau_e) difference() { collerette2(); ouverture2(); fentes2(); }
            couche(y_p1 - eps, c_porte + 2 * eps) difference() { corps2(); canal_porte2(); canaux2(); }
            couche(y_int, inter_e + eps) difference() { corps2(); poche2(); canaux2(); }
            couche(y_m1, c_meca) difference() { corps2(); poche2(); balayage2(); canaux2(); }
        }
        // logement de la pointe du pivot du levier, allongé vers le haut pour la pose du couvercle
        hull() for (dz = [0, chute]) bride_y(P_x, P_z + dz, pivot_d + 2 * jeu, y_m1 - 1.2 * E - jeu, y_m1 + 1);
    }
    // poteaux d'élastiques (dans les canaux)
    for (s = [-1, 1]) bride_y(s * x_coul, z_crochet, poteau_d, y_p1 - eps, y_cv - jeu);
    // pivots de fixation du couvercle : traversent la peau côté pièce, tête apparente
    for (p = pivots()) translate([p[0], y_cv - eps, p[1]]) rotate([-90, 0, 0]) {
        cylinder(d = axe_ch_d, h = peau_e + jeu + eps);
        translate([0, 0, peau_e + jeu]) cylinder(d1 = axe_ch_d, d2 = tete_d, h = 0.7 * axe_ch_d);
        translate([0, 0, peau_e + jeu + 0.7 * axe_ch_d - eps]) cylinder(d = tete_d, h = tete_h - 0.7 * axe_ch_d + eps);
    }
}

module couvercle_monde() {
    couche(y_cv, peau_e) difference() {
        collerette2(); ouverture2(); fentes2();
        for (p = pivots()) serrure2(p);
    }
    // pivot du levier
    bride_y(P_x, P_z, pivot_d, y_m1 - 1.2 * E, y_cv + eps);
    // plots
    for (p = plots()) bride_y(p[0], p[1], max(3, 7 * E), y_m1 + 0.1, y_cv + eps);
}

module intermediaire2() difference() {
    rect2(-poche_x + jeu / 2, bordure + jeu / 2, poche_x - jeu / 2, H - bordure - jeu / 2);
    ouverture2(); lumiere2();
}

module porte2() difference() {
    rrect2(-porte_l / 2, 0, porte_l / 2, porte_h, 3 * E);
    hull() for (x = [x_pin_min, x_pin_max]) translate([x, h_axe]) circle(d = levier_l * 0.45 + 2 * jeu);
}

module levier() {
    // pivot à l'origine, pointe vers -x, à plat ; téton vers -z (côté porte)
    e = levier_e;
    td = levier_l * 0.45;
    tl = y_levier - (y_porte + porte_e * 0.25);
    difference() {
        union() {
            linear_extrude(e) hull() { circle(d = levier_l + 4 * E); translate([-bras * 0.35, 0]) circle(d = levier_l); }
            linear_extrude(e) hull() { translate([-bras * 0.35, 0]) circle(d = levier_l); translate([-bras, 0]) circle(d = levier_l * 0.8); }
            translate([-bras, 0, -tl]) cylinder(d = td, h = tl + e / 2);
            translate([-bras, 0, -tl]) sphere(d = td);
        }
        translate([0, 0, -1]) cylinder(d = pivot_d + 2 * jeu, h = e + 2);
        for (k = [0.45, 0.62, 0.79]) translate([-bras * k, 0, -1]) linear_extrude(e + 2)
            hull() { circle(d = levier_l * 0.42); translate([bras * 0.09, 0]) circle(d = levier_l * 0.25); }
    }
}

module queue_aronde2(m = 0) polygon([[-tenon_l / 2 - m, -tenon_h - m], [tenon_l / 2 + m, -tenon_h - m],
                                    [tenon_l2 / 2 + m, m], [-tenon_l2 / 2 - m, m]]);
module coulisseau() {
    // x centré, z = 0 au bas, y = 0 face extérieure côté sas
    r = min(2, coul_l / 4);
    difference() {
        union() {
            translate([0, y_p1 + jeu, 0]) rotate([-90, 0, 0]) mirror([0, 1, 0])
                linear_extrude(y_cv - y_p1 - 2 * jeu) rrect2(-coul_l / 2, 0, coul_l / 2, coul_h - tenon_h / 2, r);
            translate([0, -tenon_sort, coul_h]) rotate([-90, 0, 0]) mirror([0, 1, 0])
                linear_extrude(epais + 2 * tenon_sort) queue_aronde2();
        }
        // fenêtre du levier
        translate([-coul_l, y_levier - jeu, z_lev_f - coul_z0 - levier_l / 2 - jeu])
            cube([2 * coul_l, levier_e + 2 * jeu, levier_l + 2 * jeu]);
        // trou pour la boucle d'élastique, sous la queue d'aronde
        translate([0, epais / 2, coul_h - tenon_h - max(1.5, 3 * E)]) rotate([0, 90, 0])
            cylinder(d = max(1.2, 2.5 * E), h = coul_l + 2, center = true);
    }
}

module patte2(s) scale(s) {
    translate([0, -2]) scale([1.25, 1]) circle(d = 9);
    for (p = [[-6.5, 4.5], [-2.3, 8], [2.3, 8], [6.5, 4.5]]) translate(p) scale([0.85, 1]) circle(d = 4.2);
}
module rebord() {
    // à plat, face d'appui vers +z ; bord côté mur en y = 0
    lg = 2 * x_coul + tenon_l2 + 8 * E;
    rf = rebord_p * 0.6;
    ch = min(1.5, rebord_e / 4);
    difference() {
        hull() for (s = [-1, 1]) {
            translate([s * (lg / 2 - rf), rebord_p - rf, 0]) cylinder(r = rf, h = rebord_e - ch, $fn = 64);
            translate([s * (lg / 2 - rf), rebord_p - rf, rebord_e - ch]) cylinder(r1 = rf, r2 = rf - ch, h = ch, $fn = 64);
            translate([s * lg / 2 - (s > 0 ? 1 : 0), 0, 0]) cube([1, 0.01, rebord_e]);
        }
        for (s = [-1, 1]) translate([s * x_coul, -1, tenon_h - eps]) rotate([-90, 0, 0]) mirror([0, 1, 0])
            linear_extrude(tenon_sort + 1.5) queue_aronde2(jeu / 2);
        for (x = [-lg / 4, lg / 4]) translate([x, rebord_p * 0.55, rebord_e - 0.6]) linear_extrude(1) patte2(rebord_p / 40);
    }
}

module arche2(w) intersection() { offset(r = w) ouverture2(); rect2(-500, z_bas + r_bas, 500, 1000); }
module enjoliveur() {
    // z = 0 contre la peau ; lèvre vers -z
    n = 6;
    lw = max(0.8, 1.6 * E);
    difference() {
        for (i = [0 : n - 1]) {
            a0 = 90 * i / n; a1 = 90 * (i + 1) / n;
            hull() {
                translate([0, 0, enj_h * sin(a0)]) linear_extrude(eps) arche2(enj_l * cos(a0));
                translate([0, 0, enj_h * sin(a1) - eps]) linear_extrude(eps) arche2(max(0.3, enj_l * cos(a1)));
            }
        }
        translate([0, 0, -1]) linear_extrude(enj_h + 2) ouverture2(-lw);
    }
    translate([0, 0, -peau_e]) linear_extrude(peau_e + eps) difference() {
        intersection() { ouverture2(-0.1); rect2(-500, z_bas + r_bas, 500, 1000); }
        ouverture2(-lw);
    }
}

// ---------------------------------------------------------------------
// Assemblage
// ---------------------------------------------------------------------
module assemblage(ecarte = 0) {
    p   = ouvert ? 1 : 0;
    ang = ouvert ? -theta : theta;
    dz  = -p * course;
    e   = ecarte;
    color("Peru") translate([0, -2 * e, 0]) cadre_monde();
    color("Sienna") en_place(-2 * e) mirror([0, 0, 1]) enjoliveur();
    if (!coupe) {
        color("BurlyWood", 0.85) translate([0, 3 * e, 0]) couvercle_monde();
        color("Sienna") en_place(epais + 3 * e) enjoliveur();
    }
    color("White", 0.4) couche(y_int + e, inter_e) intermediaire2();
    color("SteelBlue") en_place(y_porte - e) translate([0, z_porte_f - p * levee]) linear_extrude(porte_e) porte2();
    color("Gold") en_place(y_levier + 2 * e) translate([P_x, P_z]) rotate(-ang) levier();
    color("ForestGreen") for (s = [-1, 1]) translate([s * x_coul, 0, coul_z0 + dz]) coulisseau();
    color("Green") {
        translate([0, -2 * e, z_rebord_f - rebord_e + dz]) mirror([0, 1, 0]) rebord();
        translate([0, epais + 3 * e, z_rebord_f - rebord_e + dz]) rebord();
    }
    color("Red") for (s = [-1, 1]) hull() {
        translate([s * x_coul, epais / 2, coul_z0 + coul_h - tenon_h - max(1.5, 3 * E) + dz]) sphere(d = max(0.8, 2 * E));
        translate([s * x_coul, epais / 2, z_crochet]) sphere(d = max(0.8, 2 * E));
    }
    if (E >= 0.7 && !coupe) color("Tan", 0.35) difference() {        // côté en contreplaqué avec l'encoche
        translate([-137.5, y_p1 + (c_porte + inter_e + c_meca - contreplaque) / 2, 0]) cube([275, contreplaque, 285]);
        translate([-L2 - 0.5, -1, -1]) cube([2 * L2 + 1, 40, H + 1.5]);
    }
}

// ---------------------------------------------------------------------
// Pièces à plat pour l'impression
// ---------------------------------------------------------------------
module cadre_plat()      rotate([90, 0, 0]) cadre_monde();                                      // face sas sur le plateau
module couvercle_plat()  translate([0, 0, epais]) rotate([-90, 0, 0]) couvercle_monde();        // face pièce sur le plateau
module levier_plat()     rotate([180, 0, 0]) translate([0, 0, -levier_e]) levier();             // téton vers le haut
module coulisseau_plat() translate([0, 0, max(coul_l, tenon_l2) / 2]) rotate([0, 90, 0]) coulisseau();
module enjoliveur_plat() translate([0, 0, peau_e]) enjoliveur();

// maquette : deux planches de 260 x 260
module planche_1() {
    g = 5;
    translate([-(L2 + colle) - g / 2, 0, 0]) cadre_plat();
    translate([(L2 + colle) + g / 2, 0, 0]) couvercle_plat();
}
module planche_2() {
    g = 5;
    linear_extrude(inter_e) intermediaire2();
    translate([-poche_x - g - porte_h, porte_l / 2 + bordure, 0]) rotate(-90) linear_extrude(porte_e) porte2();
    translate([poche_x + g + levier_l, g, 0]) rotate(90) translate([bras, 0, 0]) levier_plat();
    for (k = [0, 1]) translate([poche_x + 3 * g + 1.5 * levier_l + k * (coul_h + g + 4), bras + 3 * g, 0]) coulisseau_plat();
    for (k = [0, 1]) translate([0, H + g + k * (rebord_p + g), 0]) rebord();
    for (s = [-1, 1]) translate([s * (ouv_l / 2 + enj_l + g / 2), H + 2 * (rebord_p + g) - z_bas - r_bas, 0]) enjoliveur_plat();
}

// ---------------------------------------------------------------------
if      (part == "assembled")     assemblage();
else if (part == "eclate")        assemblage(E >= 0.7 ? 15 : 6);
else if (part == "cadre")         cadre_plat();
else if (part == "couvercle")     couvercle_plat();
else if (part == "intermediaire") linear_extrude(inter_e) intermediaire2();
else if (part == "porte")         linear_extrude(porte_e) porte2();
else if (part == "levier")        levier_plat();
else if (part == "coulisseau")    coulisseau_plat();
else if (part == "rebord")        rebord();
else if (part == "enjoliveur")    enjoliveur_plat();
else if (part == "planche_1")     planche_1();
else if (part == "planche_2")     planche_2();
