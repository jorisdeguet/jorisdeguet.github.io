/*
   ====================================================================
   Modular 3D-Printable Shelving System - Circular Half-Circle Module
   ====================================================================
   Author: Parametric 3D Printable Modular Shelf
   Designed for: 26cm x 26cm Print Beds & 16" Wall Stud Spacing
   
   Features:
   - Side walls made of 5 half-circles alternating:
     1. Outward (at the bottom)
     2. Inward
     3. Outward (middle)
     4. Inward
     5. Outward (at the top)
   - Parametric diameter for each half circle, determining segment & total height
   - Recomputed Width for 16-Inch 2-Block Interlocked Module Span (fits on 26x26cm bed)
   - Option for flat end walls (flat_left_wall, flat_right_wall)
   - 3 Horizontal Slits per module for Left-to-Right wall alignment adjustment
     (located at 1/4, 1/2, and 3/4 of the module height)
   ====================================================================
*/

/* [Circular Half-Circle Profile Diameters] */
// Diameter of Segment 1 (Bottom, OUTWARD half-circle) in mm
dia1 = 40.0; // [20.0:1.0:80.0]

// Diameter of Segment 2 (Lower, INWARD half-circle) in mm
dia2 = 40.0; // [20.0:1.0:80.0]

// Diameter of Segment 3 (Middle, OUTWARD half-circle) in mm
dia3 = 40.0; // [20.0:1.0:80.0]

// Diameter of Segment 4 (Upper, INWARD half-circle) in mm
dia4 = 40.0; // [20.0:1.0:80.0]

// Diameter of Segment 5 (Top, OUTWARD half-circle) in mm
dia5 = 40.0; // [20.0:1.0:80.0]

/* [16-Inch 2-Block Width Calculation] */
// Target combined width for 2 interlocked modules in inches (default 16.0")
target_2block_span_in = 16.0;

// Custom width override in inches (set to 0 for automatic calculation from 16" target)
custom_width_in = 0.0; // [0.0:0.25:16.0]

// Depth of shelf box in inches
module_depth_in = 1.0;   // [3.0:0.25:12.0]

/* [Wall Thickness & Tolerances] */
// Main wall thickness in mm
wall_thickness = 3.5;  // [2.0:0.5:6.0]

// Back wall mounting plate thickness in mm
back_thickness = 4.0;  // [2.0:0.5:8.0]

// Clearance tolerance between interlocking half-circles in mm
interlock_clearance = 0.25; // [0.1:0.05:0.5]

/* [End Wall Options] */
// Make left side wall flat (end cap for left of shelf row)
flat_left_wall = false;

// Make right side wall flat (end cap for right of shelf row)
flat_right_wall = false;

/* [Mounting & Horizontal Adjustment Slits] */
// Mounting hole style: "three_horizontal_slits" (at 1/4, 1/2, 3/4 height), "single_horizontal_slit", "none"
mount_hole_style = "three_horizontal_slits"; // [three_horizontal_slits, single_horizontal_slit, none]

// Horizontal slit adjustment width in mm (1" = 25.4mm slot)
screw_slot_width = 25.4; // [10.0:1.0:50.0]

// Screw shaft diameter in mm (#8 / M4.5 screw = 4.5mm)
screw_shaft_dia = 4.5;   // [3.0:0.5:6.0]

// Screw head diameter in mm (counterbore recess)
screw_head_dia = 9.0;    // [6.0:0.5:12.0]

/* [Print Bed & Display Options] */
// Display mode: "3d" (upright), "print_flat" (back wall down), "print_diagonal" (rotated 45 deg flat)
render_mode = "3d"; // [3d, print_flat, print_diagonal]

// Printer bed X size in mm
bed_size_x = 260;

// Printer bed Y size in mm
bed_size_y = 260;

// Curve smoothness (number of segments per 180-degree half-circle)
arc_resolution = 32;

