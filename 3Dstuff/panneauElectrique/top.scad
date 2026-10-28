// =============================================================================
// FDM Printable Box - Front Complement (Top Piece)
// Designed for jorisdeguet/jorisdeguet.github.io
// =============================================================================
// This model generates a complement piece to complete the front of a box
// that stopped printing in the middle. It includes an alignment sleeve that
// fits inside the existing printed section to act as a gluing surface.
//
// ORIENTATION NOTE:
// - Standard orientation: modeled in the same coordinate system as box.scad.
// - Print orientation (default): rotated upside down so the flat front opening
//   rests flat on the print bed. This allows printing without any support
//   material!
// =============================================================================

/* [Box Dimensions] */

// Width of the box opening (installed horizontal width, model X-axis)
width = 230; // [50:1:300]

// Height of the box opening (installed vertical height, model Y-axis)
height = 230; // [50:1:300]

// Full depth of the original box (installed front-to-back depth, model Z-axis)
depth = 160; // [50:1:300]

/* [Wall & Corners] */

// Wall thickness of the side walls (in mm)
wall_thickness = 12.0; // [1.0:0.1:30.0]

// Corner radius of the opening and outer walls (in mm)
corner_radius = 30.0; // [0.0:0.5:50.0]

// Thickness of the square outer section at the back of the box (in mm)
square_thickness = 50.0; // [0.0:1.0:200.0]

/* [Complement Options] */

// Height/depth of the complement piece to print (excluding the sleeve, in mm)
complement_depth = 50.0; // [5.0:0.1:300.0]

/* [Sleeve & Glue Surface] */

// Height of the alignment sleeve (how far it projects into the existing part, in mm)
sleeve_height = 10.0; // [0.0:0.5:50.0]

// Wall thickness of the alignment sleeve (in mm)
sleeve_thickness = 2.0; // [0.5:0.1:15.0]

// Clearance/gap between the sleeve and the printed box's inner walls (in mm)
sleeve_clearance = 0.3; // [0.0:0.05:2.0]

// Height of the internal chamfer transition (in mm) for support-less printing
sleeve_chamfer_height = 8.0; // [0.0:0.5:10.0]

/* [Printer Options] */

// Orientation for printing: places the flat front face on the print bed.
// Set to 'true' to print without support material.
print_upside_down = true;

// Smoothness of circles (higher = smoother, lower = faster render)
$fn = 100; // [12:4:200]

// =============================================================================
// Safety Capping & Calculations
// =============================================================================

// Cap the corner radius to half of the smallest dimension to prevent self-intersection
max_safe_radius = min(width, height) / 2;
effective_radius = min(corner_radius, max_safe_radius);

// Cap the chamfer height so it doesn't exceed the complement depth
effective_chamfer_height = (sleeve_height > 0 && sleeve_thickness > 0) ? min(sleeve_chamfer_height, complement_depth) : 0;

// =============================================================================
// Assertions & Warnings
// =============================================================================

assert(width > 0, "Error: Width must be positive!");
assert(height > 0, "Error: Height must be positive!");
assert(depth > 0, "Error: Depth must be positive!");
assert(wall_thickness > 0, "Error: Wall thickness must be greater than 0!");
assert(width > 2 * wall_thickness, "Error: Wall thickness is too large for the given width!");
assert(height > 2 * wall_thickness, "Error: Wall thickness is too large for the given height!");

assert(complement_depth > 0, "Error: Complement depth must be greater than 0!");
assert(complement_depth <= depth, "Error: Complement depth cannot exceed the total box depth!");

assert(sleeve_height >= 0, "Error: Sleeve height must be 0 or positive!");
assert(sleeve_thickness > 0, "Error: Sleeve thickness must be greater than 0!");
assert(sleeve_thickness + sleeve_clearance < wall_thickness, "Error: Sleeve thickness + clearance must be less than the box wall thickness!");
assert(sleeve_clearance >= 0, "Error: Sleeve clearance must be 0 or positive!");
assert(sleeve_chamfer_height >= 0, "Error: Sleeve chamfer height must be 0 or positive!");

