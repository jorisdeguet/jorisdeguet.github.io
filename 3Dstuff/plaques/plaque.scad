// Parameterized decorator / Decora-style wall plaque.
// All dimensions are millimetres. Edit the values in this file for a single
// plaque, or open one of the numbered variants in this directory.

/* [Plaque layout] */

// Number of horizontal device positions.
gang_count = 1; // [1:1:4]

// "decora" cuts a standard decorator opening; "flat" leaves that position solid.
slot_styles = ["decora"];

/* [Plaque dimensions] */

// The original single-plate width is retained as the default.
single_plate_width = 100.0;
plate_height = 120.0;
plate_thickness = 4.0;
plate_corner_radius = 4.0;
edge_rounding_radius = 2.0;

// Centre-to-centre distance between adjacent device positions.
gang_spacing = 46.04;

/* [Back clearance] */

// A full-thickness rim remains against the wall.
rim_width = 2.0;
recess_depth = 2.5;

/* [Decorator opening] */

opening_width = 33.3;
opening_height = 66.7;
opening_corner_radius = 3.0;
screw_spacing = 96.8375;
screw_diameter = 4.0;
countersink_diameter = 7.2;

/* [Rendering] */

$fn = 64; // [12:4:128]
print_face_down = true;

module rounded_rectangle_2d(width, height, radius) {
    safe_radius = min(radius, min(width, height) / 2);
    offset(r = safe_radius)
        square([width - 2 * safe_radius, height - 2 * safe_radius], center = true);
}

module rounded_rectangle(width, height, radius, depth) {
    linear_extrude(height = depth)
        rounded_rectangle_2d(width, height, radius);
}

module rounded_plate(width, height, thickness, corner_radius, rounding_radius) {
    effective_rounding = min(rounding_radius, thickness);
    linear_extrude(height = thickness - effective_rounding)
        rounded_rectangle_2d(width, height, corner_radius);

    steps = 10;
    for (i = [0 : steps - 1]) {
        angle_1 = i * 90 / steps;
        angle_2 = (i + 1) * 90 / steps;
        height_1 = thickness - effective_rounding + effective_rounding * sin(angle_1);
        height_2 = thickness - effective_rounding + effective_rounding * sin(angle_2);
        inset_1 = effective_rounding * (1 - cos(angle_1));
        inset_2 = effective_rounding * (1 - cos(angle_2));

        hull() {
            translate([0, 0, height_1])
                linear_extrude(height = 0.01)
                    rounded_rectangle_2d(width - 2 * inset_1, height - 2 * inset_1, corner_radius - inset_1);
            translate([0, 0, height_2])
                linear_extrude(height = 0.01)
                    rounded_rectangle_2d(width - 2 * inset_2, height - 2 * inset_2, corner_radius - inset_2);
        }
    }
}

module countersunk_screw_hole(x, y, thickness, diameter, countersink_diameter) {
    translate([x, y, -1])
        cylinder(d = diameter, h = thickness + 2);

    translate([x, y, thickness - (countersink_diameter - diameter) / 2])
        cylinder(
            d1 = diameter,
            d2 = countersink_diameter,
            h = (countersink_diameter - diameter) / 2 + 0.01
        );
}

module decorator_opening(x, thickness, opening_width, opening_height, opening_corner_radius,
                          screw_spacing, screw_diameter, countersink_diameter,
                          include_screw_holes = true) {
    translate([x, 0, -1])
        rounded_rectangle(opening_width, opening_height, opening_corner_radius, thickness + 2);

    if (include_screw_holes) {
        countersunk_screw_hole(x, screw_spacing / 2, thickness, screw_diameter, countersink_diameter);
        countersunk_screw_hole(x, -screw_spacing / 2, thickness, screw_diameter, countersink_diameter);
    }
}

module decorator_plaque(
    gang_count,
    slot_styles,
    single_plate_width = 100,
    plate_height = 120,
    plate_thickness = 4,
    plate_corner_radius = 4,
    edge_rounding_radius = 2,
    gang_spacing = 46.04,
    rim_width = 2,
    recess_depth = 2.5,
    opening_width = 33.3,
    opening_height = 66.7,
    opening_corner_radius = 3,
    screw_spacing = 96.8375,
    screw_diameter = 4,
    countersink_diameter = 7.2,
    slot_screw_holes = []
) {
    plate_width = single_plate_width + (gang_count - 1) * gang_spacing;
    assert(gang_count >= 1, "gang_count must be at least 1");
    assert(len(slot_styles) == gang_count, "Specify one slot style for each position.");
    assert(len(slot_screw_holes) == 0 || len(slot_screw_holes) == gang_count,
           "Specify no screw-hole options or one for each position.");
    assert(recess_depth <= plate_thickness, "recess_depth cannot exceed plate_thickness.");

    difference() {
        rounded_plate(plate_width, plate_height, plate_thickness, plate_corner_radius, edge_rounding_radius);

        translate([0, 0, -0.01])
            rounded_rectangle(
                plate_width - 2 * rim_width,
                plate_height - 2 * rim_width,
                plate_corner_radius,
                recess_depth + 0.01
            );

        for (position = [0 : gang_count - 1]) {
            x = (position - (gang_count - 1) / 2) * gang_spacing;
            if (slot_styles[position] == "decora")
                decorator_opening(
                    x, plate_thickness, opening_width, opening_height, opening_corner_radius,
                    screw_spacing, screw_diameter, countersink_diameter,
                    len(slot_screw_holes) == 0 ? true : slot_screw_holes[position]
                );
            else
                assert(slot_styles[position] == "flat", "Slot styles must be \"decora\" or \"flat\".");
        }
    }
}

module duplex_outlet_plaque(
    single_plate_width = 100,
    plate_height = 120,
    plate_thickness = 4,
    plate_corner_radius = 4,
    edge_rounding_radius = 2,
    rim_width = 2,
    recess_depth = 2.5,
    outlet_width = 29,
    outlet_height = 29,
    outlet_corner_radius = 8,
    outlet_spacing = 34,
    screw_spacing = 96.8375,
    screw_diameter = 4,
    countersink_diameter = 7.2
) {
    assert(recess_depth <= plate_thickness, "recess_depth cannot exceed plate_thickness.");

    difference() {
        rounded_plate(single_plate_width, plate_height, plate_thickness, plate_corner_radius, edge_rounding_radius);

        translate([0, 0, -0.01])
            rounded_rectangle(
                single_plate_width - 2 * rim_width,
                plate_height - 2 * rim_width,
                plate_corner_radius,
                recess_depth + 0.01
            );

        for (y = [-outlet_spacing / 2, outlet_spacing / 2])
            translate([0, y, -1])
                rounded_rectangle(outlet_width, outlet_height, outlet_corner_radius, plate_thickness + 2);

        countersunk_screw_hole(0, screw_spacing / 2, plate_thickness, screw_diameter, countersink_diameter);
        countersunk_screw_hole(0, -screw_spacing / 2, plate_thickness, screw_diameter, countersink_diameter);
    }
}

module single_decorator_plaque() {
    decorator_plaque(
        gang_count, slot_styles, single_plate_width, plate_height, plate_thickness,
        plate_corner_radius, edge_rounding_radius, gang_spacing, rim_width, recess_depth,
        opening_width, opening_height, opening_corner_radius, screw_spacing, screw_diameter,
        countersink_diameter
    );
}

if (print_face_down)
    rotate([180, 0, 0]) single_decorator_plaque();
else
    single_decorator_plaque();
