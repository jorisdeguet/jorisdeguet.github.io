// =====================================================================
//  Chatière d'hiver — concept C « MUR EN L » : le sas dans l'embrasure
//
//  Vu de la pièce, la partie GAUCHE de l'embrasure reste libre : le chat
//  monte sur l'appui à gauche, face à la fenêtre. En tournant à droite, il
//  fait face à une PAROI perpendiculaire à la fenêtre, qui porte le module
//  B intérieur (../B-battant/battant.scad). Derrière, le sas occupe la
//  partie droite de l'embrasure. Tout l'ensemble est poussé contre la
//  fenêtre : l'avant de l'appui reste libre devant le verre.
//   - PAROI, d'une seule largeur (253) : le module B contre la fenêtre,
//     posé sur la marche (cale sous son avant), et au-dessus un BLOC DE
//     MOUSSE RIGIDE (XPS 1 po) coupé à la hauteur mesurée une fois le module
//     imprimé et posé, avec 3 mm de trop : il entre en force, étanche, et
//     tient le module. Le décrochage du plafond se fait au cutter ;
//   - FAÇADE, de la paroi au mur de droite, au ras de l'avant de la paroi :
//     la VITRE 413 x 308 x 2,5 non coupée, dans un CADRE EN BOIS sur trois
//     côtés (bas, droite, haut ; le bord gauche bute contre la paroi). Chaque
//     latte a une rainure pour le verre (avec un joint mousse adhésif ou un
//     cordon de silicone) et, sur son chant extérieur, une rainure pour une
//     bande de mousse rigide coupée sur place. Le montant se colle et se
//     visse entre les deux traverses ;
//   - FENÊTRE : le module B extérieur, allongé vers le bas par un SOCLE,
//     pose au fond de la gouttière de la fenêtre coulissante, à la place
//     de la chatière d'été (../../chatiere_ete) ; un CHAPEAU de fenêtre
//     imprimé au-dessus s'engage dans la fente du haut.
//  Seuls les deux modules B et le chapeau de fenêtre sont imprimés.
//
//  Repère : X le long de l'embrasure VU DE LA PIÈCE (0 = mur de gauche),
//  Y vers la fenêtre (0 = bord de l'appui), Z hauteur (0 = dessus de
//  l'appui).
// =====================================================================

include <../B-battant/battant.scad>

part = "none";        // le module B ne dessine rien de lui-même
vue = "assemble";     // [assemble, eclate, chapeau_fenetre]

/* [Embrasure (mesurée le 26 nov. 2026)] */
embr_l = 884;         // largeur entre les deux murs
embr_h = 372;         // hauteur de l'appui au haut de l'embrasure (devant)
embr_p = 315;         // de l'avant de la fenêtre (son cadre) au nu du mur
rebord_prof = 154;    // décrochage le long de la paroi : 154 depuis la fenêtre
rebord_hh = 15;       // hauteur de la marche du bas : À MESURER (la paroi pose dessus, cale devant)
haut_fen = 350;       // hauteur libre contre la fenêtre, au-dessus de la marche
/* [Fenêtre coulissante (mesurée le 26 nov. 2026)] */
fen_h = 276;          // ouverture visible, en hauteur
fen_fb = 17;          // la gouttière du bas descend sous l'ouverture (293 - 276)
fen_fb_p = 40;        // largeur de la gouttière du bas
fen_ft = 10;          // la fente du haut monte au-dessus de l'ouverture
fen_ft_p = 15;        // largeur de la fente du haut (environ)
fen_l = 254;          // largeur de l'ouverture : la fenêtre coulisse, on la ferme sur le module
fen_zf = 5;           // fond de la gouttière au-dessus de l'appui : À MESURER
fen_x0 = 600;         // bord gauche de l'ouverture (vu de la pièce) : au choix, ça coulisse
fen_y = 20;           // de l'avant de la fenêtre au milieu de la gouttière : À MESURER
socle_f = 45;         // rallonge sous le module de la fenêtre
lg_f = 4;             // le chapeau s'engage de 4 mm dans la fente du haut
lg_f_e = 11;          // épaisseur de sa languette (fente de 15)
jeu_haut = 5.5;       // sous le haut de l'ouverture : de quoi soulever le chapeau à la pose
/* [Mousse] */
mousse_c = 8;         // mousse souple comprimée, entre la paroi et la fenêtre
bloc_comp = 3;        // le bloc au-dessus de la paroi est coupé 3 mm trop haut
/* [Vitre et cadre en bois] */
verre_l = 413;
verre_h = 308;
verre_e = 2.5;
cad_l = 30;           // largeur des lattes, vue de face
cad_e = 19;           // épaisseur des lattes (3/4 po)
rain_l = 4;           // rainure du verre : 2,5 + joint
rain_p = 10;          // sa profondeur
v_eng = 8;            // le verre entre de 8 (2 de jeu au fond : le bois travaille)
rig_e = 12.7;         // mousse rigide ½ po
rig_l = 13;           // rainure de la mousse
rig_p = 8;            // sa profondeur
g_b = 5;              // mousse rigide visible sous la traverse basse
g_d = 15;             // mousse rigide visible entre le montant et le mur de droite

