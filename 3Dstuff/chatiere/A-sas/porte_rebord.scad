// =====================================================================
//  Chatière d'hiver — concept A « SAS » : module à porte relevable
//
//  Un MODULE imprimé s'insère dans une encoche du côté gauche du caisson
//  (contreplaqué). Trois groupes de pièces, sans vis :
//
//   - CADRE (pièce principale, imprimée face sur le plateau) : peau côté sas
//     avec collerette, toute l'épaisseur du mur sur les bords, canal de la
//     porte, canaux des coulisseaux, pivots des deux leviers, poteaux
//     d'élastiques et quatre petits pivots à tête conique pour le couvercle.
//   - PIÈCES MOBILES : la porte (sans aucun trou), deux leviers, deux
//     coulisseaux, deux rebords.
//   - COUVERCLE (côté pièce) : sa peau et un remplissage qui ferme la couche
//     arrière. Ses quatre trous en serrure passent sur les têtes des pivots ;
//     il descend de quelques mm et y reste suspendu par son poids.
//
//  L'ouverture est dans le BAS du module, la porte se range dans le HAUT.
//  Mécanisme symétrique, en bascule :
//   - les deux rebords (un de chaque côté du mur), juste sous l'ouverture,
//     sont reliés par deux coulisseaux qui traversent le module ;
//   - chaque coulisseau monte le long de l'ouverture jusqu'à son levier et
//     appuie sur le bras court, à l'extérieur du pivot : quand le rebord
//     descend, le bras long monte (levier inversé) ;
//   - les deux leviers se croisent : celui de droite (vu du sas) est DEVANT
//     la porte, celui de gauche DERRIÈRE ;
//   - chaque levier porte un téton au bout, qui glisse dans une rainure
//     borgne en HAUT de la porte (une sur chaque face, à ±x_teton).
//     La porte n'a aucun trou traversant et s'imprime à plat.
//   - la porte retombe par son poids ; les élastiques ne font qu'aider.
//
//  Couches, du sas vers la pièce :
//    peau | levier avant | porte | levier arrière | couvercle
//
//  Repère (aperçu `assembled`) :
//    X = le long du mur (0 = centre de l'ouverture), vu depuis le sas
//    Z = hauteur, 0 = dessus du plancher du sas (bas du module)
//    Y = épaisseur : y = 0 face extérieure côté sas, y croît vers la pièce
//  Unités : mm. Plateau visé : 260 x 260. `echelle` : 1 = réel, 0,4 = maquette.
// =====================================================================

part = "assembled"; // [assembled, eclate, cadre, couvercle, porte, levier_avant, levier_arriere, coulisseau_avant, coulisseau_arriere, rebord, planche_1, planche_2]
echelle = 1;          // 1 = réel ; 0.4 = maquette (voir porte_rebord_maquette.scad)
ouvert = false;       // aperçu : porte ouverte (rebord enfoncé) ou fermée
coupe = false;        // aperçu : sans couvercle (on voit le levier arrière)
sans_cadre = false;   // aperçu : sans cadre (on voit le levier avant)

/* [Cotes réelles (multipliées par echelle)] */
ouv_l_r = 130;        // ouverture (largeur)
ouv_h_r = 110;        // ouverture (hauteur)
r_coin_r = 12;        // rayon des coins de l'ouverture
course_r = 20;        // descente du rebord sous les pattes
portee_r = 140;       // pivot -> téton du levier
contreplaque = 12;    // épaisseur du côté du caisson (réel)
chat_kg = 4.0;
densite = 1.24;       // PLA

E = echelle;
$fn = E < 0.7 ? 32 : 48;
eps = 0.01;
reel = E >= 0.7;

