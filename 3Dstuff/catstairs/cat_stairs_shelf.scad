// =============================================================================
// PARAMETRIC MONOLITHIC CAT STAIR SHELF (30cm × 21cm)
// WITH 30° ANGLED SIDE-ACCESS SCREW HOLES & STUD-ALIGNABLE "SQUARES"
// =============================================================================
// Designed for wall-mounted cat stairs / feline agility climbing steps.
//
// Key Specifications:
// • Single Monolithic Piece: Shelf plate + two underneath support squares ("équerres")
//   fused into a unified, ultra-sturdy, ready-to-print 3D solid.
// • Shelf Dimensions: 30 cm wide (300 mm) × 21 cm deep (210 mm).
// • Compact Square Supports: Shorter height (120 mm default) with heavy-duty
//   triangular truss gusset design.
// • Stud Alignment: Bracket positions along the width are parametric percentages
//   (e.g., 20% and 80%) to align with wall studs.
// • Angled Screwdriver Access (30°): Exactly two wall screw holes per bracket,
//   angled at 30° outward to the sides so you can easily drive the screws with
//   a drill or screwdriver from the unobstructed lateral sides!
// • Cat Comfort: Smooth rounded front corners + top recessed pocket for traction pad.
// =============================================================================

/* [Visibility & Rendering Modes] */
// Select which part to preview or export to STL/3MF
render_mode = "monolithic"; // [monolithic: Single Monolithic Piece (Unified Solid), assembled: Color-Coded Preview, shelf_only: Shelf Top Only, bracket_left: Left Bracket Only, bracket_right: Right Bracket Only, both_brackets: Both Brackets Flat for Print]

// Explode distance for visual inspection in assembled mode (mm)
explode_distance = 0; // [0:100]

/* [Shelf Dimensions] */
// Total shelf width along the wall (mm) - 30 cm default
shelf_width = 250; // [100:600]

// Total shelf depth extending out from the wall (mm) - 21 cm default
shelf_depth = 210; // [100:400]

// Thickness of the shelf plate (mm)
shelf_thickness = 8; // [6:25]

// Radius of the front rounded corners for cat safety (mm)
front_corner_radius = 10; // [0:60]

/* [Square Bracket Positions (% of Shelf Width)] */
// Left bracket ("Square 1") position as % of width (0% = left edge, 100% = right edge)
bracket_1_pos_pct = 10; // [0:100]

// Right bracket ("Square 2") position as % of width (0% = left edge, 100% = right edge)
bracket_2_pos_pct = 60; // [0:100]

/* [Square Bracket Dimensions & Style] */
// Vertical height of bracket against the wall (mm) - compact / shorter
bracket_height = 100; // [60:250]

// Horizontal depth of bracket supporting the shelf (mm)
bracket_depth = 120; // [60:350]

// Lateral thickness / width of each bracket (mm)
bracket_thickness = 15; // [16:50]

// Beam width of the vertical and horizontal structural legs (mm)
leg_beam_width = 10; // [14:40]

// Width of the diagonal truss strut (mm)
strut_beam_width = 10; // [12:35]

// Radius of the inner corner stress-relief fillet (mm)
inner_fillet_radius = 10; // [5:50]

// Bracket style
bracket_style = "truss"; // [truss: Reinforced Diagonal Truss with Arch Cutout, solid_gusset: Solid Gusset Plate]

/* [30° Angled Fastener Holes (2 Per Bracket)] */
// Angle of screw holes outward to the sides (degrees) - allows easy screwdriver access
screw_side_angle = 20; // [15:45]

// Wall screw shank clearance hole diameter (mm) - 4.8mm for #8 / #10 / 4-5mm screws
wall_screw_dia = 4.8;

// Screw head / bit-holder counterbore diameter (mm)
counterbore_dia = 10.5;

// Distance from top of bracket to top screw hole (mm)
top_screw_offset_z = 24; // [15:40]

// Distance from bottom of bracket to bottom screw hole (mm)
bottom_screw_offset_z = 24; // [15:40]

// Solid plastic thickness between screw head shoulder and wall face (mm)
screw_shoulder_depth = 10.0; // [6:18]

