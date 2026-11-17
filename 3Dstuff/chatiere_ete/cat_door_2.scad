// Parametric cat door in millimeters.
// Includes a split rectangular frame, a rounded hexagonal door, optional hex screen,
// aligned 3 mm hinge-axis holes, and a separate 250 mm x 2.5 mm rod.

$fn = 48;
eps = 0.01;

// Overall frame dimensions.
frame_width_mm = 250;
frame_total_height_mm = 290;
frame_top_section_height_mm = 260;
frame_bottom_extension_height_mm = 30;

// Frame depth profile.
frame_top_depth_mm = 15;
frame_bottom_depth_mm = 35;

// Door and opening controls.
door_thickness_mm = 5;
frame_side_margin_mm = 18;
frame_top_margin_mm = 18;
bottom_swing_clearance_mm = 40;
door_vertical_offset_mm = 20;
clearance_mm = 3;
door_edge_frame_mm = 10;
hex_corner_radius_mm = 6;

// Screen pattern controls.
disable_hex_grid = true;
screen_hole_mm = 2;
screen_web_mm = 0.5;

// Hinge-axis hole controls.
alignment_hole_diameter_mm = 3;
alignment_hole_top_margin_mm = 4;
alignment_hole_z_offset_mm = 7;

// Swept clearance cut for the swinging door in the top frame.
swing_clearance_angle_deg = 85;
swing_clearance_step_deg = 5;
swing_clearance_extra_mm = clearance_mm;

// Separate rod.
hinge_rod_length_mm = 250;
hinge_rod_diameter_mm = 2.5;

// Split-joint controls for the 30 mm bottom extension.
joint_tongue_width_mm = 20;
joint_tongue_height_mm = 8;
joint_tongue_depth_mm = 6;
joint_tongue_clearance_mm = 0.4;
joint_side_inset_mm = 18;

// Display controls.
render_object = "assembled"; // "assembled", "top", "door", "top-and-door", "bottom", "rod", "bottom-and-rod"
layout_gap_mm = 20;
show_hinge_rod = true;

split_y_mm = frame_bottom_extension_height_mm;
max_frame_depth_mm = max(frame_top_depth_mm, frame_bottom_depth_mm);
sqrt3 = sqrt(3);

function frame_depth_at_y(y_pos) =
    frame_bottom_depth_mm
    - ((frame_bottom_depth_mm - frame_top_depth_mm) * (y_pos / frame_total_height_mm));

available_door_width_mm = frame_width_mm - (2 * frame_side_margin_mm) - (2 * clearance_mm);
available_door_height_mm = frame_total_height_mm - bottom_swing_clearance_mm - frame_top_margin_mm - clearance_mm;

// Flat-top regular hexagon: width = 2r, height = sqrt(3) * r.
door_radius_mm = min(
    available_door_width_mm / 2,
    available_door_height_mm / sqrt3
);

door_half_height_mm = (sqrt3 / 2) * door_radius_mm;
door_center_y_mm = bottom_swing_clearance_mm + door_half_height_mm + door_vertical_offset_mm;
door_top_local_y_mm = door_half_height_mm;

frame_opening_radius_mm = door_radius_mm + ((2 * clearance_mm) / sqrt3);
frame_opening_half_height_mm = (sqrt3 / 2) * frame_opening_radius_mm;
frame_opening_bottom_y_mm = door_center_y_mm - frame_opening_half_height_mm;
frame_opening_top_y_mm = door_center_y_mm + frame_opening_half_height_mm;

alignment_hole_radius_mm = alignment_hole_diameter_mm / 2;
alignment_hole_local_y_mm = door_top_local_y_mm - alignment_hole_radius_mm - alignment_hole_top_margin_mm;
alignment_hole_global_y_mm = door_center_y_mm + alignment_hole_local_y_mm;
alignment_hole_local_z_mm = door_thickness_mm / 2;
alignment_hole_global_z_mm = alignment_hole_local_z_mm + alignment_hole_z_offset_mm;

