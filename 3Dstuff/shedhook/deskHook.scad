// Ceiling hook — parametric arch hook.
//
// Shape (side profile, extruded plate_width_mm in Y):
//
//         ╭────╮
//        ╱      ╲   ← half-circle arch
//       │        │
//  post │        │ post
//  ─────┴────────┴─── plate
//
// Two posts rise from each end of the plate.
// A perfect semicircle arch connects the top of the left post to the
// top of the right post, arching upward over the centre.
// Screw hole goes through the plate thickness (Z) at the plate centre.

$fn = 64;

// ── Parameters ───────────────────────────────────────────────────────────────
plate_length_mm = 50;
plate_width_mm  =  5;   // extrusion depth (Y)
plate_thick_mm  =  5;
post_height_mm  = 40;   // height of each post above the plate top surface
arch_thick_mm   =  5;   // cross-section of the arch arm

screw_dia_mm    =  2.5; // clearance hole through plate width (Y, left→right)
gusset_mm       = 15;   // leg length of the 45° gusset triangle at each post base

// ── Arch geometry ─────────────────────────────────────────────────────────────
// Arch centreline endpoints = centres of the two post top edges:
//   Left  post top centre: (plate_thick/2,              plate_thick + post_height)
//   Right post top centre: (plate_length - plate_thick/2, plate_thick + post_height)
//
// A perfect semicircle (180°) sits above those two points.

arch_cx = plate_length_mm / 2;                        // midpoint of the span
arch_cy = plate_thick_mm + post_height_mm;            // height of post tops
arch_r  = (plate_length_mm - plate_thick_mm) / 2;    // = half the inner span
// Arc goes from 180° (left post top) counterclockwise through 90° (crown)
// to 0° (right post top).
a_start = 165;
a_end   =   0;

echo(str("Arch: centre=(", arch_cx, ",", arch_cy, ")  R=", arch_r, " mm"));
echo(str("Crown height: ", arch_cy + arch_r, " mm above print bed"));

// ── 2D arc tube — hull of consecutive discs along the arc centreline ──────────
module arc_tube_2d(cx, cy, R, a1, a2, thick, steps = 48) {
    r = thick / 2;
    for (i = [0 : steps - 1]) {
        a  = a1 + i       * (a2 - a1) / steps;
        an = a1 + (i + 1) * (a2 - a1) / steps;
        hull() {
            translate([cx + R*cos(a),  cy + R*sin(a)])  circle(r = r, $fn = 8);
            translate([cx + R*cos(an), cy + R*sin(an)]) circle(r = r, $fn = 8);
        }
    }
}

// ── 2D side profile (X = plate length, Y = height) ───────────────────────────
module hook_profile_2d() {
    union() {
        // Plate
        square([plate_length_mm, plate_thick_mm]);

        // Left post
        //square([plate_thick_mm, plate_thick_mm + post_height_mm]);

        // Right post
        translate([plate_length_mm - plate_thick_mm, 0])
            square([plate_thick_mm, plate_thick_mm + post_height_mm]);

        // 45° gusset — inner corner of right post / plate junction
        translate([plate_length_mm - plate_thick_mm, plate_thick_mm])
            polygon([[0, 0],
                     [-gusset_mm, 0],
                     [0, gusset_mm]]);

        // Semicircle arch
        arc_tube_2d(arch_cx, arch_cy, arch_r, a_start, a_end, arch_thick_mm);
    }
}

// ── 3D model ──────────────────────────────────────────────────────────────────
difference() {
    linear_extrude(height = plate_width_mm, convexity = 6)
        hook_profile_2d();

    // Screw clearance hole through the plate width (Y, left→right), centred on
    // the plate length and thickness.
    translate([plate_length_mm / 2, -0.01, plate_thick_mm / 2])
        rotate([-90, 0, 0])
            cylinder(d = screw_dia_mm, h = plate_width_mm + 0.02);
}