// Print confirmation to console
echo("=================================================");
echo(str("Printing Complement Dimensions: ", width, "x", height, "x", complement_depth, " mm"));
echo(str("Wall Thickness (Sides): ", wall_thickness, " mm"));
echo(str("Sleeve Height: ", sleeve_height, " mm"));
echo(str("Sleeve Thickness: ", sleeve_thickness, " mm"));
echo(str("Sleeve Clearance: ", sleeve_clearance, " mm"));
echo(str("Sleeve Chamfer Height: ", effective_chamfer_height, " mm"));
echo(str("Print Orientation: ", print_upside_down ? "Upside Down (Recommended, support-less)" : "Normal"));
echo("=================================================");

// =============================================================================
// 2D Profile Helper Module (identical to box.scad)
// =============================================================================
module rounded_rect_profile(w, h, r) {
    if (r > 0) {
        offset(r = r) {
            square([w - 2 * r, h - 2 * r], center = true);
        }
    } else {
        square([w, h], center = true);
    }
}

// =============================================================================
// Main Complement Solid Shapes
// =============================================================================

module complement_outer_solid() {
    // The complement piece spans from original Z = (depth - complement_depth) to Z = depth.
    // In local coordinates: local Z = 0 is original Z = (depth - complement_depth).
    // Let's compute the height of the square section within our complement piece.
    // The original square section ends at original Z = square_thickness.
    local_square_height = min(complement_depth, max(0, square_thickness - (depth - complement_depth)));
    local_rounded_height = complement_depth - local_square_height;
    
    union() {
        // 1. Square section (if any)
        if (local_square_height > 0) {
            linear_extrude(height = local_square_height) {
                rounded_rect_profile(width, height, 0);
            }
        }
        
        // 2. Rounded section (if any)
        if (local_rounded_height > 0) {
            translate([0, 0, local_square_height]) {
                linear_extrude(height = local_rounded_height) {
                    rounded_rect_profile(width, height, effective_radius);
                }
            }
        }
    }
}

module sleeve_outer_solid() {
    if (sleeve_height > 0) {
        translate([0, 0, -sleeve_height]) {
            linear_extrude(height = sleeve_height) {
                offset(delta = -wall_thickness - sleeve_clearance) {
                    rounded_rect_profile(width, height, effective_radius);
                }
            }
        }
    }
}

// =============================================================================
// Main Complement Inner Cutouts
// =============================================================================

module complement_inner_cutout() {
    // 1. Sleeve hollow (from local Z = -sleeve_height - 0.1 to local Z = 0)
    if (sleeve_height > 0) {
        translate([0, 0, -sleeve_height - 0.1]) {
            linear_extrude(height = sleeve_height + 0.1) {
                offset(delta = -wall_thickness - sleeve_clearance - sleeve_thickness) {
                    rounded_rect_profile(width, height, effective_radius);
                }
            }
        }
    }
    
    // 2. Chamfer transition (from local Z = 0 to local Z = effective_chamfer_height)
    if (effective_chamfer_height > 0) {
        chamfer_steps = 20;
        for (i = [0 : chamfer_steps - 1]) {
            translate([0, 0, i * effective_chamfer_height / chamfer_steps]) {
                linear_extrude(height = effective_chamfer_height / chamfer_steps + 0.05) {
                    t = i / (chamfer_steps - 1);
                    current_delta = (-wall_thickness - sleeve_clearance - sleeve_thickness) * (1 - t) + (-wall_thickness) * t;
                    offset(delta = current_delta) {
                        rounded_rect_profile(width, height, effective_radius);
                    }
                }
            }
        }
    }
    
    // 3. Main body hollow (from local Z = effective_chamfer_height to local Z = complement_depth + 0.1)
    translate([0, 0, effective_chamfer_height]) {
        linear_extrude(height = complement_depth - effective_chamfer_height + 0.1) {
            offset(delta = -wall_thickness) {
                rounded_rect_profile(width, height, effective_radius);
            }
        }
    }
}

// =============================================================================
// Main Complement Assembly
// =============================================================================

module complement_piece() {
    difference() {
        union() {
            complement_outer_solid();
            sleeve_outer_solid();
        }
        complement_inner_cutout();
    }
}

// =============================================================================
// Render Configuration
// =============================================================================

if (print_upside_down) {
    // Place front face of box on the print bed (Z = 0) for support-less printing
    translate([0, 0, complement_depth]) {
        rotate([180, 0, 0]) {
            complement_piece();
        }
    }
} else {
    // Standard orientation (matching original box coordinate space)
    complement_piece();
}
