// Shed Parameters (in inches)
width = 120;             // 10 feet
depth = 96;              // 8 feet
height_front = 96;       // 8 feet
height_back = 84;        // 7 feet (slope towards back)
roof_overshoot_left = 48; // 4 feet overshoot for bikes
roof_overshoot_right = 6;
// Note: Front/Back overshoots are now determined by the 12ft panels (centered)

// Floor Elevation
floor_attachment_height = 6; // Bottom of the joists is 6" above ground

// Dimensional Lumber
lumber_4x4 = 3.5;
lumber_2x10_thick = 1.5;
lumber_2x10_height = 9.25;
lumber_2x4_thick = 1.5;
lumber_2x4_width = 3.5;
osb_thick = 0.75;

// Glass Panel Dimensions
glass_w = 31;
glass_h = 44;

// Window Parameters (in inches)
window_w = 63.5;
window_h = 18;
side_window_w = 30.5;
side_window_h = 18;

// Roofing Panel Parameters
roof_panel_w = 26;
roof_panel_l = 144; // 12 feet
roof_panel_overlap = 2.25; // Standard corrugated overlap

// Pergola Parameters (in inches)
pergola_w = 144; // 12 feet
pergola_d = 96;  // 8 feet
pergola_h = 96;  // 8 feet

// Colors (with alpha for transparency)
col_lumber = "BurlyWood";
col_posts = "Sienna";
col_panel = [0.8, 0.6, 0.4, 0.3]; 
col_glass = [0.6, 0.8, 1.0, 0.4]; 
col_concrete = "Grey";
col_roofing = [0.3, 0.3, 0.3, 0.8]; // Dark grey for corrugated panels

module post(h) {
    color(col_posts)
    cube([lumber_4x4, lumber_4x4, h]);
}

module footing() {
    color(col_concrete)
    translate([-(12-lumber_4x4)/2, -(12-lumber_4x4)/2, -12])
    cube([12, 12, 12]);
}

module beam_4x4(l) {
    color(col_lumber)
    cube([l, lumber_4x4, lumber_4x4]);
}

module pergola(w, d, h) {
    // 4 Posts (at altitude 0 as requested)
    for (pos = [[0,0], [w-lumber_4x4, 0], [0, d-lumber_4x4], [w-lumber_4x4, d-lumber_4x4]]) {
        translate([pos[0], pos[1], 0]) post(h);
    }
    // Top Beams (Width-wise)
    translate([0, 0, h-lumber_4x4]) beam_4x4(w);
    translate([0, d-lumber_4x4, h-lumber_4x4]) beam_4x4(w);
    
    // Top Beams (Depth-wise)
    translate([lumber_4x4, 0, h-lumber_4x4]) rotate([0, 0, 90]) beam_4x4(d);
    translate([w, 0, h-lumber_4x4]) rotate([0, 0, 90]) beam_4x4(d);
    
    // Rafters (24" OC)
    for (x = [24 : 24 : w - 24]) {
        translate([x + lumber_4x4, 0, h]) rotate([0, 0, 90]) beam_4x4(d);
    }
}

module window(w, h) {
    color(col_glass)
    translate([0, 1.5, 0]) cube([w, 0.25, h]);
    color("Maroon") {
        // Frame
        cube([w, 3.5, 1.5]); 
        translate([0, 0, h - 1.5]) cube([w, 3.5, 1.5]); 
        cube([1.5, 3.5, h]); 
        translate([w - 1.5, 0, 0]) cube([1.5, 3.5, h]); 
    }
}

module stud_2x4(h) {
    color(col_lumber)
    cube([lumber_2x4_thick, lumber_2x4_width, h]);
}

module wall_panel_trapeze(w, h_start, h_end) {
    color(col_panel)
    rotate([90, 0, 90])
    linear_extrude(height = 0.5)
    polygon(points = [[0, 0], [w, 0], [w, h_end], [0, h_start]]);
}

module floor_system() {
    translate([0, 0, floor_attachment_height]) {
        color(col_lumber) cube([width, lumber_2x10_thick, lumber_2x10_height]);
        translate([0, depth - lumber_2x10_thick, 0]) color(col_lumber) cube([width, lumber_2x10_thick, lumber_2x10_height]);

        for (x = [0 : 16 : width - lumber_2x10_thick]) {
            translate([x, lumber_2x10_thick, 0]) 
            color(col_lumber) cube([lumber_2x10_thick, depth - 2*lumber_2x10_thick, lumber_2x10_height]);
        }
        translate([width - lumber_2x10_thick, lumber_2x10_thick, 0]) 
        color(col_lumber) cube([lumber_2x10_thick, depth - 2*lumber_2x10_thick, lumber_2x10_height]);

        translate([0, 0, lumber_2x10_height]) {
            for (x = [0 : 48 : width - 0.1]) {
                for (y = [0 : 96 : depth - 0.1]) {
                    w_sheet = min(48, width - x);
                    l_sheet = min(96, depth - y);
                    translate([x, y, 0]) color(col_panel) cube([w_sheet, l_sheet, osb_thick]);
                }
            }
        }
    }
}

