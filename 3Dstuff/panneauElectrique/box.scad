// =============================================================================
// FDM Printable Box with Rounded Corners
// Designed for jorisdeguet/jorisdeguet.github.io
// =============================================================================
// This model is optimized for 3D printing on an FDM printer with a 26cm cubic
// build volume.
//
// ORIENTATION NOTE:
// - When INSTALLED, the box opening faces FRONT.
// - When MODELLED & PRINTED, the opening faces UPWARD (along the Z-axis).
//   This allows printing the box without any support material, as the bottom
//   of the box (back wall when installed) rests flat on the print bed.
//
// DIMENSION MAPPING:
// - Model X-axis = Installed Width (default: 230 mm / 23 cm)
// - Model Y-axis = Installed Height (default: 230 mm / 23 cm)
// - Model Z-axis = Installed Depth (default: 170 mm / 17 cm)
// =============================================================================

/* [Box Dimensions] */

// Width of the box opening (installed horizontal width, model X-axis)
width = 230; // [50:1:300]

// Height of the box opening (installed vertical height, model Y-axis)
height = 230; // [50:1:300]

// Depth of the box (installed front-to-back depth, model Z-axis)
depth = 140; // [50:1:300]

/* [Wall & Corners] */

// Wall thickness of the side walls (in mm)
wall_thickness = 12.0; // [1.0:0.1:30.0]

// Wall thickness of the back wall (the bottom on the print bed, in mm)
back_wall_thickness = 1.0; // [1.0:0.1:30.0]

// Corner radius of the opening and outer walls (in mm)
corner_radius = 30.0; // [0.0:0.5:50.0]

// Thickness of the square outer section at the back of the box (in mm, 50mm = 5cm)
square_thickness = 30.0; // [0.0:1.0:200.0]

/* [Printer Options] */

// Maximum print volume dimension of your FDM printer (default: 260mm / 26cm)
max_print_volume = 260; // [100:1:500]

// Smoothness of circles (higher = smoother, lower = faster render)
$fn = 100; // [12:4:200]

// =============================================================================
// Safety Capping & Calculations
// =============================================================================

// Cap the corner radius to half of the smallest dimension to prevent self-intersection
max_safe_radius = min(width, height) / 2;
effective_radius = min(corner_radius, max_safe_radius);

// =============================================================================
// Assertions & Warnings
// =============================================================================

// Ensure dimensions fit the printer's build volume
assert(width <= max_print_volume, str("Error: Box width (", width, "mm) exceeds printer max volume (", max_print_volume, "mm)!"));
assert(height <= max_print_volume, str("Error: Box height (", height, "mm) exceeds printer max volume (", max_print_volume, "mm)!"));
assert(depth <= max_print_volume, str("Error: Box depth (", depth, "mm) exceeds printer max volume (", max_print_volume, "mm)!"));

// Ensure thickness is valid
assert(wall_thickness > 0, "Error: Wall thickness must be greater than 0!");
assert(back_wall_thickness > 0, "Error: Back wall thickness must be greater than 0!");
assert(back_wall_thickness < depth, "Error: Back wall thickness cannot exceed the total box depth!");
assert(width > 2 * wall_thickness, "Error: Wall thickness is too large for the given width!");
assert(height > 2 * wall_thickness, "Error: Wall thickness is too large for the given height!");
assert(square_thickness >= 0, "Error: Square thickness must be 0 or positive!");
assert(square_thickness <= depth, "Error: Square thickness cannot exceed the total box depth!");

// Print confirmation to console
echo("=================================================");
echo(str("Printing Box Dimensions: ", width, "x", height, "x", depth, " mm"));
echo(str("Wall Thickness (Sides): ", wall_thickness, " mm"));
echo(str("Back Wall Thickness: ", back_wall_thickness, " mm"));
echo(str("Corner Radius: ", effective_radius, " mm"));
echo(str("Square Section Thickness: ", square_thickness, " mm"));
echo("=================================================");

// =============================================================================
// 2D Profile Helper Module
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
// Main Box Geometry
// =============================================================================
module printable_box() {
    difference() {
        // 1. Outer Box Solid
        union() {
            // Bottom square section (from Z = 0 to square_thickness)
            if (square_thickness > 0) {
                linear_extrude(height = min(square_thickness, depth)) {
                    rounded_rect_profile(width, height, 0); // r = 0 means sharp corners
                }
            }
            
            // Top rounded section (from Z = square_thickness to depth)
            if (depth > square_thickness) {
                translate([0, 0, square_thickness]) {
                    linear_extrude(height = depth - square_thickness) {
                        rounded_rect_profile(width, height, effective_radius);
                    }
                }
            }
        }
        
        // 2. Inner Hollow Cutout
        // Shift up by back_wall_thickness along Z to keep a solid back/bottom
        translate([0, 0, back_wall_thickness]) {
            linear_extrude(height = depth) {
                offset(delta = -wall_thickness) {
                    rounded_rect_profile(width, height, effective_radius);
                }
            }
        }
    }
}

// Render the box
printable_box();