door_hole_half_width_mm = door_radius_mm - (abs(alignment_hole_local_y_mm) / sqrt3);
frame_opening_half_width_mm = frame_opening_radius_mm - (abs(alignment_hole_local_y_mm) / sqrt3);
frame_side_hole_length_mm = (frame_width_mm / 2) - frame_opening_half_width_mm;
frame_side_hole_center_x_mm = (frame_opening_half_width_mm + (frame_width_mm / 2)) / 2;

joint_center_x_mm = (frame_width_mm / 2) - joint_side_inset_mm - (joint_tongue_width_mm / 2);
joint_groove_depth_mm = joint_tongue_depth_mm + joint_tongue_clearance_mm;
joint_groove_width_mm = joint_tongue_width_mm + (2 * joint_tongue_clearance_mm);
joint_groove_height_mm = joint_tongue_height_mm + joint_tongue_clearance_mm;

assert(
    frame_top_section_height_mm + frame_bottom_extension_height_mm == frame_total_height_mm,
    "Top section height plus bottom extension height must equal total frame height."
);
assert(frame_width_mm > 0, "frame_width_mm must be positive.");
assert(frame_total_height_mm > 0, "frame_total_height_mm must be positive.");
assert(frame_top_depth_mm > 0, "frame_top_depth_mm must be positive.");
assert(frame_bottom_depth_mm > 0, "frame_bottom_depth_mm must be positive.");
assert(door_thickness_mm > 0, "door_thickness_mm must be positive.");
assert(door_thickness_mm <= frame_top_depth_mm, "door_thickness_mm must fit within the top frame thickness.");
assert(clearance_mm >= 0, "clearance_mm must be zero or positive.");
assert(bottom_swing_clearance_mm > 0, "bottom_swing_clearance_mm must be positive.");
assert(door_vertical_offset_mm >= 0, "door_vertical_offset_mm must be zero or positive.");
assert(door_radius_mm > 0, "The current dimensions leave no room for the door.");
assert(hex_corner_radius_mm >= 0, "hex_corner_radius_mm must be zero or positive.");
assert(
    hex_corner_radius_mm < ((sqrt3 / 2) * door_radius_mm),
    "hex_corner_radius_mm is too large for the hexagon size."
);
assert(
    door_edge_frame_mm < ((sqrt3 / 2) * door_radius_mm),
    "door_edge_frame_mm is too large for the hexagonal door."
);
assert(frame_opening_bottom_y_mm >= split_y_mm, "The frame opening extends into the bottom extension section.");
assert(frame_opening_top_y_mm <= frame_total_height_mm, "The frame opening extends above the frame.");
assert(screen_hole_mm > 0, "screen_hole_mm must be positive.");
assert(screen_web_mm >= 0, "screen_web_mm must be zero or positive.");
assert(alignment_hole_diameter_mm > 0, "alignment_hole_diameter_mm must be positive.");
assert(
    alignment_hole_diameter_mm <= door_thickness_mm,
    "alignment_hole_diameter_mm must fit within the door thickness."
);
assert(
    alignment_hole_global_z_mm - alignment_hole_radius_mm >= 0,
    "alignment_hole_z_offset_mm places the hole below the frame front face."
);
assert(
    alignment_hole_global_z_mm + alignment_hole_radius_mm <= frame_depth_at_y(alignment_hole_global_y_mm),
    "alignment_hole_z_offset_mm places the hole outside the frame thickness at the hinge-axis height."
);
assert(
    alignment_hole_local_y_mm + alignment_hole_radius_mm <= door_top_local_y_mm,
    "alignment hole is above the top side of the hex door."
);
assert(door_hole_half_width_mm > 0, "alignment hole is too high for the hex door.");
assert(swing_clearance_angle_deg >= 0, "swing_clearance_angle_deg must be zero or positive.");
assert(swing_clearance_angle_deg < 180, "swing_clearance_angle_deg must stay below 180 degrees.");
assert(swing_clearance_step_deg > 0, "swing_clearance_step_deg must be positive.");
assert(swing_clearance_extra_mm >= 0, "swing_clearance_extra_mm must be zero or positive.");
assert(frame_side_hole_length_mm > 0, "alignment hole does not intersect the frame sides.");
assert(joint_tongue_width_mm > 0, "joint_tongue_width_mm must be positive.");
assert(joint_tongue_height_mm > 0, "joint_tongue_height_mm must be positive.");
assert(joint_tongue_depth_mm > 0, "joint_tongue_depth_mm must be positive.");
assert(joint_tongue_clearance_mm >= 0, "joint_tongue_clearance_mm must be zero or positive.");
assert(joint_center_x_mm - (joint_tongue_width_mm / 2) > 0, "Joint tongues extend beyond the frame width.");