eps2 = 0.01;
jw = 0.4;
e_w = epais;                               // épaisseur de la paroi = celle du module B
Lm = 2 * (L2 + colle);                     // longueur d'un module, collerettes comprises
yc = cad_e / 2;

// --- paroi : la paroi pose à z = rebord_hh, une cale sous son avant ---
zP = rebord_hh;
yW = embr_p - mousse_c;                    // fond de la paroi (mousse contre la fenêtre)
u1 = yW;  u0 = u1 - Lm;  uc = u0 + Lm / 2;  // module contre la fenêtre
zb2 = H + colle_h;                         // dessus des collerettes du module
y_dec = embr_p - rebord_prof;              // décrochage
h_bloc_f = haut_fen - zb2;                 // bloc au-dessus du module, côté fenêtre
h_bloc_a = embr_h - (zP + zb2);            // côté pièce (devant le décrochage)

// --- façade, au ras de l'avant de la paroi (de droite à gauche) ---
yF = u0;                                   // face avant de la façade
xE = embr_l - g_d;                         // bord droit du cadre
xg1 = xE - cad_l + v_eng;                  // bord droit du verre
xg0 = xg1 - verre_l;                       // bord gauche du verre, contre la paroi (ruban mousse de 1)
xP = xg0 - 1;                              // face côté sas de la paroi
xS = xP - e_w;                             // face côté pièce de la paroi
xT = xP + jw;                              // bout gauche des traverses
zb0 = g_b;  zb1 = zb0 + cad_l;             // traverse basse
zg0 = zb1 - v_eng;  zg1 = zg0 + verre_h;   // verre
zh0 = zg1 - v_eng;  zh1 = zh0 + cad_l;     // traverse haute
g_h = embr_h - zh1;                        // mousse rigide visible au-dessus
// fenêtre (repère local du chapeau : z depuis le fond de la gouttière)
y_fen = embr_p + fen_y;
xc2 = fen_x0 + fen_l / 2;
zo1 = fen_fb + fen_h;                      // haut de l'ouverture
zcf0 = socle_f + zb2 + jw;                 // bas du chapeau
zcf1 = zo1 - jeu_haut;                     // haut du chapeau (sa languette monte dans la fente)

function r1(v) = round(v * 10) / 10;

echo(str("[Mur en L] embrasure ", embr_l, " x ", embr_h, " x ", embr_p, " ; passage libre à gauche : ", r1(xS), " mm ; avant de l'appui libre sur ", r1(yF), " mm ; sas de ", r1(xE + g_d - xP), " x ", r1(embr_p - yF - cad_e)));
echo(str("Paroi de x = ", r1(xS), " à ", r1(xP), ", de y = ", r1(u0), " à ", r1(u1), " (", r1(Lm), ") : module ", r1(zb2), ", posé sur la marche de ", zP,
         " (cale de ", zP, " sous ", r1(y_dec - u0), " mm à l'avant), seuil à ", zP + z_bas, " de l'appui"));
echo(str("Bloc de mousse (prévu, à recouper sur place, +", bloc_comp, ") : ", r1(Lm), " x ", r1(e_w), ", haut de ", r1(h_bloc_a + bloc_comp), " sur ", r1(y_dec - u0),
         " côté pièce et ", r1(h_bloc_f + bloc_comp), " sur ", r1(u1 - y_dec), " côté fenêtre"));
echo(str("Façade : verre de x = ", r1(xg0), " à ", r1(xg1), ", z = ", r1(zg0), " à ", r1(zg1), ", entré de ", v_eng, " dans les rainures"));
echo(str("Débit du bois ", cad_l, " x ", cad_e, " : 2 traverses de ", r1(xE - xT), ", 1 montant de ", r1(zh0 - zb1),
         " ; rainure du verre ", rain_l, " x ", rain_p, " au milieu, rainure de mousse ", rig_l, " x ", rig_p, " sur le chant extérieur"));
