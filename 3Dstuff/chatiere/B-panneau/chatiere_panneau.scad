// =====================================================================
//  Chatière d'hiver — concept B : panneau isolé dans la coulisse
//  Tunnel imprimé en 2 demi-coques traversant un panneau sandwich,
//  2 volets battants magnétiques + brosses, joint de collerette.
//
//  Repère monde (vue "assembled") :
//    X = horizontal le long de la fenêtre (+X = côté châssis coulissant)
//    Z = vertical (haut)
//    Y = épaisseur : Y=0 face EXTÉRIEURE de la peau extérieure, +Y vers la maison
//
//  Repère local d'une demi-coque (pièces à imprimer) :
//    collerette à plat sur le plateau (z=0 = face visible),
//    tube vers le haut (z+), x = largeur, y = hauteur du passage.
//
//  Toutes les cotes en mm. Volume d'impression max : 260 x 260 x 260.
// =====================================================================

part = "assembled"; // [assembled, demi_ext, demi_int, volet, auvent, entretoise, montant, gabarit]

/* [Passage du chat] */
hole_w = 150;      // largeur libre du passage
hole_h = 165;      // hauteur libre du passage

/* [Panneau sandwich] */
panel_t = 44;      // épaisseur TOTALE au droit du tunnel (peau + entretoise + peau)
skin_t  = 3;       // épaisseur d'une peau (polycarbonate / acrylique / coroplast)

/* [Tunnel] */
wall     = 3.5;    // paroi du tube
flange_x = 25;     // débord de collerette sur les côtés (porte les boulons)
flange_y = 14;     // débord de collerette haut/bas (joint seulement)
flange_t = 4;      // épaisseur de collerette
corner_r = 6;

/* [Volet] */
flap_t   = 3;      // épaisseur de la plaque du volet
side_gap = 4;      // jeu volet / paroi (rempli par la brosse)
bot_gap  = 2;      // jeu volet / plancher (aimants face à face)
piv_r    = 4.5;    // rayon du canon de charnière
pin_d    = 3;      // axe : tige acier 3 mm (ou clou / M3 lisse)
bar_h    = 6;      // hauteur de la barre basse du volet

/* [Aimants néodyme] */
mag_d = 8;
mag_h = 3;

/* [Brosses (coupe-froid à velours)] */
brush_w     = 5;   // largeur de rainure (base de velours 4,8 mm = 3/16")
brush_depth = 2.5; // profondeur de rainure

/* [Joint de collerette] */
gasket_w   = 3;    // rainure pour cordon mousse/EPDM Ø4
gasket_d   = 1.6;
gasket_off = 2;    // distance tube -> rainure

/* [Boulonnerie M4] */
bolt_d = 4;
nut_af = 7;        // écrou M4 : 7 mm sur plats
nut_h  = 3.2;

/* [Emboîtement des demi-coques] */
tongue_w = 1.6;
tongue_h = 2;
tol      = 0.25;

/* [Auvent] */
hood_d = 35;       // avancée de l'auvent

/* [Montant d'étanchéité côté châssis] */
clip_wall  = 2;    // parois de la pince
clip_grip  = 12;   // profondeur de pince sur la peau
rib_pos    = 16;   // position de la nervure (depuis le chant de la peau)
rib_h      = 3;    // hauteur de nervure (ajuster à l'écart peau/châssis mesuré)
montant_len = 260; // longueur totale à couvrir (= hauteur du panneau gris)
seg_max     = 250; // longueur max d'un tronçon imprimé

/* [Affichage assemblage] */
skin_W  = 300;     // largeur peau extérieure (= panneau gris actuel, À MESURER)
skin_H  = 260;     // hauteur peau extérieure (À MESURER)
inset_frame = 15;  // retrait du caisson intérieur côté dormant
inset_sash  = 45;  // retrait côté châssis (zone de recouvrement du coulissant)
inset_tb    = 20;  // retrait haut/bas (rails de la coulisse)
spacer_w    = 19;  // largeur du cadre-entretoise bois (1x2)
explode     = 0;   // éclaté (mm)
flap_angle  = 0;   // angle d'ouverture des volets pour l'aperçu