module frame_and_walls() {
    z_base = floor_attachment_height + lumber_2x10_height + osb_thick;
    slope_angle = atan((height_front - height_back) / depth);
    
    for (pos = [[0,0], [width-lumber_4x4, 0], [0, depth-lumber_4x4], [width-lumber_4x4, depth-lumber_4x4]]) {
        translate([pos[0], pos[1], 0]) {
            footing();
            h = (pos[1] == 0) ? height_front + z_base : height_back + z_base;
            post(h);
        }
    }

    // Back Wall
    translate([0, depth, floor_attachment_height]) {
        color(col_panel) cube([width, 0.5, height_back + lumber_2x10_height + osb_thick]);
        for (x = [lumber_4x4 : 16 : width - lumber_4x4]) {
            translate([x, -lumber_2x4_width, lumber_2x10_height + osb_thick]) stud_2x4(height_back - lumber_4x4);
        }
    }

    // Left and Right Wall Side Windows Parameters
    side_window_z_top = height_back - lumber_4x4;
    side_window_z_bot = side_window_z_top - side_window_h;
    y1 = depth - side_window_w - 5;
    y2 = depth - 2*side_window_w - 15;

    // Left Wall with Side Windows
    translate([0, 0, z_base]) {
        wall_panel_trapeze(depth, height_front, height_back);
        
        for (y_start = [y1, y2]) {
            translate([0, y_start, side_window_z_bot]) rotate([0, 0, 90]) window(side_window_w, side_window_h);
            // Window framing
            translate([lumber_2x4_width, y_start, side_window_z_bot - 1.5]) rotate([0,0,90]) color(col_lumber) cube([side_window_w, lumber_2x4_thick, 1.5]);
            translate([lumber_2x4_width, y_start, side_window_z_top]) rotate([0,0,90]) color(col_lumber) cube([side_window_w, lumber_2x4_thick, 1.5]);
        }

        for (y = [lumber_4x4 + 16 : 16 : depth - lumber_4x4 - 16]) {
            h_at_y = height_front - (height_front - height_back) * (y / depth);
            h_stud_max = h_at_y - (lumber_4x4 / cos(slope_angle));
            
            in_window = (y > y2 && y < y2 + side_window_w) || (y > y1 && y < y1 + side_window_w);
            
            if (!in_window) {
                translate([lumber_2x4_width, y, 0]) rotate([0, 0, 90]) stud_2x4(h_stud_max);
            } else {
                // Cripple studs
                translate([lumber_2x4_width, y, 0]) rotate([0, 0, 90]) stud_2x4(side_window_z_bot - 1.5);
                translate([lumber_2x4_width, y, side_window_z_top + 1.5]) rotate([0, 0, 90]) stud_2x4(h_stud_max - (side_window_z_top + 1.5));
            }
        }
    }

    // Right Wall with Side Windows
    translate([width - 0.5, 0, z_base]) {
        wall_panel_trapeze(depth, height_front, height_back);
        
        for (y_start = [y1, y2]) {
            translate([0.5, y_start, side_window_z_bot]) rotate([0, 0, 90]) window(side_window_w, side_window_h);
            // Window framing
            translate([-lumber_2x4_width, y_start, side_window_z_bot - 1.5]) rotate([0,0,90]) color(col_lumber) cube([side_window_w, lumber_2x4_thick, 1.5]);
            translate([-lumber_2x4_width, y_start, side_window_z_top]) rotate([0,0,90]) color(col_lumber) cube([side_window_w, lumber_2x4_thick, 1.5]);
        }

        for (y = [lumber_4x4 + 16 : 16 : depth - lumber_4x4 - 16]) {
            h_at_y = height_front - (height_front - height_back) * (y / depth);
            h_stud_max = h_at_y - (lumber_4x4 / cos(slope_angle));
            
            in_window = (y > y2 && y < y2 + side_window_w) || (y > y1 && y < y1 + side_window_w);
            
            if (!in_window) {
                translate([-lumber_2x4_width + 0.5, y, 0]) rotate([0, 0, 90]) stud_2x4(h_stud_max);
            } else {
                // Cripple studs
                translate([-lumber_2x4_width + 0.5, y, 0]) rotate([0, 0, 90]) stud_2x4(side_window_z_bot - 1.5);
                translate([-lumber_2x4_width + 0.5, y, side_window_z_top + 1.5]) rotate([0, 0, 90]) stud_2x4(h_stud_max - (side_window_z_top + 1.5));
            }
        }
    }
    