// ---- cotes dans le plan du mur ----
ouv_l   = ouv_l_r * E;
ouv_h   = ouv_h_r * E;
r_coin  = r_coin_r * E;
course  = course_r * E;
portee  = portee_r * E;
recouv  = 8 * E;                  // porte / ouverture, sur les côtés
recouv_b = 4 * E;                 // porte / ouverture, en bas
bordure = max(2, 3 * E);          // bord plein du cadre (côtés, haut)
bordure_b = max(1.5, 2 * E);      // fond du module
colle   = 5 * E;                  // collerette qui recouvre le contreplaqué
levier_l = max(5, 12 * E);
coul_l  = max(5, 12 * E);
tenon_l = max(3.5, 8 * E);
tenon_l2 = tenon_l + max(1.2, 3 * E);
tenon_h = max(2.5, 5 * E);
tenon_sort = max(4, 10 * E);
rebord_p = max(14, 35 * E);
rebord_e = max(3.5, 8 * E);
// pivots et ergots : minimums relevés après l'essai au 1/5 (trop fragiles)
poteau_d = max(2.5, 5 * E);       // poteaux d'élastiques
pivot_d = max(3, 6 * E);          // pivots des leviers
ergot_d = max(3, 6 * E);          // ergot du coulisseau qui pousse le levier
teton_d = max(3, 5 * E);          // tétons des leviers
axe_ch_d = max(2.4, 3 * E);       // tige des pivots de fixation du couvercle
paroi   = max(1.2, 2.5 * E);      // matière autour des fentes du levier

// ---- épaisseurs (minimums imprimables) ----
peau_e  = max(1.2, 3 * E);
porte_e = max(1.6, 3 * E);
feutre_e = reel ? 1 : 0;
jeu     = max(0.3, 0.6 * E);
levier_e = max(2.5, 5 * E);
bande_e = porte_e + max(feutre_e, 1);          // bande du haut de la porte, où sont les rainures
c_porte = feutre_e + bande_e + jeu;
c_meca  = levier_e + max(0.5, 1 * E);

y_f     = peau_e;                  // couche levier avant
y_d     = y_f + c_meca;            // couche porte
y_b     = y_d + c_porte;           // couche levier arrière
y_cv    = y_b + c_meca;            // peau du couvercle
epais   = y_cv + peau_e;
y_porte = y_d + feutre_e + jeu / 2;            // face avant de la porte (et de sa bande)
y_lev_av = y_f + (c_meca - levier_e) / 2;
y_lev_ar = y_b + (c_meca - levier_e) / 2;

// ---- géométrie du mécanisme ----
porte_l = ouv_l + 2 * recouv;
levee   = ouv_h + recouv_b + max(1, 1 * E);     // la porte monte au-dessus de l'ouverture
rapport = levee / course;
P_x     = porte_l / 2 + jeu + max(1.2, 2 * E) + pivot_d / 2;   // pivot du levier de droite (avant), hors du canal de la porte
theta   = asin((levee / 2) / portee);           // rotation ± theta
a_erg   = course / (2 * tan(theta));            // pivot -> ergot du coulisseau (bras court)
x_coul  = P_x + a_erg;                          // coulisseau à l'extérieur du pivot : bascule
x_teton = P_x - portee;                         // téton avant au plus près du centre (négatif : à gauche)
rainure = portee * (1 - cos(theta + 1));        // course horizontale du téton dans sa rainure
marge_a = 1;                                    // degrés de marge des débattements
w_bout  = teton_d + 2 * paroi;                  // largeur du bout du levier
r_bout  = portee;                               // centre du bout du levier (le téton)
r_fin   = r_bout + w_bout / 2;
lev_w_erg = levier_l + 4 * E;                   // largeur du levier au pivot et au bras court
r_court = a_erg / cos(theta + marge_a) + ergot_d / 2 + jeu + paroi;   // bout du bras court
// hauteur du bout du levier sous le téton, porte fermée (et au-dessus, porte ouverte)
delta   = portee * (sin(theta + marge_a) - sin(theta)) + w_bout / 2 + jeu;
h_teton = teton_d / 2 + jeu + max(0.8, 1.2 * E); // rainure sous le haut de la porte
prof    = bande_e - max(0.8, 1.2 * E);          // profondeur des rainures borgnes
joint   = max(1.5, 3 * E);                      // portée du feutre au-dessus de l'ouverture
recouv_haut = h_teton + delta + joint;
porte_h = recouv_b + ouv_h + recouv_haut;
z_rb_f  = bordure_b + jeu + course;             // bas du rebord (et du coulisseau), relevé
z_rebord_f = z_rb_f + rebord_e;                 // dessus du rebord
z_bas   = z_rebord_f + 2 * E;
z_haut  = z_bas + ouv_h;
z_porte_f = z_bas - recouv_b;                   // bas de la porte fermée
z_teton_f = z_porte_f + porte_h - h_teton;
P_z     = z_teton_f + levee / 2;
haut_porte = z_porte_f + porte_h + levee;       // haut de la porte ouverte
H       = max(haut_porte, z_teton_f + levee + delta) + jeu + bordure;
L2      = max(P_x + r_court + jeu + bordure,
              x_coul + coul_l / 2 + jeu + 2.4 * axe_ch_d + 6 * jeu + bordure);
