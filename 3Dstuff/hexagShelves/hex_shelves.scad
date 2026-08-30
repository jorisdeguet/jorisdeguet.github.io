/* ==============================================================================
   MODULAR HEXAGONAL WALL SHELVES WITH SOLID BACK & REAR TONGUE-AND-GROOVE
   ==============================================================================
   - Parameterizable 2 or 4 hexagon clusters per module.
   - Solid back wall for maximum rigidity and clean finish.
   - Invisible interlocking: Rear Tongue & Groove + Rear Sliding Dovetails.
     (Front outer faces meet completely flush with ZERO visible connectors).
   - Sized to fit 260mm x 260mm 3D printer build volume.
   - Designed to span 12 feet (144" / 3658mm) wide x 9"+ (229+mm) high.
   - Integrated mounting holes & horizontal adjustment slots for 16" wall studs.
   - Modular presets for 2-hex and 4-hex units, deeper bottom shelves, and full wall visualizer.
   ============================================================================== */

// [RENDER SELECTION]
// Select which component to render
PART_TO_RENDER = "module_2hex"; // [module_2hex:2-Hexagon Module (Duo), module_4hex:4-Hexagon Module (Quad), module_deep_bottom:Deep 2-Hex Bottom Module, screw_plugs:Set of 6 Screw Caps, wall_cleat:French Cleat Wall Bracket, full_wall_preview:Full 12-Foot Wall Preview (Assembly)]

// [CLUSTER CONFIGURATION]
// Number of hexagons per module (2 or 4)
HEX_COUNT = 2; // [2:2 Hexagons (Duo), 4:4 Hexagons (Quad)]

// Cluster arrangement layout
CLUSTER_SHAPE = "vertical_pair"; // [vertical_pair:2-Hex Diagonal (Upper-Left to Bottom-Right), staggered_pair:2-Hex Staggered Diagonal (Bottom-Left to Upper-Right), diamond_quad:4-Hex Diamond 2x2 (Height ~9.5in), t_quad:4-Hex T-Cluster (3 Base + 1 Top), linear_quad:4-Hex Staggered Ribbon]

// [HEXAGON DIMENSIONS]
// Circumradius for 2-Hex module (in mm). 70mm gives 242mm (~9.5in) height, fits 260mm bed.
HEX_RADIUS_2HEX = 70.0; // [50:1:78]

// Circumradius for 4-Hex module (in mm). 56mm gives 242mm (~9.5in) height, fits 260mm bed.
HEX_RADIUS_4HEX = 56.0; // [40:1:62]

// Shelf depth extending from wall (in mm)
SHELF_DEPTH = 50.0; // [60:5:180]

// Depth for deeper lower-tier accent modules (in mm)
DEEP_SHELF_DEPTH = 150.0; // [100:5:220]

// Perimeter and divider wall thickness (in mm)
WALL_THICKNESS = 3.6; // [2.5:0.2:6.0]

// Solid rear back wall thickness (in mm)
BACK_WALL_THICKNESS = 3.0; // [2.0:0.5:6.0]

// Fillet / corner radius on hexagon vertices (in mm)
CORNER_RADIUS = 3.0; // [0:0.5:8]

// [INVISIBLE REAR INTERLOCKING (TONGUE & GROOVE)]
// Type of rear interlocking joint
INTERLOCK_TYPE = "tongue_and_groove"; // [tongue_and_groove:Rear Tongue & Groove Step, rear_dovetail:Sliding Rear Dovetail Tabs, combined:Tongue & Groove + Sliding Dovetails, none:Flat Seamless Edges]

// Width of the rear interlocking tongue lip (in mm)
TONGUE_WIDTH = 3.5; // [2.0:0.5:6.0]

// Clearance tolerance for 3D printing fit (in mm, 0.20-0.30mm recommended)
TOLERANCE = 0.25; // [0.10:0.05:0.50]

// [WALL MOUNTING & 16-INCH STUDS]
// Enable mounting screw holes in the solid back wall
ENABLE_WALL_MOUNTS = true;

// Wall mounting hole style
MOUNT_STYLE = "stud_slot"; // [stud_slot:Horizontal 16in Stud-Adjust Slot, keyhole:Keyhole Slot, countersunk:Countersunk Round Hole]

// Screw shank diameter (in mm, #8 wood screw = 4.2mm, #10 = 4.8mm)
SCREW_SHANK_DIA = 4.5; // [3:0.5:6]

