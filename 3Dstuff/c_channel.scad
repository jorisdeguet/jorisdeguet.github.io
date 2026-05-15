// ============================================================
//  C Channel – 11" long, groove 1/2" deep × 1/4" wide
//  Units: inches
//
//  Cross-section (end view, channel opens to +X):
//
//              ←────── 0.75" ──────→
//   0.75" ┌───────────────────────────┐  ← screwdriver indents (outer face)
//         │       top flange          │
//   0.50" └──┐                        │
//            │ web    groove  →       │  inner groove (0.5" × 0.25")
//   0.25" ┌──┘                        │
//         │      bottom flange        │  ← countersunk blind screw holes
//   0.00" └───────────────────────────┘
//         x=0                      x=0.75"
//
//  Features:
//    • wall_t = 1/4" (thick enough for countersink + blind hole)
//    • 3 countersunk blind screw holes in bottom flange (do NOT pierce through)
//    • Screwdriver access indents on outer top flange face (blind, 1/16" deep)
//    • Solid end cap at z = 0 closes the groove (acts as a stop)
//    • Mirrored second channel rendered above with groove_width gap
//      (screw holes on both outer faces, both end caps at z = 0)
// ============================================================

// OpenSCAD works in mm; this factor converts inch values to mm for the slicer.
inch = 25.4;

$fn = 32;

// ─── Primary dimensions ──────────────────────────────────────
length       = 11;      // Overall channel length
groove_depth = 0.5;     // Inner groove depth  = 1/2"
groove_width = 0.25;    // Inner groove width  = 1/4"
wall_t       = 0.25;    // Wall / flange thickness = 1/4"

// ─── Fastener parameters ─────────────────────────────────────
num_screws   = 3;
screw_dia    = 0.168;   // #8 clearance hole (~11/64")
cs_dia       = 0.320;   // Countersink opening diameter (fits #8 flat-head)
cs_angle     = 82;      // 82° — standard imperial flat-head countersink
indent_dia   = 0.375;   // Screwdriver access indent = 3/8"
indent_depth = 0.0625;  // Indent depth = 1/16" (blind — does NOT pierce flange)

// ─── Derived dimensions ──────────────────────────────────────
total_h = groove_width + 2 * wall_t;   // Cross-section height = 0.75"
total_d = wall_t + groove_depth;        // Cross-section depth  = 0.75"
screw_x = wall_t + groove_depth / 2;   // X-center of fasteners = 0.50"

// Countersink cone height from entry face to screw_dia
cs_h = (cs_dia - screw_dia) / (2 * tan(cs_angle / 2));

echo(str("Cross-section : ", total_d, "\" × ", total_h, "\""));
echo(str("Countersink depth : ", cs_h, "\"  Blind hole depth : ", hole_depth, "\""));
echo(str("Total hole depth  : ", cs_h + hole_depth, "\" (wall_t = ", wall_t, "\")"));
for (i = [1 : num_screws])
    echo(str("Screw ", i, " at Z = ", i * length / (num_screws + 1), "\""));

// ─── Modules ─────────────────────────────────────────────────

module c_profile() {
    cube([wall_t, total_h, length]);                     // web
    cube([total_d, wall_t, length]);                     // bottom flange
    translate([0, groove_width + wall_t, 0])
        cube([total_d, wall_t, length]);                 // top flange
}

// Solid end plate that closes the groove opening at z = 0 (stop)
module end_cap() {
    cube([total_d, total_h, wall_t]);
}

module channel() {
    difference() {
        union() {
            c_profile();
            end_cap();
        }

        for (i = [1 : num_screws]) {
            z = i * length / (num_screws + 1);

            // ── Bottom flange: through-hole + countersink on inner face ─────
            // Plain through-hole for the screw shank (enters from outer face)
            translate([screw_x, -0.01, z])
                rotate([-90, 0, 0])
                    cylinder(d = screw_dia, h = wall_t + 0.02);

            // Countersink opens on the INNER face (groove side) so the screw
            // head sits flush with the inner wall of the flange.
            translate([screw_x, wall_t + 0.01, z])
                rotate([90, 0, 0])
                    cylinder(d1 = cs_dia, d2 = screw_dia, h = cs_h + 0.01);

            // ── Top flange: screwdriver access indent ────────────────────
            // Shallow dimple on outer face so a bit can reach through the
            // open channel to drive the screw. Does NOT pierce through.
            translate([screw_x, total_h + 0.01, z])
                rotate([90, 0, 0])
                    cylinder(d = indent_dia, h = indent_depth + 0.02);
        }
    }
}

// ─── Render both channels (scaled from inches to mm) ────────────────────────
//  Channel 1 : y = 0     … 0.75"
//  gap       : y = 0.75" … 1.00"  (= groove_width)
//  Channel 2 : y = 1.00" … 1.75"  (mirrored — screw holes face outward)

pair_gap = groove_width;

scale([inch, inch, inch]) {
    // Channel 1 — as designed
    channel();

    // Channel 2 — mirrored in Y, translated so the two outer faces are symmetric
    // Both end caps remain at z = 0.
    translate([0, 2 * total_h + pair_gap, 0])
        mirror([0, 1, 0])
            channel();
}
