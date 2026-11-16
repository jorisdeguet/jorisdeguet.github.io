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
//  Fermeture en deux temps :
//   - RAPPEL DOUX : un élastique s'enroule sur une CAME en spirale en haut
//     de l'axe. Son rayon diminue quand la porte s'ouvre : le couple baisse
//     (`ratio_couple`) même si l'élastique tire plus fort. La came est une
//     pièce à part, à réimprimer pour changer la force ;
//   - VERROU : des aimants en vis-à-vis dans la bande d'appui du battant et
//     dans la butée (peau du cadre à droite, butée du couvercle à gauche).
//     Poches à plusieurs distances de l'axe : plus près, moins dur à pousser.
//  Le battant porte des nervures en treillis triangulé sur sa face côté
//  pièce, à l'intérieur de l'ouverture ; les bandes d'appui restent plates.
//
//  Pièces, sans vis :
//   - CADRE (face côté sas sur le plateau) : peau avec collerette et butée,
//     toute l'épaisseur du mur, paliers de l'axe ouverts vers l'arrière,
//     chambre de la came avec 3 poteaux d'élastique, 4 tiges filetées
//     imprimées dans les coins, poches d'aimants dans la peau ;
//   - BATTANT (à plat, nervures vers le haut) : tourillon octogonal en bas,
//     mortaise en haut pour la came, poches d'aimants ;
//   - CAME (came sur le plateau) : came, tourillon rond du haut et tenon ;
//   - COUVERCLE (face côté pièce sur le plateau) : peau avec collerette,
//     butée en U de la moitié gauche (poches d'aimants), deux taquets qui
//     ferment les paliers ; 4 molettes imprimées, taraudées, se serrent à
//     la main côté pièce sur les tiges du cadre.
//
//  Repère : comme porte_rebord.scad (X le long du mur vu du sas, Z hauteur,
//  Y épaisseur, y = 0 face côté sas). L'axe est en x = 0.
// =====================================================================

part = "eclate"; // [assembled, eclate, cadre, couvercle, battant, came, molette, planche]
echelle = 1;          // 1 = réel ; 0.4 = maquette
part_gauche = 0.5;    // part du battant à gauche de l'axe (vu du sas) ; > 0.5 : le vent du dehors le referme

/* [Aperçu] */
// angle d'ouverture du battant dans l'aperçu (0 fermé, 90 grand ouvert ; négatif = bloqué par les butées)
angle = 0; // [-5:5:90]
coupe = false;        // aperçu : sans couvercle