colle_h = reel ? max(2, min(colle, 258 - H)) : colle;   // collerette du haut, réduite pour le plateau
z_crochet = H - bordure - max(2, 4 * E) - poteau_d / 2;
x_ch    = (x_coul + coul_l / 2 + jeu + L2 - bordure) / 2;

// coulisseau : du rebord (en bas) jusqu'au-dessus de son ergot
z_erg_f = P_z + a_erg * tan(theta);             // ergot, porte fermée (coulisseau en haut)
encoche = (lev_w_erg / 2) / cos(theta + marge_a) + (coul_l / 2 + jeu) * tan(theta + marge_a) + jeu;
coul_z0 = z_rb_f;
coul_h  = z_erg_f + max(encoche, ergot_d / 2) + max(3, 6 * E) - coul_z0;

// fixation du couvercle
tete_d  = 2.4 * axe_ch_d;
tete_h  = 0.7 * axe_ch_d + max(0.4, 0.6 * E);
chute   = (tete_d + axe_ch_d) / 2 + 2 * jeu;    // le couvercle se pose `chute` plus haut puis descend
function pivots() = [for (s = [-1, 1], z = [H - bordure - 1 - axe_ch_d / 2 - jeu,
                                            bordure_b + 1 + chute + tete_d / 2 + jeu]) [s * x_ch, z]];

// forces : la porte retombe par son poids ; les rebords et coulisseaux (côté bras court) s'y opposent
m_porte = porte_l * porte_h * porte_e / 1000 * densite;
m_bas   = 2 * ((2 * x_coul + tenon_l2) * rebord_p * rebord_e + coul_l * coul_h * (y_cv - y_f)) / 1000 * densite * 0.5;
F_frott = reel ? 0.5 : 0.05;                    // frottement du feutre, ramené à la porte (N)
F_elast = max(0, 1.3 * (m_bas * 0.00981 + F_frott * rapport) - m_porte * 0.00981 * rapport);
F_chat  = (m_porte * 0.00981 + F_frott) * rapport - m_bas * 0.00981 + F_elast;

echo(str("[echelle ", E, "] corps ", 2 * L2, " x ", H, " x ", epais, " mm ; avec collerettes ",
         2 * (L2 + colle), " x ", H + colle_h));
echo(str("Ouverture ", ouv_l, " x ", ouv_h, " de z = ", z_bas, " à ", z_haut, " ; porte ", porte_l, " x ", porte_h,
         " (", round(m_porte), " g), monte de ", levee));
echo(str("Leviers : portée ", portee, ", bras court ", a_erg, ", rapport ", round(rapport * 10) / 10,
         ", rotation ±", round(theta * 10) / 10, "°, tétons à x = ±", -x_teton,
         " ; élastiques ~", round(F_elast * 10) / 10, " N au total ; le chat appuie ~", round(F_chat * 10) / 10, " N"));
if (reel) echo(str("Encoche dans le contreplaqué : ", 2 * L2 + 1, " x ", H + 0.5,
                   " mm depuis le bas ; écart entre collerettes ", y_cv - peau_e, " mm (contreplaqué ", contreplaque, ")"));
