// ============================================================
// Under-Desk Speaker Housing — Friction-Fit Monolithic Block
// ============================================================
// Empty volume : 181 mm W × 115 mm H × 160 mm D (open back)
//
// Subtractive design — start from solid block, then remove:
//   1. Main speaker cavity (friction fit, 1/8" walls each side)
//   2. Both side faces: regular grid of circles through side walls
//   3. Bottom plate: regular grid of circles through the floor
//   4. Ceiling screw holes (hidden by the speaker once inserted)
//
// MOUNTING (screws fully concealed):
//   1. Hold housing against desk underside.
//   2. Reach inside cavity, drive 4 screws upward into desk wood.
//   3. Slide speaker in → screw heads disappear behind speaker.
//   Recommended: #6 × 1-1/2" flat-head wood screws.
//
// PRINT ORIENTATION:
//   Front face flat on build plate (cavity opening faces down).
//   No supports needed.
//
// ============================================================

inch = 25.4;
$fn  = 64;

// ── Cavity (empty volume) ─────────────────────────────────────
CAV_W = 181;           // empty volume width  [mm]
CAV_H = 116;           // empty volume height [mm]
CAV_D = 160;           // empty volume depth  [mm]  (open back — no back wall)

// ── Block ─────────────────────────────────────────────────────
SIDE_WALL = (1/8) * inch;          //  3.175 mm per side
FLOOR_CEIL = 6.0;                  //  6 mm floor and ceiling (accommodates screw head)

BW = CAV_W + 2 * SIDE_WALL;        //  187.35 mm
BH = CAV_H + 2 * FLOOR_CEIL;       //  125.0  mm
BD = CAV_D;                         //  160.0  mm (no back wall)

CAV_Z = FLOOR_CEIL;                 //  floor/ceiling thickness

// ── Mounting screws (ceiling, hidden by speaker) ──────────────
CEIL_T    = CAV_Z;   // ceiling wall thickness [mm]
SC_D      = 3.5;     // shaft Ø        [mm]  (#6 wood screw)
SC_HEAD_D = 10.0;    // counterbore Ø  [mm]  (screw head is 7 mm, 10 mm for clearance)
SC_HEAD_H = 3.0;     // counterbore depth [mm]  (screw head height)
SC_NX  = 2;
SC_NY  = 2;

// ── Side hole grid ────────────────────────────────────────────
// Regular grid of circles through the side walls (X direction).
// Visible on both left and right exterior faces.
SH_R    = 6;   // hole radius [mm]  (larger)
SH_COLS =  10;   // columns along Y (depth direction)
SH_ROWS =  7;   // rows    along Z (height direction)

// ── Bottom hole grid ──────────────────────────────────────────
// Regular grid of circles through the floor plate (Z direction).
BH_R    = 15;   // hole radius [mm]  (larger)
BH_COLS =  5;   // columns along X (within cavity footprint)
BH_ROWS =  4;   // rows    along Y (within cavity footprint)

// ─────────────────────────────────────────────────────────────
// Helpers: cylinders aligned with X or Y axis.
module cyl_x(r, h) { rotate([0,  90, 0]) cylinder(r=r, h=h); }
module cyl_y(r, h) { rotate([-90, 0, 0]) cylinder(r=r, h=h); }

// ─────────────────────────────────────────────────────────────
// Counterbore screw hole in the cavity ceiling.
// Placed at Z = cavity top (cavity side faces down):
//   - counterbore (Ø SC_HEAD_D, SC_HEAD_H deep) at the cavity face
//   - shaft hole  (Ø SC_D) through the remaining wall into the desk
module ceiling_screw() {
    cylinder(d=SC_D,      h=CEIL_T + 1);      // shaft — full wall + 1 mm overshoot
    cylinder(d=SC_HEAD_D, h=SC_HEAD_H);        // counterbore for screw head
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
        // ── Pass 1: block minus cavity and grid holes ──────────
        difference() {
            cube([BW, BD, BH]);

            // 1. Main speaker cavity
            translate([SIDE_WALL, -1, CAV_Z])
                cube([CAV_W, CAV_D + 10, CAV_H]);

            // 2. Side hole grid
            side_holes();

            // 3. Bottom hole grid
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
echo(str("Block          : ", BW, " mm W × ", BH, " mm H × ", BD, " mm D"));
echo(str("Cavity         : ", CAV_W, " mm W × ", CAV_H, " mm H × ", CAV_D, " mm D  (open back)"));
echo(str("Side walls     : ", SIDE_WALL, " mm (1/8\")"));
echo(str("Floor/ceiling  : ", CAV_Z,     " mm ← screws in ceiling"));
