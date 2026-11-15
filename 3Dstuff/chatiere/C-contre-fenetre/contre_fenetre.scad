// =====================================================================
//  Chatière d'hiver — Concept C : « contre-fenêtre » qui ferme la niche
//  Mur intérieur isolé (cadre bois + verre 411×309 + XPS + chatière)
//  posé en compression dans la niche de la fenêtre de sous-sol.
//
//  Pièces imprimées (toutes ≤ 260 mm) :
//    clip_u           segment de profilé en U pour verre (rainure ruban mousse)
//    clip_u_vert      demi-profilé vertical (2 par côté en mode continu)
//    clip_corner      clip d'angle en L (mode « clips »)
//    flap_frame_main  cadre-tunnel de chatière (bride + tunnel, poches aimants)
//    flap_frame_ring  anneau de serrage côté opposé
//    flap             battant à charnière (poches aimants dans le bourrelet)
//  Aperçu :
//    assembled        niche + fenêtre existante + contre-fenêtre complète
//
//  Repère « assembled » : X = largeur (vu de la pièce, gauche→droite),
//  Y = profondeur (0 = face avant de la niche, + vers la fenêtre),
//  Z = hauteur (0 = dessus de l'appui).
// =====================================================================

/* [Pièce] */
part = "assembled"; // [assembled, clip_u, clip_u_vert, clip_corner, flap_frame_main, flap_frame_ring, flap]

/* [Niche — À MESURER] */
recess_w   = 850;   // largeur intérieure de la niche (INCONNUE : mesurer !)
recess_h   = 368;   // hauteur de la niche (14.5 po)
recess_d   = 305;   // profondeur fenêtre → bord avant de l'appui (12 po)
wall_pos   = 0;     // recul du mur depuis la face avant de la niche (0 = affleurant)

/* [Bois] */
wood_t     = 19;    // épaisseur vue de face (1×3 : 3/4 po = 19 mm)
wood_d     = 64;    // profondeur du cadre (1×3 : 2-1/2 po = 64 mm)
seal_gap   = 3;     // jeu périphérique comblé par le coupe-froid compressé

/* [Verre] */
glass_w    = 411;
glass_h    = 309;
glass_t    = 4;     // épaisseur réelle d'un carreau (mesurer au pied à coulisse)
glazing    = "double"; // [double, simple]  double = les 2 carreaux en sandwich
igu_gap    = 12;    // lame d'air entre les 2 carreaux (mode double)
edge_gap   = 2;     // jeu entre la tranche du verre et le fond du profilé
engage     = 8;     // prise du verre dans le profilé
glazing_mode = "continu"; // [continu, clips]

/* [Profilé U / clips] */
chan_wall  = 2.4;   // épaisseur des ailes
foam_t     = 3;     // ruban mousse (épaisseur nominale)
foam_w     = 6;     // largeur du ruban mousse
foam_comp  = 0.4;   // compression visée (40 %)
groove_d   = 1;     // profondeur de la rainure qui loge le ruban
tab_w      = 12;    // patte de vissage (côté pièce)
tab_t      = 3;
screw_d    = 3.6;   // vis #6
screw_head = 7.2;
clip_len   = 60;    // longueur d'un clip_u (mode clips) ; ≤ 250 en mode continu
corner_arm = 50;

/* [Chatière] */
flap_w     = 160;   // ouverture libre (largeur)
flap_h     = 170;   // ouverture libre (hauteur)
flap_side  = "right"; // [right, left]  côté du trou hexagonal existant
panel_t    = 38;    // épaisseur du panneau XPS (1-1/2 po)
tunnel_wall= 5;
flange     = 22;    // largeur de la bride
flange_t   = 4;
ring_t     = 4;
bolt_d     = 4.5;   // boulons M4 traversants
mag_d      = 6.3;   // aimant néodyme 6×3 mm (+jeu)
mag_h      = 3.3;
pin_d      = 3.3;   // tige de charnière Ø3 mm (acier/laiton, ou clou 1/8 po)
hinge_r    = 5;
side_gap   = 2;     // jeu latéral du battant
bottom_gap = 2;
flap_t     = 3;
bead_h     = 12;    // bourrelet bas du battant (loge les aimants)
bead_t     = 9;
pile_w     = 5;     // rainure pour coupe-froid à poils (« pile »)
pile_d     = 2;

