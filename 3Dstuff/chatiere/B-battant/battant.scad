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
//  La face côté pièce du battant est entièrement plane (dessous à
//  l'impression, sans support). Côté sas, dans l'ouverture, la plaque est
//  amincie et porte des nervures concentriques qui suivent sa forme, avec
//  des rayons vers les coins. Les bandes d'appui restent plates.
//
//  Pièces, sans vis :
//   - CADRE (face côté sas sur le plateau) : peau avec collerette et butée,
//     toute l'épaisseur du mur, paliers de l'axe ouverts vers l'arrière,
//     chambre de la came avec 3 poteaux d'élastique, 4 tiges filetées
//     imprimées dans les coins, poches d'aimants dans la peau ;
//   - BATTANT (à plat, face côté pièce dessous, nervures dessus) : tourillon octogonal en bas,
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

part = "assembled"; // [assembled, eclate, cadre, couvercle, axe, battant, came, molette, planche]
// cadre d'une seule pièce (les deux peaux ensemble) : le battant entre de face, ouvert à 90°, puis un AXE descend par le
// haut à travers le cadre et le battant : rond en bas, carré dans le battant, rond dans le palier du haut, came en tête
monobloc = false;
axe_s = 4;            // carré de l'axe dans le battant (un coin chanfreiné : un seul sens possible)
axe_k = 1.2;          // chanfrein du coin
axe_j = 0.2;          // jeu radial de l'axe dans les paliers et dans le battant
axe_bas = 6;          // longueur du bout rond du bas, dans le palier du bas
poteau_d = 5;         // monobloc : poteaux d'élastique (en goutte vers la face côté sas : sans support à l'impression)
poteau_tete = 0.8;    // rebord de la tête des poteaux, qui retient la boucle d'élastique
echelle = 1;          // 1 = réel ; 0.4 = maquette
part_gauche = 0.5;    // part du battant à gauche de l'axe (vu du sas) ; > 0.5 : le vent du dehors le referme

/* [Aperçu] */
// angle d'ouverture du battant dans l'aperçu (0 fermé, 90 grand ouvert ; négatif = bloqué par les butées)
angle = 0; // [-5:5:90]
coupe = false;        // aperçu : sans couvercle
rapide = false;       // rendu rapide pour regarder : filets lisses, arrondis grossiers, moins de facettes (pas pour imprimer)
arrondis = true;      // arrondis des bords (peaux, battant) ; à couper pendant la conception, rapide les coupe aussi

/* [Cotes réelles (multipliées par echelle)] */
ouv_l_r = 210;        // ouverture totale : deux passages d'environ 100 mm
ouv_h_r = 150;        // un peu plus que le minimum (125) pour un chat adulte
r_coin_r = 30;        // rayon des coins de l'ouverture (battant : + recouvrement, cadre : + bordure)
z_bas_r = 30;         // seuil de l'ouverture au-dessus du bas du corps
socle_r = 0;          // rallonge pleine sous le module (module de la fenêtre : 45), cadre et couvercle
/* [Aile vissée sur un 2x4 (panneau gauche)] */
aile_r = 0;           // aile pleine sur un côté, posée à plat sur le 2x4 et vissée à travers (0 : pas d'aile)
aile_gauche = false;  // vu de la face qui touche le 2x4 (face du cadre) : l'aile à gauche (tout le module en miroir)
bordure_s_r = 8;      // largeur des montants du cadre de chaque côté de la cavité (tiges dans les coins)
vis_n = 4;            // vis à bois n° 8 de 2 po, tête fraisée côté couvercle, en quinconce sur deux colonnes
vis_d_r = 4.5;
vis_tete_r = 9;
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
aim_bas = true;       // poches aussi dans la bande du bas (sinon seulement en haut)
/* [Nervures du battant] */
// face côté pièce entièrement plane (dessous à l'impression) ; côté sas, dans l'ouverture, la plaque est amincie et porte
// des nervures concentriques qui suivent la forme du battant ; une bande pleine (toute l'épaisseur) le long de l'axe
nervures = true;      // sinon plaque pleine
nerv_n = 6;           // nombre d'anneaux
nerv_l_r = 1.6;       // largeur des nervures
nerv_plaque_r = 2;    // épaisseur de la plaque entre les nervures, côté pièce
nerv_saillie_r = 3;   // les nervures dépassent la face côté sas de la bande d'appui (dans le trou de la peau)
epais_r = 23.6;       // épaisseur du module (comme porte_rebord.scad)
contreplaque = 12;
densite = 1.24;

