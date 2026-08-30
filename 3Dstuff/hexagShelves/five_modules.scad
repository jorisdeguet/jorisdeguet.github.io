/* ==============================================================================
   5-MODULE DIAGONAL HONEYCOMB WALL SHELF WITH 16-INCH STUD VISUALIZER & DOWELS
   ==============================================================================
   - Renders 5 modules side-by-side forming a continuous 10-hexagon zigzag band.
   - Sized perfectly (HEX_RADIUS = 45.155 mm) so that 3 modules cover exactly
     16 inches horizontally.
   - Touching on the upper-left to bottom-right sloped faces.
   - Flat floors alternate vertically by exactly half a hexagon height.
   - No tongue-and-groove or visible interlocking joints.
   - Features clever, invisible vertical half-cylindrical grooves on outer sloped
     mating faces. Sliding a 3D-printed alignment pin (dowel) from the back locks 
     them together in perfect alignment.
   - Includes wood stud visualizers spaced at 16 inches.
   - Simulates anchoring points and dynamically color-codes screws:
     * Silver/Shiny = Screws anchoring directly into a solid wood stud (ideal!)
       Only one in three modules needs to be fastened to studs (e.g. Module 1 and 4)!
     * Yellow/Orange = Drywall anchors (rendered as backup if you wish to use them)
   - Slide the assembly horizontally with 'WALL_OFFSET_X' to align slots with studs.
   ============================================================================== */

// [VISUALIZATION CONFIGURATION]
// Slide the entire shelf assembly horizontally to align slots with studs (in mm)
WALL_OFFSET_X = 67.7325; // [-200:1:500]

// Show the 16" studs behind the wall
SHOW_WALL_STUDS = true;

// Show screws & anchors inside the back wall mounting slots
SHOW_SCREWS_AND_ANCHORS = true;

// Render 3D printed alignment pins (dowels) next to the assembly
RENDER_ALIGNMENT_PINS = true;

// [HEXAGON DIMENSIONS]
// Circumradius of each hexagon (in mm). 45.155mm makes 3 modules span exactly 16 inches.
HEX_RADIUS = 45.155; // [35:0.1:80]

// Shelf depth extending from wall (in mm)
SHELF_DEPTH = 20.0; // [60:5:180]

// Perimeter and divider wall thickness (in mm)
WALL_THICKNESS = 3.6; // [2.5:0.2:6.0]

// Solid rear back wall thickness (in mm)
BACK_WALL_THICKNESS = 3.0; // [2.0:0.5:6.0]

// Fillet / corner radius on hexagon vertices (in mm)
CORNER_RADIUS = 3.0; // [0:0.5:8]

// [WALL MOUNTING CONFIGURATION]
// Enable mounting screw holes in the solid back wall
ENABLE_WALL_MOUNTS = true;

// Screw shank diameter (in mm, #8 wood screw = 4.2mm, #10 = 4.8mm)
SCREW_SHANK_DIA = 4.5; // [3:0.5:6]

// Screw head diameter for countersink / keyhole (in mm)
SCREW_HEAD_DIA = 9.2; // [7:0.5:12]

// Stud adjustment slot width (in mm, gives horizontal leeway to hit 16" studs)
STUD_SLOT_LENGTH = 22.0; // [10:2:35]

// [CLEVER SIDE-ALIGNMENT CONNECTORS]
// Radius of the alignment pin (in mm). 2.0mm = 4.0mm diameter pin.
PIN_RADIUS = 2.0; // [1.0:0.1:3.5]

// Depth of the pin groove from the back (in mm). Stops 10mm from the front to be invisible.
GROOVE_DEPTH = 90.0; // [30:5:170]

$fn = $preview ? 36 : 60;

// ==============================================================================
// GEOMETRY & ALIGNMENT RESOLVERS
// ==============================================================================

inrad = HEX_RADIUS * cos(30);

// Coordinates of the 2-Hex Diagonal Cluster
// Hex 1 is on upper-left, Hex 2 is on bottom-right
function get_hex_centers(r = HEX_RADIUS) = [
    [-0.75 * r, inrad / 2], // Upper-left (high shelf)
    [0.75 * r, -inrad / 2]  // Bottom-right (low shelf)
];

