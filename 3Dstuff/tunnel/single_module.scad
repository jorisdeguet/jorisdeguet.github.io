/*
   ====================================================================
   Modular 3D-Printable Shelving System - Single Module
   ====================================================================
   Author: Parametric 3D Printable Modular Shelf
   Designed for: 26cm x 26cm Print Beds & 16" Wall Stud Spacing
   
   Features:
   - Recomputed Width for 16-Inch 2-Block Interlocked Module Span
     Single Width W = (16" + tooth_depth + clearance) / 2 = 208.325mm (8.20")
     Fits easily flat on 26cm x 26cm print beds
   - Key-Tooth Side Profile: Straight 45-degree angled ramps with flat lands
   - Parameterable Number of Teeth (`num_teeth`) which divides side height
   - Convex polygon frame with 4 corner chamfers (octagonal end caps)
   - Option for flat end walls (`flat_left_wall`, `flat_right_wall`)
   - 3 Horizontal Slits per module for Left-to-Right wall adjustment
     (located at 1/4, 1/2, and 3/4 of the module height)
   ====================================================================
*/

/* [Key-Teeth Profile Parameters] */
// Number of key teeth along side wall (integer divider of side height)
num_teeth = 5;         // [2:1:10]

// Height of each tooth in mm
tooth_height = 26.0;   // [15.0:1.0:40.0]

// Inward depth of each key tooth in mm (45-degree angle -> ramp height = depth)
tooth_depth = 10.0;    // [4.0:1.0:20.0]

/* [16-Inch 2-Block Width Calculation] */
// Target combined width for 2 interlocked modules in inches (default 16.0")
target_2block_span_in = 16.0;

// Size of 4 corner chamfers/bevels in mm
corner_bevel_size = 20.0; // [5.0:1.0:40.0]

// Depth of shelf box in inches
module_depth_in = 6.0;   // [4.0:0.25:12.0]

/* [Wall Thickness & Details] */
// Main wall thickness in mm
wall_thickness = 3.5;  // [2.0:0.5:6.0]

// Back wall mounting plate thickness in mm
back_thickness = 4.0;  // [2.0:0.5:8.0]

// Clearance tolerance between interlocking teeth in mm (0.2-0.3mm snug fit)
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

// ====================================================================
// DERIVED CALCULATIONS & MATHEMATICAL HELPERS
// ====================================================================

// Total side wall height (divided by num_teeth)
h_wall = num_teeth * tooth_height;

// Total Module Height derived from teeth count and corner bevels
H = 2 * corner_bevel_size + h_wall;
module_height_in = H / 25.4;

// Recalculated module width W so 2 interlocked blocks span exactly 16 inches (406.4 mm)
span_2block_mm = target_2block_span_in * 25.4;
W = (span_2block_mm + tooth_depth + interlock_clearance) / 2;
module_width_in = W / 25.4;

D = module_depth_in * 25.4;

// Display diagnostic information in OpenSCAD console
echo("=================================================");
echo(str("2-BLOCK SPAN TARGET: ", target_2block_span_in, "\" (", span_2block_mm, " mm)"));
echo(str("RECOMPUTED SINGLE MODULE WIDTH: W = ", W, " mm (", module_width_in, " inches)"));
echo(str("KEY TEETH METRICS: Teeth Count = ", num_teeth, ", Tooth Height = ", tooth_height, " mm, 45-Deg Ramp = ", tooth_depth, " mm"));
echo(str("MODULE DIMENSIONS: ", module_width_in, "\" W x ", module_height_in, "\" H (", H, "mm) x ", module_depth_in, "\" D"));
echo(str("PRINT BED FIT (260x260mm): Flat width = ", W, "mm, Flat height = ", H, "mm"));
if (H <= bed_size_y && W <= bed_size_x) {
    echo("-> FIT STATUS: DIRECT FLAT FIT on 26cm x 26cm bed!");
} else {
    echo("-> FIT STATUS: DIAGONAL / STANDING FIT required for 26cm bed");
}
echo("=================================================");

// Generate 2D outer boundary points for key-tooth profile (straight 45-deg angles)
function outer_profile(W, H, bevel, n_teeth, t_h, depth, clr, flat_l=false, flat_r=false) =
    let (
        z_b = bevel,
        z_t = H - bevel,
        ramp = min(depth, t_h / 2)
    )
    concat(
        // 1. Bottom flat edge (left to right)
        [ [ bevel, 0 ] ],
        [ [ W - bevel - clr, 0 ] ],
        
        // 2. Bottom-right chamfer
        [ [ W - clr, z_b ] ],
        
        // 3. Right side wall (key teeth going up)
        flat_r ? [ [ W - clr, z_t ] ] :
        [ for (k = [0 : n_teeth - 1]) for (pt = [
            [ W - clr, z_b + k * t_h ],
            [ W - ramp - clr, z_b + k * t_h + ramp ],
            [ W - ramp - clr, z_b + (k + 1) * t_h - ramp ],
            [ W - clr, z_b + (k + 1) * t_h ]
        ]) pt ],
        
        // 4. Top-right chamfer
        [ [ W - bevel - clr, H ] ],
        
        // 5. Top flat edge (right to left)
        [ [ bevel, H ] ],
        
        // 6. Top-left chamfer
        [ [ 0, z_t ] ],
        
        // 7. Left side wall (key teeth going down)
        flat_l ? [ [ 0, z_b ] ] :
        [ for (k = [n_teeth - 1 : -1 : 0]) for (pt = [
            [ 0, z_b + (k + 1) * t_h ],
            [ ramp, z_b + (k + 1) * t_h - ramp ],
            [ ramp, z_b + k * t_h + ramp ],
            [ 0, z_b + k * t_h ]
        ]) pt ]
    );

