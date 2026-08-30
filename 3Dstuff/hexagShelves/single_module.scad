/* ==============================================================================
   DIAGONAL HEXAGONAL SHELF MODULE (SINGLE MODULE)
   ==============================================================================
   - A single module consisting of 2 hexagons touching on their sloped sides.
   - Diagonally arranged from upper-left to bottom-right.
   - Perfectly flat horizontal bottoms to store items.
   - Flat sides alternate by half a hexagon height.
   - Includes solid back wall and integrated adjustable mounting screw slots.
   - No tongue-and-groove or visible interlocking joints.
   - Sized so that 3 modules span exactly 16 inches horizontally (HEX_RADIUS = 45.155 mm).
   - Bounding box is ~158mm x 117mm, easily fitting onto a 26cm x 26cm bed!
   - Features clever, invisible, 3D-printer-friendly vertical half-cylindrical 
     grooves on the outer sloped mating faces. These form 4.0mm diameter pin holes
     when assembled side-by-side. Slide a 3D-printed pin from the back to align
     and structurally lock modules together without any visible connectors from the front.
   ============================================================================== */

// [HEXAGON DIMENSIONS]
// Circumradius of each hexagon (in mm). 45.155mm makes 3 modules span exactly 16 inches.
HEX_RADIUS = 45.155; // [35:0.1:80]

// Shelf depth extending from wall (in mm)
SHELF_DEPTH = 100.0; // [60:5:180]

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

// Resolve inradius
inrad = HEX_RADIUS * cos(30);

// Coordinates of the 2-Hex Diagonal Cluster
// Hex 1 is on upper-left, Hex 2 is on bottom-right
function get_hex_centers(r = HEX_RADIUS) = [
    [-0.75 * r, inrad / 2], // Upper-left
    [0.75 * r, -inrad / 2]  // Bottom-right
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

// Build the shelf in 3D
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

// Optional: Render a small helper visualizer of the sliding connection pin (dowel) next to the shelf
render_helper_pin = false;

if (render_helper_pin) {
    translate([HEX_RADIUS * 2, 0, 0]) {
        color([0.7, 0.7, 0.7]) {
            // Chamfered ends for smooth slide-in
            cylinder(r1 = PIN_RADIUS - 0.5, r2 = PIN_RADIUS - 0.15, h = 1.5, $fn = 20);
            translate([0, 0, 1.5]) cylinder(r = PIN_RADIUS - 0.15, h = GROOVE_DEPTH - 3.5, $fn = 20);
            translate([0, 0, GROOVE_DEPTH - 2]) cylinder(r1 = PIN_RADIUS - 0.15, r2 = PIN_RADIUS - 0.5, h = 1.5, $fn = 20);
        }
    }
}

// Render the single module
diagonal_hex_shelf();