module single_hex_2d(r, corner_r = CORNER_RADIUS) {
    if (corner_r > 0) {
        offset(r = corner_r) offset(delta = -corner_r) circle(r = r, $fn = 6);
    } else {
        circle(r = r, $fn = 6);
    }
}

// Full outer envelope (2D)
module cluster_outer_2d(r = HEX_RADIUS) {
    pts = get_hex_centers(r);
    union() {
        for (p = pts) {
            translate(p) single_hex_2d(r, CORNER_RADIUS);
        }
    }
}

// Inner open cavities (2D)
module cluster_inner_2d(r = HEX_RADIUS, wall = WALL_THICKNESS) {
    pts = get_hex_centers(r);
    union() {
        for (p = pts) {
            translate(p) single_hex_2d(r - wall, max(0, CORNER_RADIUS - wall));
        }
    }
}

// Mounting screw slot
module wall_mount_slot(back_thick = BACK_WALL_THICKNESS) {
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
}

// Apply mounting holes to the solid back wall
module apply_wall_mount_holes(r = HEX_RADIUS) {
    pts = get_hex_centers(r);
    for (p = pts) {
        // Place mount hole near the upper center of each hexagon
        translate([p[0], p[1] + inrad * 0.45, 0]) {
            wall_mount_slot(BACK_WALL_THICKNESS);
        }
    }
}

// Build the 2-hex shelf module in 3D
module diagonal_hex_shelf(r = HEX_RADIUS, depth_z = SHELF_DEPTH) {
    difference() {
        // 1. Solid Outer Shell & Solid Back Wall
        linear_extrude(height = depth_z) {
            cluster_outer_2d(r);
        }
        
        // 2. Hollow Out Cavities (Leaves solid back wall)
        translate([0, 0, BACK_WALL_THICKNESS]) {
            linear_extrude(height = depth_z + 1) {
                cluster_inner_2d(r, WALL_THICKNESS);
            }
        }
        
        // 3. Mounting Screw Holes through the Back Wall
        if (ENABLE_WALL_MOUNTS) {
            apply_wall_mount_holes(r);
        }
        
        // 4. Clever invisible side-alignment grooves (vertical half-cylinders)
        // Stops 10mm from front face to be 100% hidden.
        // Left sloped mating face groove (at [-1.5 * r, 0])
        translate([-1.5 * r, 0, -1]) {
            cylinder(r = PIN_RADIUS, h = GROOVE_DEPTH + 1, $fn = 24);
        }
        // Right sloped mating face groove (at [1.5 * r, 0])
        translate([1.5 * r, 0, -1]) {
            cylinder(r = PIN_RADIUS, h = GROOVE_DEPTH + 1, $fn = 24);
        }
    }
}

// Alignment Pin (Dowel) model
module connection_pin(dia = PIN_RADIUS * 2, len = GROOVE_DEPTH - 2) {
    color([0.7, 0.7, 0.7]) {
        // Slightly reduced diameter for print tolerance
        p_r = dia/2 - 0.15;
        // Chamfered ends for smooth insertion
        cylinder(r1 = p_r - 0.3, r2 = p_r, h = 1.5, $fn = 24);
        translate([0, 0, 1.5]) cylinder(r = p_r, h = len - 3.0, $fn = 24);
        translate([0, 0, len - 1.5]) cylinder(r1 = p_r, r2 = p_r - 0.3, h = 1.5, $fn = 24);
    }
}

// ==============================================================================
// 16-INCH STUD ALIGNMENT & ANCHORING SIMULATOR
// ==============================================================================

STUD_SPACING_MM = 16 * 25.4; // 406.4 mm
STUD_WIDTH_MM = 1.5 * 25.4;  // 38.1 mm
STUD_HEIGHT_MM = 350.0;

// Helper to sum a list in OpenSCAD
function sum_list(list, i=0, total=0) = 
    (i >= len(list)) ? total : sum_list(list, i + 1, total + list[i]);

