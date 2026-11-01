// =============================================================================
//  bit_holder.scad — Workbench block for drill bits, screwdriver bits,
//                    spade bits and oscillating multi-tool (Dremel) blades
//  Units: millimetres   (block height = 1" = 25.4 mm)
// =============================================================================
//
//  Layout, front (−Y) to back (+Y):
//    row 1  twist drill bits      round holes
//    row 2  screwdriver bits      1/4" hex holes  (Phillips, square, flat)
//    row 3  spade bits            1/4" hex holes, wider pitch
//    row 4  multi-tool blades     thin vertical slots
//
//  Each opening gets a short label ENGRAVED in the top face, just in front of
//  it. Edit the inventory lists below; the block resizes itself.
//
//  Print flat, bottom face on the bed, no supports needed.
// =============================================================================

$fn = 64;

// ── Block ─────────────────────────────────────────────────────────────────────
block_h       = 25.4;   // 1 inch
floor_t       = 3.0;    // solid material left under every opening
margin        = 6;      // outer border, left/right/front/back
corner_r      = 4;      // vertical-edge rounding
row_gap       = 3;      // extra space between rows

// ── Labels ────────────────────────────────────────────────────────────────────
font_name     = "Liberation Sans:style=Bold";
text_size     = 3.6;    // cap height ≈ text_size
engrave_depth = 0.6;
label_gap     = 1.5;    // distance between a hole's front edge and its label
char_w        = 0.68;   // rough width of one character, × text_size (for pitch)

// ── Fits ──────────────────────────────────────────────────────────────────────
round_clear   = 0.4;    // added to drill-bit diameter
hex_af        = 6.35;   // 1/4" hex across flats
hex_clear     = 0.35;   // added to across-flats
slot_clear    = 0.6;    // added to blade thickness and width

// ── Inventory ─────────────────────────────────────────────────────────────────
//  PLACEHOLDERS — replace with the real inventory.
//  Drill bits: [label, shank diameter in mm]
in = 25.4;
drills = [
    ["1/16",  1/16 * in],
    ["3/32",  3/32 * in],
    ["1/8",   1/8  * in],
    ["5/32",  5/32 * in],
    ["3/16",  3/16 * in],
    ["7/32",  7/32 * in],
    ["1/4",   1/4  * in],
    ["5/16",  5/16 * in],
    ["3/8",   3/8  * in],
];

//  Screwdriver bits (all 1/4" hex): label only
hex_bits = ["PH1", "PH2", "PH3", "SQ1", "SQ2", "SQ3", "SL4", "SL6"];

//  Spade bits (1/4" hex shank): label only
spade_bits = ["1/2", "5/8", "3/4", "7/8", "1", "1¼"];
spade_pitch = 16;       // centre-to-centre; turn the paddles front-to-back

//  Multi-tool blades: [label, blade width at the mount (mm), thickness (mm)]
blades = [
    ["WOOD",  34, 1.0],
    ["METAL", 34, 1.0],
    ["PLUNGE",22, 1.0],
    ["SCRAPE",45, 1.2],
];
blade_pitch_extra = 4;  // gap between neighbouring slots along the row

// ── Derived sizes ─────────────────────────────────────────────────────────────
function label_w(s)  = len(s) * char_w * text_size;
function sum(v, i=0) = i >= len(v) ? 0 : v[i] + sum(v, i + 1);
function prefix(v, n) = n <= 0 ? 0 : v[n - 1] + prefix(v, n - 1);

hex_hole_af = hex_af + hex_clear;
hex_hole_d  = hex_hole_af / cos(30);            // across corners
wall        = 2.5;                              // minimum wall between openings

// Pitch of every cell in a row = max(opening + wall, label width + wall)
drill_pitch = [for (d = drills) max(d[1] + round_clear + wall, label_w(d[0]) + wall)];
hex_pitch   = [for (b = hex_bits) max(hex_hole_d + wall, label_w(b) + wall)];
spade_p     = [for (b = spade_bits) max(spade_pitch, label_w(b) + wall)];
blade_slot_t = [for (b = blades) b[2] + slot_clear];
// Slots run front-to-back (blade plane along Y), so the pitch is set by the label
blade_pitch = [for (b = blades) max(b[2] + slot_clear + wall + blade_pitch_extra,
                                    label_w(b[0]) + wall)];

// Depth (Y) a row occupies: opening + gap + label
max_drill_d  = max([for (d = drills) d[1]]) + round_clear;
max_blade_w  = max([for (b = blades) b[1]]) + slot_clear;
row_depth = [
    max_drill_d + label_gap + text_size,
    hex_hole_d  + label_gap + text_size,
    hex_hole_d  + label_gap + text_size,
    max_blade_w + label_gap + text_size,
];
row_len = [sum(drill_pitch), sum(hex_pitch), sum(spade_p), sum(blade_pitch)];

block_w = max(row_len) + 2 * margin;
block_d = sum(row_depth) + 3 * row_gap + 2 * margin;

// Front edge (Y) of row r
function row_y(r) = margin + prefix(row_depth, r) + r * row_gap;
// Centre X of cell i in a row with pitches p (rows are centred on the block)
function cell_x(p, i) = (block_w - sum(p)) / 2 + prefix(p, i) + p[i] / 2;

hole_depth = block_h - floor_t;

// ── Geometry ──────────────────────────────────────────────────────────────────
module rounded_block() {
    linear_extrude(block_h)
        offset(r = corner_r) offset(delta = -corner_r)
            square([block_w, block_d]);
}

// Opening cut down from the top face; small chamfer at the mouth eases insertion
module drop_in(z_h = hole_depth) {
    translate([0, 0, block_h - z_h]) linear_extrude(z_h + 1) children();
}

module label(s, x, y) {
    translate([x, y, block_h - engrave_depth])
        linear_extrude(engrave_depth + 1)
            text(s, size = text_size, font = font_name, halign = "center", valign = "bottom");
}

module row_round() {
    r = 0; y0 = row_y(r);
    yc = y0 + text_size + label_gap + max_drill_d / 2;
    for (i = [0 : len(drills) - 1]) {
        x = cell_x(drill_pitch, i);
        d = drills[i][1] + round_clear;
        translate([x, yc]) drop_in() circle(d = d);
        translate([x, yc, block_h - 0.6]) cylinder(d1 = d, d2 = d + 1.2, h = 0.61);
        label(drills[i][0], x, y0);
    }
}

module row_hex(r, names, pitches) {
    y0 = row_y(r);
    yc = y0 + text_size + label_gap + hex_hole_d / 2;
    for (i = [0 : len(names) - 1]) {
        x = cell_x(pitches, i);
        translate([x, yc]) drop_in() circle(d = hex_hole_d, $fn = 6);
        translate([x, yc, block_h - 0.6])
            cylinder(d1 = hex_hole_d, d2 = hex_hole_d + 1.2, h = 0.61, $fn = 6);
        label(names[i], x, y0);
    }
}

module row_blades() {
    r = 3; y0 = row_y(r);
    for (i = [0 : len(blades) - 1]) {
        x = cell_x(blade_pitch, i);
        t = blade_slot_t[i];
        w = blades[i][1] + slot_clear;
        yc = y0 + text_size + label_gap + max_blade_w / 2;
        translate([x, yc]) drop_in() square([t, w], center = true);
        label(blades[i][0], x, y0);
    }
}

difference() {
    rounded_block();
    row_round();
    row_hex(1, hex_bits, hex_pitch);
    row_hex(2, spade_bits, spade_p);
    row_blades();
}

echo(str("Block: ", block_w, " × ", block_d, " × ", block_h, " mm"));