/* [Cotes réelles (multipliées par echelle)] */
ouv_l_r = 210;        // ouverture totale : deux passages d'environ 100 mm
ouv_h_r = 125;        // juste assez pour un chat adulte
r_coin_r = 30;        // rayon des coins de l'ouverture (battant : + recouvrement, cadre : + bordure)
z_bas_r = 30;         // seuil de l'ouverture au-dessus du plancher du sas
angle_max = 100;      // ouverture maximale : le battant bute ensuite sur le couvercle, près de l'axe
/* [Came et élastique] */
came_r0_r = 8.5;      // rayon de la came, porte fermée
pretension_r = 20;    // allongement de l'élastique, porte fermée (règle la forme de la spirale)
ratio_couple = 0.5;   // couple à angle_max / couple porte fermée
poteau = 2;           // poteau où l'élastique est accroché dans l'aperçu (0, 1, 2 : de plus en plus tendu)
k_elast = 0.1;        // raideur supposée de l'élastique, N/mm (seulement pour les échos)
/* [Aimants] */
aim_d_r = 6;          // aimant disque Ø x épaisseur (maquette : Ø2 x 1)
aim_e_r = 2;
aim_dist_r = [15, 30, 45, 60, 80];   // distances des poches à l'axe
/* [Nervures du battant] */
nervures = true;
nerv_maille_r = 35;   // côté des triangles du treillis
nerv_h_r = 5;         // hauteur des nervures (côté pièce)
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
bordure_s = max(7, 8 * E);         // côtés : place pour les tiges et la sortie du fil
colle  = 5 * E;
peau_e = max(1.2, 3 * E);
batt_e = max(3.2, 6 * E);          // épaisseur du battant
feutre_e = reel ? 1 : 0;
jeu    = max(0.3, 0.6 * E);
tour_l = max(3, 5 * E);            // longueur des tourillons
// tourillon octogonal : méplats dessus/dessous à l'impression, épaisseur = celle du battant
tour_rc = batt_e / 2 / cos(22.5);
g_ax   = batt_e + jeu;             // zone de l'axe où les butées changent de côté
// came : plaque à gorge (joue / gorge / joue) en haut de l'axe, avec tourillon rond et tenon
x0_el  = pretension_r * E;
r_pin  = batt_e / 2;               // tourillon rond de la came
came_j = max(0.6, 1 * E);          // joues
came_g = max(1.6, 3 * E);          // gorge
came_h = 2 * came_j + came_g;
th_max = angle_max * PI / 180;
ten_w  = max(2.4, 5 * E);          // tenon en lame dans le chant du battant
ten_e  = max(1.2, 2 * E);
ten_p  = max(5, 8 * E);
jt     = reel ? 0.2 : 0.15;
// aimants
aim_d  = reel ? aim_d_r * E : 2;
aim_e  = reel ? aim_e_r * E : 1;
aim_p  = aim_e + 0.2;              // profondeur des poches
aim_dist = [for (d = aim_dist_r) d * E];
// nervures
nerv_h = max(2, nerv_h_r * E);
nerv_l = max(1.2, 2 * E);
nerv_m = max(2, 3 * E);            // retrait par rapport au bord de l'ouverture
nerv_p = max(10, nerv_maille_r * E) * sin(60);   // écart entre nervures parallèles
// tiges filetées imprimées avec le cadre, molettes taraudées imprimées
// filet imprimable : cercle excentré tordu en hélice (profil arrondi, sans support)
tige_d = reel ? 10 : 6;            // diamètre extérieur du filet
pas    = reel ? 3 : 2;
prof_f = reel ? 1.2 : 0.8;         // profondeur du filet
jeu_f  = reel ? 0.35 : 0.25;       // jeu radial tige / molette
mol_d  = tige_d + 2 * (reel ? 3 : 2);   // molette : petite
mol_h  = reel ? 8 : 5;
r_bord = min(peau_e - 0.4, max(1, 2.5 * E));   // arrondi des bords où passe le chat

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
// bandeau du haut : palier rond, puis la chambre de la came
z_c0   = f_t + jeu + tour_l;                   // dessous de la came
H      = z_c0 + came_h + jeu + bordure;
r_po   = max(0.8, 1.5 * E);                     // poteaux d'élastique
x_po   = [for (d = [35, 50, 65]) x_ax + d * E];
y_po   = y_cv - jeu - r_po - max(0.2, 0.3 * E);
came_r0 = min(came_r0_r * E, y_po - r_po - y_ax);   // limité pour que l'élastique passe sous les poteaux
colle_h = colle;
r_batt = r_coin + recouv;                      // coins du battant
r_cav  = r_batt + jeu;                         // coins de la cavité

// profil de la came : rayon de contact quand le battant a tourné de t degrés (élastique : F = k (x0 + s))
// couple voulu T = T0 (1 - a u) ; (x0 + s)^2 = x0^2 + (2/k) int T ; r = T / (k (x0 + s))
a_c = 1 - ratio_couple;
function came_den(t) = let(th = t * PI / 180) sqrt(1 + 2 * came_r0 / x0_el * (th - a_c * th * th / (2 * th_max)));
function came_r(t) = max(r_pin, came_r0 * (1 - a_c * t / angle_max) / came_den(t));
function allong(t) = x0_el * (came_den(t) - 1);
// la came ne doit pas sortir de l'épaisseur intérieure en tournant (côté sas : l'axe est près de la peau)
function came_ymin() = min([for (t = [0 : 5 : angle_max]) for (a = [0 : 5 : angle_max]) (came_r(t) + came_j) * sin(90 - t + a)]);
function came_ymax() = max([for (t = [0 : 5 : angle_max]) for (a = [0 : 5 : angle_max]) (came_r(t) + came_j) * sin(90 - t + a)]);