// ====================================================================
// DERIVED CALCULATIONS & MATHEMATICAL HELPERS
// ====================================================================

// Array of all 5 diameters
diameters = [dia1, dia2, dia3, dia4, dia5];

// Cumulative height helper function
function get_cum_z(dias, idx) = 
    (idx <= 0) ? 0 : dias[idx-1] + get_cum_z(dias, idx-1);

// Total Module Height derived from the sum of all 5 half-circle diameters
H = dia1 + dia2 + dia3 + dia4 + dia5;
module_height_in = H / 25.4;

// Module Width W: so 2 interlocked modules span 16 inches (406.4 mm)
span_2block_mm = target_2block_span_in * 25.4;
W = (custom_width_in > 0) ? (custom_width_in * 25.4) : (span_2block_mm / 2);
module_width_in = W / 25.4;

D = module_depth_in * 25.4;

// Display diagnostic information in OpenSCAD console
echo("=================================================");
echo(str("CIRCULAR HALF-CIRCLE MODULE PROFILE"));
echo(str("DIAMETERS: [1: Bottom Out=", dia1, "mm, 2: In=", dia2, "mm, 3: Mid Out=", dia3, "mm, 4: In=", dia4, "mm, 5: Top Out=", dia5, "mm]"));
echo(str("TOTAL HEIGHT: H = ", H, " mm (", module_height_in, " inches)"));
echo(str("SINGLE MODULE WIDTH: W = ", W, " mm (", module_width_in, " inches)"));
echo(str("2-BLOCK INTERLOCKED SPAN: ", target_2block_span_in, "\" (", span_2block_mm, " mm)"));
echo(str("PRINT BED FIT (260x260mm): Flat width = ", W, "mm, Flat height = ", H, "mm"));
if (H <= bed_size_y && W <= bed_size_x) {
    echo("-> FIT STATUS: DIRECT FLAT FIT on 26cm x 26cm bed!");
} else {
    echo("-> FIT STATUS: DIAGONAL / STANDING FIT required for 26cm bed");
}
echo("=================================================");

// Generate 2D outer boundary points for circular half-circle profile
// Sequence: 1: Outward (+), 2: Inward (-), 3: Outward (+), 4: Inward (-), 5: Outward (+)
function outer_circ_profile(W, dias, clr=0, flat_l=false, flat_r=false, n_steps=32) =
    let (
        local_H = dias[0] + dias[1] + dias[2] + dias[3] + dias[4],
        signs = [1, -1, 1, -1, 1] // Outward (+1), Inward (-1), Outward (+1), Inward (-1), Outward (+1)
    )
    concat(
        // 1. Bottom flat edge (left to right from 0 to W - clr)
        [ [ 0, 0 ], [ W - clr, 0 ] ],
        
        // 2. Right side wall (5 half-circles going up from Z=0 to Z=H)
        flat_r ? [ [ W - clr, local_H ] ] :
        [ for (i = [0 : 4]) 
            let (
                d = dias[i],
                r = d / 2,
                z_base = get_cum_z(dias, i),
                z_c = z_base + r,
                s = signs[i]
            )
            for (step = [0 : n_steps])
                let (
                    ang = -90 + step * 180 / n_steps,
                    z = z_c + r * sin(ang),
                    dx = s * r * cos(ang)
                )
                [ W - clr + dx, z ]
        ],
        
        // 3. Top flat edge (right to left from W - clr to 0)
        [ [ 0, local_H ] ],
        
        // 4. Left side wall (5 half-circles going down from Z=H to Z=0)
        flat_l ? [ [ 0, 0 ] ] :
        [ for (i = [4 : -1 : 0])
            let (
                d = dias[i],
                r = d / 2,
                z_base = get_cum_z(dias, i),
                z_c = z_base + r,
                s = signs[i]
            )
            for (step = [n_steps : -1 : 0])
                let (
                    ang = -90 + step * 180 / n_steps,
                    z = z_c + r * sin(ang),
                    dx = s * r * cos(ang)
                )
                [ -dx, z ]
        ]
    );