echo(str("Mousse rigide ", rig_e, " : bandes de ", g_b + rig_p, " (bas), ", g_d + rig_p, " (droite), ", r1(g_h + rig_p), " (haut) de large"));
echo(str("Fenêtre : module de ", r1(Lm), " x ", r1(socle_f + zb2), " (socle ", socle_f, "), seuil à ", socle_f + z_bas, " du fond de la gouttière, ",
         socle_f + z_bas - fen_fb, " au-dessus du bas de l'ouverture ; chapeau ", r1(Lm), " x ", r1(zcf1 - zcf0), " + languette de ", r1(jeu_haut + lg_f)));
assert(xS >= 300, "Le passage libre à gauche est trop étroit.");
assert(fen_x0 >= xP + 5, "La paroi passe devant l'ouverture de la fenêtre.");
assert(fen_x0 + fen_l <= embr_l, "L'ouverture de la fenêtre dépasse l'embrasure.");
assert(Lm <= fen_l, "Le module B est plus large que l'ouverture de la fenêtre.");
assert(u0 >= 0, "La paroi dépasse de l'appui.");
assert(e_w <= fen_fb_p, "Le module ne rentre pas dans la gouttière.");
assert(zcf1 - zcf0 >= 15, "Pas de place pour le chapeau de fenêtre : baisser socle_f.");
assert(jeu_haut >= colle_h - jw + 0.3, "On ne peut pas soulever le chapeau au-dessus des collerettes à la pose.");
assert(jeu_haut + lg_f <= fen_ft - 0.4, "La languette du chapeau sort de la fente du haut quand on le soulève.");
assert(lg_f_e <= fen_ft_p - 2, "Languette trop épaisse pour la fente du haut.");
assert(socle_f + H + colle_h <= 255, "Module de la fenêtre trop haut pour le plateau.");
assert(g_h >= 5, "Vitre trop haute pour l'embrasure : lattes plus étroites (cad_l).");
assert(v_eng < rain_p, "Le verre touche le fond de la rainure.");
assert(rain_p + rig_p <= cad_l - 6, "Les deux rainures se rejoignent presque : lattes plus larges.");
assert((cad_e - rig_l) / 2 >= 3, "Joues de la rainure de mousse trop minces.");
assert(h_bloc_f > 10, "Pas de place pour le bloc de mousse au-dessus de la paroi.");

module bx(x0, y0, z0, x1, y1, z1) translate([x0, y0, z0]) cube([x1 - x0, y1 - y0, z1 - z0]);

// ---------------- façade : cadre en bois ----------------
// repère de la façade : celui du mur, mais y = 0 à sa face avant (on la place ensuite en y = yF)
// sens = +1 : le verre est au-dessus (traverse basse) ; -1 : au-dessous (traverse haute)
module traverse(z0, z1, sens) difference() {
    bx(xT, 0, z0, xE, cad_e, z1);
    zv = sens > 0 ? z1 - rain_p : z0 - 1;
    bx(xT - 1, yc - rain_l / 2, zv, xE + 1, yc + rain_l / 2, zv + rain_p + 1);   // rainure du verre
    zm = sens > 0 ? z0 - 1 : z1 - rig_p;
    bx(xT - 1, yc - rig_l / 2, zm, xE + 1, yc + rig_l / 2, zm + rig_p + 1);      // rainure de la mousse
}
module montant_d() difference() {
    bx(xE - cad_l, 0, zb1, xE, cad_e, zh0);
    bx(xE - cad_l - 1, yc - rain_l / 2, zb1 - 1, xE - cad_l + rain_p, yc + rain_l / 2, zh0 + 1);
    bx(xE - rig_p, yc - rig_l / 2, zb1 - 1, xE + 1, yc + rig_l / 2, zh0 + 1);
}
module facade() translate([0, yF, 0]) children();

