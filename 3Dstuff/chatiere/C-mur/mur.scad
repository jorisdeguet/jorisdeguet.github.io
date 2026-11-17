// =====================================================================
//  Chatière d'hiver — concept C « MUR EN L » : le sas dans l'embrasure
//
//  Vu de la pièce, la partie GAUCHE de l'embrasure reste libre : le chat
//  monte sur l'appui à gauche, face à la fenêtre. En tournant à droite, il
//  fait face à une PAROI perpendiculaire à la fenêtre, qui porte le premier
//  MODULE B (../B-battant/battant.scad). Derrière, le sas occupe la partie
//  droite de l'embrasure :
//   - PAROI : module B posé sur l'appui (il dépasse un peu du bord de
//     l'appui, pour ne pas toucher le rebord PVC), CHAPEAU au-dessus, BANDE
//     arrière jusqu'à la fenêtre, posée sur le rebord PVC ;
//   - FAÇADE côté pièce, de la paroi au mur de droite : la VITRE 411 x 309
//     non coupée entre deux montants et deux traverses imprimés ;
//   - FENÊTRE : le deuxième module B prend la place de la chatière d'été
//     (250 x 290, ../../chatiere_ete), sous un CHAPEAU de fenêtre.
//  Mousse comprimée contre le mur de droite, le haut de l'embrasure et la
//  fenêtre : tout tient par friction, sans vis. Les pièces s'emboîtent par
//  languettes et rainures ; les âmes glissent entre les collerettes des
//  modules, comme le contreplaqué du concept B.
//
//  Repère : X le long de l'embrasure VU DE LA PIÈCE (0 = mur de gauche),
//  Y vers la fenêtre (0 = bord de l'appui), Z hauteur (0 = dessus de
//  l'appui).
// =====================================================================

include <../B-battant/battant.scad>

part = "none";        // le module B ne dessine rien de lui-même
vue = "assemble";     // [assemble, eclate, chapeau, bande_bas, bande_haut, traverse_bas, traverse_haut, montant_g, montant_d, chapeau_fenetre]
piece = 0;            // traverses : numéro du tronçon à exporter

/* [Embrasure : À MESURER] */
embr_l = 860;         // largeur entre les deux murs — supposée
embr_h = 368;         // 14,5 po
embr_p = 305;         // 12 po, de la fenêtre au bord de l'appui
rebord_prof = 60;     // rebord PVC devant la fenêtre
rebord_hh = 15;
/* [Fenêtre : emplacement de la chatière d'été, À MESURER] */
fen_l = 250;
fen_h = 290;
fen_x0 = 560;         // bord gauche de l'emplacement (vu de la pièce)
fen_z0 = 20;          // bas de l'emplacement au-dessus de l'appui
fen_y = 15;           // de la face intérieure de la fenêtre au milieu de l'emplacement
/* [Mousse] */
mousse_n = 15;        // au repos
mousse_c = 8;         // comprimée
/* [Vitre et façade] */
verre_l = 411;
verre_h = 309;
verre_e = 4;          // à mesurer
trav_b = 30;          // traverse basse
mont_l = 20;          // montant contre la paroi
mont_d = 30;          // montant contre le mur de droite (règle la place de la paroi)
rain_p = 8;           // rainures de la vitre
plateau = 255;

eps2 = 0.01;
jw = 0.4;
e_w = epais;                               // épaisseur des parois = celle du module B
ame0 = peau_e + jw;                        // âme : entre les collerettes d'un module
ame1 = e_w - peau_e - jw;
lg_e = 6;
rain_e = max(verre_e + 3, lg_e + 2 * jw);
yc = e_w / 2;
Lm = 2 * (L2 + colle);                     // longueur d'un module, collerettes comprises

// --- implantation ---
zT = embr_h - mousse_c;                    // haut des pièces
xE = embr_l - mousse_c;                    // bord droit de la façade
xF = xE - (mont_l + verre_l - 2 * rain_p + mont_d);   // bord gauche de la façade
xS = xF - jw - e_w;                        // face côté pièce de la paroi
xs1 = xF + mont_l;
xg0 = xs1 - rain_p;  xg1 = xg0 + verre_l;
zg0 = trav_b - rain_p;  zg1 = zg0 + verre_h;
zt0 = zg1 - rain_p;
Lr = xE - xF;
nr = ceil(Lr / plateau);
xj = [for (i = [1 : nr - 1]) xF + i * Lr / nr];
// paroi : repère local x = le long de la paroi (= Y du mur), y dans l'épaisseur (0 = face côté sas)
yW = embr_p - mousse_c;                    // fond de la paroi (mousse contre la fenêtre)
u0 = embr_p - rebord_prof - Lm - 1;        // avant du module (négatif : dépasse de l'appui)
u1 = u0 + Lm;
uc = u0 + Lm / 2;
zb2 = H + colle_h;                         // joint des deux moitiés de la bande
// fenêtre
y_fen = embr_p + fen_y;
xc2 = fen_x0 + fen_l / 2;

function tient(l, w) = max(l, w) <= plateau || (l + w) <= plateau * sqrt(2);