$fn = 48;
eps = 0.01;

// ---------------------------------------------------------------------
// Grandeurs dérivées
// ---------------------------------------------------------------------
glass_pack = glazing == "double" ? 2*glass_t + igu_gap : glass_t;
frame_W    = recess_w - 2*seal_gap;
frame_H    = recess_h - 2*seal_gap;
inner_H    = frame_H - 2*wood_t;
clr        = (inner_H - glass_h)/2;       // cadre → tranche du verre
chan_base  = clr - edge_gap;              // fond plein du profilé
chan_h     = clr + engage;                // hauteur totale du profilé
foam_eff   = foam_t*(1-foam_comp) - groove_d;
chan_in    = glass_pack + 2*foam_eff;     // entre les ailes (hors rainures)
chan_out   = chan_in + 2*chan_wall;
zone_g     = glass_w + 2*clr;             // largeur d'une travée vitrée

flap_out_w = flap_w + 2*tunnel_wall;
flap_out_h = flap_h + 2*tunnel_wall;
flange_W   = flap_out_w + 2*flange;
flange_H   = flap_out_h + 2*flange;
tunnel_len = flange_t + panel_t + ring_t;
z_mid      = flange_t + panel_t/2;        // plan du battant (local)
hinge_y    = flap_h/2 - hinge_r - 1;
flap_len   = hinge_y + flap_h/2 - bottom_gap;
mag_y      = -flap_h/2 + bottom_gap + bead_h/2;

inner_W    = frame_W - 2*wood_t;
flap_zone_min = flange_W + 10;
n_max      = glazing == "double" ? 1 : 2;
function fits(k) = k*(zone_g + wood_t) + flap_zone_min <= inner_W;
n_panes    = fits(n_max) ? n_max : (fits(1) ? 1 : 0);
flap_zone  = inner_W - n_panes*(zone_g + wood_t);

assert(chan_base >= 2, str("Hauteur insuffisante : fond du profilé = ", chan_base, " mm (<2). Amincir le bois ou couper le verre."));
assert(flange_W <= 260 && flange_H <= 260, "Cadre de chatière > 260 mm : réduire flap_w/flap_h/flange");

echo(str("=== CONTRE-FENÊTRE — niche ", recess_w, " × ", recess_h, " mm ==="));
echo(str("Cadre hors-tout : ", frame_W, " × ", frame_H, " × ", wood_d, " mm"));
echo(str("Traverses (haut/bas) : 2 × ", frame_W, " mm ; montants : ", 2 + n_panes, " × ", inner_H, " mm"));
echo(str("Travées vitrées : ", n_panes, " (", glazing, ") — largeur travée ", zone_g, " mm"));
echo(str("Zone XPS + chatière : ", flap_zone, " × ", inner_H, " mm (min ", flap_zone_min, ")"));
echo(str("Profilé : fond ", chan_base, " mm, hauteur ", chan_h, " mm, intérieur ", chan_in, " mm"));
echo(str("Profilés continus : horizontaux 4 × ", zone_g/2, " mm, verticaux 2 × ", inner_H - 2*chan_h, " mm (par travée)"));
echo(str("Largeur mini niche : 1 travée = ", 2*seal_gap + 3*wood_t + zone_g + flap_zone_min,
         " mm ; 2 travées = ", 2*seal_gap + 4*wood_t + 2*zone_g + flap_zone_min, " mm"));
if (n_panes == 0) echo("ATTENTION : niche trop étroite pour un carreau entier + chatière → couper le verre ou utiliser du polycarbonate.");

