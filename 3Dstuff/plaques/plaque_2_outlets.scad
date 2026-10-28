// Two-position decorator plaque. Change either slot to "flat" for no opening.
use <plaque.scad>

/* [Plaque dimensions] */

single_plate_width = 100.0;
plate_height = 120.0;
plate_thickness = 4.0;
plate_corner_radius = 4.0;
edge_rounding_radius = 2.0;
gang_spacing = 46.04;

/* [Back clearance] */

rim_width = 2.0;
recess_depth = 2.5;

/* [Slot styles] */

slot_1_style = "decora"; // [decora,flat]
slot_2_style = "decora"; // [decora,flat]
print_face_down = true;

module model() {
    decorator_plaque(
        gang_count = 2,
        slot_styles = [slot_1_style, slot_2_style],
        single_plate_width = single_plate_width,
        plate_height = plate_height,
        plate_thickness = plate_thickness,
        plate_corner_radius = plate_corner_radius,
        edge_rounding_radius = edge_rounding_radius,
        gang_spacing = gang_spacing,
        rim_width = rim_width,
        recess_depth = recess_depth
    );
}

if (print_face_down) rotate([180, 0, 0]) model(); else model();
