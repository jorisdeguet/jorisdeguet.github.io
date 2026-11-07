// =============================================================================
//  lightning_sleeve.scad — two-part (clamshell) repair sleeve for an Apple
//                          Lightning cable whose head/strain-relief is breaking
//  Units: millimetres          Tested with OpenSCAD 2021.01
// =============================================================================
//
//  Idea: print two identical half-shells, fill one with hot glue, lay the
//  damaged connector + cable in it, add glue, close with the other half.
//  The sleeve stops FLUSH with the front face of the plug head, so the whole
//  metal tongue stays exposed and the plug still goes all the way into the
//  phone. Behind the head it continues as a tapered strain relief.
//
//  Axes (model space, "assembled" view):
//    +X  along the cable, away from the phone. x = 0 is the front face of the
//        plug head (where the metal tongue comes out); the tongue points to −X.
//    Y   across the WIDE side of the head.
//    Z   across the THIN side of the head. The sleeve is split on z = 0, so it
//        opens like a book along the thin axis.
//
//  The two halves are IDENTICAL (the design is symmetric about z = 0): print
//  two of the same part. Each half is printed SPLIT FACE DOWN on the bed: that
//  face is perfectly flat (good mating), the outside can taper freely, and the
//  only "overhang" is the roof of the head cavity, a short flat bridge
//  (~6–7 mm) that PLA handles without supports.
//
//  Alignment: the head itself keys the two halves (snug cavity in both), plus
//  two blind holes per half behind the head for pins cut from 1.75 mm
//  filament. Glue overflow: small vent holes over the head and a flared exit
//  around the cable at the rear; excess glue escapes there instead of
//  forcing the halves apart.
//
// -----------------------------------------------------------------------------
//  DIMENSIONS & SOURCES   [O] = official/published   [M] = measured/teardown,
//                         approximate — MEASURE YOUR OWN CABLE WITH CALIPERS
// -----------------------------------------------------------------------------
//  • Metal plug ("tongue"): ~6.7 mm wide × 1.5 mm thick                    [O]
//      Wikipedia, "Lightning (connector)" (from Apple's 2012 announcement
//      material). https://en.wikipedia.org/wiki/Lightning_(connector)
//    Protrusion length ~7.5–7.7 mm                                          [M]
//      (common teardown/caliper figure; only used for the ghost preview).
//  • Plug head overmold: Apple OEM ≈ 8.0 × 5.3–5.5 mm, ≈ 10 mm long          [M]
//      Third-party heads vary a lot (e.g. StarTech USBLT1MBS manual lists the
//      connector housing as 7.7 mm wide × 4.8 mm high).
//      https://manualmachine.com/startech/usblt1mbs/8144544-user-manual
//  • Max overmold size for case compatibility: Apple's "Accessory Design
//      Guidelines for Apple Devices" (public PDF, R22 2024-05) gives the case
//      opening / plug-overmold envelope in its Lightning chapter; the exact
//      figures were NOT verified for this file (the detailed Lightning
//      connector spec is MFi-licensee only).                                [O]
//      https://developer.apple.com/accessories/Accessory-Design-Guidelines.pdf
//  • Case keepout around the Lightning port: rounded (stadium) opening
//      13.65 mm wide × 6.85 mm high — figure given by the user.          [O]
//    The front `keepout_len` mm of the sleeve is clipped to that outline
//    (minus `keepout_margin`). The sleeve still wraps all FOUR sides there,
//    but around an Apple head (5.4 mm thick) only ~0.57 mm per side is left
//    on the thin faces, so in that zone the glue gap on the top/bottom drops
//    to `glue_ko` (0.1 mm) and the top/bottom skin is ~0.48 mm (4 layers at
//    0.12 mm). The sides keep the normal glue gap and wall.
//  • Cable OD: Apple USB-A/USB-C to Lightning ≈ 3.0 mm; braided third-party
//    cables 3.5–4.5 mm                                                      [M]
//  • Original rubber boot (strain relief): ≈ 4.2 mm tapering to cable size
//    over ≈ 8 mm on Apple cables                                            [M]
// =============================================================================

/* [Output] */
// "bottom", "top" (identical halves, print-ready), "both_print" (2 halves
// side by side), "assembled" (closed sleeve + ghost connector, preview only)
part = "both_print";   // [bottom, top, both_print, assembled]

/* [Connector — measure yours] */
head_w      = 8.0;   // [M] plug head width (wide side, Y)
head_t      = 5.4;   // [M] plug head thickness (thin side, Z)
head_len    = 10.0;  // [M] rigid head length, from tongue face to start of boot
head_r      = 1.2;   // [M] corner radius of the head cross-section
tongue_w    = 6.7;   // [O] metal tongue width  (ghost only)
tongue_t    = 1.5;   // [O] metal tongue thickness (ghost only)
tongue_len  = 7.6;   // [M] metal tongue protrusion (ghost only)
boot_d0     = 4.2;   // [M] rubber boot diameter where it leaves the head
boot_d1     = 3.3;   // [M] boot diameter at its end (set = cable_d if cut off)
boot_len    = 8.0;   // [M] boot length (0 if you cut the old boot away)
cable_d     = 3.2;   // [M] cable outer diameter