zone_aire = ouv_l * ouv_h - (4 - PI) * r_coin * r_coin;
m_nerv = nervures ? zone_aire * 3 * nerv_l / nerv_p * nerv_h / 1000 * densite : 0;
m_batt = (porte_l * (f_t - f_b) - (4 - PI) * r_batt * r_batt) * batt_e / 1000 * densite + m_nerv;
passage_d = ouv_l / 2 - x_ax - g_ax;          // côté droit (vu du sas) : le chat qui sort du sas
passage_g = ouv_l / 2 + x_ax - g_ax;
bras = porte_l / 4;                            // le chat pousse vers le milieu d'un passage
// vent du dehors (pression côté sas) : couple de fermeture / couple d'ouverture (1 : neutre)
vent = pow(porte_l / 2 + x_ax, 2) / pow(porte_l / 2 - x_ax, 2);

echo(str("[echelle ", E, "] corps ", 2 * L2, " x ", H, " x ", epais, " mm ; avec collerettes ",
         2 * (L2 + colle), " x ", H + colle_h));
echo(str("Ouverture ", ouv_l, " x ", ouv_h, " de z = ", z_bas, " à ", z_haut, " ; passages de ", passage_d, " (droite, vu du sas) et ", passage_g,
         " ; battant ", porte_l, " x ", f_t - f_b, " x ", batt_e, (nervures ? str(" + nervures de ", nerv_h) : ""), " (", round(m_batt), " g)"));
echo(str("Came : rayon ", round(came_r(0) * 10) / 10, " fermé, ", round(came_r(45) * 10) / 10, " à 45°, ", round(came_r(90) * 10) / 10,
         " à 90°, ", round(came_r(angle_max) * 10) / 10, " à ", angle_max, "° ; l'élastique s'allonge de ", round(allong(angle_max) * 10) / 10,
         " mm en plus des ", x0_el, " du repos"));
echo(str("Rappel (élastique supposé de ", k_elast, " N/mm) : poussée au milieu d'un passage ",
         [for (t = [0, 45, 90, angle_max]) round(k_elast * (x0_el + allong(t)) * came_r(t) / bras * 1000 / 9.81)], " g à 0 / 45 / 90 / ", angle_max, "°"));
echo(str("Aimants Ø", aim_d, " x ", aim_e, " : poches à ", aim_dist, " mm de l'axe, en haut et en bas de chaque moitié. ",
         "Pour 1 N d'attraction, le chat pousse ", [for (d = aim_dist) round(d / bras * 100) / 100], " N au milieu du passage."));
echo(str("Vent du dehors : couple de fermeture ", round(vent * 100) / 100, " fois le couple d'ouverture"));
echo(str("Fixation : 4 tiges filetées imprimées Ø", tige_d, " pas ", pas, ", dépassant de ", l_tige, " mm ; 4 molettes Ø", mol_d, " x ", mol_h));
if (reel) echo(str("Encoche dans le contreplaqué : ", 2 * L2 + 1, " x ", H + 0.5, " mm depuis le bas (rectangle)"));
assert(!reel || 2 * (L2 + colle) <= 258, "Le cadre dépasse le plateau de 260 mm.");
assert(!reel || H + colle_h <= 258, "Le cadre est trop haut pour le plateau.");
assert(part_gauche >= 0.5, "La moitié gauche ne doit pas être la plus petite : le vent ouvrirait le battant.");
assert(f_b - tour_l - bordure_b() > 0, "Pas de place sous le battant pour le palier du bas.");
assert(-came_ymin() <= y_ax - peau_e - jeu, str("La came touche la peau côté sas en tournant : baisser came_r0_r (", round(-came_ymin() * 10) / 10, " > ", y_ax - peau_e - jeu, ")."));
assert(came_ymax() <= y_cv - jeu - y_ax, "La came touche le couvercle en tournant : baisser came_r0_r.");
assert(came_r0 + came_j + jeu < x_po[0] - x_ax - r_po, "La came touche le premier poteau.");
assert(y_ax + came_r0 <= y_po - r_po + 0.1, "L'élastique frotterait sur les poteaux plus proches : baisser came_r0_r.");
assert(aim_d + 2 * max(0.5, E) <= recouv, "Aimants trop grands pour la bande de recouvrement.");
function bordure_b() = max(1.5, 2 * E);