/* [Cat Comfort & Traction] */
// Add recessed pocket on top for adhesive carpet / sisal / felt pad
add_carpet_recess = true;

// Depth of the carpet recess pocket (mm)
carpet_recess_depth = 2.5; // [1:6]

// Margin around the carpet recess from outer shelf edges (mm)
carpet_margin = 10; // [5:40]

/* [Print & Quality Settings] */
$fn = 64;


// =============================================================================
// DERIVED DIMENSIONS & CONSOLE CALCULATIONS
// =============================================================================

// Absolute X coordinates for Left and Right Brackets
b1_x = (bracket_1_pos_pct / 100) * shelf_width;
b2_x = (bracket_2_pos_pct / 100) * shelf_width;
bracket_span_mm = abs(b2_x - b1_x);
bracket_span_in = bracket_span_mm / 25.4;

echo("===============================================================");
echo("MONOLITHIC CAT STAIRS SHELF SPECIFICATIONS:");
echo(str("• Shelf dimensions       : ", shelf_width, " mm W × ", shelf_depth, " mm D × ", shelf_thickness, " mm T (", shelf_width/10, " × ", shelf_depth/10, " cm)"));
echo(str("• Bracket 1 (Left)       : X = ", b1_x, " mm (", bracket_1_pos_pct, "% of width)"));
echo(str("• Bracket 2 (Right)      : X = ", b2_x, " mm (", bracket_2_pos_pct, "% of width)"));
echo(str("• Stud / Bracket Span    : ", bracket_span_mm, " mm (", bracket_span_in, " inches)"));
echo(str("• Bracket Height × Depth : ", bracket_height, " mm H × ", bracket_depth, " mm D × ", bracket_thickness, " mm T"));
echo(str("• Screw Angle            : ", screw_side_angle, "° from lateral sides (2 holes per bracket)"));
echo("===============================================================");


// =============================================================================
// 2D PROFILES
// =============================================================================

// Shelf 2D outline (flat back against wall, smooth rounded front corners)
module shelf_2d(w, d, r_front) {
    hull() {
        translate([0, 0]) square([0.1, 0.1]);
        translate([w - 0.1, 0]) square([0.1, 0.1]);
        translate([r_front, d - r_front]) circle(r = r_front);
        translate([w - r_front, d - r_front]) circle(r = r_front);
    }
}

// 2D Bracket Profile (in Y-Z coordinate plane: Y forward from wall, Z downward)
module bracket_2d(H, D, leg_w, strut_w, r_fillet, style) {
    tip_r = 6;
    difference() {
        // Outer right-triangle envelope with rounded front and bottom corners
        hull() {
            translate([0, -tip_r]) square([0.1, tip_r]);
            translate([0, 0]) square([tip_r, 0.1]);
            translate([D - tip_r, -tip_r]) circle(r = tip_r);
            translate([tip_r, -H + tip_r]) circle(r = tip_r);
        }

        // Inner triangular truss window
        if (style == "truss") {
            p_corner = [leg_w + r_fillet, -leg_w - r_fillet];
            p_front  = [D - strut_w * 2.0, -leg_w];
            p_bottom = [leg_w, -H + strut_w * 2.0];

            offset(r = 8) offset(delta = -8) {
                polygon(points = [
                    p_corner,
                    p_front,
                    p_bottom
                ]);
            }
        }
    }
}


// =============================================================================
// 3D BRACKET MODULE ("SQUARE" / ÉQUERRE) WITH 30° ANGLED SIDE SCREW HOLES
// =============================================================================
module bracket_3d(is_left = true) {
    // Left bracket angles outward to the left (+angle in rotation);
    // Right bracket angles outward to the right (-angle in rotation).
    side_sign = is_left ? 1 : -1;