E = echelle;
$socle = socle_r * E;   // variable spéciale : mur.scad la change pour le module de la fenêtre
aile = aile_r * E;
$fn = rapide ? 20 : E < 0.7 ? 32 : 48;
eps = 0.01;
reel = E >= 0.7;

ouv_l  = ouv_l_r * E;
ouv_h  = ouv_h_r * E;
r_coin = r_coin_r * E;
z_bas  = z_bas_r * E;
z_haut = z_bas + ouv_h;
recouv = 8 * E;                    // recouvrement des butées
bordure = max(2, 3 * E);           // bord plein (haut)
bordure_s = max(3, bordure_s_r * E);   // côtés : montants du cadre
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
nerv_l = max(1.2, nerv_l_r * E);   // largeur des nervures
nerv_m = max(2, 3 * E);            // retrait par rapport au bord de l'ouverture
nerv_p = (ouv_h / 2 - max(2, 3 * E) - 6 * E) / nerv_n;   // écart : le dernier anneau garde un trou d'environ 12 mm de haut
canal_l = axe_s + 2 * max(1.6, 2.4 * E);   // bande pleine le long de l'axe (le carré de l'axe y passe en monobloc)
nerv_t = max(1.2, nerv_plaque_r * E);
nerv_s = min(max(0, nerv_saillie_r * E), peau_e + feutre_e + jeu / 2 - max(0.3, 0.6 * E));   // reste dans le trou de la peau
nerv_T = batt_e + nerv_s;          // épaisseur totale aux nervures
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
r_po   = monobloc ? poteau_d / 2 : max(0.8, 1.5 * E);   // poteaux d'élastique
x_po   = [for (d = [35, 50, 65]) x_ax + d * E];
// monobloc : la chambre est ouverte côté pièce, les poteaux s'y approchent (l'élastique passe sous les plus proches)
y_po   = monobloc ? epais - r_po - poteau_tete - 0.3 : y_cv - jeu - r_po - max(0.2, 0.3 * E);
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
nerv_f = min(1, nerv_l / nerv_p + canal_l / ouv_l);   // part de la zone pleine (approx.)
m_nerv = nervures ? zone_aire * (nerv_f * nerv_s - (1 - nerv_f) * (batt_e - nerv_t)) / 1000 * densite : 0;
m_batt = (porte_l * (f_t - f_b) - (4 - PI) * r_batt * r_batt) * batt_e / 1000 * densite + m_nerv;
passage_d = ouv_l / 2 - x_ax - g_ax;          // côté droit (vu du sas) : le chat qui sort du sas
passage_g = ouv_l / 2 + x_ax - g_ax;
bras = porte_l / 4;                            // le chat pousse vers le milieu d'un passage
// vent du dehors (pression côté sas) : couple de fermeture / couple d'ouverture (1 : neutre)
vent = pow(porte_l / 2 + x_ax, 2) / pow(porte_l / 2 - x_ax, 2);

echo(str("[echelle ", E, "] corps ", 2 * L2, " x ", H, " x ", epais, " mm ; avec collerettes ",
         2 * (L2 + colle), " x ", H + colle_h));
echo(str("Ouverture ", ouv_l, " x ", ouv_h, " de z = ", z_bas, " à ", z_haut, " ; passages de ", passage_d, " (droite, vu du sas) et ", passage_g,
         " ; battant ", porte_l, " x ", f_t - f_b, " x ", batt_e, (nervures ? str(", plaque de ", nerv_t, " et nervures de ", nerv_T - nerv_t, " (", nerv_s, " de saillie côté sas) : ", nerv_n, " anneaux tous les ", round(nerv_p * 10) / 10, ", bande pleine de ", canal_l, " le long de l'axe") : ""), " (", round(m_batt), " g)"));
