// Parametric ceiling hook for side-printing.
// The default render is already oriented flat for printing so the layer lines
// follow the hook profile instead of stacking through the loaded section.

$fn = 96;
eps = 0.01;

render_mode = "print"; // "print" or "installed"

// Core sizing.
hook_width_mm = 5;
thing_diameter_mm = 55;
fit_clearance_mm = 3;
hook_wall_mm = 7;
mouth_opening_mm = 18;

// Mounting and fastener sizing.
mount_pad_radius_mm = 10;
web_thickness_mm = 11;
screw_shank_diameter_mm = 4.5;
screw_head_diameter_mm = 8.8;
screw_head_angle_deg = 90;
countersink_on_top = true;

clear_diameter_mm = thing_diameter_mm + fit_clearance_mm;
inner_radius_mm = clear_diameter_mm / 2;
outer_radius_mm = inner_radius_mm + hook_wall_mm;
ring_center_y_mm = -outer_radius_mm;
mouth_cut_x_mm = inner_radius_mm - mouth_opening_mm;
web_anchor_y_mm = ring_center_y_mm + (outer_radius_mm * 0.45);
countersink_depth_mm =
    (screw_head_diameter_mm - screw_shank_diameter_mm)
    / (2 * tan(screw_head_angle_deg / 2));

assert(hook_width_mm > 0, "hook_width_mm must be positive.");
assert(thing_diameter_mm > 0, "thing_diameter_mm must be positive.");
assert(fit_clearance_mm >= 0, "fit_clearance_mm must be zero or positive.");
assert(hook_wall_mm > 0, "hook_wall_mm must be positive.");
assert(mouth_opening_mm > 0, "mouth_opening_mm must be positive.");
assert(mouth_cut_x_mm < inner_radius_mm, "mouth_opening_mm is too large.");
assert(mount_pad_radius_mm > (screw_head_diameter_mm / 2), "mount_pad_radius_mm is too small for the screw head.");
assert(web_thickness_mm > 0, "web_thickness_mm must be positive.");
assert(screw_shank_diameter_mm > 0, "screw_shank_diameter_mm must be positive.");
assert(screw_head_diameter_mm > screw_shank_diameter_mm, "screw_head_diameter_mm must be larger than the shank.");
assert(screw_head_angle_deg > 0 && screw_head_angle_deg < 180, "screw_head_angle_deg must be between 0 and 180.");
assert(countersink_depth_mm < hook_width_mm, "Countersink is deeper than the hook width.");

echo(str("Clear inside diameter: ", clear_diameter_mm, " mm"));
echo(str("Outer diameter: ", 2 * outer_radius_mm, " mm"));
echo(str("Lowest point is directly under screw hole center at X = 0 mm"));

module ring_2d() {
    difference() {
        circle(r = outer_radius_mm);
        circle(r = inner_radius_mm);
    }
}

module c_hook_2d() {
    translate([0, ring_center_y_mm])
        difference() {
            ring_2d();
            translate([mouth_cut_x_mm, -outer_radius_mm - eps])
                square([outer_radius_mm * 2 + mount_pad_radius_mm, outer_radius_mm * 2 + (2 * eps)]);
        }
}

module hook_profile_2d() {
    union() {
        c_hook_2d();

        circle(r = mount_pad_radius_mm);

        hull() {
            circle(r = mount_pad_radius_mm);
            translate([0, web_anchor_y_mm])
                circle(r = web_thickness_mm / 2);
        }
    }
}

module hook_body() {
    linear_extrude(height = hook_width_mm, convexity = 10)
        hook_profile_2d();
}

module screw_cut() {
    translate([0, 0, -eps])
        cylinder(d = screw_shank_diameter_mm, h = hook_width_mm + (2 * eps));

    if (countersink_on_top)
        translate([0, 0, hook_width_mm - countersink_depth_mm - eps])
            cylinder(
                d1 = screw_shank_diameter_mm,
                d2 = screw_head_diameter_mm,
                h = countersink_depth_mm + eps
            );
    else
        translate([0, 0, -eps])
            cylinder(
                d1 = screw_head_diameter_mm,
                d2 = screw_shank_diameter_mm,
                h = countersink_depth_mm + eps
            );
}

module printable_hook() {
    difference() {
        hook_body();
        screw_cut();
    }
}

module installed_hook() {
    rotate([90, 0, 0])
        printable_hook();
}

if (render_mode == "print")
    printable_hook();
else if (render_mode == "installed")
    installed_hook();
else
    assert(false, "render_mode must be print or installed.");
