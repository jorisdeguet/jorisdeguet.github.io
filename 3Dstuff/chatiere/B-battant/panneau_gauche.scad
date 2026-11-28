// =====================================================================
//  Chatière d'hiver : panneau GAUCHE, module à battant vissé sur un 2x4
//
//  Le module de battant.scad avec ses réglages pour ce panneau :
//  ouverture de 190, montants de 3 mm, aile de 44 vissée à gauche (vue du
//  côté du 2x4), sans collerette côté fenêtre. On voit aussi le 2x4 (en
//  bois, derrière la face plate du cadre), la fenêtre et les 4 vis.
//  Plans : B-battant/README.md ; STL dans stl_panneau_gauche/.
// =====================================================================

include <battant.scad>

ouv_l_r = 190;
bordure_s_r = 3;
aile_r = 44;
aile_gauche = true;
aim_dist_r = [30, 45, 60];   // aimants : sans les poches la plus près et la plus loin de l'axe
aim_bas = false;      // aimants seulement dans la bande du haut
monobloc = true;      // cadre d'une pièce : battant glissé de face à 90°, axe enfilé par le haut
part = "assembled";   // [assembled, eclate, cadre, battant, axe] : vue montée, éclatée, ou une pièce à imprimer
angle = 45;           // [-5:5:100]
contexte = true;      // fenêtre, 2x4 et vis

mousse_f = 3;         // mousse entre le panneau et la fenêtre
p2x4 = [210, 290];    // le 2x4 : de 210 à 290 de la fenêtre, 38 d'épaisseur

// repère : le module est en miroir, l'aile est à -X et le bout côté fenêtre à +X (x = L2)
xf = L2 + mousse_f;   // face de la fenêtre
if (contexte && part == "assembled") {
    color("Tan") translate([xf - p2x4[1], -38, -20]) cube([p2x4[1] - p2x4[0], 38, H + colle_h + 60]);
    color("LightBlue", 0.4) translate([xf, -60, -20]) cube([15, 120, H + colle_h + 60]);
    color("SlateGray") translate([L2, 0, -$socle]) cube([mousse_f, epais, H + colle_h]);
    color("Silver") for (p = vis_pts) translate([-p[0], 0, p[1]]) rotate([90, 0, 0]) {
        translate([0, 0, -epais]) cylinder(d1 = vis_tete, d2 = vis_d, h = (vis_tete - vis_d) / 2, $fn = 24);
        translate([0, 0, -epais]) cylinder(d = vis_d - 0.6, h = epais + 26, $fn = 16);
    }
}