echo(str("Came : rayon ", round(came_r(0) * 10) / 10, " fermé, ", round(came_r(45) * 10) / 10, " à 45°, ", round(came_r(90) * 10) / 10,
         " à 90°, ", round(came_r(angle_max) * 10) / 10, " à ", angle_max, "° ; l'élastique s'allonge de ", round(allong(angle_max) * 10) / 10,
         " mm en plus des ", x0_el, " du repos"));
echo(str("Rappel (élastique supposé de ", k_elast, " N/mm) : poussée au milieu d'un passage ",
         [for (t = [0, 45, 90, angle_max]) round(k_elast * (x0_el + allong(t)) * came_r(t) / bras * 1000 / 9.81)], " g à 0 / 45 / 90 / ", angle_max, "°"));
echo(str("Aimants Ø", aim_d, " x ", aim_e, " : poches à ", aim_dist, " mm de l'axe, ", aim_bas ? "en haut et en bas" : "en haut seulement", " de chaque moitié. ",
         "Pour 1 N d'attraction, le chat pousse ", [for (d = aim_dist) round(d / bras * 100) / 100], " N au milieu du passage."));
echo(str("Vent du dehors : couple de fermeture ", round(vent * 100) / 100, " fois le couple d'ouverture"));
if (!monobloc) echo(str("Fixation : 4 tiges filetées imprimées Ø", tige_d, " pas ", pas, ", dépassant de ", l_tige, " mm ; 4 molettes Ø", mol_d, " x ", mol_h));
if ($socle > 0) echo(str("Socle de ", $socle, " mm : cadre et couvercle de ", 2 * (L2 + colle), " x ", $socle + H + colle_h, ", seuil à ", $socle + z_bas, " du bas"));
long_tot = 2 * L2 + (aile > 0 ? aile : 2 * colle);
if (reel && aile == 0) echo(str("Encoche dans le contreplaqué : ", 2 * L2 + 1, " x ", H + 0.5, " mm depuis le bas (rectangle)"));
if (aile > 0) echo(str("Aile de ", aile, " ", aile_gauche ? "à gauche" : "à droite", " (vu de la face du cadre, qui pose sur le 2x4) : module de ", long_tot, " x ", $socle + H + colle_h,
         " ; du bout opposé au bord de l'ouverture : ", L2 + ouv_l / 2, ", au début de l'aile : ", 2 * L2,
         " ; ", vis_n, " vis en quinconce (x depuis le bout opposé, z) ", [for (p = vis_pts) [round(L2 + p[0]), round(p[1])]], ", Ø", vis_d, " fraisées Ø", vis_tete, " côté couvercle"));
if (aile > 0) echo(str("Battant : la moitié du côté de l'aile tourne vers le couvercle, à l'opposé du 2x4 ; elle balaie jusqu'à ",
         L2 + x_ax + porte_l / 2, " du bout opposé"));
// tiges dans les coins : il doit rester de la matière jusqu'au bord du cadre (côté et bas/haut)
tig_marge = min([for (p = tiges()) min(L2 - abs(p[0]), p[1], H - p[1]) - tige_d / 2 - jeu_f]);
echo(str("Montants de ", bordure_s, " : matière entre les tiges et le bord du cadre ", round(tig_marge * 10) / 10, " mm"));
if (monobloc) echo(str("Monobloc : cadre d'une pièce, imprimé à plat face côté sas sur le plateau ; battant glissé de face à 90°, axe de ",
         round((z_c0 + came_h - (f_b - jeu - axe_bas)) * 10) / 10, " (rond Ø", 2 * axe_rb, " en bas, carré ", axe_s, " dans le battant, rond Ø", round(20 * axe_rt) / 10,
         " dans le palier du haut, came en tête), imprimé couché sur son méplat"));
