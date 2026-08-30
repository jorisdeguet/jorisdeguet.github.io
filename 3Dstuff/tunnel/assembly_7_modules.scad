/*
   ====================================================================
   Modular 3D-Printable Shelving System - 7-Module Assembly & Stud Mount
   ====================================================================
   Author: Parametric 7-Module Assembly with Wall Stud Anchoring
   Designed for: 26cm x 26cm Print Beds & 16" Wall Stud Spacing
   
   Features:
   - Recomputed width W = (16" + tooth_depth + clearance) / 2 = 208.325mm
     so every 2 interlocked blocks span EXACTLY 16 inches!
   - Alternating modules offset by half a tooth height (Z_shift = tooth_height / 2)
     so key-teeth mesh together snugly side-by-side!
   - Anchored on 16" wall studs via 3 horizontal adjustment slits per stud module
   - Module 1 has flat left wall (left end cap)
   - Module 7 has flat right wall (right end cap)
   ====================================================================
*/

use <single_module.scad>

/* [Key-Teeth Profile & 16" 2-Block Settings] */
// Target combined width for 2 interlocked modules in inches (default 16.0")
target_2block_span_in = 16.0;

// Number of key teeth along side wall (integer divider of side height)
num_teeth = 4;         // [2:1:10]

// Height of each tooth in mm
tooth_height = 26.0;   // [15.0:1.0:40.0]

// Inward depth of each key tooth in mm (45-degree angle -> ramp height = depth)
tooth_depth = 10.0;    // [4.0:1.0:20.0]

// Module depth in inches
common_depth_in = 3.0;   // [4.0:0.25:12.0]

/* [Corner Bevel & Interlock Options] */
// Size of 4 corner chamfers/bevels in mm
corner_bevel_size = 20.0; // [5.0:1.0:40.0]

// Interlock clearance tolerance in mm
interlock_clr = 0.25;

// Horizontal slit width in mm for left-right adjustment
slot_width = 25.4;

/* [Wall Stud & Anchoring Settings] */
// Wall stud center-to-center spacing in inches
stud_spacing_in = 16.0;

// Standard 2x4 stud face width (1.5 inches)
stud_width_in = 1.5;

// Visual stud height in inches
stud_height_in = 18.0;

// Render 16" wall studs behind modules
show_studs = true;

// Render anchoring screws into studs
show_screws = true;

// Render translucent drywall background
show_wall = true;

// ====================================================================
// DERIVED CALCULATIONS & RENDERING
// ====================================================================

// Calculate uniform module height derived from teeth count and corner bevels
h_wall = num_teeth * tooth_height;
module_height_mm = 2 * corner_bevel_size + h_wall;

// Recalculated single module width W in mm so 2 interlocked blocks span exactly 16 inches (406.4 mm)
span_2block_mm = target_2block_span_in * 25.4;
W = (span_2block_mm + tooth_depth + interlock_clr) / 2; // 208.325 mm
common_width_in = W / 25.4;

// Half-tooth Z offset for alternating modules (indices 1, 3, 5)
z_half_tooth = tooth_height / 2;

// Color palette for the 7 modules for distinct visualization
module_colors = [
    [0.25, 0.55, 0.85], // Teal / Blue
    [0.90, 0.45, 0.25], // Terracotta / Orange
    [0.35, 0.70, 0.45], // Emerald Green
    [0.85, 0.65, 0.20], // Warm Gold
    [0.60, 0.40, 0.75], // Purple
    [0.85, 0.35, 0.50], // Rose
    [0.20, 0.65, 0.75]  // Cyan
];

// Conversions to mm
D = common_depth_in * 25.4;
stud_spacing = stud_spacing_in * 25.4;
stud_w = stud_width_in * 25.4;
stud_h = stud_height_in * 25.4;

// Render 16" Wooden Wall Studs
module render_studs() {
    start_x = W / 2;
    
    for (s = [0 : 3]) {
        // Studs positioned at 0", 16", 32", 48" intervals
        stud_x = s * stud_spacing + W / 2;
        
        // Wooden 2x4 Stud (1.5" x 3.5" x height)
        color([0.72, 0.53, 0.35, 1.0]) {
            translate([stud_x - stud_w / 2, -3.5 * 25.4, - (stud_h - module_height_mm)/2])
                cube([stud_w, (3.5 - 0.5) * 25.4, stud_h]);
        }
        
        // Screws anchoring into studs through the 3 horizontal adjustment slits
        if (show_screws) {
            mod_idx = s * 2;
            local_h = module_height_mm;
            mod_z_shift = (mod_idx % 2 == 1) ? z_half_tooth : 0;
            
            // 3 screws per stud corresponding to the 3 slits
            slit_ratios = [0.25, 0.50, 0.75];
            
            for (r = slit_ratios) {
                screw_z = mod_z_shift + local_h * r;
                
                color([0.85, 0.85, 0.90]) {
                    translate([stud_x, 10, screw_z])
                    rotate([90, 0, 0])
                    union() {
                        cylinder(d = 4.5, h = 60, $fn = 20);
                        translate([0, 0, -2])
                            cylinder(d1 = 4.5, d2 = 9.0, h = 3.0, $fn = 20);
                    }
                }
            }
        }
    }
}

// Render Drywall Wall Panel Background
module render_wall() {
    color([0.85, 0.85, 0.82, 0.70]) {
        translate([-W/2, -0.5 * 25.4, - (stud_h - module_height_mm)/2])
            cube([8 * W, 0.5 * 25.4, stud_h]);
    }
}

// Render 7 Interlocking Modules with Half-Tooth Z Offset for Alternating Modules
module render_7_modules() {
    for (i = [0 : 6]) {
        // Horizontal X position taking interlock tooth overlap into account
        x_pos = i * (W - tooth_depth);
        
        // Vertical Z offset by half a tooth height for alternating modules (1 out of 2)
        z_pos = (i % 2 == 1) ? z_half_tooth : 0;
        
        // Module 1 (far left): flat left side wall
        // Module 7 (far right): flat right side wall
        is_left_end = (i == 0);
        is_right_end = (i == 6);
        
        translate([x_pos, 0, z_pos])
        color(module_colors[i])
        single_module(
            width_in = common_width_in,
            depth_in = common_depth_in,
            n_teeth = num_teeth,
            t_h = tooth_height,
            t_d = tooth_depth,
            wall_t = 3.5,
            back_t = 4.0,
            bevel = corner_bevel_size,
            flat_l = is_left_end,
            flat_r = is_right_end,
            clr = interlock_clr,
            mount_style = "three_horizontal_slits",
            slot_w = slot_width
        );
    }
}

// ====================================================================
// MAIN SCENE ASSEMBLY
// ====================================================================

// Render 7 Modules
render_7_modules();

// Render Studs & Wall behind modules
if (show_studs) render_studs();
if (show_wall) render_wall();