module hexagon_2d(radius) {
    polygon(points = [
        [ radius, 0],
        [ radius / 2,  (sqrt3 / 2) * radius],
        [-radius / 2,  (sqrt3 / 2) * radius],
        [-radius, 0],
        [-radius / 2, -(sqrt3 / 2) * radius],
        [ radius / 2, -(sqrt3 / 2) * radius]
    ]);
}

module rounded_hexagon_2d(radius, corner_radius_mm) {
    if (corner_radius_mm > 0)
        offset(r = corner_radius_mm)
            offset(delta = -corner_radius_mm)
                hexagon_2d(radius);
    else
        hexagon_2d(radius);
}

module honeycomb_holes_2d(bounds_radius, hole_flat_mm, web_mm) {
    hole_radius_mm = hole_flat_mm / sqrt3;
    cell_radius_mm = (hole_flat_mm + web_mm) / sqrt3;
    q_limit = ceil((bounds_radius * 2) / (1.5 * cell_radius_mm)) + 2;
    r_limit = ceil((bounds_radius * 2) / (sqrt3 * cell_radius_mm)) + 2;

    union() {
        for (q = [-q_limit : q_limit]) {
            for (r = [-r_limit : r_limit]) {
                translate([
                    1.5 * cell_radius_mm * q,
                    sqrt3 * cell_radius_mm * (r + (q / 2))
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

module frame_section_body(y_min_mm, y_max_mm) {
    depth_min_mm = frame_depth_at_y(y_min_mm);
    depth_max_mm = frame_depth_at_y(y_max_mm);

    rotate([0, 90, 0])
        linear_extrude(height = frame_width_mm, center = true, convexity = 10)
            polygon(points = [
                [0, y_min_mm],
                [0, y_max_mm],
                [-depth_max_mm, y_max_mm],
                [-depth_min_mm, y_min_mm]
            ]);
}

module door_panel_2d() {
    rounded_hexagon_2d(door_radius_mm, hex_corner_radius_mm);
}

module frame_opening_2d() {
    rounded_hexagon_2d(frame_opening_radius_mm, hex_corner_radius_mm);
}

module door_screen_region_2d() {
    offset(delta = -door_edge_frame_mm)
        door_panel_2d();
}

module door_swing_clearance_2d() {
    offset(delta = swing_clearance_extra_mm)
        door_panel_2d();
}

module door_alignment_hole_cut() {
    translate([0, alignment_hole_local_y_mm, alignment_hole_local_z_mm])
        x_cylinder((2 * door_hole_half_width_mm) + (2 * eps), alignment_hole_diameter_mm);
}

module frame_alignment_hole_cut() {
    union() {
        translate([-frame_side_hole_center_x_mm, alignment_hole_global_y_mm, alignment_hole_global_z_mm])
            x_cylinder(frame_side_hole_length_mm + (2 * eps), alignment_hole_diameter_mm);

        translate([ frame_side_hole_center_x_mm, alignment_hole_global_y_mm, alignment_hole_global_z_mm])
            x_cylinder(frame_side_hole_length_mm + (2 * eps), alignment_hole_diameter_mm);
    }
}

module door_swing_clearance_cut() {
    union() {
        for (angle_deg = [-swing_clearance_angle_deg : swing_clearance_step_deg : swing_clearance_angle_deg]) {
            translate([0, alignment_hole_global_y_mm, alignment_hole_global_z_mm])
                rotate([angle_deg, 0, 0])
                    translate([
                        0,
                        -alignment_hole_local_y_mm,
                        -alignment_hole_local_z_mm - swing_clearance_extra_mm
                    ])
                        linear_extrude(
                            height = door_thickness_mm + (2 * swing_clearance_extra_mm),
                            convexity = 10
                        )
                            door_swing_clearance_2d();
        }
    }
}

module bottom_extension_tongues() {
    union() {
        translate([
            -joint_center_x_mm - (joint_tongue_width_mm / 2),
            split_y_mm - eps,
            0
        ])
            cube([joint_tongue_width_mm, joint_tongue_height_mm + eps, joint_tongue_depth_mm]);

        translate([
             joint_center_x_mm - (joint_tongue_width_mm / 2),
            split_y_mm - eps,
            0
        ])
            cube([joint_tongue_width_mm, joint_tongue_height_mm + eps, joint_tongue_depth_mm]);
    }
}

module top_section_grooves() {
    union() {
        translate([
            -joint_center_x_mm - (joint_groove_width_mm / 2),
            split_y_mm - eps,
            -eps
        ])
            cube([joint_groove_width_mm, joint_groove_height_mm + (2 * eps), joint_groove_depth_mm + eps]);

        translate([
             joint_center_x_mm - (joint_groove_width_mm / 2),
            split_y_mm - eps,
            -eps
        ])
            cube([joint_groove_width_mm, joint_groove_height_mm + (2 * eps), joint_groove_depth_mm + eps]);
    }
}

module top_frame_part() {
    color([0.18, 0.65, 0.22])
        difference() {
            frame_section_body(split_y_mm, frame_total_height_mm);

            translate([0, door_center_y_mm, -eps])
                linear_extrude(height = max_frame_depth_mm + (2 * eps), convexity = 10)
                    frame_opening_2d();

            door_swing_clearance_cut();
            frame_alignment_hole_cut();
            top_section_grooves();
        }
}

module bottom_extension_part() {
    color([0.82, 0.18, 0.18])
        union() {
            frame_section_body(0, split_y_mm);
            bottom_extension_tongues();
        }
}

module door_part() {
    color([0.78, 0.80, 0.84])
        translate([0, door_center_y_mm, alignment_hole_z_offset_mm])
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

module hinge_rod_part() {
    color([0.70, 0.12, 0.12])
        x_cylinder(hinge_rod_length_mm, hinge_rod_diameter_mm);
}

module assembled_view() {
    top_frame_part();
    bottom_extension_part();
    door_part();

    if (show_hinge_rod)
        translate([0, alignment_hole_global_y_mm, alignment_hole_global_z_mm])
            hinge_rod_part();
}

module top_frame_on_bed() {
    translate([0, 0, max_frame_depth_mm])
        top_frame_part();
}

module bottom_frame_on_bed() {
    translate([0, 0, frame_bottom_depth_mm])
        bottom_extension_part();
}

module door_on_bed() {
    translate([0, 0, -alignment_hole_z_offset_mm])
        door_part();
}

module top_and_door_printable() {
    translate([0, 0, 0])
        top_frame_on_bed();

    translate([0, -(door_center_y_mm - door_half_height_mm + layout_gap_mm), -alignment_hole_z_offset_mm])
        door_part();
}

module bottom_printable() {
    bottom_frame_on_bed();
}

module door_printable() {
    door_on_bed();
}

module rod_printable() {
    translate([0, 0, hinge_rod_diameter_mm / 2])
        hinge_rod_part();
}

module bottom_and_rod_printable() {
    bottom_frame_on_bed();

    translate([0, -(layout_gap_mm + (hinge_rod_diameter_mm / 2)), 0])
        rod_printable();
}

if (render_object == "assembled")
    assembled_view();
else if (render_object == "top")
    top_frame_on_bed();
else if (render_object == "door")
    door_printable();
else if (render_object == "top-and-door")
    top_and_door_printable();
else if (render_object == "bottom")
    bottom_printable();
else if (render_object == "rod")
    rod_printable();
else if (render_object == "bottom-and-rod")
    bottom_and_rod_printable();
else
    assert(false, "render_object must be one of: assembled, top, door, top-and-door, bottom, rod, bottom-and-rod");