// ---------------------------------------------------------------------
// Profilé en U (local : X = longueur, Y = épaisseur, Z = depuis le cadre)
// ---------------------------------------------------------------------
module u_profile_2d() {           // dans le plan (Y,Z)
    difference() {
        translate([-chan_out/2, 0]) square([chan_out, chan_h]);
        translate([-chan_in/2, chan_base]) square([chan_in, chan_h]);
        // rainures pour ruban mousse sur les faces internes des ailes
        for (s = [-1, 1])
            translate([s > 0 ? chan_in/2 - eps : -chan_in/2 - groove_d + eps,
                       chan_h - 1 - foam_w])
                square([groove_d, foam_w]);
    }
    // patte de vissage côté pièce (-Y)
    translate([-chan_out/2 - tab_w, 0]) square([tab_w + eps, tab_t]);
}

module tab_holes(L) {
    for (x = L > 80 ? [L*0.15, L*0.5, L*0.85] : [L/2])
        translate([x, -chan_out/2 - tab_w/2, 0]) {
            translate([0,0,-1]) cylinder(d = screw_d, h = tab_t + 2);
            translate([0,0,tab_t - (screw_head-screw_d)/2])
                cylinder(d1 = screw_d, d2 = screw_head, h = (screw_head-screw_d)/2 + eps);
        }
}

module clip_u(L = clip_len) {
    difference() {
        rotate([90,0,90]) linear_extrude(L) u_profile_2d();
        tab_holes(L);
    }
}

module clip_corner() {
    difference() {
        union() {
            rotate([90,0,90]) linear_extrude(corner_arm) u_profile_2d();          // bras sur la traverse
            translate([0,0,corner_arm]) rotate([0,90,0])
                rotate([90,0,90]) linear_extrude(corner_arm) u_profile_2d();      // bras sur le montant
        }
        tab_holes(corner_arm);
        translate([0,0,corner_arm]) rotate([0,90,0]) tab_holes(corner_arm);
    }
}

// ---------------------------------------------------------------------
// Chatière (local : X = largeur, Y = hauteur, Z = profondeur ; bride en z=0)
// ---------------------------------------------------------------------
module bolt_holes() {
    for (sx = [-1,1], sy = [-1,1])
        translate([sx*(flange_W/2 - flange/2), sy*(flange_H/2 - flange/2), -1])
            cylinder(d = bolt_d, h = tunnel_len + 2);
}

module flap_frame_main() {
    difference() {
        union() {
            translate([-flange_W/2, -flange_H/2, 0]) cube([flange_W, flange_H, flange_t]);
            translate([-flap_out_w/2, -flap_out_h/2, 0]) cube([flap_out_w, flap_out_h, tunnel_len]);
        }
        translate([-flap_w/2, -flap_h/2, -1]) cube([flap_w, flap_h, tunnel_len + 2]);
        bolt_holes();
        // axe de charnière
        translate([0, hinge_y, z_mid]) rotate([0,90,0]) cylinder(d = pin_d, h = flap_out_w + 2, center = true);
        // poches d'aimants dans les flancs, à hauteur du bourrelet
        for (s = [-1,1]) translate([s*(flap_w/2 + mag_h/2 - eps), mag_y, z_mid])
            rotate([0,90,0]) cylinder(d = mag_d, h = mag_h, center = true);
        // rainures « pile » : flancs (au-dessus des aimants) et seuil
        for (s = [-1,1]) translate([s > 0 ? flap_w/2 - eps : -flap_w/2 - pile_d + eps,
                                    mag_y + bead_h/2 + 2, z_mid - pile_w/2])
            cube([pile_d, hinge_y - hinge_r - 2 - (mag_y + bead_h/2 + 2), pile_w]);
        translate([-flap_w/2, -flap_h/2 - pile_d + eps, z_mid - pile_w/2]) cube([flap_w, pile_d, pile_w]);
    }
}

module flap_frame_ring() {
    difference() {
        translate([-flange_W/2, -flange_H/2, 0]) cube([flange_W, flange_H, ring_t]);
        translate([-flap_out_w/2 - 0.3, -flap_out_h/2 - 0.3, -1]) cube([flap_out_w + 0.6, flap_out_h + 0.6, ring_t + 2]);
        bolt_holes();
    }
}