echo(str("[Mur en L] embrasure ", embr_l, " x ", embr_h, " x ", embr_p, " ; passage libre à gauche : ", round(xS), " mm"));
echo(str("Paroi à x = ", round(xS * 10) / 10, " : module de ", Lm, " (dépasse de ", -u0, " mm de l'appui), chapeau ", Lm, " x ", zT - H,
         " ; bande ", round(yW - u1 + colle), " x ", zT - rebord_hh, " en 2"));
echo(str("Façade ", round(Lr), " mm : montants ", mont_l, " et ", mont_d, ", vitre de x = ", xg0, " à ", xg1,
         " ; traverses en ", nr, " tronçons de ", round(Lr / nr), " (", trav_b, " et ", zT - zt0, " de haut)"));
echo(str("Fenêtre : module dans l'emplacement de ", fen_l, " x ", fen_h, " (corps ", 2 * L2, " de large), chapeau ", fen_l, " x ", fen_h - H));
assert(xS >= 200, "Le passage libre à gauche est trop étroit : embrasure trop petite.");
assert(fen_x0 >= xS + e_w, "La paroi passe devant l'emplacement de la chatière dans la fenêtre.");
assert(2 * L2 <= fen_l, "Le module B est plus large que l'emplacement de la fenêtre.");
assert(H + colle_h + 10 <= fen_h, "Le module B est trop haut pour l'emplacement de la fenêtre.");
assert(zt0 + 20 <= zT, "Vitre trop haute pour l'embrasure.");
assert(tient(zt0 - trav_b + 2 * rain_p, mont_d + 2), "Montant droit trop grand, même en diagonale.");
assert(zT - zb2 <= plateau && zb2 - rebord_hh <= plateau, "Bande arrière trop haute.");

module bx(x0, y0, z0, x1, y1, z1) translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]);
module ame(x0, z0, x1, z1) bx(x0, ame0, z0, x1, ame1, z1);
module lang(x0, z0, x1, z1) bx(x0, yc - lg_e / 2, z0, x1, yc + lg_e / 2, z1);
module lang_j(x0, z0, x1, z1) bx(x0, yc - lg_e / 2 - jw, z0, x1, yc + lg_e / 2 + jw, z1);
module rain(x0, z0, x1, z1) bx(x0, yc - rain_e / 2, z0, x1, yc + rain_e / 2, z1);
module rain_ame(x0, z0, x1, z1) bx(x0, ame0 - jw, z0, x1, ame1 + jw, z1);

// ---------------- paroi (repère local) ----------------
module chapeau_l() difference() {
    union() {
        bx(u0, 0, zb2 + jw, u1, e_w, zT);
        ame(u0 + colle + jw, H + jw, u1 - colle - jw, zb2 + jw + eps2);   // entre les collerettes du haut
    }
    rain_ame(u1 - colle - jw, zb2, u1 + 1, zT + 1);                       // reçoit la bande du haut
}
module bande_l(bas) {
    z0 = bas ? rebord_hh + jw : zb2 + jw;
    z1 = bas ? zb2 : zT;
    difference() {
        union() {
            bx(u1, 0, z0, yW, e_w, z1);
            ame(u1 - colle + jw, z0, u1 + eps2, z1);
            if (bas) lang(u1 + 3, z1 - eps2, yW - 3, z1 + 8 - jw);
        }
        if (!bas) lang_j(u1 + 2, z0 - 1, yW - 2, z0 + 8);
    }
}
module en_paroi() translate([xS + e_w, 0, 0]) rotate([0, 0, 90]) children();

// ---------------- façade (repère du mur) ----------------
module traverse(z0, z1, haut) difference() {
    bx(xF, 0, z0, xE, e_w, z1);
    if (haut) rain(xF + 1, z0 - 1, xE - 1, z0 + rain_p + 1);
    else      rain(xF + 1, z1 - rain_p - 1, xE - 1, z1 + 1);
}
module troncon(z0, z1, haut, i) {
    xa = i == 0 ? xF - 1 : xj[i - 1];
    xb = i == nr - 1 ? embr_l + 1 : xj[i];
    za = haut ? z0 + rain_p + 2 : z0 + 2;
    zb = haut ? z1 - 2 : z1 - rain_p - 2;
    difference() {
        union() {
            intersection() { traverse(z0, z1, haut); bx(xa, -1, z0 - 1, xb, e_w + 1, z1 + 1); }
            if (i < nr - 1) lang(xb - eps2, za, xb + 10 - jw, zb);
        }
        if (i > 0) bx(xa - 1, yc - lg_e / 2 - jw, za - jw, xa + 10, yc + lg_e / 2 + jw, zb + jw);
    }
}
module traverse_bas(i)  troncon(0, trav_b, false, i);
module traverse_haut(i) troncon(zt0, zT, true, i);
// montants : languettes en haut et en bas dans la rainure des traverses, rainure de la vitre vers l'intérieur
module montant(gauche) {
    x0 = gauche ? xF : xg1 - rain_p;
    x1 = gauche ? xs1 : xE;
    difference() {
        union() {
            bx(x0, 0, trav_b + jw, x1, e_w, zt0 - jw);
            if (gauche) lang(x0 + 2, trav_b - rain_p, xg0 - 1, zt0 + rain_p);
            else        lang(xg1 + 1, trav_b - rain_p, x1 - 2, zt0 + rain_p);
        }
        if (gauche) rain(xg0 - 1, trav_b, x1 + 1, zt0);
        else        rain(x0 - 1, trav_b, xg1 + 1, zt0);
    }
}