// Generate 2D inner cavity boundary points in [X, Z] plane
function inner_profile(W, H, wall, bevel, n_teeth, t_h, depth, clr, flat_l=false, flat_r=false) =
    let (
        z_b = bevel,
        z_t = H - bevel,
        ramp = min(depth, t_h / 2)
    )
    concat(
        // 1. Inner bottom flat edge
        [ [ bevel + wall/2, wall ] ],
        [ [ W - bevel - wall/2 - clr, wall ] ],
        
        // 2. Inner bottom-right chamfer
        [ [ W - wall - clr, z_b + wall/2 ] ],
        
        // 3. Inner right side wall
        flat_r ? [ [ W - wall - clr, z_t - wall/2 ] ] :
        [ for (k = [0 : n_teeth - 1]) for (pt = [
            [ W - wall - clr, z_b + k * t_h + wall/2 ],
            [ W - wall - ramp - clr, z_b + k * t_h + ramp + wall/2 ],
            [ W - wall - ramp - clr, z_b + (k + 1) * t_h - ramp - wall/2 ],
            [ W - wall - clr, z_b + (k + 1) * t_h - wall/2 ]
        ]) pt ],
        
        // 4. Inner top-right chamfer
        [ [ W - bevel - wall/2 - clr, H - wall ] ],
        
        // 5. Inner top flat edge
        [ [ bevel + wall/2, H - wall ] ],
        
        // 6. Inner top-left chamfer
        [ [ wall, z_t - wall/2 ] ],
        
        // 7. Inner left side wall
        flat_l ? [ [ wall, z_b + wall/2 ] ] :
        [ for (k = [n_teeth - 1 : -1 : 0]) for (pt = [
            [ wall, z_b + (k + 1) * t_h - wall/2 ],
            [ wall + ramp, z_b + (k + 1) * t_h - ramp - wall/2 ],
            [ wall + ramp, z_b + k * t_h + ramp + wall/2 ],
            [ wall, z_b + k * t_h + wall/2 ]
        ]) pt ]
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

// Single Module Geometry Generator (X = Width, Y = Depth [0 to D], Z = Height [0 to H])
module single_module(
    width_in = module_width_in,
    depth_in = module_depth_in,
    n_teeth = num_teeth,
    t_h = tooth_height,
    t_d = tooth_depth,
    wall_t = wall_thickness,
    back_t = back_thickness,
    bevel = corner_bevel_size,
    flat_l = flat_left_wall,
    flat_r = flat_right_wall,
    clr = interlock_clearance,
    mount_style = mount_hole_style,
    slot_w = screw_slot_width
) {
    local_h_wall = n_teeth * t_h;
    local_H = 2 * bevel + local_h_wall;
    
    // Width derived from 16-inch 2-block span equation if width_in is omitted
    local_W = (width_in > 0) ? (width_in * 25.4) : ((target_2block_span_in * 25.4 + t_d + clr) / 2);
    local_D = depth_in * 25.4;
    
    difference() {
        union() {
            // Main extruded hollow shell box (extrude along Y from 0 to local_D)
            rotate([90, 0, 0])
            translate([0, 0, -local_D])
            linear_extrude(height = local_D) {
                difference() {
                    polygon(outer_profile(local_W, local_H, bevel, n_teeth, t_h, t_d, clr, flat_l, flat_r));
                    polygon(inner_profile(local_W, local_H, wall_t, bevel, n_teeth, t_h, t_d, clr, flat_l, flat_r));
                }
            }
            
            // Back wall plate (at Y=0, thickness back_t)
            rotate([90, 0, 0])
            translate([0, 0, -back_t])
            linear_extrude(height = back_t) {
                polygon(outer_profile(local_W, local_H, bevel, n_teeth, t_h, t_d, clr, flat_l, flat_r));
            }
        }
        
        // Mounting Cutouts (3 Horizontal Slits: 1/4, 1/2, 3/4 height)
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
    single_module();
} else if (render_mode == "print_flat") {
    // Rotated flat on back plate (Y=0 becomes Z=0)
    rotate([-90, 0, 0])
    single_module();
} else if (render_mode == "print_diagonal") {
    // Rotated 45 degrees flat on build bed for maximum diagonal fit
    rotate([0, 0, 45])
    rotate([-90, 0, 0])
    single_module();
}
