// Parametric cat door with a rectangular tapered frame and a clean hexagonal flap.
// Dimensions are expressed in millimeters internally. Main size controls are in inches.

inch = 25.4;
$fn = 48;
eps = 0.01;

// Primary size controls.
frame_width_in = 20;
frame_height_in = 17.5;

// Frame and door thickness controls.
frame_top_depth_in = 0.5;
frame_bottom_depth_in = 1.0;
door_thickness_in = 0.2;
frame_border_mm = 18;
door_edge_frame_mm = 10;
clearance_mm = 5;

// Screen pattern controls.
disable_hex_grid = true;
screen_hole_mm = 2;   // Flat-to-flat size of each hexagonal hole.
screen_web_mm = 0.5;  // Material left between screen holes.

// Alignment hole controls.
alignment_hole_diameter_mm = 3;
alignment_hole_top_margin_mm = 4;

frame_width_mm = frame_width_in * inch;
frame_height_mm = frame_height_in * inch;
frame_top_depth_mm = frame_top_depth_in * inch;
frame_bottom_depth_mm = frame_bottom_depth_in * inch;
door_thickness_mm = door_thickness_in * inch;
max_frame_depth_mm = max(frame_top_depth_mm, frame_bottom_depth_mm);

opening_width_mm = frame_width_mm - (2 * frame_border_mm);
opening_height_mm = frame_height_mm - (2 * frame_border_mm);

// A flat-top regular hexagon has width 2r and height sqrt(3) * r.
door_radius_mm = min(
    (opening_width_mm - (2 * clearance_mm)) / 2,
    (opening_height_mm - (2 * clearance_mm)) / sqrt(3)
);

door_top_y_mm = (sqrt(3) / 2) * door_radius_mm;
frame_opening_radius_mm = door_radius_mm + ((2 * clearance_mm) / sqrt(3));
alignment_hole_radius_mm = alignment_hole_diameter_mm / 2;
alignment_hole_y_mm = door_top_y_mm - alignment_hole_radius_mm - alignment_hole_top_margin_mm;
alignment_hole_z_mm = door_thickness_mm / 2;
door_hole_half_width_mm = door_radius_mm - (alignment_hole_y_mm / sqrt(3));
frame_opening_half_width_mm = frame_opening_radius_mm - (alignment_hole_y_mm / sqrt(3));
frame_side_hole_length_mm = (frame_width_mm / 2) - frame_opening_half_width_mm;
frame_side_hole_center_x_mm = (frame_opening_half_width_mm + (frame_width_mm / 2)) / 2;

assert(opening_width_mm > 0, "frame_border_mm is too large for the selected width.");
assert(opening_height_mm > 0, "frame_border_mm is too large for the selected height.");
assert(door_radius_mm > 0, "The current frame and clearance values leave no space for the door.");
assert(door_thickness_mm > 0, "door_thickness_in must be positive.");
assert(
    door_thickness_mm <= frame_top_depth_mm,
    "door_thickness_in must not exceed the top frame thickness."
);
assert(
    door_edge_frame_mm < ((sqrt(3) / 2) * door_radius_mm),
    "door_edge_frame_mm is too large for the hexagonal door."
);
assert(screen_hole_mm > 0, "screen_hole_mm must be positive.");
assert(screen_web_mm >= 0, "screen_web_mm must be zero or positive.");
assert(alignment_hole_diameter_mm > 0, "alignment_hole_diameter_mm must be positive.");
assert(
    alignment_hole_diameter_mm <= door_thickness_mm,
    "alignment_hole_diameter_mm must fit within the door thickness."
);
assert(
    alignment_hole_diameter_mm <= frame_top_depth_mm,
    "alignment_hole_diameter_mm must fit within the top frame thickness."
);
assert(alignment_hole_top_margin_mm >= 0, "alignment_hole_top_margin_mm must be zero or positive.");
assert(
    alignment_hole_y_mm + alignment_hole_radius_mm <= door_top_y_mm,
    "alignment hole is above the top side of the hex door."
);
assert(door_hole_half_width_mm > 0, "alignment hole is too high for the hex door.");
assert(frame_side_hole_length_mm > 0, "alignment hole does not intersect the frame sides.");

