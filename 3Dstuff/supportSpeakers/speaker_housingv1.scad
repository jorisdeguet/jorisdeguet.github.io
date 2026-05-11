// ============================================================
// Under-Desk Speaker Housing — Friction-Fit Monolithic Block
// ============================================================
// Speaker : 5" W × 4.5" H × 11" D  (front face = 5" × 4.5")
// Housing : 5" W × 5" H × 7" D
//
// Design approach: start from a solid 5"×5"×7" block and
// subtract material.
//
//   Step 1 (this file) — Main speaker cavity:
//     • 1/8" side walls (left & right)
//     • ~0.2" top & bottom margins (cavity centred in height)
//     • 1/8" back wall
//     • Speaker slides in from the front face; friction holds it.
//
// MOUNTING (screws fully concealed):
//   The 4 mounting screw holes are on the INNER CEILING of the
//   cavity.  After positioning the housing against the desk:
//     1. Reach inside with a screwdriver.
//     2. Drive 4 screws upward through the ceiling into the desk.
//     3. Slide the speaker in → screw heads are completely hidden.
//   Recommended screw: #6 × 1-1/2" flat-head wood screw.
//
// PRINT ORIENTATION:
//   Stand the housing with its FRONT FACE flat on the build plate.
//   The cavity opening faces down — no internal supports needed.
//   The 7" depth becomes the print height (~178 mm).
//
// ============================================================

inch = 25.4;
$fn  = 64;

// ── Block ─────────────────────────────────────────────────────
BW = 5.0 * inch;   // block width   (X, left ↔ right)  127.00 mm
BH = 5.0 * inch;   // block height  (Z, up  ↔ down)    127.00 mm
BD = 7.0 * inch;   // block depth   (Y, front ↔ back)  177.80 mm

// ── Cavity ────────────────────────────────────────────────────
//   Width : 5" − 2×(1/8") = 4.75"    ← "1/8 on each side"
//   Height: 4.6" centred in 5" block  ← "centred, 4.6" high"
//   Depth : 7" − 1/8"   = 6.875"     ← "goes to 1/8 of the back"

SIDE_WALL = (1/8) * inch;          //  3.175 mm per side
BACK_WALL = (1/8) * inch;          //  3.175 mm back wall

CAV_W = BW - 2 * SIDE_WALL;        //  4.75"  = 120.650 mm
CAV_H = 4.6 * inch;                //  4.6"   = 116.840 mm
CAV_D = BD - BACK_WALL;            //  6.875" = 174.625 mm

// Equal top & bottom margins (cavity centred vertically)
CAV_Z = (BH - CAV_H) / 2;          //  ≈ 0.2"  = 5.080 mm

// ── Mounting screws ───────────────────────────────────────────
// Ceiling thickness = CAV_Z ≈ 5 mm.
// Countersink opens into the cavity; screw bites into desk above.
CEIL_T  = CAV_Z;          // ceiling wall thickness [mm]
SC_D    = 3.5;             // shaft diameter   [mm]  (#6 wood screw)
SC_HD   = 7.0;             // head  diameter   [mm]
SC_CS   = CEIL_T - 1.0;   // countersink depth (leaves 1 mm land)

// 2 × 2 grid, evenly distributed inside the cavity footprint
SC_NX = 2;
SC_NY = 2;

// ─────────────────────────────────────────────────────────────
// Countersink hole oriented upward (into the desk).
// Z = 0 here → inner cavity-ceiling face (wide / head recess).
// Z = CEIL_T  → outer top face (exits into desk wood).
module ceiling_screw() {
    cylinder(d=SC_D,  h=CEIL_T + 1);        // shaft through wall
    cylinder(d1=SC_HD, d2=SC_D, h=SC_CS);   // countersink cone
}

// ─────────────────────────────────────────────────────────────
module housing() {
    difference() {

        // ── Solid 5"×7"×5" block ───────────────────────────
        cube([BW, BD, BH]);

        // ── Main cavity ────────────────────────────────────
        // Opens at Y = 0 (front face). Speaker slides in along +Y.
        translate([SIDE_WALL, -1, CAV_Z])
            cube([CAV_W, CAV_D, CAV_H]);

        // ── Mounting screw holes in cavity ceiling ──────────
        // Inner ceiling face is at Z = CAV_Z + CAV_H.
        cz       = CAV_Z + CAV_H;
        pitch_x  = CAV_W  / (SC_NX + 1);
        pitch_y  = CAV_D  / (SC_NY + 1);

        for (ix = [1 : SC_NX])
            for (iy = [1 : SC_NY])
                translate([
                    SIDE_WALL + ix * pitch_x,
                    iy * pitch_y,
                    cz
                ])
                    ceiling_screw();
    }
}

// ── Render ───────────────────────────────────────────────────
housing();

// ── Console output ────────────────────────────────────────────
echo(str("─── Housing ──────────────────────────────────────────"));
echo(str("Block          : ", BW/inch, "\" W × ", BH/inch,
         "\" H × ", BD/inch, "\" D"));
echo(str("Cavity         : ", CAV_W/inch, "\" W × ", CAV_H/inch,
         "\" H × ", CAV_D/inch, "\" D"));
echo(str("Side walls     : ", SIDE_WALL, " mm (1/8\")"));
echo(str("Back wall      : ", BACK_WALL, " mm (1/8\")"));
echo(str("Top/bot margin : ", CAV_Z, " mm (~0.2\") — ceiling for screws"));
echo(str("──────────────────────────────────────────────────────"));