if (reel && (2 * (L2 + colle) > 258 || H + colle_h > 258))
    echo(str("ATTENTION : le cadre (", 2 * (L2 + colle), " x ", H + colle_h, ") ne tient pas sur un plateau de 260 mm."));

assert(P_x - r_fin > -(x_coul - coul_l / 2 - jeu - 1), "Le bout d'un levier touche le coulisseau d'en face.");
assert(-x_teton + teton_d / 2 + jeu + max(1.2, 3 * E) < porte_l / 2, "Les rainures sortent de la porte.");
assert(coul_z0 + coul_h + max(5, 10 * E) < z_crochet, "Pas de place pour l'élastique au-dessus du coulisseau.");
assert(P_z - r_court * sin(theta + marge_a) - lev_w_erg / 2 > z_haut + joint, "Le bras court passe devant l'ouverture.");
assert(chute < course, "Les tenons sortiraient des fentes à la pose du couvercle.");
assert(!reel || F_chat < chat_kg * 9.81 * 0.6, "Le rebord est trop dur pour le chat.");

// ---------------------------------------------------------------------
// Contours 2D (plan X-Z)
// ---------------------------------------------------------------------
module rect2(x0, z0, x1, z1) translate([x0, z0]) square([x1 - x0, z1 - z0]);
module rrect2(x0, z0, x1, z1, r) translate([x0 + r, z0 + r]) offset(r = r) square([x1 - x0 - 2 * r, z1 - z0 - 2 * r]);
module corps2() rect2(-L2, 0, L2, H);
module interieur2() rect2(-L2 + bordure, bordure_b, L2 - bordure, H - bordure);
module collerette2() hull() {          // bas droit (posé sur le plancher), haut arrondi
    rect2(-L2 - colle, 0, L2 + colle, 1);
    for (s = [-1, 1]) translate([s * (L2 + colle - 3 * E), H + colle_h - 3 * E]) circle(r = 3 * E);
}
module ouverture2() rrect2(-ouv_l / 2, z_bas, ouv_l / 2, z_haut, r_coin);
module canal_porte2() rect2(-porte_l / 2 - jeu, z_porte_f - jeu, porte_l / 2 + jeu, haut_porte + jeu);
module canaux2() for (s = [-1, 1]) hull() {     // fond plat : le pied du coulisseau est carré
    rect2(s * x_coul - coul_l / 2 - jeu, coul_z0 - course - 0.5, s * x_coul + coul_l / 2 + jeu, coul_z0 - course);
    translate([s * x_coul, z_crochet + poteau_d / 2 + jeu + coul_l / 2]) circle(d = coul_l + 2 * jeu);
}
module fentes2() for (s = [-1, 1])
    rect2(s * x_coul - tenon_l2 / 2 - jeu, coul_z0 - course - jeu, s * x_coul + tenon_l2 / 2 + jeu, coul_z0 + tenon_h + jeu);
module serrure2(p) {
    translate([p[0], p[1] - chute]) circle(d = tete_d + 2 * jeu);
    hull() for (dz = [-chute, 0]) translate([p[0], p[1] + dz]) circle(d = axe_ch_d + 2 * jeu);
}

// levier : pivot à l'origine, bras long vers -x (téton), bras court vers +x (ergot)
module levier_contour2() {
    hull() { circle(d = lev_w_erg); translate([r_court - lev_w_erg / 2, 0]) circle(d = lev_w_erg); }
    hull() { circle(d = lev_w_erg); translate([-0.35 * r_bout, 0]) circle(d = levier_l); }
    hull() { translate([-0.35 * r_bout, 0]) circle(d = levier_l); translate([-r_bout, 0]) circle(d = w_bout); }
}
module levier2() difference() {
    levier_contour2();
    circle(d = pivot_d + 2 * jeu);
    // fente de l'ergot du coulisseau (radiale, sur le bras court)
    hull() for (r = [a_erg, a_erg / cos(theta + marge_a)]) translate([r, 0]) circle(d = ergot_d + 2 * jeu);
    for (k = [0.4, 0.58, 0.76]) translate([-r_bout * k, 0])
        hull() { circle(d = levier_l * 0.42); translate([r_bout * 0.08, 0]) circle(d = levier_l * 0.25); }
}
// zone balayée par le levier de droite (le gauche est son miroir) : vrai balayage, par pas de ~2°,
// éventuellement prolongé de `dz` vers le haut ou le bas (pose du couvercle)
n_bal = ceil(2 * (theta + marge_a) / 2);
function a_bal(i) = -(theta + marge_a) + i * 2 * (theta + marge_a) / n_bal;
module balayage2(dz = 0) for (i = [0 : n_bal - 1]) hull() for (a = [a_bal(i), a_bal(i + 1)], d = [0, dz])
    translate([P_x, P_z + d]) rotate(a) offset(r = jeu) levier_contour2();