/* [Sleeve] */
wall        = 0.8;   // wall thickness around the head (keep thin for cases)
glue        = 0.35;  // glue clearance PER SIDE around head and boot
cable_glue  = 0.6;   // glue clearance PER SIDE around the cable (channel = cable_d + 2×this)
nose_r      = 3.0;   // outer corner radius of the head section (rounder = wider;
                     // width grows so the wall stays >= `wall`; max = half the thickness)
collar_len  = 3.0;   // full-size section behind the head (holds the pins)
relief_len  = 16.0;  // tapered strain relief length behind the collar
relief_end_wall = 0.9; // wall around the cable at the far end of the taper
front_setback = 0.0; // >0 stops the sleeve this far behind the head's front face

/* [Phone-case keepout] */
keepout_w      = 13.65; // case opening width (rounded ends)
keepout_t      = 6.85;  // case opening height
keepout_margin = 0.15;  // clearance per side inside the opening
keepout_len    = 6.0;   // how deep the head goes into the case opening (from the tongue face)
glue_ko        = 0.1;   // top/bottom glue gap inside the case zone (if needed to fit)
min_skin       = 0.4;   // thinnest acceptable top/bottom skin (warning below this)

/* [Pins & glue overflow] */
use_pins    = true;  // blind holes for pins cut from filament
pin_d       = 1.75;  // pin diameter (1.75 mm filament)
pin_clear   = 0.15;  // extra hole diameter
pin_depth   = 2.4;   // hole depth in each half
vents       = 2;     // vent holes over the head, per half (0 = none)
vent_d      = 1.2;   // vent hole diameter
rear_flare  = 0.6;   // extra radius at the cable exit (glue escapes there)

/* [Hidden] */
$fn  = 48;
eps  = 0.01;

// ---------------------------------------------------------------- derived ---
cav_w   = head_w + 2*glue;              // head cavity
cav_t   = head_t + 2*glue;
cav_r   = head_r + glue;
out_t   = cav_t + 2*wall;
out_r   = min(max(nose_r, cav_r + wall), out_t/2 - eps);  // rounded outer corners
// corner circles share their centre line with the cavity corners → wall >= `wall`
out_w   = 2*(cav_w/2 - cav_r + out_r);  // outer envelope around the head
x0      = front_setback;                // front edge of the sleeve
x_head  = head_len;                     // end of rigid head
x_col   = head_len + collar_len;        // end of collar
x_end   = x_col + relief_len;           // rear end of the sleeve
end_d   = cable_d + 2*cable_glue + 2*relief_end_wall;
cab_cd  = cable_d + 2*cable_glue;       // cable channel diameter
pin_hd  = pin_d + pin_clear;
boot_cd0 = (boot_len > 0 ? boot_d0 : cable_d) + 2*glue;
// pin position: halfway between the boot cavity and the outer side
pin_x   = head_len + collar_len/2;
pin_y   = (boot_cd0/2 + out_w/2) / 2;
pin_margin = min(pin_y - pin_hd/2 - boot_cd0/2, out_w/2 - pin_y - pin_hd/2);
pin_h   = min(pin_depth, out_t/2 - 0.6);
ko_w    = keepout_w - 2*keepout_margin;   // usable keepout outline
ko_t    = keepout_t - 2*keepout_margin;
ko_x    = x0 + keepout_len;               // end of the clipped zone
ko_thin = keepout_len > 0 && min(out_t, ko_t)/2 - cav_t/2 < min_skin;
cav_t_ko = ko_thin ? head_t + 2*glue_ko : cav_t;  // head cavity height in the zone
skin_ko = min(out_t, ko_t)/2 - cav_t_ko/2;        // top/bottom skin in the zone

echo(str("Sleeve outer size around head: ", out_w, " x ", out_t,
         " mm (W x T); total length ", x_end - x0, " mm"));
if (keepout_len > 0)
    echo(str("Case zone (first ", keepout_len, " mm): ",
             min(out_w, ko_w), " x ", min(out_t, ko_t), " mm",
             ", top/bottom skin ", skin_ko, " mm",
             ko_thin ? str(" (top/bottom glue gap reduced to ", glue_ko, " mm)") : ""));
if (keepout_len > 0 && skin_ko < min_skin)
    echo("WARNING: top/bottom skin in the case zone is thinner than min_skin — head too thick for the case opening?");
if (out_w > ko_w)
    echo("WARNING: sleeve wider than the case opening — reduce wall/glue");
if (use_pins) {
    echo(str("Cut 2 pins from ", pin_d, " mm filament, length ",
             2*pin_h - 0.4, " mm"));
    if (pin_margin < 0.3)
        echo("WARNING: pin holes are too close to a wall — increase collar_len/wall or set use_pins=false");
}
assert(cav_r < min(cav_w, cav_t)/2, "head_r too large for head size");
assert(x0 < head_len, "front_setback must be shorter than the head");