// ---------------- fenêtre ----------------
// chapeau de fenêtre (repère local : x le long de la fenêtre, z depuis le bas de l'emplacement)
module chapeau_f() union() {
    bx(-fen_l / 2, 0, zb2 + jw, fen_l / 2, e_w, fen_h);
    ame(-L2 + jw, H + jw, L2 - jw, zb2 + jw + eps2);
}
module en_fenetre() translate([xc2, y_fen - e_w / 2, fen_z0]) children();

// ---------------- modules B ----------------
// repère B : X vu du sas, Y = 0 face côté sas
module module_b(a) {
    color("Peru") cadre_monde();
    color("BurlyWood", 0.9) couvercle_monde();
    color("SteelBlue") battant_tourne(a);
    elastique_monde(a);
    for (p = tiges()) color("DimGray") translate([p[0], epais, p[1]]) rotate([-90, 0, 0]) rotate(360 * (peau_e + eps) / pas) molette();
}
// paroi : face côté sas du module vers +X (le sas), face côté pièce vers le passage libre
module module_paroi(a) translate([xS + e_w, uc, 0]) rotate([0, 0, 90]) module_b(a);
// fenêtre : face côté sas du module vers le dehors (+Y)
module module_fenetre(a) translate([xc2, y_fen + e_w / 2, fen_z0]) rotate([0, 0, 180]) module_b(a);

// ---------------- environnement ----------------
module embrasure() {
    color("Gainsboro") bx(-40, -80, -25, embr_l + 40, embr_p + 80, 0);
    color("White") bx(0, embr_p - rebord_prof, 0, embr_l, embr_p, rebord_hh);
    color("Gainsboro", 0.45) { bx(-40, -80, 0, 0, embr_p + 80, embr_h); bx(embr_l, -80, 0, embr_l + 40, embr_p + 80, embr_h); }
    color("WhiteSmoke") difference() {                          // cadre de la fenêtre
        bx(0, embr_p, rebord_hh, embr_l, embr_p + 40, embr_h);
        bx(30, embr_p - 1, fen_z0, fen_x0 - 15, embr_p + 41, fen_z0 + fen_h);
        bx(fen_x0, embr_p - 1, fen_z0, fen_x0 + fen_l, embr_p + 41, fen_z0 + fen_h);
    }
    color("PaleTurquoise", 0.3) bx(30, embr_p + 20, fen_z0, fen_x0 - 15, embr_p + 24, fen_z0 + fen_h);
}
module mousse() color("SlateGray") {
    bx(xE, 0, 0, embr_l, e_w, zT);                              // façade / mur de droite
    bx(xS, yW, rebord_hh, xS + e_w, embr_p, zT);                // paroi / fenêtre
    bx(xS, u0, zT, xS + e_w, embr_p, embr_h);                   // haut de la paroi
    bx(xF, 0, zT, embr_l, e_w, embr_h);                         // haut de la façade
}
module vitre() color("PaleTurquoise", 0.35) bx(xg0, yc - verre_e / 2, zg0, xg1, yc + verre_e / 2, zg1);
module pieces(e = 0) {
    color("LightGray") translate([-e, 0, e]) en_paroi() chapeau_l();
    color("Silver") translate([-e, e, 0]) en_paroi() bande_l(true);
    color("Silver") translate([-e, e, e]) en_paroi() bande_l(false);
    color("Silver") for (i = [0 : nr - 1]) translate([e * i, -e, -e / 2]) traverse_bas(i);
    color("Silver") for (i = [0 : nr - 1]) translate([e * i, -e, e]) traverse_haut(i);
    color("LightGray") translate([0, -e, 0]) montant(true);
    color("LightGray") translate([e, -e, 0]) montant(false);
    color("LightGray") translate([0, 0, e]) en_fenetre() chapeau_f();
}
module scene(e = 0) {
    embrasure();
    if (e == 0) mousse();
    pieces(e);
    translate([0, -e, 0]) vitre();
    module_paroi(angle);
    module_fenetre(angle);
}

// à plat : une grande face sur le plateau
module a_plat() rotate([90, 0, 0]) children();

if (vue == "assemble")             scene();
else if (vue == "eclate")          scene(30);
else if (vue == "chapeau")         a_plat() chapeau_l();
else if (vue == "bande_bas")       a_plat() bande_l(true);
else if (vue == "bande_haut")      a_plat() bande_l(false);
else if (vue == "traverse_bas")    a_plat() traverse_bas(piece);
else if (vue == "traverse_haut")   a_plat() traverse_haut(piece);
else if (vue == "montant_g")       a_plat() montant(true);
else if (vue == "montant_d")       a_plat() montant(false);
else if (vue == "chapeau_fenetre") a_plat() chapeau_f();