// Screw head diameter for countersink / keyhole (in mm)
SCREW_HEAD_DIA = 9.2; // [7:0.5:12]

// Stud adjustment slot width (in mm, gives horizontal leeway to hit 16" studs)
STUD_SLOT_LENGTH = 22.0; // [10:2:35]

// [WALL ASSEMBLY PREVIEW CONFIGURATION]
// Total wall span length to preview (in feet, default 12)
PREVIEW_WALL_FEET = 12; // [4:1:20]

// Target minimum height (in inches, default 9)
PREVIEW_MIN_HEIGHT_INCHES = 9;

// Stud spacing on wall (in inches, standard 16)
PREVIEW_STUD_SPACING_INCHES = 16;

// Preview layout style
PREVIEW_LAYOUT_STYLE = "staggered_cascade"; // [staggered_cascade:Staggered with Downward Cascades, continuous_band:Continuous 2-Row Band]

// [3D PRINT BED CONSTRAINTS]
BED_MAX_X = 260;
BED_MAX_Y = 260;

$fn = $preview ? 36 : 60;

// ==============================================================================
// ACTIVE DIMENSION RESOLVER & PRINT BED VALIDATION
// ==============================================================================

// Select radius based on module type
ACTIVE_HEX_RADIUS = (PART_TO_RENDER == "module_4hex" || HEX_COUNT == 4) ? HEX_RADIUS_4HEX : HEX_RADIUS_2HEX;
ACTIVE_INRADIUS = ACTIVE_HEX_RADIUS * cos(30);

// Cluster center coordinates based on layout
function get_hex_centers(count = HEX_COUNT, shape = CLUSTER_SHAPE, r = ACTIVE_HEX_RADIUS) = 
    let(
        dy_vert = 2 * r * cos(30),        // vertical step between flat-top hexes
        dx_diag = 1.5 * r,                 // horizontal step
        dy_diag = r * cos(30)              // vertical step for staggered
    )
    (count == 2 && shape == "vertical_pair") ? [
        [-dx_diag / 2, dy_diag / 2],
        [dx_diag / 2, -dy_diag / 2]
    ] :
    (count == 2 && shape == "staggered_pair") ? [
        [-dx_diag / 2, -dy_diag / 2],
        [dx_diag / 2, dy_diag / 2]
    ] :
    (count == 4 && shape == "diamond_quad") ? [
        [-dx_diag / 2, dy_vert / 2],
        [-dx_diag / 2, -dy_vert / 2],
        [dx_diag / 2, dy_vert / 2 + dy_diag],
        [dx_diag / 2, -dy_vert / 2 + dy_diag]
    ] :
    (count == 4 && shape == "t_quad") ? [
        [-dx_diag, -dy_diag],
        [0, 0],
        [dx_diag, -dy_diag],
        [0, dy_vert]
    ] :
    (count == 4 && shape == "linear_quad") ? [
        [-1.5 * dx_diag, -dy_diag / 2],
        [-0.5 * dx_diag, dy_diag / 2],
        [0.5 * dx_diag, -dy_diag / 2],
        [1.5 * dx_diag, dy_diag / 2]
    ] : [
        [-dx_diag / 2, dy_diag / 2],
        [dx_diag / 2, -dy_diag / 2]
    ];

// Calculate bounding box for active cluster
centers = get_hex_centers(HEX_COUNT, CLUSTER_SHAPE, ACTIVE_HEX_RADIUS);
min_x = min([for (c = centers) c[0] - ACTIVE_HEX_RADIUS]);
max_x = max([for (c = centers) c[0] + ACTIVE_HEX_RADIUS]);
min_y = min([for (c = centers) c[1] - ACTIVE_INRADIUS]);
max_y = max([for (c = centers) c[1] + ACTIVE_INRADIUS]);

BBOX_WIDTH = max_x - min_x;
BBOX_HEIGHT = max_y - min_y;

echo("=================================================");
echo(str("CLUSTER CONFIG: ", HEX_COUNT, " Hexagons (Shape: ", CLUSTER_SHAPE, ")"));
echo(str("INDIVIDUAL HEX: Radius = ", ACTIVE_HEX_RADIUS, " mm, Flat-to-Flat = ", round(2 * ACTIVE_INRADIUS * 10)/10, " mm (", round(2 * ACTIVE_INRADIUS / 25.4 * 10)/10, " in)"));
echo(str("MODULE BOUNDING BOX: Width = ", round(BBOX_WIDTH*10)/10, " mm (", round(BBOX_WIDTH/25.4*10)/10, " in), Height = ", round(BBOX_HEIGHT*10)/10, " mm (", round(BBOX_HEIGHT/25.4*10)/10, " in)"));
echo(str("PRINT BED LIMIT: ", BED_MAX_X, " x ", BED_MAX_Y, " mm"));