module balayage_chute2(sens) balayage2(sens * chute);

// ---------------------------------------------------------------------
// Pièces en place (repère du mur)
// ---------------------------------------------------------------------
module en_place(y0) translate([0, y0, 0]) rotate([90, 0, 0]) mirror([0, 0, 1]) children();
module couche(y0, e) en_place(y0) linear_extrude(e) children();
module bride_y(x, z, d, y0, y1) translate([x, y0, z]) rotate([-90, 0, 0]) cylinder(d = d, h = y1 - y0);

module cadre_monde() {
    couche(0, peau_e) difference() { collerette2(); ouverture2(); fentes2(); }
    // couche levier avant : pleine sauf la zone du levier de droite
    couche(y_f - eps, c_meca + 2 * eps) difference() { corps2(); ouverture2(); balayage2(); canaux2(); }
    // couche porte : canal de la porte ; la zone du levier avant est ouverte hors de la porte
    // (pour le poser), le bossage du couvercle la referme
    couche(y_d, c_porte + eps) difference() { corps2(); canal_porte2(); canaux2(); balayage_chute2(1); }
    // couche levier arrière : seulement le bord (toute l'épaisseur du mur)
    couche(y_b, c_meca) difference() { corps2(); interieur2(); }
    // pivots des leviers
    bride_y(P_x, P_z, pivot_d, y_f - eps, y_d - 0.2);
    bride_y(-P_x, P_z, pivot_d, y_b - eps, y_cv - 0.2);
    // poteaux d'élastiques (dans les canaux)
    for (s = [-1, 1]) bride_y(s * x_coul, z_crochet, poteau_d, y_f - eps, y_cv - jeu);
    // pivots de fixation du couvercle : traversent le couvercle, tête apparente
    for (p = pivots()) translate([p[0], y_b - eps, p[1]]) rotate([-90, 0, 0]) {
        cylinder(d = axe_ch_d, h = c_meca + peau_e + jeu + eps);
        translate([0, 0, c_meca + peau_e + jeu]) cylinder(d1 = axe_ch_d, d2 = tete_d, h = 0.7 * axe_ch_d);
        translate([0, 0, c_meca + peau_e + jeu + 0.7 * axe_ch_d - eps]) cylinder(d = tete_d, h = tete_h - 0.7 * axe_ch_d + eps);
    }
}

module couvercle_monde() {
    couche(y_cv, peau_e) difference() {
        collerette2(); ouverture2(); fentes2();
        for (p = pivots()) serrure2(p);
    }
    // remplissage de la couche arrière : appui de la porte, sauf la zone du levier de gauche
    couche(y_b + 0.1, c_meca - 0.1 + eps) difference() {
        offset(delta = -jeu / 2) interieur2();
        ouverture2(); canaux2();
        mirror([1, 0]) balayage_chute2(-1);
        for (p = pivots()) serrure2(p);
    }
    // bossage qui referme la couche porte autour du levier avant, hors de la porte
    couche(y_d + 0.2, c_porte - 0.1 + eps) difference() {
        intersection() {
            offset(delta = -jeu / 2) balayage2();
            rect2(porte_l / 2 + 1.5 * jeu, -1, L2, H + 1);
        }
        offset(delta = jeu / 2) canaux2();
        translate([P_x, P_z]) circle(d = pivot_d + 2 * jeu);
    }
}