// ---------------------------------------------------------------------
module rect2(x0, z0, x1, z1) translate([x0, z0]) square([x1 - x0, z1 - z0]);
module rrect2(x0, z0, x1, z1, r) translate([x0 + r, z0 + r]) offset(r = r) square([x1 - x0 - 2 * r, z1 - z0 - 2 * r]);
module en_place(y0) translate([0, y0, 0]) rotate([90, 0, 0]) mirror([0, 0, 1]) children();
module couche(y0, e) en_place(y0) linear_extrude(e) children();
// plaque d'épaisseur e, bords arrondis (quart de rond r) sur la face z = 0 (bas) et/ou z = e (haut)
function retrait(t, r) = r - sqrt(max(0, r * r - (r - t) * (r - t)));
module plaque(e, r, bas = false, haut = false, n = 5) {
    z0 = bas ? r : 0;
    z1 = haut ? e - r : e;
    translate([0, 0, z0 - eps]) linear_extrude(z1 - z0 + 2 * eps) children();
    for (i = [0 : n - 1]) {
        t = r * (i + 0.5) / n;                 // distance moyenne de la tranche à la face
        if (bas)  translate([0, 0, r * i / n]) linear_extrude(r / n + eps) offset(delta = -retrait(t, r)) children();
        if (haut) translate([0, 0, e - r * (i + 1) / n - eps]) linear_extrude(r / n + eps) offset(delta = -retrait(t, r)) children();
    }
}
module couche_arrondie(y0, e, r, bas = false, haut = false) en_place(y0) plaque(e, r, bas, haut) children();

// corps et collerettes : rectangles ; seuls l'ouverture, le battant et la cavité sont arrondis
module corps2() rect2(-L2, 0, L2, H);
module collerette2() rect2(-L2 - colle, 0, L2 + colle, H + colle_h);
module battant2() rrect2(-porte_l / 2, f_b, porte_l / 2, f_t, r_batt);
module cavite2() offset(r = jeu) battant2();
// peau du sas : la moitié gauche passe en entier, la moitié droite s'appuie (recouvrement)
module ouv_sas2() {
    intersection() { cavite2(); rect2(-L2, 0, x_ax + g_ax, H); }
    rrect2(x_ax - r_coin, z_bas, ouv_l / 2, z_haut, r_coin);
}
// peau de la pièce : l'inverse
module ouv_piece2() { intersection() { cavite2(); rect2(x_ax - g_ax, 0, L2, H); } rrect2(-ouv_l / 2, z_bas, x_ax + r_coin, z_haut, r_coin); }
// tiges : dans les 4 coins du cadre, sur la diagonale entre le centre de l'arrondi de la cavité et le coin
function tiges() = [for (sx = [-1, 1], haut = [true, false]) let(
        c = [sx * (cav_x - r_cav), haut ? f_t + jeu - r_cav : f_b - jeu + r_cav],
        k = [sx * L2, haut ? H : 0],
        u = (k - c) / norm(k - c))
    c + u * (r_cav + max(1.5, 3 * E) + tige_d / 2 + jeu_f)];
l_tige = peau_e + mol_h + (reel ? 2 : 1);      // dépasse du dos du cadre
module filet(d, h, j = 0) linear_extrude(h, twist = -360 * h / pas, slices = max(8, ceil(h / pas * 24)), convexity = 6)
    translate([prof_f / 2, 0]) circle(r = d / 2 - prof_f / 2 + j, $fn = 32);