if (BBOX_WIDTH <= BED_MAX_X && BBOX_HEIGHT <= BED_MAX_Y) {
    echo("STATUS: [PASS] Module fits completely within your 26cm x 26cm print bed!");
} else {
    echo("STATUS: [WARNING] Module exceeds 26cm bed! Rotate 90 deg or decrease hex radius.");
}
echo("=================================================");

// ==============================================================================
// 2D HEXAGON PROFILE FUNCTIONS
// ==============================================================================

module single_hex_2d(r, corner_r = CORNER_RADIUS) {
    if (corner_r > 0) {
        offset(r = corner_r) offset(delta = -corner_r) circle(r = r, $fn = 6);
    } else {
        circle(r = r, $fn = 6);
    }
}

// Full multi-hex cluster outer envelope (2D)
module cluster_outer_2d(count = HEX_COUNT, shape = CLUSTER_SHAPE, r = ACTIVE_HEX_RADIUS) {
    pts = get_hex_centers(count, shape, r);
    union() {
        for (p = pts) {
            translate(p) single_hex_2d(r, CORNER_RADIUS);
        }
    }
}

// Inner open cavities for the cluster (2D)
module cluster_inner_2d(count = HEX_COUNT, shape = CLUSTER_SHAPE, r = ACTIVE_HEX_RADIUS, wall = WALL_THICKNESS) {
    pts = get_hex_centers(count, shape, r);
    union() {
        for (p = pts) {
            translate(p) single_hex_2d(r - wall, max(0, CORNER_RADIUS - wall));
        }
    }
}

// ==============================================================================
// INVISIBLE REAR TONGUE & GROOVE INTERLOCKING
// ==============================================================================

// Outer tongue flange on the rear back wall (extends along boundary)
module rear_tongue_additions_2d(count = HEX_COUNT, shape = CLUSTER_SHAPE, r = ACTIVE_HEX_RADIUS) {
    pts = get_hex_centers(count, shape, r);
    tongue_w = TONGUE_WIDTH - TOLERANCE;
    
    // Add tongue tabs on positive X / top-right perimeter edges
    for (p = pts) {
        translate(p) {
            // For each of the 6 faces, place tongue on faces 0, 1, 5 (right / upper sides)
            for (face = [0, 1, 5]) {
                angle = 30 + 60 * face;
                rotate([0, 0, angle]) {
                    translate([0, r * cos(30) + tongue_w / 2, 0]) {
                        square([r * 0.7, tongue_w], center = true);
                    }
                }
            }
        }
    }
}

// Recessed groove pocket on mating rear edges
module rear_groove_cutouts_2d(count = HEX_COUNT, shape = CLUSTER_SHAPE, r = ACTIVE_HEX_RADIUS) {
    pts = get_hex_centers(count, shape, r);
    groove_w = TONGUE_WIDTH + TOLERANCE;
    
    // Cut groove step on negative X / bottom-left perimeter edges
    for (p = pts) {
        translate(p) {
            // Place groove pockets on faces 2, 3, 4 (left / lower sides)
            for (face = [2, 3, 4]) {
                angle = 30 + 60 * face;
                rotate([0, 0, angle]) {
                    translate([0, r * cos(30) - groove_w / 2, 0]) {
                        square([r * 0.85, groove_w + 0.5], center = true);
                    }
                }
            }
        }
    }
}

// Rear Sliding Dovetail Tab (Male)
module rear_dovetail_male_tab(length = 25, width = 12, depth = 3.5) {
    linear_extrude(height = length) {
        polygon(points = [
            [-width * 0.35, 0],
            [-width / 2, depth],
            [width / 2, depth],
            [width * 0.35, 0]
        ]);
    }
}

// Rear Sliding Dovetail Slot (Female)
module rear_dovetail_female_slot(length = 26, width = 12, depth = 3.5, tol = TOLERANCE) {
    w_wide = width + 2 * tol;
    w_narrow = (width * 0.7) + 2 * tol;
    d = depth + tol;
    
    linear_extrude(height = length + 2) {
        polygon(points = [
            [-w_narrow / 2, -0.1],
            [-w_wide / 2, d],
            [w_wide / 2, d],
            [w_narrow / 2, -0.1]
        ]);
    }
}