assert(monobloc || tig_marge >= 1.5, "Montants trop étroits : les tiges des coins sortent du cadre.");
assert(aile == 0 || vis_xs[1] - vis_xs[0] >= vis_tete, "Aile trop étroite pour deux colonnes de vis.");
assert(!reel || long_tot <= 258, "Le cadre dépasse le plateau de 260 mm.");
assert(!reel || $socle + H + colle_h <= 255, "Le cadre est trop haut pour le plateau.");
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
module plaque(e, r, bas0 = false, haut0 = false, n = 5) {
    bas = bas0 && arrondis && !rapide;
    haut = haut0 && arrondis && !rapide;
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
module corps2() rect2(-L2, -$socle, L2 + aile, H);
colle_o = aile > 0 ? 0 : colle;      // avec une aile, pas de collerette au bout opposé (il touche la fenêtre)
module collerette2() rect2(-L2 - colle_o, -$socle, aile > 0 ? L2 + aile : L2 + colle, H + colle_h);
// vis de l'aile : un trou traversant, fraisé côté couvercle (y = epais) ; la face du cadre (y = 0) pose sur le 2x4
vis_d = vis_d_r * E;
vis_tete = vis_tete_r * E;
vis_m = max(vis_tete / 2 + 2, 7 * E);              // marge aux bords de l'aile
vis_xs = [L2 + vis_m, L2 + aile - vis_m];          // deux colonnes
vis_pts = [for (i = [0 : vis_n - 1]) [vis_xs[i % 2], -$socle + 20 + i * ($socle + H - 40) / max(1, vis_n - 1)]];
module trous_vis(y0, y1) if (aile > 0) for (p = vis_pts) translate([p[0], 0, p[1]]) {
    translate([0, y0 - 1, 0]) rotate([-90, 0, 0]) cylinder(d = vis_d, h = y1 - y0 + 2, $fn = 24);
    if (y1 >= epais - eps) translate([0, epais - (vis_tete - vis_d) / 2, 0]) rotate([-90, 0, 0])
        cylinder(d1 = vis_d, d2 = vis_tete, h = (vis_tete - vis_d) / 2 + eps, $fn = 32);
}
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
module filet(d, h, j = 0) if (rapide) cylinder(d = d - prof_f + 2 * j, h = h, $fn = 16);
    else linear_extrude(h, twist = -360 * h / pas, slices = max(8, ceil(h / pas * 24)), convexity = 6)
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
// goutte : rond, pointe à 45° vers la face côté sas (le bas à l'impression du cadre à plat)
module goutte2(r) hull() { circle(r = r, $fn = 32); translate([0, -r * sqrt(2)]) square(0.01, center = true); }
module poteaux_monde() for (x = x_po) translate([x, y_po, z_c0 - jeu - eps]) if (monobloc) {
    h = came_h + 2 * jeu + 1.5;
    linear_extrude(h + 2 * eps) goutte2(r_po);
    translate([0, 0, h - 1.2]) linear_extrude(1.2 + 2 * eps) goutte2(r_po + poteau_tete);   // tête
    linear_extrude(1.2) offset(r = 1) goutte2(r_po);                                        // pied élargi
} else cylinder(r = r_po, h = came_h + 2 * jeu + 2 * eps, $fn = 24);

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
function aimants() = [for (s = [1, -1], d = aim_dist, z = aim_bas ? [f_b + recouv / 2, f_t - recouv / 2] : [f_t - recouv / 2]) [x_ax + s * d, z, s]];
module poche_aim(y0, h) translate([0, y0, 0]) rotate([-90, 0, 0]) cylinder(d = aim_d + 0.3, h = h, $fn = 24);
// les poches s'ouvrent du côté OPPOSÉ à l'appui : une paroi mince reste entre l'aimant et la face d'appui,
// sinon l'aimant d'en face l'arracherait de sa poche à la première fermeture. On l'enfonce par l'arrière, et on colle.
aim_paroi = 0.6;
assert(peau_e - aim_paroi >= aim_e, "Peau trop mince pour loger l'aimant derrière sa paroi.");

// tiges : du dos du cadre (y_cv) vers la pièce, bout chanfreiné
module tiges_monde() for (p = tiges()) translate([p[0], y_cv - eps, p[1]]) rotate([-90, 0, 0]) intersection() {
    filet(tige_d, l_tige + eps);
    cylinder(d1 = tige_d + 2 * l_tige, d2 = tige_d - 2 * prof_f, h = l_tige + eps);
}
module peau_sas2() difference() { collerette2(); ouv_sas2(); }
module peau_piece2() difference() { collerette2(); ouv_piece2(); }
// butée en U de la moitié gauche, appuyée sur la face arrière du battant
module butee_u2() difference() {
    intersection() { offset(delta = -jeu / 2) cavite2(); rect2(-cav_x, -1, x_ax - g_ax, H); }
    rrect2(-ouv_l / 2, z_bas, x_ax + r_coin, z_haut, r_coin);
}
module poches_cadre() for (a = aimants()) if (a[2] > 0) translate([a[0], 0, a[1]])
    poche_aim(-eps, peau_e - aim_paroi + eps);                                   // ouverte sur la face côté sas
module poches_couvercle() for (a = aimants()) if (a[2] < 0) translate([a[0], 0, a[1]])
    poche_aim(y_lip + aim_paroi, epais - y_lip - aim_paroi + eps);                // ouverte sur la face côté pièce
module couvercle_corps() {
    couche_arrondie(y_cv, peau_e, r_bord, haut = true) peau_piece2();
    couche(y_lip, y_cv - y_lip + eps) butee_u2();
}

// ---------------- monobloc : axe traversant ----------------
// repère local de l'axe : (0, 0) sur l'axe, battant fermé ; méplat d'impression en y = -axe_s / 2
axe_rb = axe_s / 2;                        // bout rond du bas : passe dans le trou carré du battant
axe_rt = axe_s / sqrt(2) + 0.2;            // rond du palier du haut : le carré y passe
axe_rc = axe_rt + 1.2;                     // collerette sous la came : l'axe pend par elle sur le fond de la chambre
module cle2(k = 0) offset(delta = k) polygon([[-axe_s / 2, -axe_s / 2], [axe_s / 2, -axe_s / 2], [axe_s / 2, axe_s / 2 - axe_k],
                                               [axe_s / 2 - axe_k, axe_s / 2], [-axe_s / 2, axe_s / 2]]);
module meplat2() translate([-50, -axe_s / 2]) square([100, 100]);
module axe_local() intersection() {
    union() {
        translate([0, 0, f_b - jeu - axe_bas]) cylinder(r = axe_rb, h = axe_bas + jeu + eps, $fn = 24);
        translate([0, 0, f_b]) linear_extrude(f_t + jeu - f_b + eps) cle2();
        translate([0, 0, f_t + jeu]) cylinder(r = axe_rt, h = z_c0 - jeu - f_t - jeu + eps, $fn = 32);
        translate([0, 0, z_c0 - jeu]) cylinder(r = axe_rc, h = jeu + eps, $fn = 32);
        translate([0, 0, z_c0]) difference() {                                    // came : joue / gorge / joue
            union() {
                linear_extrude(came_j) came2(came_j);
                translate([0, 0, came_j - eps]) linear_extrude(came_g + 2 * eps) came2();
                translate([0, 0, came_j + came_g]) linear_extrude(came_j) came2(came_j);
                cylinder(r = axe_rc, h = came_j + eps, $fn = 32);
            }
            rotate(70) translate([came_r0 - max(1.2, 2.5 * E), 0, -1]) cylinder(d = trou_el, h = came_h + 2, $fn = 12);
        }
    }
    translate([0, 0, -1]) linear_extrude(H + 10) meplat2();
}
module axe_monde() translate([x_ax, y_ax, 0]) axe_local();
// paliers et chambre de la came dans le cadre monobloc
module paliers_mono() translate([x_ax, y_ax, 0]) {
    translate([0, 0, f_b - jeu - axe_bas - 1]) cylinder(r = axe_rb + axe_j, h = axe_bas + 1 + eps, $fn = 32);
    translate([0, 0, f_t + jeu - eps]) cylinder(r = axe_rt + axe_j, h = z_c0 - jeu - f_t - jeu + 2 * eps, $fn = 32);
}
// grain sous le battant, autour du palier du bas : le battant y repose (il ne frotte pas le fond de la cavité)
module grain_mono() translate([x_ax, y_ax, f_b - jeu - eps]) difference() {
    cylinder(r = axe_s / 2 + 2.4, h = jeu + eps, $fn = 32);
    translate([0, 0, -1]) cylinder(r = axe_rb + axe_j, h = jeu + 2, $fn = 32);
}
// chambre : ouverte en haut (on y descend l'axe) et côté pièce (on y accroche l'élastique, rien à imprimer en pont)
module chambre_mono() translate([0, peau_e, 0]) rotate([90, 0, 0]) mirror([0, 0, 1])
    linear_extrude(epais - peau_e + 1) rect2(x_ax - came_r0 - came_j - 2 * jeu, z_c0 - jeu, x_po[2] + r_po + max(2, 3 * E), H + colle_h + 1);

module cadre_monde() {
    difference() {
        union() {
            couche_arrondie(0, peau_e, r_bord, bas = true) peau_sas2();
            couche(peau_e - eps, y_cv - peau_e + eps) difference() { corps2(); cavite2(); if (!monobloc) chambre2(); }
            if (monobloc) { couvercle_corps(); grain_mono(); }
        }
        if (monobloc) {
            chambre_mono();
            paliers_mono();
            poches_couvercle();
        } else for (p = [pal_h, pal_b]) palier(p[0], p[1], tour_rc + jeu);
        trous_vis(0, monobloc ? epais : y_cv);
        poches_cadre();
    }
    if (!monobloc) tiges_monde();
    poteaux_monde();
}

module couvercle_monde() {
    difference() {
        couvercle_corps();
        for (p = tiges()) translate([p[0], y_cv - 1, p[1]]) rotate([-90, 0, 0]) cylinder(d = tige_d + 2 * jeu_f + 0.4, h = peau_e + 2);
        poches_couvercle();
        trous_vis(y_cv, epais);
    }
    // taquets qui ferment les paliers derrière les tourillons
    r = tour_rc + jeu / 2;
    for (p = [pal_h, pal_b]) translate([x_ax - r, y_ax + tour_rc + jeu, p[0] + jeu / 2])
        cube([2 * r, y_cv - (y_ax + tour_rc + jeu) + eps, p[1] - p[0] - jeu]);
}


// nervures (2D) : anneaux concentriques qui suivent l'ouverture (contour du battant), rayons vers les coins et le long de l'axe
module zone_nerv2() offset(delta = -nerv_m) rrect2(-ouv_l / 2, z_bas, ouv_l / 2, z_haut, r_coin);
// anneau à d du bord de la zone : coins arrondis gardés (rayon au moins la moitié de l'écart)
module rzone2(d) let(m = nerv_m + d, r = max(r_coin - m, nerv_p / 2))
    if (ouv_h / 2 - m > r) rrect2(-ouv_l / 2 + m, z_bas + m, ouv_l / 2 - m, z_haut - m, r);
module anneau2(d) difference() { rzone2(d); rzone2(d + nerv_l); }
module nervures2() intersection() {
    zone_nerv2();
    for (k = [0 : nerv_n - 1]) anneau2(k * nerv_p);
}
// battant : repère du mur, fermé. Bande d'appui plate : la moitié droite s'appuie de sa face avant, la gauche de sa face
// arrière. Face côté pièce entièrement plane (dessous à l'impression) ; seule la face côté sas de la moitié gauche est
// arrondie au bord. Tourillon octogonal en bas, mortaise de la came en haut.
// bande pleine le long de l'axe, sur toute l'épaisseur (le carré de l'axe y passe en monobloc)
module sans_axe2() difference() { children(); rect2(x_ax - canal_l / 2, -1, x_ax + canal_l / 2, H + 1); }
module battant_monde() difference() {
    union() {
        intersection() {
            couche(y_pf, batt_e) battant2();
            translate([x_ax, -1, -1]) cube([porte_l, epais + 2, H + 2]);
        }
        intersection() {
            couche_arrondie(y_pf, batt_e, batt_e * 0.4, bas = true) battant2();
            translate([x_ax - porte_l, -1, -1]) cube([porte_l, epais + 2, H + 2]);
        }
        if (nervures) couche(y_pf - nerv_s, nerv_s + eps) nervures2();                    // saillie côté sas
        if (!monobloc) translate([x_ax, y_ax, f_b - tour_l]) rotate([0, 0, 22.5]) cylinder(r = tour_rc, h = tour_l + eps, $fn = 8);
    }
    if (nervures) couche(y_pf - nerv_s - 1, nerv_s + 1 + batt_e - nerv_t) sans_axe2() difference() {   // plaque amincie côté sas
        offset(delta = -nerv_l) zone_nerv2();
        nervures2();
    }
    if (monobloc) translate([x_ax, y_ax, f_b - 1]) linear_extrude(f_t - f_b + 2) cle2(axe_j);   // trou carré de l'axe
    else translate([x_ax - ten_w / 2 - jt, y_ax - ten_e / 2 - jt, f_t - ten_p - jt]) cube([ten_w + 2 * jt, ten_e + 2 * jt, ten_p + jt + 1]);
    for (a = aimants()) translate([a[0], 0, a[1]])
        if (a[2] > 0) poche_aim(y_pf + aim_paroi, batt_e - aim_paroi + eps);    // appui côté sas : ouverte côté pièce
        else poche_aim(y_pf - eps, batt_e - aim_paroi + eps);                     // appui côté pièce : ouverte côté sas
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
    color("Peru") translate([0, monobloc ? 0 : -2 * e, 0]) cadre_monde();
    if (!coupe && !monobloc) color("BurlyWood", 0.85) translate([0, 3 * e, 0]) couvercle_monde();

