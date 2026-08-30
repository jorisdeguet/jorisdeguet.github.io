// ==========================================
// Custom Sofa Side - Parametric & Split Model
// ==========================================
// This model represents a custom L-shaped sofa side plate with sloped internal edges
// and three parametric screw holes for fixation.
//
// Sliced into 5 printable pieces that fit on a 260mm x 260mm printer bed.
// Assembly system uses 4 connection bars in total:
// - 1 bar for the top part (horizontal cut, left/X=50 slot)
// - 3 bars for the bottom parts (vertical cuts, Y=65 slots)
// All dimensions are in millimeters (mm).
//
// You can customize the parameters and choose which part to render below.

/* [Visualization & Rendering] */
// Select which part to display/export
show_part = 0; // [0:All Assembled, 1:Part 1, 2:Part 2, 3:Part 3, 4:Part 4, 5:Part 5, 6:Exploded View]

// Separation distance for the exploded view (when show_part = 6)
explode_distance = 60; // [0:200]

/* [Main Dimensions] */
// Thickness of the sofa side plate and the connection bars
thickness = .6; // [5:100]

// Total width of the bottom edge
bottom_width = 870;

// Total height of the left edge
total_height = 480;

// Width of the horizontal flat section at the top of the backrest
top_width = 60;

// Horizontal span of the backrest slope
slope_span_x = 160;

// Vertical drop of the backrest slope
slope_drop_y = 390;

// Height of the right vertical edge (above the base)
right_height = 130;

/* [Screw Holes] */
// Diameter of the screw holes
hole_diameter = 12;

// Horizontal adjustment range of the slots
slot_length = 20;

// Height of the screw holes from the bottom edge
hole_y = 40;

// X-coordinate of the first (leftmost) hole
hole_1_x = 95;

// Distance from the first hole to the middle hole
hole_1_to_2_distance = 292;

// Distance from the first hole to the rightmost hole
hole_1_to_3_distance = 657;

/* [Alignment Bars & Slots] */
// Width of the flat alignment bars
bar_width = 10;

// Length of the flat alignment bars
bar_length = 100;

// Tolerance/clearance around the bar in the slot (3D printing clearance)
bar_tolerance = 0.2;

// X-coordinate of the single backrest connector (left side of Cut 1)
connector_x = 50;

/* [Internal Splitting Parameters] */
// X-coordinate where the backrest is split from the seat
cut_x_left = 220;

// Y-coordinate where the backrest is split horizontally
cut_y_back = 240;

// First X-coordinate splitting the seat
cut_x_seat1 = 437; // 220 + (870-220)/3 ≈ 437

// Second X-coordinate splitting the seat
cut_x_seat2 = 653; // 220 + 2*(870-220)/3 ≈ 653

// Number of fragments for circular holes (smoothness)
$fn = 60;

// 2D Profile of the Sofa Side
module sofa_side_2d() {
    points = [
        [0, 0],                                      // A: Bottom-left corner
        [bottom_width, 0],                           // B: Bottom-right corner
        [bottom_width, right_height],                // C: Top of the right vertical edge
        [top_width + slope_span_x, total_height - slope_drop_y], // D: Bottom of the backrest slope
        [top_width, total_height],                   // E: Top of the backrest slope
        [0, total_height]                            // F: Top-left corner
    ];
    
    polygon(points);
}

// Helper module for a rounded adjustment slot (horizontal)
module screw_hole_slot(x, y) {
    translate([x, y, -0.05]) {
        hull() {
            translate([-slot_length / 2, 0, 0])
                cylinder(d = hole_diameter, h = thickness + 0.1);
            translate([slot_length / 2, 0, 0])
                cylinder(d = hole_diameter, h = thickness + 0.1);
        }
    }
}

// 3D Extruded Plate with Screw Holes (Solid, uncut)
module sofa_side_3d() {
    difference() {
        // Extrude the 2D profile
        linear_extrude(height = thickness, center = false) {
            sofa_side_2d();
        }
        
        // Subtract the three screw holes (as rounded slots for adjustment)
        screw_hole_slot(hole_1_x, hole_y);
        screw_hole_slot(hole_1_x + hole_1_to_2_distance, hole_y);
        screw_hole_slot(hole_1_x + hole_1_to_3_distance, hole_y);
    }
}