    difference() {
        // Main bracket solid body (centered on X=0)
        translate([-bracket_thickness / 2, 0, 0])
        rotate([90, 0, 90])
        linear_extrude(height = bracket_thickness, convexity = 10)
        bracket_2d(bracket_height, bracket_depth, leg_beam_width, strut_beam_width, inner_fillet_radius, bracket_style);

        // --- 2 ANGLED WALL SCREW HOLES (30° FROM SIDE) ---
        // Z coordinates for Top and Bottom screws
        z_screws = [-top_screw_offset_z, -(bracket_height - bottom_screw_offset_z)];

        for (z_pos = z_screws) {
            translate([0, 0, z_pos])
            rotate([0, 0, side_sign * screw_side_angle])
            rotate([-90, 0, 0]) {
                // 1. Screw shank clearance hole exiting into wall at Y=0
                // Drilled from t = -2 (past wall face) to shoulder depth
                translate([0, 0, -2])
                    cylinder(d = wall_screw_dia, h = screw_shoulder_depth + 2.05);

                // 2. Countersink / transitional cone at shoulder
                translate([0, 0, screw_shoulder_depth])
                    cylinder(d1 = wall_screw_dia, d2 = counterbore_dia, h = (counterbore_dia - wall_screw_dia) / 2);

                // 3. Counterbore / screwdriver clearance tunnel exiting the side of the bracket
                translate([0, 0, screw_shoulder_depth + (counterbore_dia - wall_screw_dia) / 2])
                    cylinder(d = counterbore_dia, h = 250);
            }
        }
    }
}


// =============================================================================
// 3D SHELF MODULE
// =============================================================================
module shelf_plate_3d() {
    difference() {
        // Base shelf solid
        linear_extrude(height = shelf_thickness, convexity = 10)
        shelf_2d(shelf_width, shelf_depth, front_corner_radius);

        // Top recessed tray for carpet / sisal / felt pad
        if (add_carpet_recess) {
            c_w = shelf_width - 2 * carpet_margin;
            c_d = shelf_depth - carpet_margin - 8;
            c_r = max(2, front_corner_radius - carpet_margin);

            translate([carpet_margin, 8, shelf_thickness - carpet_recess_depth])
            linear_extrude(height = carpet_recess_depth + 0.2)
            shelf_2d(c_w, c_d, c_r);
        }
    }
}


// =============================================================================
// COMPLETE MONOLITHIC SOLID & RENDERING SWITCH
// =============================================================================

// Unified single-piece model
module monolithic_shelf() {
    union() {
        // Shelf plate at top (Z = 0 to shelf_thickness)
        shelf_plate_3d();

        // Left Square Bracket (welded seamlessly underneath)
        translate([b1_x, 0, 0])
        bracket_3d(is_left = true);

        // Right Square Bracket (welded seamlessly underneath)
        translate([b2_x, 0, 0])
        bracket_3d(is_left = false);
    }
}

// Render mode selector
if (render_mode == "monolithic") {
    // Single monolithic solid (ready for printing / slicing)
    color([0.28, 0.60, 0.85])
    monolithic_shelf();

} else if (render_mode == "assembled") {
    // Two-tone color preview with optional explode
    translate([0, 0, explode_distance])
    color([0.88, 0.72, 0.52]) // Wood tone shelf
    shelf_plate_3d();

    translate([b1_x, 0, 0])
    color([0.22, 0.48, 0.78]) // Blue bracket
    bracket_3d(is_left = true);

    translate([b2_x, 0, 0])
    color([0.22, 0.48, 0.78]) // Blue bracket
    bracket_3d(is_left = false);

} else if (render_mode == "shelf_only") {
    shelf_plate_3d();

} else if (render_mode == "bracket_left") {
    // Left bracket laid flat on side for printing
    translate([0, 0, bracket_thickness / 2])
    rotate([0, -90, 0])
    bracket_3d(is_left = true);

} else if (render_mode == "bracket_right") {
    // Right bracket laid flat on side for printing
    translate([0, 0, bracket_thickness / 2])
    rotate([0, -90, 0])
    bracket_3d(is_left = false);

} else if (render_mode == "both_brackets") {
    // Both brackets flat side-by-side on print bed
    translate([0, 0, bracket_thickness / 2])
    rotate([0, -90, 0])
    bracket_3d(is_left = true);

    translate([bracket_height + 20, 0, bracket_thickness / 2])
    rotate([0, -90, 0])
    bracket_3d(is_left = false);
}