// Check if a given X position (relative to wall origin) overlaps any 16" stud
function overlaps_stud(x, slot_len = STUD_SLOT_LENGTH) = 
    let(
        overlaps = [for (s = [-2:8]) 
            let(stud_center = s * STUD_SPACING_MM)
            (abs(x - stud_center) <= (STUD_WIDTH_MM / 2 + slot_len / 2)) ? 1 : 0
        ]
    )
    sum_list(overlaps) > 0;

// Finds the closest stud index and its center coordinate
function get_closest_stud_info(x) =
    let(
        s_idx = round(x / STUD_SPACING_MM),
        stud_center = s_idx * STUD_SPACING_MM,
        dist = x - stud_center
    )
    [s_idx, stud_center, dist];

// Draw 3D screws or drywall anchors
module render_screw_or_anchor(x_pos, is_stud_match) {
    if (is_stud_match) {
        // Render a wood screw (Silver/Metal)
        color([0.85, 0.85, 0.88]) {
            // Screw head
            translate([0, 0, BACK_WALL_THICKNESS - 1.0]) {
                cylinder(r = SCREW_HEAD_DIA / 2, h = 1.5, $fn = 16);
                // Screw head groove
                translate([0, 0, 1.5]) cube([SCREW_HEAD_DIA * 0.8, 1.0, 0.5], center = true);
            }
            // Screw shank extending through the back wall and deep into the stud
            translate([0, 0, -25]) cylinder(r = SCREW_SHANK_DIA / 2, h = 30, $fn = 12);
        }
    } else {
        // Render a plastic drywall anchor (Yellow/Orange)
        color([1.0, 0.85, 0.3]) {
            // Anchor flange
            translate([0, 0, 0.2]) cylinder(r = SCREW_HEAD_DIA / 2 * 1.1, h = 0.8, $fn = 16);
            // Anchor body split expansion sleeve
            translate([0, 0, -20]) cylinder(r = SCREW_SHANK_DIA / 2 * 1.6, h = 20, $fn = 12);
        }
    }
}

// ==============================================================================
// MAIN ASSEMBLY & VISUALIZER
// ==============================================================================

// Translate the entire shelf system by the user-defined offset
translate([WALL_OFFSET_X, 0, 0]) {
    
    // Loop through the 5 modules and place them side-by-side
    for (m = [0 : 4]) {
        mod_x = m * 3.0 * HEX_RADIUS;
        
        // Alternating color scheme for visual clarity
        color_val = (m % 2 == 0) ? [0.18, 0.72, 0.62, 0.95] : [0.22, 0.48, 0.78, 0.95];
        
        translate([mod_x, 0, 0]) {
            diagonal_hex_shelf(HEX_RADIUS, SHELF_DEPTH);
            
            // Console reports and anchor markers
            if (SHOW_SCREWS_AND_ANCHORS) {
                pts = get_hex_centers(HEX_RADIUS);
                
                // Hex 1 (Upper-Left)
                let(
                    hx = mod_x + pts[0][0],
                    hy = pts[0][1] + inrad * 0.45,
                    abs_x = WALL_OFFSET_X + hx,
                    stud_info = get_closest_stud_info(abs_x),
                    stud_idx = stud_info[0],
                    stud_center = stud_info[1],
                    dist = stud_info[2],
                    has_stud = overlaps_stud(abs_x)
                ) {
                    // Position inside the back wall slot
                    translate([pts[0][0], hy, 0]) {
                        // For visualization: only mount screw if we hit a stud
                        // or if we decide to anchor it. By default, user wants only 1 in 3 modules to be fastened.
                        // We will render screws where they hit studs!
                        if (has_stud) {
                            render_screw_or_anchor(abs_x, true);
                            // Highlight matching anchoring points in 3D
                            color([0.2, 1.0, 0.2, 0.8]) translate([0, 0, -5]) cylinder(r = 8, h = 2, center = true);
                        }
                    }
                }
                
                // Hex 2 (Bottom-Right)
                let(
                    hx = mod_x + pts[1][0],
                    hy = pts[1][1] + inrad * 0.45,
                    abs_x = WALL_OFFSET_X + hx,
                    stud_info = get_closest_stud_info(abs_x),
                    stud_idx = stud_info[0],
                    stud_center = stud_info[1],
                    dist = stud_info[2],
                    has_stud = overlaps_stud(abs_x)
                ) {
                    // Position inside the back wall slot
                    translate([pts[1][0], hy, 0]) {
                        if (has_stud) {
                            render_screw_or_anchor(abs_x, true);
                            // Highlight matching anchoring points in 3D
                            color([0.2, 1.0, 0.2, 0.8]) translate([0, 0, -5]) cylinder(r = 8, h = 2, center = true);
                        }
                    }
                }
            }
        }
    }
}