// ==============================================================================
// WALL MOUNTING HOLES (KEYHOLES & 16-INCH STUD SLOTS)
// ==============================================================================

module wall_mount_slot(back_thick = BACK_WALL_THICKNESS) {
    if (MOUNT_STYLE == "stud_slot") {
        // Horizontal slot for 16" stud alignment leeway
        union() {
            // Screw shank slot
            hull() {
                translate([-STUD_SLOT_LENGTH / 2, 0, -1]) cylinder(r = SCREW_SHANK_DIA / 2, h = back_thick + 2, $fn = 24);
                translate([STUD_SLOT_LENGTH / 2, 0, -1]) cylinder(r = SCREW_SHANK_DIA / 2, h = back_thick + 2, $fn = 24);
            }
            // Front countersink recess for screw head (inside the shelf cell)
            translate([0, 0, back_thick - 1.6]) {
                hull() {
                    translate([-STUD_SLOT_LENGTH / 2, 0, 0]) cylinder(r = SCREW_HEAD_DIA / 2, h = back_thick, $fn = 24);
                    translate([STUD_SLOT_LENGTH / 2, 0, 0]) cylinder(r = SCREW_HEAD_DIA / 2, h = back_thick, $fn = 24);
                }
            }
        }
    } else if (MOUNT_STYLE == "keyhole") {
        // Teardrop keyhole slot
        union() {
            cylinder(r = SCREW_HEAD_DIA / 2 + 0.3, h = back_thick + 2, center = true, $fn = 28);
            translate([0, 7, 0]) cube([SCREW_SHANK_DIA + 0.2, 14, back_thick + 2], center = true);
            translate([0, 7, -back_thick / 2 + 1.2]) cube([SCREW_HEAD_DIA + 0.8, 14, back_thick], center = true);
        }
    } else {
        // Simple countersunk round hole
        cylinder(r = SCREW_SHANK_DIA / 2, h = back_thick + 2, center = true, $fn = 24);
        translate([0, 0, back_thick / 2 - 1.5]) {
            cylinder(r1 = SCREW_SHANK_DIA / 2, r2 = SCREW_HEAD_DIA / 2, h = 2.0, center = false, $fn = 24);
        }
    }
}

// Cut mounting holes in the solid back wall of selected hex cells
module apply_wall_mount_holes(count = HEX_COUNT, shape = CLUSTER_SHAPE, r = ACTIVE_HEX_RADIUS) {
    pts = get_hex_centers(count, shape, r);
    inrad = r * cos(30);
    
    for (p = pts) {
        // Place mount hole near the upper center of each hexagon
        translate([p[0], p[1] + inrad * 0.45, 0]) {
            wall_mount_slot(BACK_WALL_THICKNESS);
        }
    }
}

// ==============================================================================
// MULTI-HEXAGON SHELF MODULE 3D BUILDER
// ==============================================================================

module modular_hex_shelf(
    count = HEX_COUNT,
    shape = CLUSTER_SHAPE,
    r = ACTIVE_HEX_RADIUS,
    depth_z = SHELF_DEPTH,
    back_thick = BACK_WALL_THICKNESS,
    wall_thick = WALL_THICKNESS,
    with_mounts = ENABLE_WALL_MOUNTS,
    is_deep = false
) {
    actual_depth = is_deep ? DEEP_SHELF_DEPTH : depth_z;
    tongue_thick = back_thick / 2;
    
    difference() {
        union() {
            // 1. Solid Outer Shell & Solid Back Wall
            linear_extrude(height = actual_depth) {
                cluster_outer_2d(count, shape, r);
            }
            
            // 2. Rear Interlocking Tongue Lip (Male tabs on right/top edges)
            if (INTERLOCK_TYPE == "tongue_and_groove" || INTERLOCK_TYPE == "combined") {
                linear_extrude(height = tongue_thick) {
                    rear_tongue_additions_2d(count, shape, r);
                }
            }
            
            // 3. Sliding Rear Dovetail Tabs (if enabled)
            if (INTERLOCK_TYPE == "rear_dovetail" || INTERLOCK_TYPE == "combined") {
                pts = get_hex_centers(count, shape, r);
                for (p = pts) {
                    // Male dovetail tab on right vertical face
                    translate([p[0] + r * cos(30), p[1], 0]) {
                        rotate([0, 0, 90]) rear_dovetail_male_tab(length = actual_depth * 0.6, width = 10, depth = 2.5);
                    }
                }
            }
        }
        
        // 4. Hollow Out Hexagon Interior Compartments (Leaves solid back wall)
        translate([0, 0, back_thick]) {
            linear_extrude(height = actual_depth + 1) {
                cluster_inner_2d(count, shape, r, wall_thick);
            }
        }
        
        // 5. Rear Interlocking Groove Pocket (Female step on left/bottom mating edges)
        if (INTERLOCK_TYPE == "tongue_and_groove" || INTERLOCK_TYPE == "combined") {
            translate([0, 0, -0.5]) {
                linear_extrude(height = tongue_thick + 0.5 + TOLERANCE) {
                    rear_groove_cutouts_2d(count, shape, r);
                }
            }
        }
        
        // 6. Sliding Rear Dovetail Slots on left faces (if enabled)
        if (INTERLOCK_TYPE == "rear_dovetail" || INTERLOCK_TYPE == "combined") {
            pts = get_hex_centers(count, shape, r);
            for (p = pts) {
                translate([p[0] - r * cos(30), p[1], -1]) {
                    rotate([0, 0, -90]) rear_dovetail_female_slot(length = actual_depth * 0.65, width = 10, depth = 2.5);
                }
            }
        }
        
        // 7. Mounting Screw Holes through the Solid Back Wall
        if (with_mounts) {
            apply_wall_mount_holes(count, shape, r);
        }
    }
}