// paliers : fente ronde au bout, ouverte vers l'arrière (y = y_cv)
module palier(z0, z1, r) hull() {
    translate([x_ax, y_ax, z0]) cylinder(r = r, h = z1 - z0);
    translate([x_ax - r, y_ax, z0]) cube([2 * r, y_cv - y_ax + eps, z1 - z0]);
}
pal_h = [f_t + jeu - eps, z_c0 - jeu + eps];   // palier du haut : tourillon rond de la came
pal_b = [f_b - tour_l - eps, f_b - jeu + eps];         // palier du bas : le battant repose sur le bout du tourillon

// chambre de la came (2D, repère XZ) : de la came aux poteaux, toute l'épaisseur intérieure
module chambre2() rect2(x_ax - came_r0 - came_j - 2 * jeu, z_c0 - jeu, x_po[2] + r_po + max(2, 3 * E), z_c0 + came_h + jeu);
module poteaux_monde() for (x = x_po) translate([x, y_po, z_c0 - jeu - eps]) cylinder(r = r_po, h = came_h + 2 * jeu + 2 * eps, $fn = 24);

// came (2D) : spirale de 90° (porte fermée, contact de l'élastique) à 90 - angle_max ; ext = joue
module came2(ext = 0) union() {
    polygon(concat([[0, 0]], [for (t = [0 : angle_max / 32 : angle_max]) (came_r(t) + ext) * [cos(90 - t), sin(90 - t)]]));
    circle(r = r_pin);
}
trou_el = max(1, 1.6 * E);
module came_piece() {   // repère local : axe en (0, 0), dessous de la came en z = 0
    difference() {
        union() {
            linear_extrude(came_j) came2(came_j);
            translate([0, 0, came_j - eps]) linear_extrude(came_g + 2 * eps) came2();
            translate([0, 0, came_j + came_g]) linear_extrude(came_j) came2(came_j);
        }
        // trou pour accrocher l'élastique, près du début de la spirale
        rotate(70) translate([came_r0 - max(1.2, 2.5 * E), 0, -1]) cylinder(d = trou_el, h = came_h + 2, $fn = 12);
    }
    // tourillon rond, puis tenon en lame (dans le battant)
    translate([0, 0, -(tour_l + jeu) - eps]) cylinder(r = r_pin, h = tour_l + jeu + 2 * eps);
    translate([-ten_w / 2, -ten_e / 2, -(tour_l + jeu) - ten_p]) cube([ten_w, ten_e, ten_p + eps]);
}
module came_monde() translate([x_ax, y_ax, z_c0]) came_piece();

// aimants : [x, z, côté] ; côté 1 = moitié droite (face avant contre la peau du sas), -1 = moitié gauche (face arrière contre le couvercle)
function aimants() = [for (s = [1, -1], d = aim_dist, z = [f_b + recouv / 2, f_t - recouv / 2]) [x_ax + s * d, z, s]];
module poche_aim(y0, h) translate([0, y0, 0]) rotate([-90, 0, 0]) cylinder(d = aim_d + 0.3, h = h, $fn = 24);
aim_peau = aim_p > peau_e - 0.6;               // peau trop mince : la poche traverse

// tiges : du dos du cadre (y_cv) vers la pièce, bout chanfreiné
module tiges_monde() for (p = tiges()) translate([p[0], y_cv - eps, p[1]]) rotate([-90, 0, 0]) intersection() {
    filet(tige_d, l_tige + eps);
    cylinder(d1 = tige_d + 2 * l_tige, d2 = tige_d - 2 * prof_f, h = l_tige + eps);
}
module cadre_monde() {
    difference() {
        union() {
            couche_arrondie(0, peau_e, r_bord, bas = true) difference() { collerette2(); ouv_sas2(); }
            couche(peau_e - eps, y_cv - peau_e + eps) difference() { corps2(); cavite2(); chambre2(); }
        }
        for (p = [pal_h, pal_b]) palier(p[0], p[1], tour_rc + jeu);
        for (a = aimants()) if (a[2] > 0) translate([a[0], 0, a[1]])
            if (aim_peau) poche_aim(-eps, peau_e + 2 * eps); else poche_aim(peau_e - aim_p, aim_p + eps);
    }
    tiges_monde();
    poteaux_monde();
}

