// ============================================================
// Under-Desk Speaker Housing — Friction-Fit Monolithic Block
// ============================================================
// Speaker : 5" W × 4.5" H × 11" D  (front face = 5" × 4.5")
// Housing : 5" W × 5" H × 7" D
//
// Subtractive design — start from solid block, then remove:
//   1. Main speaker cavity (friction fit, 1/8" walls all around)
//   2. Back face: 5" Ø circle through the 1/8" back wall
//   3. Both side faces: random Ø circles through the side walls
//   4. Bottom plate: random Ø circles through the floor
//   5. Ceiling screw holes (hidden by the speaker once inserted)
//
// MOUNTING (screws fully concealed):
//   1. Hold housing against desk underside.
//   2. Reach inside cavity, drive 4 screws upward into desk wood.
//   3. Slide speaker in → screw heads disappear behind speaker.
//   Recommended: #6 × 1-1/2" flat-head wood screws.
//
// PRINT ORIENTATION:
//   Front face flat on build plate (cavity opening faces down).
//   No supports needed. Print height ≈ 178 mm (7").
//
// ============================================================

inch = 25.4;
$fn  = 64;

// ── Block ─────────────────────────────────────────────────────
BW = 5.0 * inch;   // width   (X, left ↔ right)   127.00 mm
BH = 5.0 * inch;   // height  (Z, up  ↔ down)      127.00 mm
BD = 7.0 * inch;   // depth   (Y, front ↔ back)    177.80 mm

// ── Cavity ────────────────────────────────────────────────────
//   Width : 5" − 2×(1/8") = 4.75"    ← 1/8" wall each side
//   Height: 4.6" centred in 5" block  ← ~0.2" margin top & bottom
//   Depth : 7" − 1/8"   = 6.875"     ← 1/8" back wall

SIDE_WALL = (1/8) * inch;          //  3.175 mm per side
BACK_WALL = (1/8) * inch;          //  3.175 mm

CAV_W = BW - 2 * SIDE_WALL;        //  4.75"  = 120.650 mm
CAV_H = 4.6  * inch;               //  4.6"   = 116.840 mm
CAV_D = BD   - BACK_WALL;          //  6.875" = 174.625 mm

CAV_Z = (BH - CAV_H) / 2;          //  floor/ceiling thickness ≈ 5.08 mm

// ── Mounting screws (ceiling, hidden by speaker) ──────────────
CEIL_T = CAV_Z;    // ceiling wall thickness [mm]
SC_D   = 3.5;      // shaft Ø  [mm]  (#6 wood screw)
SC_HD  = 7.0;      // head  Ø  [mm]
SC_CS  = CEIL_T - 1.0;  // countersink depth (1 mm land remains)
SC_NX  = 2;
SC_NY  = 2;

// ── Back hole ─────────────────────────────────────────────────
// 5" Ø circle centred on the 5"×5" back face (inscribed circle).
BACK_R = BW / 2;   // 63.5 mm = 2.5"

// ── Side hole grid ────────────────────────────────────────────
// Regular grid of circles through the side walls (X direction).
// Visible on both left and right exterior faces.
SH_R    = 15;   // hole radius [mm]  (larger)
SH_COLS =  5;   // columns along Y (depth direction)
SH_ROWS =  3;   // rows    along Z (height direction)

// ── Bottom hole grid ──────────────────────────────────────────
// Regular grid of circles through the floor plate (Z direction).
BH_R    = 13;   // hole radius [mm]  (larger)
BH_COLS =  3;   // columns along X (within cavity footprint)
BH_ROWS =  5;   // rows    along Y (within cavity footprint)

// ─────────────────────────────────────────────────────────────
// Helpers: cylinders aligned with X or Y axis.
module cyl_x(r, h) { rotate([0,  90, 0]) cylinder(r=r, h=h); }
module cyl_y(r, h) { rotate([-90, 0, 0]) cylinder(r=r, h=h); }

// ─────────────────────────────────────────────────────────────
// Countersink in the cavity ceiling.
// Local Z=0 = inner face (head recess); Z=CEIL_T = desk face.
module ceiling_screw() {
    cylinder(d=SC_D,  h=CEIL_T + 1);
    cylinder(d1=SC_HD, d2=SC_D, h=SC_CS);
}

// Grid of holes through the side walls (both sides at once).
module side_holes() {
    mg_y = SH_R + 10;
    mg_z = SH_R + 10;
    for (c = [0 : SH_COLS - 1])
        for (r = [0 : SH_ROWS - 1]) {
            y = mg_y + c * (BD - 2*mg_y) / (SH_COLS - 1);
            z = mg_z + r * (BH - 2*mg_z) / (SH_ROWS - 1);
            translate([-1, y, z])
                cyl_x(SH_R, BW + 2);
        }
}

// Grid of holes through the bottom floor plate.
// Constrained to the cavity footprint so side walls stay intact.
module bottom_holes() {
    x0 = SIDE_WALL + BH_R + 10;
    x1 = SIDE_WALL + CAV_W - BH_R - 10;
    y0 = BH_R + 10;
    y1 = CAV_D - BH_R - 10;
    for (c = [0 : BH_COLS - 1])
        for (r = [0 : BH_ROWS - 1]) {
            x = x0 + c * (x1 - x0) / (BH_COLS - 1);
            y = y0 + r * (y1 - y0) / (BH_ROWS - 1);
            translate([x, y, -1])
                cylinder(r=BH_R, h=CEIL_T + 2);
        }
}

// ─────────────────────────────────────────────────────────────
module housing() {
    // Screw holes are subtracted in a second pass so grid holes
    // can never accidentally close them off.
    cz      = CAV_Z + CAV_H;
    pitch_x = CAV_W / (SC_NX + 1);
    pitch_y = CAV_D / (SC_NY + 1);

    difference() {
        // ── Pass 1: block minus cavity, back hole, grid holes ──
        difference() {
            cube([BW, BD, BH]);

            // 1. Main speaker cavity
            translate([SIDE_WALL, -1, CAV_Z])
                cube([CAV_W, CAV_D + 1, CAV_H]);

            // 2. Back face — 5" Ø circle
            translate([BW/2, CAV_D - 1, BH/2])
                cyl_y(BACK_R, BACK_WALL + 2);

            // 3. Side hole grid
            side_holes();

            // 4. Bottom hole grid
            bottom_holes();
        }

        // ── Pass 2: screw holes punched last ───────────────────
        for (ix = [1 : SC_NX])
            for (iy = [1 : SC_NY])
                translate([SIDE_WALL + ix * pitch_x, iy * pitch_y, cz])
                    ceiling_screw();
    }
}

// ── Render ────────────────────────────────────────────────────
housing();

// ── Dimensions summary ────────────────────────────────────────
echo(str("Block          : ", BW/inch, "\" W × ", BH/inch,
         "\" H × ", BD/inch, "\" D"));
echo(str("Cavity         : ", CAV_W/inch, "\" W × ", CAV_H/inch,
         "\" H × ", CAV_D/inch, "\" D"));
echo(str("Side walls     : ", SIDE_WALL, " mm (1/8\")"));
echo(str("Back wall      : ", BACK_WALL, " mm (1/8\")  ← 5\" Ø hole cut here"));
echo(str("Floor/ceiling  : ", CAV_Z,     " mm (~0.2\") ← screws in ceiling"));
