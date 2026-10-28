// Four-position decorator plaque. Four "decora" slots suit four switches;
// set any slot to "flat" where no switch or outlet is installed.
use <plaque.scad>

/* [Plaque dimensions] */

single_plate_width = 80.0;
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
slot_3_style = "decora"; // [decora,flat]
slot_4_style = "flat"; // [decora,flat]

/* [Slot screw holes] */

slot_1_screw_holes = true;
slot_2_screw_holes = false;
slot_3_screw_holes = true;
slot_4_screw_holes = true;

print_face_down = true;

module model() {
    decorator_plaque(
        gang_count = 4,
        slot_styles = [slot_1_style, slot_2_style, slot_3_style, slot_4_style],
        slot_screw_holes = [
            slot_1_screw_holes,
            slot_2_screw_holes,
            slot_3_screw_holes,
            slot_4_screw_holes
        ],
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