module couvercle_monde() {
    difference() {
        union() {
            couche_arrondie(y_cv, peau_e, r_bord, haut = true) difference() { collerette2(); ouv_piece2(); }
            // butée en U de la moitié gauche, appuyée sur la face arrière du battant
            couche(y_lip, y_cv - y_lip + eps) difference() {
                intersection() { offset(delta = -jeu / 2) cavite2(); rect2(-cav_x, -1, x_ax - g_ax, H); }
                rrect2(-ouv_l / 2, z_bas, x_ax + r_coin, z_haut, r_coin);
            }
        }
        for (p = tiges()) translate([p[0], y_cv - 1, p[1]]) rotate([-90, 0, 0]) cylinder(d = tige_d + 2 * jeu_f + 0.4, h = peau_e + 2);
        for (a = aimants()) if (a[2] < 0) translate([a[0], 0, a[1]]) poche_aim(y_lip - eps, aim_p + eps);
    }
    // taquets qui ferment les paliers derrière les tourillons
    r = tour_rc + jeu / 2;
    for (p = [pal_h, pal_b]) translate([x_ax - r, y_ax + tour_rc + jeu, p[0] + jeu / 2])
        cube([2 * r, y_cv - (y_ax + tour_rc + jeu) + eps, p[1] - p[0] - jeu]);
}

// nervures (2D) : contour et treillis triangulé, à l'intérieur de l'ouverture
module zone_nerv2() offset(delta = -nerv_m) rrect2(-ouv_l / 2, z_bas, ouv_l / 2, z_haut, r_coin);
module nervures2() {
    difference() { zone_nerv2(); offset(delta = -nerv_l) zone_nerv2(); }
    n = ceil(norm([ouv_l, ouv_h]) / 2 / nerv_p) + 1;
    intersection() {
        zone_nerv2();
        translate([x_ax, (z_bas + z_haut) / 2]) for (a = [0, 60, 120], i = [-n : n]) rotate(a)
            translate([-ouv_l, i * nerv_p - nerv_l / 2]) square([2 * ouv_l, nerv_l]);
    }
}
// battant : repère du mur, fermé. Bande d'appui plate : la moitié droite s'appuie de sa face avant, la gauche de sa face
// arrière ; l'autre face est arrondie au bord. Tourillon octogonal en bas, mortaise de la came en haut.
module battant_monde() difference() {
    union() {
        intersection() {
            couche_arrondie(y_pf, batt_e, batt_e * 0.4, haut = true) battant2();
            translate([x_ax, -1, -1]) cube([porte_l, epais + 2, H + 2]);
        }
        intersection() {
            couche_arrondie(y_pf, batt_e, batt_e * 0.4, bas = true) battant2();
            translate([x_ax - porte_l, -1, -1]) cube([porte_l, epais + 2, H + 2]);
        }
        if (nervures) couche(y_pf + batt_e - eps, nerv_h + eps) nervures2();
        translate([x_ax, y_ax, f_b - tour_l]) rotate([0, 0, 22.5]) cylinder(r = tour_rc, h = tour_l + eps, $fn = 8);
    }
    translate([x_ax - ten_w / 2 - jt, y_ax - ten_e / 2 - jt, f_t - ten_p - jt]) cube([ten_w + 2 * jt, ten_e + 2 * jt, ten_p + jt + 1]);
    for (a = aimants()) translate([a[0], 0, a[1]])
        if (a[2] > 0) poche_aim(y_pf - eps, aim_p + eps); else poche_aim(y_pf + batt_e - aim_p, aim_p + eps);
}
// molette : à plat, taraudée, moletée ; chanfrein d'entrée du filet en bas
module molette() difference() {
    k = reel ? 2.4 : 1.6;
    union() {
        cylinder(d = mol_d - k, h = mol_h);
        for (i = [0 : 9]) rotate(i * 36) translate([mol_d / 2 - k / 2, 0, 0]) cylinder(d = k, h = mol_h, $fn = 12);
    }
    translate([0, 0, -eps]) filet(tige_d, mol_h + 2 * eps, jeu_f);
    translate([0, 0, -eps]) cylinder(d1 = tige_d + 2 * jeu_f + 1, d2 = tige_d - 2 * prof_f, h = 1 + prof_f);
}
module battant_tourne(a) translate([x_ax, y_ax, 0]) rotate([0, 0, a]) translate([-x_ax, -y_ax, 0]) { battant_monde(); came_monde(); }
// élastique (aperçu) : du point de contact sur la came au poteau choisi
module elastique_monde(a = 0) color("Red") hull() {
    zc = z_c0 + came_h / 2;
    translate([x_ax, y_ax + came_r(max(0, a)), zc]) sphere(d = max(0.8, 1.5 * E), $fn = 8);
    translate([x_po[poteau], y_po - r_po, zc]) sphere(d = max(0.8, 1.5 * E), $fn = 8);
}