// Alignment Bar Indents/Slots module
// Subtracts pockets from the cut faces. Pockets include the bar_tolerance on all sides.
module all_indents() {
    t_w = bar_width + 2 * bar_tolerance;
    t_l = bar_length + 2 * bar_tolerance;
    t_h = thickness + 0.2;
    
    // Cut 1: Only 1 vertical bar crossing Y = cut_y_back (on the left side, X = connector_x)
    translate([connector_x - t_w/2, cut_y_back - t_l/2, -0.1])
        cube([t_w, t_l, t_h]);
        
    // Cut 2: One horizontal bar crossing X = cut_x_left (at Y = 65)
    translate([cut_x_left - t_l/2, 65 - t_w/2, -0.1])
        cube([t_l, t_w, t_h]);
        
    // Cut 3: One horizontal bar crossing X = cut_x_seat1 (at Y = 65)
    translate([cut_x_seat1 - t_l/2, 65 - t_w/2, -0.1])
        cube([t_l, t_w, t_h]);

    // Cut 4: One horizontal bar crossing X = cut_x_seat2 (at Y = 65)
    translate([cut_x_seat2 - t_l/2, 65 - t_w/2, -0.1])
        cube([t_l, t_w, t_h]);
}

// --- MODULES FOR INDIVIDUAL PIECES ---

// Part 1: Top Left backrest (Fits in 220mm x 240mm)
module part1() {
    color("LightCoral")
    difference() {
        intersection() {
            sofa_side_3d();
            // Bounding box for Part 1 (Top Left)
            translate([-50, cut_y_back, -50])
                cube([cut_x_left + 50, total_height - cut_y_back + 100, thickness + 100]);
        }
        all_indents();
    }
}

// Part 2: Bottom Left backrest base (Fits in 220mm x 240mm)
module part2() {
    color("LightGreen")
    difference() {
        intersection() {
            sofa_side_3d();
            // Bounding box for Part 2 (Bottom Left)
            translate([-50, -50, -50])
                cube([cut_x_left + 50, cut_y_back + 50, thickness + 100]);
        }
        all_indents();
    }
}

// Part 3: Seat Left section (Fits in 217mm x 130mm)
module part3() {
    color("LightBlue")
    difference() {
        intersection() {
            sofa_side_3d();
            // Bounding box for Part 3 (Seat Left)
            translate([cut_x_left, -50, -50])
                cube([cut_x_seat1 - cut_x_left, total_height + 100, thickness + 100]);
        }
        all_indents();
    }
}

// Part 4: Seat Middle section (Fits in 216mm x 130mm)
module part4() {
    color("LightGoldenrodYellow")
    difference() {
        intersection() {
            sofa_side_3d();
            // Bounding box for Part 4 (Seat Middle)
            translate([cut_x_seat1, -50, -50])
                cube([cut_x_seat2 - cut_x_seat1, total_height + 100, thickness + 100]);
        }
        all_indents();
    }
}

// Part 5: Seat Right section (Fits in 217mm x 130mm)
module part5() {
    color("Plum")
    difference() {
        intersection() {
            sofa_side_3d();
            // Bounding box for Part 5 (Seat Right)
            translate([cut_x_seat2, -50, -50])
                cube([bottom_width - cut_x_seat2 + 50, total_height + 100, thickness + 100]);
        }
        all_indents();
    }
}

// --- PRINTABLE GROUPINGS (PART + 1 BAR FOR PARTS 1, 3, 4, AND 5) ---

module part1_printable() {
    part1();
    // Place 1 vertical bar for Cut 1
    translate([cut_x_left + 10, cut_y_back, 0])
        color("DarkOrange") cube([bar_width, bar_length, thickness]);
}

module part2_printable() {
    part2(); // No bar printed with Part 2 (yields exactly 4 bars total)
}