function hex_half_width(radius, y_pos) = radius - (abs(y_pos) / sqrt(3));

module hexagon_2d(radius) {
    polygon(points = [
        [ radius, 0],
        [ radius / 2,  (sqrt(3) / 2) * radius],
        [-radius / 2,  (sqrt(3) / 2) * radius],
        [-radius, 0],
        [-radius / 2, -(sqrt(3) / 2) * radius],
        [ radius / 2, -(sqrt(3) / 2) * radius]
    ]);
}

module honeycomb_holes_2d(bounds_radius, hole_flat_mm, web_mm) {
    hole_radius_mm = hole_flat_mm / sqrt(3);
    cell_radius_mm = (hole_flat_mm + web_mm) / sqrt(3);
    q_limit = ceil((bounds_radius * 2) / (1.5 * cell_radius_mm)) + 2;
    r_limit = ceil((bounds_radius * 2) / (sqrt(3) * cell_radius_mm)) + 2;

    union() {
        for (q = [-q_limit : q_limit]) {
            for (r = [-r_limit : r_limit]) {
                translate([
                    1.5 * cell_radius_mm * q,
                    sqrt(3) * cell_radius_mm * (r + (q / 2))
                ])
                    hexagon_2d(hole_radius_mm);
            }
        }
    }
}

module x_cylinder(length_mm, diameter_mm) {
    rotate([0, 90, 0])
        cylinder(h = length_mm, d = diameter_mm, center = true);
}

module outer_frame_body() {
    rotate([0, 90, 0])
        linear_extrude(height = frame_width_mm, center = true, convexity = 10)
            polygon(points = [
                [0, -frame_height_mm / 2],
                [0,  frame_height_mm / 2],
                [-frame_top_depth_mm,  frame_height_mm / 2],
                [-frame_bottom_depth_mm, -frame_height_mm / 2]
            ]);
}

module frame_opening_2d() {
    hexagon_2d(frame_opening_radius_mm);
}

module door_panel_2d() {
    hexagon_2d(door_radius_mm);
}

module door_screen_region_2d() {
    offset(delta = -door_edge_frame_mm)
        door_panel_2d();
}

module door_alignment_hole_cut() {
    translate([0, alignment_hole_y_mm, alignment_hole_z_mm])
        x_cylinder((2 * door_hole_half_width_mm) + (2 * eps), alignment_hole_diameter_mm);
}

module frame_alignment_hole_cut() {
    union() {
        translate([-frame_side_hole_center_x_mm, alignment_hole_y_mm, alignment_hole_z_mm])
            x_cylinder(frame_side_hole_length_mm + (2 * eps), alignment_hole_diameter_mm);

        translate([ frame_side_hole_center_x_mm, alignment_hole_y_mm, alignment_hole_z_mm])
            x_cylinder(frame_side_hole_length_mm + (2 * eps), alignment_hole_diameter_mm);
    }
}

module frame_part() {
    color([0.99, 0.18, 0.20])
        difference() {
            outer_frame_body();

            translate([0, 0, -eps])
                linear_extrude(height = max_frame_depth_mm + (2 * eps), convexity = 10)
                    frame_opening_2d();

            frame_alignment_hole_cut();
        }
}

module door_part() {
    color([0.78, 0.80, 0.84])
        difference() {
            linear_extrude(height = door_thickness_mm, convexity = 10)
                door_panel_2d();

            if (!disable_hex_grid)
                translate([0, 0, -eps])
                    linear_extrude(height = door_thickness_mm + (2 * eps), convexity = 10)
                        intersection() {
                            door_screen_region_2d();
                            honeycomb_holes_2d(
                                bounds_radius = door_radius_mm,
                                hole_flat_mm = screen_hole_mm,
                                web_mm = screen_web_mm
                            );
                        }

            door_alignment_hole_cut();
        }
}

frame_part();
door_part();