max_bed = 260;
$fn = 48;

// ------------------------------------------------------------- dérivés
TW = hole_w + 2*wall;
TH = hole_h + 2*wall;
FW = TW + 2*flange_x;
FH = TH + 2*flange_y;
L  = panel_t/2;            // longueur de tube par demi-coque
H  = flange_t + L;         // hauteur totale d'une demi-coque
bar_t = mag_d + 3;         // épaisseur de la barre aimantée
zp = flange_t + piv_r + 1; // profondeur de l'axe de charnière
z0 = zp - piv_r;           // face du volet côté collerette
zc = z0 + flap_t/2;        // plan des brosses
zm = z0 + bar_t/2;         // plan des aimants
piv_y  = hole_h/2 - side_gap - piv_r;
flap_y0 = -hole_h/2 + bot_gap;
fw = hole_w - 2*side_gap;
bx = TW/2 + flange_x/2;                     // boulons sur les côtés
bolt_pts = [for (sy=[-1,0,1]) for (sx=[-1,1]) [sx*bx, sy*(FH/2 - 8)]];
nseg = ceil(montant_len/seg_max);
seg_len = montant_len/nseg;
core_W = skin_W - inset_frame - inset_sash;
core_H = skin_H - 2*inset_tb;
cx = (inset_frame - inset_sash)/2;          // centre du tunnel (milieu du caisson)
cz = 0;

echo(str("Tunnel : passage ", hole_w, " x ", hole_h,
         " | tube ", TW, " x ", TH, " | collerette ", FW, " x ", FH,
         " | trou panneau ", TW+1, " x ", TH+1));
echo(str("Demi-coque hauteur ", H, " mm ; ecart entre volets ~ ", panel_t + 2*flange_t - 2*z0 - 2*flap_t, " mm"));
echo(str("Montant : ", nseg, " troncons de ", seg_len, " mm"));
assert(FW <= max_bed && FH <= max_bed, "Collerette > 260 mm : réduire flange_x/flange_y ou le passage");
assert(z0 + max(bar_t, 2*piv_r) <= H - tongue_h - 1, "panel_t trop mince pour les volets (min ~30 mm)");
assert(TH + 2 <= core_H, "Le tunnel ne rentre pas dans le caisson : vérifier skin_H / inset_tb");

// ------------------------------------------------------------- utilitaires
module rr(w, h, r) { offset(r=r) offset(delta=-r) square([w, h], center=true); }
module ring(w, h, t) { difference() { square([w+t, h+t], center=true); square([w-t, h-t], center=true); } }

// ------------------------------------------------------------- demi-coque
module half(outer=true) {
    difference() {
        union() {
            linear_extrude(flange_t) rr(FW, FH, corner_r);
            linear_extrude(H) square([TW, TH], center=true);
            if (outer) translate([0,0,H-0.01]) linear_extrude(tongue_h) ring(TW-wall, TH-wall, tongue_w);
        }
        // passage
        translate([0,0,-1]) linear_extrude(H + tongue_h + 2) square([hole_w, hole_h], center=true);
        // rainure d'emboîtement (demi intérieure)
        if (!outer) translate([0,0,H-tongue_h-0.4]) linear_extrude(tongue_h+1)
            ring(TW-wall, TH-wall, tongue_w + 2*tol);
        // rainure de joint sur la face d'appui (z = flange_t)
        translate([0,0,flange_t-gasket_d]) linear_extrude(gasket_d+0.01) difference() {
            square([TW+2*(gasket_off+gasket_w), TH+2*(gasket_off+gasket_w)], center=true);
            square([TW+2*gasket_off, TH+2*gasket_off], center=true);
        }
        // boulons : fraisage côté extérieur, piège à écrou côté intérieur
        for (p = bolt_pts) translate([p[0], p[1], 0]) {
            translate([0,0,-1]) cylinder(d=bolt_d+0.4, h=flange_t+2);
            if (outer) translate([0,0,-0.01]) cylinder(d1=2*bolt_d+0.5, d2=bolt_d+0.4, h=(bolt_d+0.1)/2);
            else       translate([0,0,-0.01]) cylinder(d=nut_af/cos(30)+0.4, h=nut_h, $fn=6);
        }
        // axe de charnière (traverse les 2 parois, captif une fois posé)
        translate([0, piv_y, zp]) rotate([0,90,0]) cylinder(d=pin_d+0.3, h=TW+2, center=true);
        // rainures de brosse : côtés, plafond, plancher (interrompu au centre pour l'aimant)
        for (s=[-1,1]) translate([s*(hole_w/2 + brush_depth/2 - 0.01), 0, zc])
            cube([brush_depth+0.02, hole_h, brush_w], center=true);
        translate([0, hole_h/2 + brush_depth/2 - 0.01, zc]) cube([hole_w, brush_depth+0.02, brush_w], center=true);
        gap = mag_d + 8; sl = (hole_w - gap)/2;
        for (s=[-1,1]) translate([s*(gap/2 + sl/2), -hole_h/2 - brush_depth/2 + 0.01, zc])
            cube([sl, brush_depth+0.02, brush_w], center=true);
        // logement d'aimant dans le plancher
        translate([0, -hole_h/2 - (mag_h+0.2) + 0.01, zm]) rotate([-90,0,0]) cylinder(d=mag_d+0.3, h=mag_h+0.2);
    }
}

