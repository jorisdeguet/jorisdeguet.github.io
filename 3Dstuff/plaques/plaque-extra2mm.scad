// Single decorator plaque with a 2 mm deeper lip, for an electrical box that
// sits slightly proud of the wall. The front face is unchanged; the rim that
// rests on the wall reaches `extra_lip` further back.
use <plaque.scad>

/* [Extra lip] */

// How far the box stands out from the wall.
extra_lip = 2.0;

/* [Plaque dimensions] */

single_plate_width = 100.0;
plate_height = 120.0;
plate_thickness = 4.0;   // standard plaque, before the extra lip
plate_corner_radius = 4.0;
edge_rounding_radius = 2.0;

/* [Back clearance] */

rim_width = 2.0;
recess_depth = 2.5;      // standard plaque, before the extra lip

/* [Decorator opening] */

opening_clearance = 0.6;
print_face_down = true;

module model() {
    decorator_plaque(
        gang_count = 1,
        slot_styles = ["decora"],
        single_plate_width = single_plate_width,
        plate_height = plate_height,
        plate_thickness = plate_thickness + extra_lip,
        plate_corner_radius = plate_corner_radius,
        edge_rounding_radius = edge_rounding_radius,
        rim_width = rim_width,
        recess_depth = recess_depth + extra_lip,
        opening_clearance = opening_clearance
    );
}

if (print_face_down) rotate([180, 0, 0]) model(); else model();