    color("SteelBlue") translate([x_ax, y_ax, 0]) rotate([0, 0, angle]) translate([-x_ax, -y_ax, 0]) battant_monde();
    color("Orange") translate([x_ax, y_ax, 2 * e]) rotate([0, 0, angle]) translate([-x_ax, -y_ax, 0]) if (monobloc) axe_monde(); else came_monde();
    if (e == 0) elastique_monde(angle);
    // tiges filetées et molettes
    if (!monobloc) for (p = tiges()) {
        if (!coupe) color("DimGray") translate([p[0], epais + 6 * e, p[1]]) rotate([-90, 0, 0]) rotate(360 * (peau_e + eps) / pas) molette();   // vissée
    }
    if (reel && !coupe && aile == 0) color("Tan", 0.35) difference() {
        translate([-137.5, peau_e, 0]) cube([275, contreplaque, H + 30]);
        translate([-L2 - 0.5, -1, -1]) cube([2 * L2 + 1, 40, H + 1.5]);
    }
}

module cadre_plat()     rotate([90, 0, 0]) cadre_monde();
module axe_plat()       translate([0, 0, axe_s / 2]) rotate([90, 0, 0]) axe_local();   // couché sur son méplat
module couvercle_plat() translate([0, 0, epais]) rotate([-90, 0, 0]) couvercle_monde();
module battant_plat()   rotate([-90, 0, 0]) translate([0, -(y_pf + batt_e), 0]) battant_monde();   // face côté pièce sur le plateau
module came_plat()      rotate([180, 0, 0]) translate([0, 0, -came_h]) came_piece();

module planche() {
    g = 5;
    translate([-(L2 + colle) - g / 2, 0, 0]) cadre_plat();
    translate([(L2 + colle) + g / 2, 0, 0]) couvercle_plat();
    translate([(L2 + colle) + g / 2, f_b - tour_l - g, 0]) battant_plat();   // devant le couvercle, à côté du cadre
    for (i = [0 : 3]) translate([-(L2 + colle) - g / 2 + (i - 1.5) * (mol_d + g), mol_d / 2 + g, 0]) molette();
    translate([-(L2 + colle) - g / 2 + 2.5 * (mol_d + g), mol_d / 2 + g, 0]) came_plat();
}

mirror([aile_gauche ? 1 : 0, 0, 0]) {
if      (part == "assembled") assemblage();
else if (part == "eclate")    assemblage(reel ? 15 : 6);
else if (part == "cadre")     cadre_plat();
else if (part == "couvercle") couvercle_plat();
else if (part == "axe")       axe_plat();
else if (part == "battant")   battant_plat();
else if (part == "came")      came_plat();
else if (part == "molette")   molette();
else if (part == "planche")   planche();
}