module part3_printable() {
    // Translate Part 3 to start at local origin X=0, but Y=20 to leave space for the bar below
    translate([-cut_x_left, 20, 0])
        part3();
    // Place 1 horizontal bar for Cut 2
    translate([0, 0, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
}

module part4_printable() {
    // Translate Part 4 to start at local origin X=0, but Y=20 to leave space for the bar below
    translate([-cut_x_seat1, 20, 0])
        part4();
    // Place 1 horizontal bar for Cut 3
    translate([0, 0, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
}

module part5_printable() {
    // Translate Part 5 to start at local origin X=0, but Y=20 to leave space for the bar below
    translate([-cut_x_seat2, 20, 0])
        part5();
    // Place 1 horizontal bar for Cut 4
    translate([0, 0, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
}

// --- DISPLAY LOGIC ---

if (show_part == 0) {
    // Show all parts assembled
    part1();
    part2();
    part3();
    part4();
    part5();
    
    // Render the 4 alignment bars inside the slots
    // Bar 1 (Cut 1 left)
    translate([connector_x - bar_width/2, cut_y_back - bar_length/2, 0])
        color("DarkOrange") cube([bar_width, bar_length, thickness]);
    // Bar 2 (Cut 2 horizontal)
    translate([cut_x_left - bar_length/2, 65 - bar_width/2, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
    // Bar 3 (Cut 3 horizontal)
    translate([cut_x_seat1 - bar_length/2, 65 - bar_width/2, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
    // Bar 4 (Cut 4 horizontal)
    translate([cut_x_seat2 - bar_length/2, 65 - bar_width/2, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
        
} else if (show_part == 1) {
    // Part 1: Top Left with 1 vertical bar, centered for build plate
    translate([-120, -360, 0])
        part1_printable();
        
} else if (show_part == 2) {
    // Part 2: Bottom Left, centered for build plate
    translate([-cut_x_left/2, -cut_y_back/2, 0])
        part2_printable();
        
} else if (show_part == 3) {
    // Part 3: Seat Left with 1 horizontal bar, centered
    translate([-(cut_x_seat1 - cut_x_left)/2, -75, 0])
        part3_printable();
        
} else if (show_part == 4) {
    // Part 4: Seat Middle with 1 horizontal bar, centered
    translate([-(cut_x_seat2 - cut_x_seat1)/2, -75, 0])
        part4_printable();
        
} else if (show_part == 5) {
    // Part 5: Seat Right with 1 horizontal bar, centered
    translate([-(bottom_width - cut_x_seat2)/2, -75, 0])
        part5_printable();
        
} else if (show_part == 6) {
    // Exploded view showing fitment and alignment bars
    translate([0, explode_distance, 0]) part1();
    translate([0, 0, 0]) part2();
    translate([explode_distance, 0, 0]) part3();
    translate([explode_distance * 2, 0, 0]) part4();
    translate([explode_distance * 3, 0, 0]) part5();
    
    // Bars floated in the middle of cuts
    // Bar 1 (between Part 1 and Part 2, floated at Y = cut_y_back + explode_distance / 2)
    translate([connector_x - bar_width/2, cut_y_back - bar_length/2 + explode_distance / 2, 0])
        color("DarkOrange") cube([bar_width, bar_length, thickness]);
        
    // Bar 2 (between Part 2 and Part 3, floated at X = cut_x_left + explode_distance / 2)
    translate([cut_x_left - bar_length/2 + explode_distance / 2, 65 - bar_width/2, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
        
    // Bar 3 (between Part 3 and Part 4, floated at X = cut_x_seat1 + explode_distance * 1.5)
    translate([cut_x_seat1 - bar_length/2 + explode_distance * 1.5, 65 - bar_width/2, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);

    // Bar 4 (between Part 4 and Part 5, floated at X = cut_x_seat2 + explode_distance * 2.5)
    translate([cut_x_seat2 - bar_length/2 + explode_distance * 2.5, 65 - bar_width/2, 0])
        color("DarkOrange") cube([bar_length, bar_width, thickness]);
}