// ==============================================================================
// ACCESSORY MODELS: SCREW PLUGS & CLEATS
// ==============================================================================

// Decorative flush screw cover caps (snap into countersunk holes from front)
module screw_plug_model() {
    cylinder(r = SCREW_HEAD_DIA / 2 - 0.1, h = 1.6, $fn = 32);
    translate([0, 0, 1.6]) {
        cylinder(r1 = SCREW_SHANK_DIA / 2, r2 = SCREW_SHANK_DIA / 2 - 0.2, h = 2.0, $fn = 24);
    }
}

// Batch plate of 6 screw caps
module screw_plugs_batch() {
    echo("Rendering Plate of 6 Flush Screw Covers");
    for (i = [0:2]) {
        for (j = [0:1]) {
            translate([i * (SCREW_HEAD_DIA + 6), j * (SCREW_HEAD_DIA + 6), 0]) {
                screw_plug_model();
            }
        }
    }
}

// French Cleat Wall Mounting Bracket (screws into 16" stud)
module french_cleat_bracket() {
    w = 46;
    h = 24;
    t = 7;
    
    difference() {
        polyhedron(
            points = [
                [-w/2, 0, 0], [w/2, 0, 0], [w/2, h - 5, 0], [-w/2, h - 5, 0],
                [-w/2, 0, t], [w/2, 0, t], [w/2, h, t], [-w/2, h, t]
            ],
            faces = [
                [0,1,2,3], [4,7,6,5], [0,4,5,1], [3,2,6,7], [0,3,7,4], [1,5,6,2]
            ]
        );
        // Countersunk wood screw holes for 16" stud
        for (dx = [-13, 13]) {
            translate([dx, h/2 - 2, -1]) {
                cylinder(r = SCREW_SHANK_DIA / 2, h = t + 2, $fn = 24);
                translate([0, 0, t - 1.8]) {
                    cylinder(r1 = SCREW_SHANK_DIA / 2, r2 = SCREW_HEAD_DIA / 2, h = 2.5, $fn = 24);
                }
            }
        }
    }
}

// ==============================================================================
// 12-FOOT WALL ASSEMBLY VISUALIZER
// ==============================================================================

module full_wall_assembly_visualizer() {
    wall_len_mm = PREVIEW_WALL_FEET * 12 * 25.4;       // 12 ft = 3657.6 mm
    min_ht_mm = PREVIEW_MIN_HEIGHT_INCHES * 25.4;       // 9 in = 228.6 mm
    stud_spacing_mm = PREVIEW_STUD_SPACING_INCHES * 25.4; // 16 in = 406.4 mm
    
    r = (HEX_COUNT == 4) ? HEX_RADIUS_4HEX : HEX_RADIUS_2HEX;
    inrad = r * cos(30);
    dx = 3.0 * r;
    num_modules = ceil(wall_len_mm / dx);
    
    echo("-------------------------------------------------");
    echo(str("WALL PREVIEW: 12 Feet (", wall_len_mm, " mm) Wide x 9+ Inches (", min_ht_mm, " mm) High"));
    echo(str("MODULES ACROSS: ", num_modules, " (", HEX_COUNT, "-Hex modules, Step = ", round(dx*10)/10, " mm)"));
    echo(str("STUD INTERVALS: 16 inches (", stud_spacing_mm, " mm) -> 10 stud locations across 12 ft"));
    echo("-------------------------------------------------");
    