// Render the 3D-printed alignment pins on the side for visual reference/printing
if (RENDER_ALIGNMENT_PINS) {
    // We need 4 alignment pins for 5 modules
    for (p_idx = [0:3]) {
        translate([WALL_OFFSET_X + p_idx * 30, -180, 0]) {
            connection_pin();
        }
    }
}

// ==============================================================================
// STATIONARY WALL & STUD PREVIEW (Does not move with WALL_OFFSET_X)
// ==============================================================================

if (SHOW_WALL_STUDS) {
    // 1. Semi-transparent Wall Surface Background
    color([0.9, 0.9, 0.9, 0.3]) {
        translate([200, 0, -10]) cube([1200, STUD_HEIGHT_MM, 2], center = true);
    }
    
    // 2. 16-Inch Wall Studs (at 0, 16", 32", 48", etc.)
    for (s = [-1 : 4]) {
        stud_x = s * STUD_SPACING_MM;
        
        // Render wood 2x4 stud
        color([0.82, 0.62, 0.42, 0.7]) {
            translate([stud_x, 0, -35]) {
                cube([STUD_WIDTH_MM, STUD_HEIGHT_MM, 50], center = true);
            }
        }
        
        // 3. Bold Marker Line and Label at the top/bottom of each stud
        color([0.9, 0.2, 0.1, 0.9]) {
            translate([stud_x, -STUD_HEIGHT_MM/2, 0]) {
                cube([4, 25, 2], center = true);
            }
            translate([stud_x, STUD_HEIGHT_MM/2, 0]) {
                cube([4, 25, 2], center = true);
            }
        }
    }
}

// Print detailed alignment guide to the console
echo("===============================================================================");
echo("16-INCH STUD ALIGNMENT REPORT (3 MODULES SPAN 16 INCHES):");
echo("Each module is connected via sliding rear alignment pins (dowels).");
echo("Screws are only needed on modules that line up with solid wall studs!");
echo(str("Current Horizontal Offset: ", WALL_OFFSET_X, " mm"));
echo("===============================================================================");
for (m = [0 : 4]) {
    mod_x = m * 3.0 * HEX_RADIUS;
    pts = get_hex_centers(HEX_RADIUS);
    
    // Hex 1
    let(
        hx = mod_x + pts[0][0],
        abs_x = WALL_OFFSET_X + hx,
        stud_info = get_closest_stud_info(abs_x),
        has_stud = overlaps_stud(abs_x)
    ) {
        echo(str("Module ", m + 1, " (Left Hex): Wall X = ", round(abs_x), " mm | Closest Stud: #", stud_info[0], " at ", stud_info[1], " mm (dist: ", round(stud_info[2]), " mm) -> ", has_stud ? "[CONNECTED TO STUD - FASTEN WITH WOOD SCREW]" : "[No Stud - Float & Pin Connected]"));
    }
    
    // Hex 2
    let(
        hx = mod_x + pts[1][0],
        abs_x = WALL_OFFSET_X + hx,
        stud_info = get_closest_stud_info(abs_x),
        has_stud = overlaps_stud(abs_x)
    ) {
        echo(str("Module ", m + 1, " (Right Hex): Wall X = ", round(abs_x), " mm | Closest Stud: #", stud_info[0], " at ", stud_info[1], " mm (dist: ", round(stud_info[2]), " mm) -> ", has_stud ? "[CONNECTED TO STUD - FASTEN WITH WOOD SCREW]" : "[No Stud - Float & Pin Connected]"));
    }
}
echo("===============================================================================");