// porte : x centré, y = 0 face avant (côté sas), z = 0 bas de la porte.
// Face avant et bande du haut dans le même plan : elle s'imprime à plat, face avant sur le plateau.
// Deux rainures borgnes horizontales dans la bande : avant à x_teton, arrière à -x_teton.
module rainure2(s = 1) hull() for (dx = [0, rainure]) translate([s * (x_teton + dx), porte_h - h_teton]) circle(d = teton_d + 2 * jeu);
module porte() difference() {
    union() {
        couche(0, porte_e) rrect2(-porte_l / 2, 0, porte_l / 2, porte_h, 3 * E);
        couche(0, bande_e) rrect2(-porte_l / 2, porte_h - 2 * h_teton, porte_l / 2, porte_h, min(3 * E, 0.8 * h_teton));
    }
    couche(-1, prof + 1) rainure2();
    couche(bande_e - prof, prof + 1) rainure2(-1);
}

// longueur des tétons des leviers : jusqu'au fond de la rainure, moins le jeu
l_av = (y_porte - (y_lev_av + levier_e)) + prof - jeu;
l_ar = (y_lev_ar - (y_porte + bande_e)) + prof - jeu;

// levier : à plat, téton vers le haut (+z). Les deux leviers ne diffèrent que par la
// longueur du téton (le feutre avant éloigne un peu la porte du levier avant).
module levier(avant = true) {
    linear_extrude(levier_e) levier2();
    translate([-portee, 0, levier_e - eps]) cylinder(d = teton_d, h = (avant ? l_av : l_ar) + eps);
}

module queue_aronde2(m = 0) polygon([[-tenon_l / 2 - m, -tenon_h - m], [tenon_l / 2 + m, -tenon_h - m],
                                    [tenon_l2 / 2 + m, m], [-tenon_l2 / 2 - m, m]]);
