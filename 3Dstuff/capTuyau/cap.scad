// =============================================================================
//  cap.scad — Two-piece cap ring with dovetail joint
//  Units: inches
// =============================================================================
//
//  Ring: 9" outer diameter × 1" tall
//  Inner bore: 5.5" Ø at top, 6.5" Ø at bottom (tapered for easy installation)
//  Top exterior edge: 1/4" radius round-over
//
//  Split at Y = 0 into two equal semicircular halves.
//  ASSEMBLY: slide Half B DOWN (−Z) onto Half A.
//    • Half A carries dovetail tails  — narrow at base (Y=0), wider at tip (Y=−depth)
//    • Half B carries matching sockets — the narrow opening traps the wide tip,
//      locking the halves against radial (Y) separation without glue.
//  DISASSEMBLY: slide Half B back up (+Z).
//
//  Joint located on the mating faces within the bottom flange zone:
//    OD 9"  →  bottom ID 6.5"  →  radial width = 1.25"
//
//  Render control  (set PART):
//    0 = assembled view  (default)
//    1 = half A only  (tail half,   print with mating face on build plate)
//    2 = half B only  (socket half, print with mating face on build plate)
//    3 = both halves, separated 1" in Y  (pre-assembly view)
// =============================================================================

$fn = 256;

PART = 3;

// ── Ring dimensions ────────────────────────────────────────────────────────────

OD      = 9.0;
OR      = OD  / 2;       // outer radius = 4.5"

ID_top  = 5.5;
IR_top  = ID_top / 2;    // inner radius at top = 2.75"

ID_bot  = 6.5;
IR_bot  = ID_bot / 2;    // inner radius at bottom = 3.25"

H       = 1.0;
R_edge  = 0.25;           // top exterior edge round-over

// ── Dovetail parameters ────────────────────────────────────────────────────────
//
//  One tail/socket pair per mating-face side (±X), centred in the 1.25" flange.
//  Tail cross-section (XY plane, extruded in Z):
//
//    Y=0 (mating face):  |←  TG_w_base  →|   ← narrow base
//    Y=−TG_depth (tip):  |←── TG_w_tip ──→|  ← wider tip (locked by socket)
//
//  TG_w_tip > socket opening width → tail CANNOT pull out in +Y.

TG_depth  = 0.15;                              // tail protrusion in Y
TG_z      = 0.05;                              // tail Z bottom offset
TG_top    = 0.25;                              // plain (flat) zone at top of mating face
TG_h      = H - TG_z - TG_top;                // tail height = 0.70"
TG_w_base = 0.50;                              // tail width at mating face
TG_angle  = 14;                                // dovetail half-angle (°)
TG_w_tip  = TG_w_base                          // tail width at tip (wider)
            + 2 * TG_depth * tan(TG_angle);    // ≈ 0.575"
TG_r      = (IR_bot + OR) / 2;                // radial centre ≈ 3.875"
TG_clr    = 0.008;                             // assembly clearance (all sides)

eps = 0.01;

// ── 2D ring cross-section profile ─────────────────────────────────────────────
//  Trapezoid with quarter-circle arc at the top-outer corner.
module ring_profile(arc_n = 32) {
    polygon(concat(
        [[IR_bot, 0], [OR, 0]],
        [for (i = [0 : arc_n])
            [ OR - R_edge + R_edge * cos(90 * i / arc_n),
              H  - R_edge + R_edge * sin(90 * i / arc_n) ]],
        [[IR_top, H]]
    ));
}

module ring_solid() {
    rotate_extrude() ring_profile();
}

// ── Dovetail tail polygons (in XY, extruded in Z) ─────────────────────────────
module tail_poly_right() {
    hw_b = TG_w_base / 2;
    hw_t = TG_w_tip  / 2;
    polygon([
        [TG_r - hw_b,  0        ],   // base (narrow, at mating face)
        [TG_r + hw_b,  0        ],
        [TG_r + hw_t, -TG_depth ],   // tip  (wide, locked in socket)
        [TG_r - hw_t, -TG_depth ]
    ]);
}

module tail_poly_left() {
    hw_b = TG_w_base / 2;
    hw_t = TG_w_tip  / 2;
    polygon([
        [-(TG_r + hw_b),  0        ],
        [-(TG_r - hw_b),  0        ],
        [-(TG_r - hw_t), -TG_depth ],
        [-(TG_r + hw_t), -TG_depth ]
    ]);
}

// ── Dovetail socket polygons (TG_clr larger on every side) ───────────────────
module socket_poly_right() {
    c    = TG_clr;
    hw_b = TG_w_base / 2 + c;
    hw_t = TG_w_tip  / 2 + c;
    polygon([
        [TG_r - hw_b,  eps            ],
        [TG_r + hw_b,  eps            ],
        [TG_r + hw_t, -(TG_depth + c) ],
        [TG_r - hw_t, -(TG_depth + c) ]
    ]);
}

module socket_poly_left() {
    c    = TG_clr;
    hw_b = TG_w_base / 2 + c;
    hw_t = TG_w_tip  / 2 + c;
    polygon([
        [-(TG_r + hw_b),  eps            ],
        [-(TG_r - hw_b),  eps            ],
        [-(TG_r - hw_t), -(TG_depth + c) ],
        [-(TG_r + hw_t), -(TG_depth + c) ]
    ]);
}

// ── 3D tails — extruded in Z, offset to TG_z ─────────────────────────────────
module dovetail_tails() {
    translate([0, 0, TG_z]) {
        linear_extrude(height = TG_h) tail_poly_right();
        linear_extrude(height = TG_h) tail_poly_left();
    }
}

// ── 3D sockets — stops at TG_top from the top, matching the tail height ───────
module dovetail_sockets() {
    translate([0, 0, -eps])
        linear_extrude(height = H - TG_top + eps) {
            socket_poly_right();
            socket_poly_left();
        }
}

// ── Half-space helpers ─────────────────────────────────────────────────────────
module pos_y_box() {
    translate([-(OR + 1), 0, -eps])
        cube([2 * (OR + 1), OR + 1, H + 2 * eps]);
}
module neg_y_box() {
    translate([-(OR + 1), -(OR + 1), -eps])
        cube([2 * (OR + 1), OR + 1, H + 2 * eps]);
}

// ── Half-ring A — Y ≥ 0, carries dovetail tails ───────────────────────────────
module half_ring_A() {
    union() {
        intersection() { ring_solid(); pos_y_box(); }
        dovetail_tails();
    }
}

// ── Half-ring B — Y ≤ 0, carries dovetail sockets ────────────────────────────
module half_ring_B() {
    difference() {
        intersection() { ring_solid(); neg_y_box(); }
        dovetail_sockets();
    }
}

// ── Render ─────────────────────────────────────────────────────────────────────
//  All dimensions above are in inches.  scale(25.4) converts to millimetres
//  for OpenSCAD's native unit system.

scale(25.4) {
    if (PART == 0) {
        // Assembled view
        half_ring_A();
        half_ring_B();

    } else if (PART == 1) {
        // Half A for printing — mating face flat on build plate
        rotate([-90, 0, 0]) half_ring_A();

    } else if (PART == 2) {
        // Half B for printing — mating face flat on build plate
        rotate([90, 0, 180]) half_ring_B();

    } else if (PART == 3) {
        // Pre-assembly view — both halves separated by 1" in Y
        half_ring_A();
        translate([0, -1, 0]) half_ring_B();
    }
}