// Battant, imprimé à plat (X = largeur, Y = hauteur, Z = épaisseur)
module flap() {
    fw = flap_w - 2*side_gap;
    difference() {
        union() {
            translate([-fw/2, 0, hinge_r]) rotate([0,90,0]) cylinder(r = hinge_r, h = fw);
            translate([-fw/2, -flap_len, 0]) cube([fw, flap_len, flap_t]);
            translate([-fw/2, -flap_len, 0]) cube([fw, bead_h, bead_t]);
        }
        translate([-fw/2 - 1, 0, hinge_r]) rotate([0,90,0]) cylinder(d = pin_d + 0.3, h = fw + 2);
        for (s = [-1,1]) translate([s*(fw/2 - mag_h/2 + eps), -flap_len + bead_h/2, bead_t/2])
            rotate([0,90,0]) cylinder(d = mag_d, h = mag_h, center = true);
    }
}

// ---------------------------------------------------------------------
// Vue assemblée
// ---------------------------------------------------------------------
module board(x, z, w, h) {  // pièce de bois vue de face
    translate([x, wall_pos, z]) cube([w, wood_d, h]);
}

// place un profilé de longueur L le long d'une face du cadre
// face: "bottom" | "top" | "left" (normale +X) | "right" (normale -X)
module place_chan(face, x, z, L) {
    yc = wall_pos + wood_d/2;
    if (face == "bottom") translate([x, yc, z]) clip_u(L);
    if (face == "top")    translate([x + L, yc, z]) rotate([0,180,0]) clip_u(L);
    if (face == "left")   translate([x, yc, z + L]) rotate([0,90,0]) clip_u(L);
    if (face == "right")  translate([x, yc, z]) rotate([0,-90,0]) clip_u(L);
}

module glazed_bay(x0) {
    zb = seal_gap + wood_t;        // dessus de la traverse basse
    zt = zb + inner_H;             // dessous de la traverse haute
    yc = wall_pos + wood_d/2;
    // verre
    color("lightblue", 0.35)
        translate([x0 + clr, yc - glass_pack/2, zb + clr]) cube([glass_w, glass_pack, glass_h]);
    if (glazing == "double")
        color("dimgray") translate([x0 + clr + 3, yc - igu_gap/2, zb + clr + 3]) cube([glass_w - 6, igu_gap, 4]);
    color("orange") {
        if (glazing_mode == "continu") {
            for (i = [0,1]) {
                place_chan("bottom", x0 + i*zone_g/2, zb, zone_g/2);
                place_chan("top",    x0 + i*zone_g/2, zt, zone_g/2);
            }
            place_chan("left",  x0,          zb + chan_h, inner_H - 2*chan_h);
            place_chan("right", x0 + zone_g, zb + chan_h, inner_H - 2*chan_h);
        } else {
            place_chan("bottom", x0 + zone_g/2 - clip_len/2, zb, clip_len);
            place_chan("top",    x0 + zone_g/2 - clip_len/2, zt, clip_len);
            place_chan("left",   x0,          zb + inner_H/2 - clip_len/2, clip_len);
            place_chan("right",  x0 + zone_g, zb + inner_H/2 - clip_len/2, clip_len);
            yc2 = wall_pos + wood_d/2;
            translate([x0, yc2, zb])                       clip_corner();
            translate([x0 + zone_g, yc2, zb]) mirror([1,0,0]) clip_corner();
            translate([x0, yc2, zt]) mirror([0,0,1])        clip_corner();
            translate([x0 + zone_g, yc2, zt]) mirror([1,0,0]) mirror([0,0,1]) clip_corner();
        }
    }
}