// Horizontal Slit Cutter module (enables left-to-right alignment adjustment)
module horizontal_slit_cutter(x, z, shaft_d, head_d, slot_w, wall_t) {
    translate([x, -0.1, z])
    rotate([-90, 0, 0])
    union() {
        // Main slot for screw shaft (left-to-right slide)
        hull() {
            translate([-slot_w/2, 0, 0])
                cylinder(d = shaft_d + 0.3, h = wall_t + 0.5, $fn = 32);
            translate([slot_w/2, 0, 0])
                cylinder(d = shaft_d + 0.3, h = wall_t + 0.5, $fn = 32);
        }
        // Counterbore recess for screw head / washer to sit flush
        hull() {
            translate([-slot_w/2, 0, -0.1])
                cylinder(d = head_d + 0.5, h = wall_t/2 + 0.1, $fn = 32);
            translate([slot_w/2, 0, -0.1])
                cylinder(d = head_d + 0.5, h = wall_t/2 + 0.1, $fn = 32);
        }
    }
}

// Single Circular Module Geometry Generator
// Coordinates: X = Width [0 to W], Y = Depth [0 to D], Z = Height [0 to H]
module circular_module(
    width_in = 0,
    depth_in = module_depth_in,
    dias = diameters,
    wall_t = wall_thickness,
    back_t = back_thickness,
    flat_l = flat_left_wall,
    flat_r = flat_right_wall,
    clr = interlock_clearance,
    mount_style = mount_hole_style,
    slot_w = screw_slot_width,
    steps = arc_resolution
) {
    local_H = dias[0] + dias[1] + dias[2] + dias[3] + dias[4];
    local_W = (width_in > 0) ? (width_in * 25.4) : (target_2block_span_in * 25.4 / 2);
    local_D = depth_in * 25.4;
    
    pts = outer_circ_profile(local_W, dias, clr, flat_l, flat_r, steps);
    
    difference() {
        union() {
            // Main extruded hollow box shell (extrude along Y from 0 to local_D)
            rotate([90, 0, 0])
            translate([0, 0, -local_D])
            linear_extrude(height = local_D) {
                difference() {
                    polygon(pts);
                    offset(delta = -wall_t) polygon(pts);
                }
            }
            
            // Back wall mounting plate (at Y=0, thickness back_t)
            rotate([90, 0, 0])
            translate([0, 0, -back_t])
            linear_extrude(height = back_t) {
                polygon(pts);
            }
        }
        
        // Mounting Cutouts (Horizontal Slits)
        if (mount_style == "three_horizontal_slits") {
            // Slit 1 at 1/4 (25%) height
            horizontal_slit_cutter(local_W / 2, local_H * 0.25, screw_shaft_dia, screw_head_dia, slot_w, back_t);
            // Slit 2 at middle (50%) height
            horizontal_slit_cutter(local_W / 2, local_H * 0.50, screw_shaft_dia, screw_head_dia, slot_w, back_t);
            // Slit 3 at 3/4 (75%) height
            horizontal_slit_cutter(local_W / 2, local_H * 0.75, screw_shaft_dia, screw_head_dia, slot_w, back_t);
        } else if (mount_style == "single_horizontal_slit") {
            horizontal_slit_cutter(local_W / 2, local_H * 0.50, screw_shaft_dia, screw_head_dia, slot_w, back_t);
        }
    }
}

// Render according to selected mode
if (render_mode == "3d") {
    circular_module();
} else if (render_mode == "print_flat") {
    // Rotated flat on back plate (Y=0 becomes Z=0)
    rotate([-90, 0, 0])
    circular_module();
} else if (render_mode == "print_diagonal") {
    // Rotated 45 degrees flat on build bed for maximum diagonal fit
    rotate([0, 0, 45])
    rotate([-90, 0, 0])
    circular_module();
}
