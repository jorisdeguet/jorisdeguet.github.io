/*
   ====================================================================
   Modular 3D-Printable Shelving System - 7-Module Assembly & Stud Mount
   ====================================================================
   Author: Parametric 7-Module Circular Half-Circle Assembly with Wall Studs
   Designed for: 26cm x 26cm Print Beds & 16" Wall Stud Spacing
   
   Features:
   - Module side walls formed by 5 half-circles:
     (1: Outward bottom, 2: Inward, 3: Outward mid, 4: Inward, 5: Outward top)
   - Module width W = 16" / 2 = 203.2 mm so every 2 modules span EXACTLY 16 inches!
   - Alternating modules offset vertically by 1 diameter (Z_shift = dia1)
     so half-circles mesh together snugly and continuously side-by-side!
   - Anchored on 16" wall studs via 3 horizontal adjustment slits per stud module
   - Module 1 (far left) has flat left wall (left end cap)
   - Module 7 (far right) has flat right wall (right end cap)
   ====================================================================
*/

use <circular_module.scad>

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

/* [16-Inch 2-Block Settings & Dimensions] */
// Target combined width for 2 interlocked modules in inches (default 16.0")
target_2block_span_in = 16.0;

// Module depth in inches
common_depth_in = 3.0;   // [3.0:0.25:12.0]

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

diameters = [dia1, dia2, dia3, dia4, dia5];

// Calculate module height derived from sum of 5 half-circle diameters
module_height_mm = dia1 + dia2 + dia3 + dia4 + dia5;

// Single module width W in mm so 2 interlocked blocks span exactly 16 inches (406.4 mm)
span_2block_mm = target_2block_span_in * 25.4;
W = span_2block_mm / 2; // 203.2 mm (8.0 inches)
common_width_in = W / 25.4;

// 1-diameter vertical offset for alternating modules (indices 1, 3, 5)
z_shift = dia1;

// Color palette for the 7 modules for distinct visualization
module_colors = [
    [0.25, 0.55, 0.85], // 1: Teal / Blue
    [0.90, 0.45, 0.25], // 2: Terracotta / Orange
    [0.35, 0.70, 0.45], // 3: Emerald Green
    [0.85, 0.65, 0.20], // 4: Warm Gold
    [0.60, 0.40, 0.75], // 5: Purple
    [0.85, 0.35, 0.50], // 6: Rose
    [0.20, 0.65, 0.75]  // 7: Cyan
];

// Conversions to mm
D = common_depth_in * 25.4;
stud_spacing = stud_spacing_in * 25.4;
stud_w = stud_width_in * 25.4;
stud_h = stud_height_in * 25.4;

// Render 16" Wooden Wall Studs
module render_studs() {
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
            mod_z_shift = (mod_idx % 2 == 1) ? z_shift : 0;
            
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

// Render 7 Interlocking Circular Modules with 1-Diameter Z Offset for Alternating Modules
module render_7_modules() {
    for (i = [0 : 6]) {
        // Horizontal X position
        x_pos = i * W;
        
        // Vertical Z offset by 1 diameter for alternating modules (1 out of 2)
        z_pos = (i % 2 == 1) ? z_shift : 0;
        
        // Module 1 (far left): flat left side wall
        // Module 7 (far right): flat right side wall
        is_left_end = (i == 0);
        is_right_end = (i == 6);
        
        translate([x_pos, 0, z_pos])
        color(module_colors[i])
        circular_module(
            width_in = common_width_in,
            depth_in = common_depth_in,
            dias = diameters,
            wall_t = 3.5,
            back_t = 4.0,
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

// Render 7 Circular Modules
render_7_modules();

// Render Studs & Wall behind modules
if (show_studs) render_studs();
if (show_wall) render_wall();
