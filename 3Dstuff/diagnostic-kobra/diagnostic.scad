// Pièces de diagnostic pour un bruit de grattement sur les premières couches.
// Unités : mm. Choisir la pièce avec `part`, exporter en STL, trancher avec
// les réglages HABITUELS (même profil que les impressions qui grattent).
//
//  "premiere_couche" : 5 carrés d'UNE couche (4 coins + centre) -> Z offset
//                      et planéité du plateau, zone par zone.
//  "escalier"        : 6 marches de 1, 2, 3, 5, 8 et 12 couches -> à quelle
//                      hauteur le grattement commence / s'arrête.
//  "bosses"          : petites îles + longs déplacements entre elles -> le
//                      grattement vient-il de la buse qui frotte des bords
//                      relevés (curling / sur-extrusion) pendant les trajets ?

part = "premiere_couche"; // [premiere_couche, escalier, bosses]

/* [Machine] */
// Zone utile du plateau à couvrir (laisser une marge de ~15 mm au bord).
bed_x = 220;
bed_y = 220;
layer_h = 0.2;
first_layer_h = 0.2;

/* [Première couche] */
square_size = 30;
margin = 15;

/* [Escalier] */
step_layers = [1, 2, 3, 5, 8, 12];
step_w = 25;
step_d = 40;

/* [Bosses] */
islands_per_side = 4;
island_d = 8;
island_layers = 15;

function layers_to_h(n) = first_layer_h + (n - 1) * layer_h;

module premiere_couche() {
    h = first_layer_h;
    pos = [[margin, margin], [bed_x - margin - square_size, margin],
           [margin, bed_y - margin - square_size],
           [bed_x - margin - square_size, bed_y - margin - square_size],
           [(bed_x - square_size) / 2, (bed_y - square_size) / 2]];
    for (i = [0 : len(pos) - 1])
        translate([pos[i][0], pos[i][1], 0])
            cube([square_size, square_size, h]);
    // repère du coin avant gauche : petit triangle
    translate([margin, margin + square_size + 3, 0])
        linear_extrude(h) polygon([[0, 0], [8, 0], [0, 8]]);
}

module escalier() {
    for (i = [0 : len(step_layers) - 1])
        translate([i * step_w, 0, 0])
            cube([step_w, step_d, layers_to_h(step_layers[i])]);
}

module bosses() {
    pitch = (min(bed_x, bed_y) - 2 * margin) / (islands_per_side - 1);
    for (i = [0 : islands_per_side - 1], j = [0 : islands_per_side - 1])
        translate([margin + i * pitch, margin + j * pitch, 0])
            cylinder(d = island_d, h = layers_to_h(island_layers), $fn = 40);
}

if (part == "premiere_couche") premiere_couche();
else if (part == "escalier") escalier();
else bosses();