    // 1. Ghosted Reference Box for 12ft x 9in wall coverage
    %translate([wall_len_mm / 2, min_ht_mm / 2, -15]) {
        cube([wall_len_mm, min_ht_mm, 2], center = true);
    }
    
    // 2. Vertical 16-Inch Wall Stud Grid Lines (in Orange)
    for (s = [0 : ceil(wall_len_mm / stud_spacing_mm)]) {
        stud_x = s * stud_spacing_mm;
        if (stud_x <= wall_len_mm + 50) {
            color([1.0, 0.4, 0.1, 0.75]) {
                translate([stud_x, -inrad * 1.5, -8]) {
                    cube([38.1, min_ht_mm * 2.6, 5], center = true); // 1.5" standard 2x4 stud width
                }
            }
        }
    }
    
    // 3. Render Honeycomb Modules Across Wall
    for (m = [0 : num_modules - 1]) {
        mod_x = m * dx;
        dist_to_stud = min([for (s = [0:10]) abs(mod_x - s * stud_spacing_mm)]);
        is_stud_module = (dist_to_stud < (dx / 2 + 10));
        
        // Staggered vertical position
        mod_y = (HEX_COUNT == 4) ? ((m % 2 == 0) ? 0 : (inrad * 1.0)) : 0;
        
        translate([mod_x, mod_y, 0]) {
            if (is_stud_module) {
                // Steel Blue for Modules Anchored to 16" Studs
                color([0.22, 0.48, 0.78, 0.95]) modular_hex_shelf(HEX_COUNT, CLUSTER_SHAPE, r, SHELF_DEPTH, with_mounts = true);
            } else if (m % 3 == 1) {
                // Warm Amber for Accent Modules
                color([0.92, 0.65, 0.22, 0.95]) modular_hex_shelf(HEX_COUNT, CLUSTER_SHAPE, r, SHELF_DEPTH, with_mounts = false);
            } else {
                // Teal for Standard Interlocking Modules
                color([0.18, 0.72, 0.62, 0.95]) modular_hex_shelf(HEX_COUNT, CLUSTER_SHAPE, r, SHELF_DEPTH, with_mounts = false);
            }
        }
        
        // Cascading lower modules (extensions towards the bottom)
        if (PREVIEW_LAYOUT_STYLE == "staggered_cascade") {
            if ((m >= 2 && m <= 5) || (m >= 9 && m <= 13) || (m >= 16 && m <= 19)) {
                lower_y = mod_y - 2 * inrad * 1.0;
                translate([mod_x, lower_y, 0]) {
                    if (m == 3 || m == 11 || m == 17) {
                        // Coral for Deep Lower Shelf Units (extra storage depth)
                        color([0.95, 0.35, 0.35, 0.95]) modular_hex_shelf(HEX_COUNT, CLUSTER_SHAPE, r, DEEP_SHELF_DEPTH, with_mounts = is_stud_module, is_deep = true);
                    } else {
                        color([0.18, 0.72, 0.62, 0.95]) modular_hex_shelf(HEX_COUNT, CLUSTER_SHAPE, r, SHELF_DEPTH, with_mounts = is_stud_module);
                    }
                }
            }
        }
    }
}

// ==============================================================================
// TOP-LEVEL RENDER DISPATCHER
// ==============================================================================

if (PART_TO_RENDER == "module_2hex") {
    modular_hex_shelf(count = 2, shape = "vertical_pair", r = HEX_RADIUS_2HEX, depth_z = SHELF_DEPTH);
} else if (PART_TO_RENDER == "module_4hex") {
    modular_hex_shelf(count = 4, shape = "diamond_quad", r = HEX_RADIUS_4HEX, depth_z = SHELF_DEPTH);
} else if (PART_TO_RENDER == "module_deep_bottom") {
    modular_hex_shelf(count = 2, shape = "vertical_pair", r = HEX_RADIUS_2HEX, depth_z = DEEP_SHELF_DEPTH, is_deep = true);
} else if (PART_TO_RENDER == "screw_plugs") {
    screw_plugs_batch();
} else if (PART_TO_RENDER == "wall_cleat") {
    french_cleat_bracket();
} else if (PART_TO_RENDER == "full_wall_preview") {
    full_wall_assembly_visualizer();
}