// coulisseau : x centré, z = 0 au bas (queue d'aronde dans le rebord), y = repère du mur.
// avant = true : celui de droite, qui pousse le levier avant ; sinon celui de gauche.
module coulisseau(avant = true) {
    r = min(2, coul_l / 4);
    z_e = z_erg_f - coul_z0;
    y_c0 = avant ? y_f : y_b;                           // couche de son levier
    difference() {
        union() {
            translate([0, y_f + jeu, 0]) rotate([-90, 0, 0]) mirror([0, 1, 0])
                linear_extrude(y_cv - y_f - 2 * jeu) rrect2(-coul_l / 2, 0, coul_l / 2, coul_h, r);
            translate([0, -tenon_sort, tenon_h]) rotate([-90, 0, 0]) mirror([0, 1, 0])
                linear_extrude(epais + 2 * tenon_sort) queue_aronde2();
        }
        // encoche : le bras court du levier passe dans sa couche, au-dessus
        translate([-coul_l, avant ? y_f - 1 : y_b - jeu, z_e - encoche])
            cube([2 * coul_l, (avant ? y_d - y_f + 1 : y_cv - y_b + 1) + jeu, coul_h]);
        // trou pour la boucle d'élastique, en haut
        translate([0, epais / 2, coul_h - max(1.5, 3 * E)]) rotate([0, 90, 0])
            cylinder(d = max(1.2, 2.5 * E), h = coul_l + 2, center = true);
    }
    // ergot qui traverse la fente du levier
    if (avant) translate([0, y_d + jeu + eps, z_e]) rotate([90, 0, 0]) cylinder(d = ergot_d, h = y_d + jeu - y_c0 - 0.3 + eps);
    else       translate([0, y_b - jeu - eps, z_e]) rotate([-90, 0, 0]) cylinder(d = ergot_d, h = c_meca + jeu - 0.3 + eps);
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

// ---------------------------------------------------------------------
// Assemblage
// ---------------------------------------------------------------------
module assemblage(ecarte = 0) {
    p   = ouvert ? 1 : 0;
    rot = ouvert ? -theta : theta;     // fermée : bout du bras long en bas
    dz  = -p * course;
    e   = ecarte;
    if (!sans_cadre) color("Peru") translate([0, -2 * e, 0]) cadre_monde();
    if (!coupe) color("BurlyWood", 0.85) translate([0, 3 * e, 0]) couvercle_monde();
    color("SteelBlue") translate([0, y_porte, z_porte_f + p * levee]) porte();
    color("Gold") en_place(y_lev_av - e) translate([P_x, P_z, 0]) rotate([0, 0, rot]) levier(true);
    color("Orange") mirror([1, 0, 0]) en_place(y_lev_ar + levier_e + e) translate([P_x, P_z, 0]) rotate([0, 0, rot])
        mirror([0, 0, 1]) levier(false);
    color("ForestGreen") {
        translate([x_coul, 0, coul_z0 + dz]) coulisseau(true);
        translate([-x_coul, 0, coul_z0 + dz]) coulisseau(false);
    }
    color("Green") {
        translate([0, -2 * e, z_rb_f + dz]) mirror([0, 1, 0]) rebord();
        translate([0, epais + 3 * e, z_rb_f + dz]) rebord();
    }
    color("Red") for (s = [-1, 1]) hull() {
        translate([s * x_coul, epais / 2, coul_z0 + coul_h - max(1.5, 3 * E) + dz]) sphere(d = max(0.8, 2 * E));
        translate([s * x_coul, epais / 2, z_crochet]) sphere(d = max(0.8, 2 * E));
    }
    if (reel && !coupe && !sans_cadre) color("Tan", 0.35) difference() {   // côté en contreplaqué avec l'encoche
        translate([-137.5, peau_e, 0]) cube([275, contreplaque, H + 30]);
        translate([-L2 - 0.5, -1, -1]) cube([2 * L2 + 1, 40, H + 1.5]);
    }
}

// ---------------------------------------------------------------------
// Pièces à plat pour l'impression
// ---------------------------------------------------------------------
module cadre_plat()      rotate([90, 0, 0]) cadre_monde();                               // face sas sur le plateau
module couvercle_plat()  translate([0, 0, epais]) rotate([-90, 0, 0]) couvercle_monde(); // face pièce sur le plateau
module porte_plat()      rotate([90, 0, 0]) porte();                                     // à plat, face avant dessous
module coulisseau_plat(avant) translate([0, 0, max(coul_l, tenon_l2) / 2]) rotate([0, 90, 0]) coulisseau(avant); // couché

// maquette : deux planches de 260 x 260
module planche_1() {
    g = 5;
    translate([-(L2 + colle) - g / 2, 0, 0]) cadre_plat();
    translate([(L2 + colle) + g / 2, 0, 0]) couvercle_plat();
}
module planche_2() {
    g = 6;
    lw = lev_w_erg;
    y_l = g + lw / 2;                              // porte à plat en y < 0, le reste en y > 0
    y_r = y_l + 1.5 * lw + 2 * g;
    y_c = y_r + 2 * rebord_p + 2 * g + tenon_sort;
    porte_plat();
    for (k = [0, 1]) translate([(r_fin - r_court) / 2, y_l + k * (lw + g), 0]) levier(k == 0);
    for (k = [0, 1]) translate([0, y_r + k * (rebord_p + g), 0]) rebord();
    // coulisseaux couchés côte à côte, le long de x
    translate([-coul_h - g / 2, y_c, 0]) coulisseau_plat(true);
    translate([g / 2, y_c, 0]) coulisseau_plat(false);
}

// ---------------------------------------------------------------------
if      (part == "assembled")          assemblage();
else if (part == "eclate")             assemblage(reel ? 15 : 6);
else if (part == "cadre")              cadre_plat();
else if (part == "couvercle")          couvercle_plat();
else if (part == "porte")              porte_plat();
else if (part == "levier_avant")       levier(true);
else if (part == "levier_arriere")     levier(false);
else if (part == "coulisseau_avant")   coulisseau_plat(true);
else if (part == "coulisseau_arriere") coulisseau_plat(false);
else if (part == "rebord")             rebord();
else if (part == "planche_1")          planche_1();
else if (part == "planche_2")          planche_2();