// ---------------- fenêtre ----------------
// chapeau de fenêtre (repère local : x le long de la fenêtre, centré ; y = 0 face côté sas du module ; z depuis le fond
// de la gouttière). Son âme descend entre les collerettes du module ; sa languette monte dans la fente du haut.
ame0 = peau_e + jw;
ame1 = e_w - peau_e - jw;
module chapeau_f() union() {
    bx(-Lm / 2, 0, zcf0, Lm / 2, e_w, zcf1);
    bx(-L2 + jw, ame0, socle_f + H + jw, L2 - jw, ame1, zcf0 + eps2);
    bx(-Lm / 2 + 2, e_w / 2 - lg_f_e / 2, zcf1 - eps2, Lm / 2 - 2, e_w / 2 + lg_f_e / 2, zcf1 + jeu_haut + lg_f);
}
// module de la fenêtre : face côté sas vers le dehors (+Y), fond du socle au fond de la gouttière
module en_fenetre() translate([xc2, y_fen + e_w / 2, fen_zf]) rotate([0, 0, 180]) children();

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
module module_paroi(a) translate([xS + e_w, uc, zP]) rotate([0, 0, 90]) module_b(a);
module module_fenetre(a) en_fenetre() translate([0, 0, socle_f]) { $socle = socle_f; module_b(a); }

// ---------------- environnement ----------------
module embrasure() {
    zf = fen_zf;
    color("Gainsboro") bx(-40, -80, -25, embr_l + 40, embr_p + 80, 0);
    color("White") bx(0, y_dec, 0, embr_l, embr_p, rebord_hh);
    color("Gainsboro", 0.45) { bx(-40, -80, 0, 0, embr_p + 80, embr_h); bx(embr_l, -80, 0, embr_l + 40, embr_p + 80, embr_h); }
    color("Gainsboro", 0.3) bx(-40, -80, embr_h, embr_l + 40, embr_p, embr_h + 25);
    color("Gainsboro", 0.3) bx(xS - 30, y_dec, zP + haut_fen, xP + 30, embr_p, embr_h);   // linteau près de la paroi (supposé)
    color("WhiteSmoke") difference() {                          // cadre et vantaux de la fenêtre (simplifiés)
        bx(0, embr_p, rebord_hh, embr_l, embr_p + 2 * fen_y + 10, embr_h);
        bx(fen_x0, embr_p - 1, zf + fen_fb, fen_x0 + fen_l, embr_p + 2 * fen_y + 11, zf + zo1);
        bx(fen_x0 - 30, y_fen - fen_fb_p / 2, zf, fen_x0 + fen_l + 30, y_fen + fen_fb_p / 2, zf + fen_fb + 1);   // gouttière
        bx(fen_x0 - 30, y_fen - fen_ft_p / 2, zf + zo1 - 1, fen_x0 + fen_l + 30, y_fen + fen_ft_p / 2, zf + zo1 + fen_ft);   // fente du haut
    }
}
// mousses : souple contre la fenêtre et sous l'avant de la paroi, bloc rigide au-dessus, bandes rigides du cadre
module mousse(e = 0) {
    zt = zP + zb2;
    color("SlateGray") {
        bx(xS, yW, zP, xP, embr_p, zP + haut_fen);              // paroi / fenêtre
        bx(xS, u0, 0, xP, y_dec, zP);                           // cale sous l'avant de la paroi
    }
    color("LightPink") translate([-e, 0, e]) {                  // bloc XPS au-dessus de la paroi, en décroché
        bx(xS, u0, zt, xP, y_dec, embr_h);
        bx(xS, y_dec, zt, xP, u1, zP + haut_fen);
    }
    color("Khaki") translate([0, -e, 0]) facade() {             // bandes rigides dans les rainures du cadre
        h = rig_e / 2;
        bx(xT, yc - h, 0, xE, yc + h, zb0 + rig_p);
        bx(xE - rig_p, yc - h, zb1, embr_l, yc + h, zh0);
        bx(xT, yc - h, zh1 - rig_p, xE, yc + h, embr_h);
    }
}
module vitre() color("PaleTurquoise", 0.35) facade() bx(xg0, yc - verre_e / 2, zg0, xg1, yc + verre_e / 2, zg1);
module bois(e = 0) color("Tan") facade() {
    translate([0, -e, -e / 2]) traverse(zb0, zb1, 1);
    translate([0, -e, e]) traverse(zh0, zh1, -1);
    translate([e, -e, 0]) montant_d();
}
module scene(e = 0) {
    embrasure();
    mousse(e);
    bois(e);
    translate([0, -e, 0]) vitre();
    color("LightGray") translate([0, 0, e]) en_fenetre() chapeau_f();
    module_paroi(angle);
    module_fenetre(angle);
}

if (vue == "assemble")             scene();
else if (vue == "eclate")          scene(30);
else if (vue == "chapeau_fenetre") rotate([90, 0, 0]) chapeau_f();   // à plat