// ------------------------------------------------------------- volet (repère local de la demi-coque)
module flap_local() {
    difference() {
        union() {
            translate([0, piv_y, zp]) rotate([0,90,0]) cylinder(r=piv_r, h=fw, center=true);
            translate([-fw/2, flap_y0, z0]) cube([fw, piv_y - flap_y0, flap_t]);
            translate([-fw/2, flap_y0, z0]) cube([fw, bar_h, bar_t]);
            // raidisseurs verticaux
            for (x=[-fw/4, fw/4]) translate([x-1, flap_y0, z0]) cube([2, piv_y - flap_y0, flap_t+3]);
        }
        translate([0, piv_y, zp]) rotate([0,90,0]) cylinder(d=pin_d+0.5, h=fw+2, center=true);
        translate([0, flap_y0 - 0.01, zm]) rotate([-90,0,0]) cylinder(d=mag_d+0.3, h=mag_h+0.2);
    }
}
module flap_print() translate([0,0,-z0]) flap_local();
module flap_swung(a) translate([0,piv_y,zp]) rotate([a,0,0]) translate([0,-piv_y,-zp]) flap_local();

// ------------------------------------------------------------- auvent (vissé sur les 2 boulons du haut)
hp_y0 = FH/2 - 16;  // bas de la plaque d'appui (repère collerette)
module hood() {
    hp_h = FH/2 - hp_y0;
    difference() {
        union() {
            translate([-FW/2, 0, 0]) cube([FW, hp_h, 3]);
            translate([-FW/2, hp_h-3, 0]) cube([FW, 3, hood_d]);
            for (s=[-1,1]) hull() {
                translate([s*(FW/2-1.5)-1.5, 0, 0]) cube([3, hp_h, 3]);
                translate([s*(FW/2-1.5)-1.5, hp_h-3, 0]) cube([3, 3, hood_d]);
            }
        }
        for (p = bolt_pts) if (p[1] > 0) translate([p[0], p[1]-hp_y0, -1]) {
            cylinder(d=bolt_d+0.4, h=6);
            translate([0,0,1+3-(bolt_d+0.1)/2]) cylinder(d1=bolt_d+0.4, d2=2*bolt_d+0.5, h=(bolt_d+0.1)/2+0.01);
        }
    }
}

// ------------------------------------------------------------- entretoise de boulon (empêche d'écraser les peaux)
module entretoise() difference() {
    cylinder(d=9, h=panel_t - 2*skin_t);
    translate([0,0,-1]) cylinder(d=bolt_d+0.5, h=panel_t);
}