// ---------------------------------------------------------------- helpers ---
// Rounded-rectangle cross-section in the YZ plane, extruded along +X.
module rrect_x(w, t, r, len) {
    rr = min(r, min(w, t)/2 - eps);
    rotate([0, 90, 0])
        linear_extrude(len)
            offset(r = rr) square([t - 2*rr, w - 2*rr], center = true);
}
// Circular cross-section along +X.
module disc_x(d, len) { rotate([0, 90, 0]) cylinder(d = d, h = len); }

// ------------------------------------------------------------------ solids ---
// Stadium (rounded-end) outline in the YZ plane, extruded along +X.
module stadium_x(w, t, len) {
    rotate([0, 90, 0]) linear_extrude(len)
        hull() for (s = [-1, 1]) translate([0, s*(w - t)/2]) circle(d = t);
}

// Outer envelope, clipped to the case keepout over the first keepout_len mm.
module outer_solid() {
    intersection() {
        outer_raw();
        union() {
            translate([x0 - 1, 0, 0]) stadium_x(ko_w, ko_t, keepout_len + 1);
            translate([ko_x, -50, -50]) cube(100);
        }
    }
}

module outer_raw() {
    // head + collar: constant section
    translate([x0, 0, 0]) rrect_x(out_w, out_t, out_r, x_col - x0);
    // tapered strain relief
    hull() {
        translate([x_col - eps, 0, 0]) rrect_x(out_w, out_t, out_r, eps);
        translate([x_end - eps, 0, 0]) disc_x(end_d, eps);
    }
}

module cavity() {
    // head, open at the front; flatter in the case zone if needed
    x_ko = min(ko_x, x_head);
    translate([-1, 0, 0]) rrect_x(cav_w, cav_t_ko, cav_r, x_ko + 1);
    translate([x_ko - eps, 0, 0]) rrect_x(cav_w, cav_t, cav_r, x_head - x_ko + eps);
    // old rubber boot (cone)
    if (boot_len > 0)
        hull() {
            translate([x_head - eps, 0, 0]) disc_x(boot_d0 + 2*glue, eps);
            translate([x_head + boot_len, 0, 0]) disc_x(boot_d1 + 2*glue, eps);
        }
    // cable channel, out through the back
    translate([x_head, 0, 0]) disc_x(cab_cd, x_end - x_head + 1);
    // flared rear exit for glue overflow
    flare_len = min(2.5, relief_len/2);
    hull() {
        translate([x_end - flare_len, 0, 0]) disc_x(cab_cd, eps);
        translate([x_end, 0, 0]) disc_x(cab_cd + 2*rear_flare, eps);
    }
    translate([x_end - eps, 0, 0]) disc_x(cab_cd + 2*rear_flare, 1);
}

module pin_holes() {
    if (use_pins)
        for (s = [-1, 1])
            translate([pin_x, s*pin_y, -pin_h])
                cylinder(d = pin_hd, h = 2*pin_h, $fn = 24);
}

vx0 = ko_thin ? min(ko_x, head_len - 2) : x0;   // keep vents out of the thin skin
module vent_holes() {
    if (vents > 0 && vx0 < head_len - 1)
        for (i = [1 : vents])
            translate([vx0 + (head_len - vx0) * i/(vents + 1), 0, -out_t])
                cylinder(d = vent_d, h = 2*out_t, $fn = 16);
}

module sleeve_full() {
    difference() {
        outer_solid();
        cavity();
        pin_holes();
        vent_holes();
    }
}

// Upper half (z >= 0), in model position.
module half_upper() {
    intersection() {
        sleeve_full();
        translate([x0 - 1, -out_w, 0]) cube([x_end - x0 + 2, 2*out_w, out_t]);
    }
}

// One half, print-ready: the upper half already has its flat split face on
// z = 0 and its outside facing up, i.e. split face down on the bed.
module half_print() { half_upper(); }

// ------------------------------------------------------------ ghost cable ---
module ghost_connector() {
    color("silver") translate([-tongue_len, -tongue_w/2, -tongue_t/2])
        cube([tongue_len, tongue_w, tongue_t]);
    color("white") {
        rrect_x(head_w, head_t, head_r, head_len);
        if (boot_len > 0)
            hull() {
                translate([head_len - eps, 0, 0]) disc_x(boot_d0, eps);
                translate([head_len + boot_len, 0, 0]) disc_x(boot_d1, eps);
            }
        translate([head_len, 0, 0]) disc_x(cable_d, x_end - head_len + 15);
    }
}

// ------------------------------------------------------------------ output ---
gap = 4;   // spacing between parts on the bed

if (part == "bottom" || part == "top") {
    half_print();
} else if (part == "both_print") {
    translate([0, -(out_w/2 + gap/2), 0]) half_print();
    translate([0,  (out_w/2 + gap/2), 0]) half_print();
} else if (part == "assembled") {
    color("orange", 0.9) half_upper();
    color("gold", 0.9) mirror([0, 0, 1]) half_upper();
    %ghost_connector();
} else {
    echo(str("Unknown part = \"", part, "\""));
}
