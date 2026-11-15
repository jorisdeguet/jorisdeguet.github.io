// Plaque Decora pour une prise juste au-dessus d'une étagère.
// Le bas de la plaque s'arrête au ras du dessus de l'étagère et une fine lèvre
// continue vers le bas, à plat contre le mur, pour se glisser derrière le bois.
// La vis du bas est supprimée par défaut : la lèvre retient le bas de la plaque.
// Unités : mm. Origine = centre de la prise (entre les deux vis de plaque).
use <plaque.scad>

/* [Plaque] */
plate_width = 100.0;
// Distance du centre de la prise au haut de la plaque (plaque standard : 60).
top_extent = 60.0;
plate_thickness = 4.0;
plate_corner_radius = 4.0;
edge_rounding_radius = 2.0;
rim_width = 2.0;
recess_depth = 2.5;

/* [Étagère] */
// Distance entre le centre de la vis de plaque du BAS et le dessus de l'étagère,
// mesurée contre le mur. Estimée sur la photo à ~3 mm : À MESURER.
shelf_below_screw = 3.0;
// Jeu entre le bas de la face de la plaque et le dessus de l'étagère.
shelf_clearance = 0.4;

/* [Lèvre derrière le bois] */
// 0 = pas de lèvre (si l'étagère est collée au mur).
lip_length = 10.0;
// Doit passer entre le mur et le dos de l'étagère.
lip_thickness = 1.0;
// Largeur de la lèvre (centrée). Moins large que la plaque pour passer
// entre d'éventuelles vis/équerres de l'étagère.
lip_width = 80.0;

/* [Oreilles de la prise] */
// Les oreilles métalliques de la prise touchent l'étagère : on ouvre le cadre
// arrière du bas sur cette largeur (oreilles ~36 mm de large sur la photo).
ear_notch_width = 44.0;

/* [Ouverture Decora] */
opening_width = 33.3;
opening_height = 66.7;
opening_corner_radius = 3.0;
screw_spacing = 96.8375;
screw_diameter = 4.0;
countersink_diameter = 7.2;
// Garder le trou de vis du bas ? (gêné par l'étagère si shelf_below_screw < ~4 mm)
bottom_screw = false;

/* [Rendu] */
$fn = 64;
// "print" : dos sur le plateau (la lèvre est au niveau du plateau, sans support)
// "wall"  : vue en place, avec l'étagère en fantôme
mode = "print"; // [print, wall]

bottom_y = -(screw_spacing / 2 + shelf_below_screw - shelf_clearance);
plate_h = top_extent - bottom_y;
center_y = (top_extent + bottom_y) / 2;

module plaque_etagere() {
    difference() {
        translate([0, center_y, 0])
            rounded_plate(plate_width, plate_h, plate_thickness,
                          plate_corner_radius, edge_rounding_radius);

        // Dégagement arrière standard + encoche dans le cadre du bas pour les
        // oreilles de la prise.
        translate([0, center_y, -0.01])
            rounded_rectangle(plate_width - 2 * rim_width, plate_h - 2 * rim_width,
                              plate_corner_radius, recess_depth + 0.01);
        translate([-ear_notch_width / 2, bottom_y - 1, -0.01])
            cube([ear_notch_width, rim_width + 2, recess_depth + 0.01]);

        translate([0, 0, -1])
            rounded_rectangle(opening_width, opening_height, opening_corner_radius, plate_thickness + 2);

        countersunk_screw_hole(0, screw_spacing / 2, plate_thickness, screw_diameter, countersink_diameter);
        if (bottom_screw)
            countersunk_screw_hole(0, -screw_spacing / 2, plate_thickness, screw_diameter, countersink_diameter);
    }

    // Lèvre : dans le plan du mur (z = 0), accrochée au cadre du bas de part et
    // d'autre de l'encoche, puis continue sous le dessus de l'étagère.
    if (lip_length > 0)
        difference() {
            translate([-lip_width / 2, bottom_y - lip_length, 0])
                cube([lip_width, lip_length + rim_width, lip_thickness]);
            translate([-ear_notch_width / 2, bottom_y, -1])
                cube([ear_notch_width, rim_width + 1, lip_thickness + 2]);
            // chanfrein d'entrée sur l'arête basse, côté étagère
            translate([-lip_width / 2 - 1, bottom_y - lip_length, lip_thickness])
                rotate([45, 0, 0]) cube([lip_width + 2, lip_thickness, lip_thickness]);
        }
}

if (mode == "print") {
    plaque_etagere();
} else {
    plaque_etagere();
    // étagère fantôme : dessus à bottom_y - shelf_clearance, dos contre le mur
    %translate([-200, bottom_y - shelf_clearance - 25, lip_thickness])
        cube([400, 25, 250]);
}