// ------------------------------------------------------------- montant d'étanchéité (pince sur le chant de la peau)
// u : 0 = chant de la peau, + vers l'intérieur du panneau ; v : 0 = face ext. de la peau, + vers la maison
module montant2d() {
    s = skin_t + tol;
    difference() {
        union() {
            translate([-clip_wall, -clip_wall]) square([clip_wall + clip_grip, s + 2*clip_wall]);
            translate([rib_pos, s + clip_wall - 0.01]) square([brush_w + 4, rib_h + brush_depth]);
            translate([0, s + clip_wall - 0.01]) square([rib_pos + 0.01, 2]);  // âme reliant pince et nervure
        }
        translate([0, 0]) square([clip_grip + 1, s]);
        translate([rib_pos + 2, s + clip_wall + rib_h + 0.01]) square([brush_w, brush_depth + 0.01]);
    }
}
module montant_print() translate([0,0,clip_wall]) rotate([90,0,90]) linear_extrude(seg_len) montant2d();

// ------------------------------------------------------------- gabarit de perçage/découpe (imprimer, coller sur la peau)
module gabarit() linear_extrude(1.2) difference() {
    rr(FW, FH, corner_r);
    square([TW+1, TH+1], center=true);
    for (p = bolt_pts) translate(p) circle(d=3);
}

// ------------------------------------------------------------- assemblage
M_out = [[1,0,0,cx],[0,0,1,-flange_t],[0,1,0,cz],[0,0,0,1]];
M_in  = [[1,0,0,cx],[0,0,-1,panel_t+flange_t],[0,1,0,cz],[0,0,0,1]];

module panel_view() {
    hole = [TW+1, TH+1];
    // peau extérieure (glisse dans la coulisse, même taille que le panneau gris)
    color("lightblue", 0.35) difference() {
        translate([-skin_W/2, 0, -skin_H/2]) cube([skin_W, skin_t, skin_H]);
        translate([cx-hole[0]/2, -1, cz-hole[1]/2]) cube([hole[0], skin_t+2, hole[1]]);
    }
    // cadre-entretoise bois
    color("burlywood") translate([-skin_W/2 + inset_frame, skin_t, -core_H/2]) difference() {
        cube([core_W, panel_t - 2*skin_t, core_H]);
        translate([spacer_w, -1, spacer_w]) cube([core_W-2*spacer_w, panel_t, core_H-2*spacer_w]);
    }
    // peau intérieure
    color("lightblue", 0.35) translate([0, panel_t - skin_t, 0]) difference() {
        translate([-skin_W/2 + inset_frame, 0, -core_H/2]) cube([core_W, skin_t, core_H]);
        translate([cx-hole[0]/2, -1, cz-hole[1]/2]) cube([hole[0], skin_t+2, hole[1]]);
    }
}

module assembled() {
    panel_view();
    translate([0, -explode, 0]) {
        color("orange") multmatrix(M_out) half(true);
        color("white")  multmatrix(M_out) flap_swung(flap_angle);
        color("darkorange") multmatrix(M_out) translate([0, hp_y0, 0]) mirror([0,0,1]) hood();
    }
    translate([0, explode, 0]) {
        color("gold")  multmatrix(M_in) half(false);
        color("white") multmatrix(M_in) flap_swung(flap_angle);
    }
    // entretoises de boulons
    color("gray") for (p = bolt_pts) translate([cx+p[0], skin_t, cz+p[1]]) rotate([-90,0,0]) entretoise();
    // montant côté châssis coulissant (chant +X de la peau ext.)
    color("seagreen") for (i=[0:nseg-1])
        multmatrix([[-1,0,0,skin_W/2],[0,1,0,0],[0,0,1,0],[0,0,0,1]]) // u -> -X, v -> +Y
            translate([0, 0, -skin_H/2 + i*seg_len + 0.5]) linear_extrude(seg_len - 1) montant2d();
}

// ------------------------------------------------------------- sélection
if      (part == "assembled")  assembled();
else if (part == "demi_ext")   half(true);
else if (part == "demi_int")   half(false);
else if (part == "volet")      flap_print();
else if (part == "auvent")     hood();
else if (part == "entretoise") entretoise();
else if (part == "montant")    montant_print();
else if (part == "gabarit")    gabarit();