module assemblage(ecarte = 0) {
    e = ecarte;
    color("Peru") translate([0, -2 * e, 0]) cadre_monde();
    if (!coupe) color("BurlyWood", 0.85) translate([0, 3 * e, 0]) couvercle_monde();
    color("SteelBlue") translate([x_ax, y_ax, 0]) rotate([0, 0, angle]) translate([-x_ax, -y_ax, 0]) battant_monde();
    color("Orange") translate([x_ax, y_ax, 2 * e]) rotate([0, 0, angle]) translate([-x_ax, -y_ax, 0]) came_monde();
    if (e == 0) elastique_monde(angle);
    // tiges filetées et molettes
    for (p = tiges()) {
        if (!coupe) color("DimGray") translate([p[0], epais + 6 * e, p[1]]) rotate([-90, 0, 0]) rotate(360 * (peau_e + eps) / pas) molette();   // vissée
    }
    if (reel && !coupe) color("Tan", 0.35) difference() {
        translate([-137.5, peau_e, 0]) cube([275, contreplaque, H + 30]);
        translate([-L2 - 0.5, -1, -1]) cube([2 * L2 + 1, 40, H + 1.5]);
    }
}

module cadre_plat()     rotate([90, 0, 0]) cadre_monde();
module couvercle_plat() translate([0, 0, epais]) rotate([-90, 0, 0]) couvercle_monde();
module battant_plat()   rotate([90, 0, 0]) translate([0, -y_pf, 0]) battant_monde();
module came_plat()      rotate([180, 0, 0]) translate([0, 0, -came_h]) came_piece();

module planche() {
    g = 5;
    translate([-(L2 + colle) - g / 2, 0, 0]) cadre_plat();
    translate([(L2 + colle) + g / 2, 0, 0]) couvercle_plat();
    translate([(L2 + colle) + g / 2, f_b - tour_l - g, 0]) battant_plat();   // devant le couvercle, à côté du cadre
    for (i = [0 : 3]) translate([-(L2 + colle) - g / 2 + (i - 1.5) * (mol_d + g), mol_d / 2 + g, 0]) molette();
    translate([-(L2 + colle) - g / 2 + 2.5 * (mol_d + g), mol_d / 2 + g, 0]) came_plat();
}

if      (part == "assembled") assemblage();
else if (part == "eclate")    assemblage(reel ? 15 : 6);
else if (part == "cadre")     cadre_plat();
else if (part == "couvercle") couvercle_plat();
else if (part == "battant")   battant_plat();
else if (part == "came")      came_plat();
else if (part == "molette")   molette();
else if (part == "planche")   planche();