    // Front Wall Framing with Window
    window_z_top = height_front - 12 - lumber_4x4; // 12" from top of wall (under top beam)
    window_z_bot = window_z_top - window_h;
    
    translate([0, 0, z_base]) {
        // Window opening framing
        translate([lumber_4x4, 0, window_z_bot - 1.5]) color(col_lumber) cube([window_w, lumber_2x4_width, 1.5]);
        translate([lumber_4x4, 0, window_z_top]) color(col_lumber) cube([window_w, lumber_2x4_width, 1.5]);
        translate([lumber_4x4 + window_w, 0, 0]) stud_2x4(height_front - lumber_4x4);
        
        // Window instance
        translate([lumber_4x4, 0, window_z_bot]) window(window_w, window_h);

        for (x = [lumber_4x4 + 16 : 16 : width - 50]) { 
            if (x < lumber_4x4 || x > lumber_4x4 + window_w) {
                translate([x, 0, 0]) stud_2x4(height_front - lumber_4x4);
            } else {
                // Cripple studs
                translate([x, 0, 0]) stud_2x4(window_z_bot - 1.5);
                translate([x, 0, window_z_top + 1.5]) stud_2x4(height_front - lumber_4x4 - (window_z_top + 1.5));
            }
        }
    }
    
    z_front_top = z_base + height_front;
    z_back_top = z_base + height_back;
    total_beam_width = width + roof_overshoot_left + roof_overshoot_right;
    rafter_l = (depth) / cos(slope_angle);

    translate([-roof_overshoot_left, 0, z_front_top - lumber_4x4]) beam_4x4(total_beam_width);
    translate([-roof_overshoot_left, depth - lumber_4x4, z_back_top - lumber_4x4]) beam_4x4(total_beam_width);
    
    // Rafters
    for (x = [-roof_overshoot_left : 24 : width + roof_overshoot_right - lumber_4x4]) {
        translate([x, 0, z_front_top]) rotate([-slope_angle, 0, 0]) color(col_lumber) cube([lumber_4x4, rafter_l, lumber_4x4]);
    }
}

module door() {
    z_base = floor_attachment_height + lumber_2x10_height + osb_thick;
    door_w = glass_w + 4;
    door_h = 2*glass_h + 6;
    
    translate([width - door_w - 5, 0, z_base]) {
        color("Maroon") {
            cube([door_w, lumber_2x4_width, 1.5]); 
            translate([0, 0, door_h - 1.5]) cube([door_w, lumber_2x4_width, 1.5]); 
            cube([1.5, lumber_2x4_width, door_h]); 
            translate([door_w - 1.5, 0, 0]) cube([1.5, lumber_2x4_width, door_h]); 
        }
        color(col_glass) {
            translate([2, 1.5, 2]) cube([glass_w, 0.25, glass_h]);
            translate([2, 1.5, glass_h + 4]) cube([glass_w, 0.25, glass_h]);
        }
    }
}

module roof() {
    slope_angle = atan((height_front - height_back) / depth);
    total_roof_width = width + roof_overshoot_left + roof_overshoot_right;
    
    // Center the 12ft panels on the 8ft structure (depth)
    // Sloped depth is depth/cos(slope_angle)
    sloped_depth = depth / cos(slope_angle);
    overhang_each_side = (roof_panel_l - sloped_depth) / 2;
    
    z_start = floor_attachment_height + lumber_2x10_height + osb_thick + height_front + lumber_4x4;

    // Effective width per panel after overlap
    effective_w = roof_panel_w - roof_panel_overlap;
    num_panels = ceil(total_roof_width / effective_w);

    translate([-roof_overshoot_left, -overhang_each_side, z_start])
    rotate([-slope_angle, 0, 0]) {
        for (i = [0 : num_panels - 1]) {
            translate([i * effective_w, 0, 0.5]) {
                color(col_roofing)
                cube([roof_panel_w, roof_panel_l, 0.5]);
            }
        }
    }
}

// Final Assembly
floor_system();
frame_and_walls();
door();
roof();

// Pergolas on the right
translate([width, 0, 0]) pergola(pergola_w, pergola_d, pergola_h);
translate([width + pergola_w, 0, 0]) pergola(pergola_w, pergola_d, pergola_h);

// Existing Fence on the left
module fence(l, h) {
    color("Grey", 0.5) {
        // Posts
        for (y = [0 : 96 : l]) {
            translate([-2, y, 0]) cube([4, 4, h + 12]); // Posts slightly higher
        }
        // Fence panels
        translate([-0.5, 0, 0]) cube([1, l, h]);
    }
}

translate([-104, 0, 0]) fence(depth, 60);