module assembled() {
    // --- niche (fantôme) ---
    %union() {
        translate([-40, -20, -20]) cube([recess_w + 80, recess_d + 20, 20]);            // appui
        translate([-40, -20, recess_h]) cube([recess_w + 80, recess_d + 20, 20]);       // linteau
        translate([-40, -20, 0]) cube([40, recess_d + 20, recess_h]);                   // joue gauche
        translate([recess_w, -20, 0]) cube([40, recess_d + 20, recess_h]);             // joue droite
    }
    // fenêtre existante (au fond) avec panneau gris et trou hexagonal
    color("gainsboro", 0.5) translate([0, recess_d, 0]) difference() {
        cube([recess_w, 40, recess_h]);
        translate([flap_side == "right" ? recess_w*0.78 : recess_w*0.22, -1, recess_h/2])
            rotate([-90,0,0]) rotate([0,0,30]) cylinder(r = 110, h = 42, $fn = 6);
    }

    x_in  = seal_gap + wood_t;          // bord gauche de l'ouverture intérieure
    // ordre des travées : chatière du côté flap_side
    x_flapzone = flap_side == "right" ? x_in + n_panes*(zone_g + wood_t) : x_in;
    x_glass0   = flap_side == "right" ? x_in : x_in + flap_zone + wood_t;

    // --- cadre bois ---
    color("burlywood") {
        board(seal_gap, seal_gap, frame_W, wood_t);                       // traverse basse
        board(seal_gap, seal_gap + frame_H - wood_t, frame_W, wood_t);   // traverse haute
        board(seal_gap, seal_gap + wood_t, wood_t, inner_H);              // montant gauche
        board(seal_gap + frame_W - wood_t, seal_gap + wood_t, wood_t, inner_H); // montant droit
        if (n_panes > 0) for (i = [0 : n_panes - 1]) {                    // meneaux
            xm = flap_side == "right" ? x_in + (i+1)*zone_g + i*wood_t
                                      : x_in + flap_zone + i*(zone_g + wood_t);
            board(xm, seal_gap + wood_t, wood_t, inner_H);
        }
    }
    // coupe-froid périphérique
    color("black", 0.6) difference() {
        translate([0, wall_pos + 5, 0]) cube([recess_w, wood_d - 10, recess_h]);
        translate([seal_gap, wall_pos, seal_gap]) cube([frame_W, wood_d, frame_H]);
    }

    // --- travées vitrées ---
    if (n_panes > 0) for (i = [0 : n_panes - 1])
        glazed_bay(x_glass0 + i*(zone_g + wood_t));

    // --- zone XPS + chatière ---
    y_xps = wall_pos + (wood_d - panel_t)/2;
    zb    = seal_gap + wood_t;
    fcx   = x_flapzone + flap_zone/2;
    fcz   = zb + 3 + flange_H/2;
    color("pink") difference() {
        translate([x_flapzone, y_xps, zb]) cube([flap_zone, panel_t, inner_H]);
        translate([fcx - flap_out_w/2, y_xps - 1, fcz - flap_out_h/2]) cube([flap_out_w, panel_t + 2, flap_out_h]);
    }
    // cadre-tunnel : bride côté pièce
    translate([fcx, y_xps - flange_t, fcz]) mirror([0,1,0]) rotate([90,0,0]) {
        color("white") flap_frame_main();
        color("white") translate([0,0,flange_t + panel_t]) flap_frame_ring();
        color("seagreen", 0.85) translate([0, hinge_y, z_mid - flap_t/2]) flap_in_place();
    }
}

module flap_in_place() { // battant fermé, dans le repère du cadre-tunnel
    // flap() a l'axe en (y=0, z=hinge_r) ; on recentre l'axe sur l'origine
    translate([0, 0, -hinge_r + flap_t/2]) flap();
}

// ---------------------------------------------------------------------
if (part == "assembled")       assembled();
if (part == "clip_u")          clip_u(glazing_mode == "continu" ? min(250, zone_g/2) : clip_len);
if (part == "clip_u_vert")     clip_u((inner_H - 2*chan_h)/2);
if (part == "clip_corner")     translate([0,0,chan_out/2]) rotate([-90,0,0]) clip_corner();
if (part == "flap_frame_main") flap_frame_main();
if (part == "flap_frame_ring") flap_frame_ring();
if (part == "flap")            flap();
