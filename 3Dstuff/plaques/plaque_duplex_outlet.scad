// Single duplex outlet plaque with two rounded "face" openings.
use <plaque.scad>

/* [Plaque dimensions] */

single_plate_width = 100.0;
plate_height = 120.0;
plate_thickness = 4.0;
plate_corner_radius = 4.0;
edge_rounding_radius = 2.0;

/* [Back clearance] */

rim_width = 2.0;
recess_depth = 2.5;

/* [Outlet openings] */

// These parameters control the two rounded outlet openings.
outlet_width = 29.0;
outlet_height = 29.0;
outlet_corner_radius = 8.0;
outlet_spacing = 34.0;
print_face_down = true;

module model() {
    duplex_outlet_plaque(
        single_plate_width = single_plate_width,
        plate_height = plate_height,
        plate_thickness = plate_thickness,
        plate_corner_radius = plate_corner_radius,
        edge_rounding_radius = edge_rounding_radius,
        rim_width = rim_width,
        recess_depth = recess_depth,
        outlet_width = outlet_width,
        outlet_height = outlet_height,
        outlet_corner_radius = outlet_corner_radius,
        outlet_spacing = outlet_spacing
    );
}

if (print_face_down) rotate([180, 0, 0]) model(); else model();
