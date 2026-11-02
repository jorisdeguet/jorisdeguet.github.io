// =============================================================================
//  bitbox.scad — Workbench block for drill bits, screwdriver bits,
//                spade bits, oscillating multi-tool blades and pencils
//  Units: millimetres   (block height = 1" = 25.4 mm)
// =============================================================================
//
//  Layout, front (−Y) to back (+Y):
//    rows 1-3  twist drill bits    round holes, small → large
//    row 4     screwdriver bits    1/4" hex holes (Phillips, square, flat)
//    row 5     spade bits          1/4" hex holes (the last inch of the shank is hex)
//    row 6     multi-tool blades   thin slots, then pencil holes
//
//  Every opening is tilted `tilt` degrees, top leaning toward +Y:
//    • on a shelf the bits lean back slightly;
//    • on a wall (bottom face against the wall, +Y pointing up) the bits point
//      outward and a little upward, so they cannot slide out.
//
//  Wall mounting: KEYHOLE slots in the bottom face, one per corner. Drive the
//  screws into the wall leaving the heads `screw_proud` mm out, push the block
//  on over the heads, then slide it down. The screws end up hidden inside the
//  thickness of the block.
//
//  Plastic saving: the underside is hollow, leaving a top skin, an outer
//  wall, a sleeve around every opening, ribs that join each opening to its
//  neighbours (in its row, in the rows next to it, and out to the walls),
//  and solid bosses around the keyholes, tied to the side walls.
//
//  Labels are ENGRAVED in the top face, in front of each opening (below it
//  when wall-mounted).
//
//  show_bits = true adds stand-in bits for a preview only.
//  PRINT UPSIDE DOWN (top face on the bed): the hollow side then faces up and
//  only the small hole floors and keyhole lips are bridged — no supports.
//  orient = "print" exports it that way; orient = "use" shows it right side up.
// =============================================================================

$fn = 48;

show_bits = false;      // preview only — set false before exporting the STL
orient    = "print";    // "print" = upside down, ready to slice; "use" = right side up

// ── Block ─────────────────────────────────────────────────────────────────────
in            = 25.4;
block_h       = 1 * in; // 1 inch
floor_t       = 3.0;    // material under every opening
margin_y      = 6;      // front and back border
corner_r      = 6;      // vertical-edge rounding
row_gap       = 6;      // extra space between rows (finger room)
finger_gap    = 6;      // minimum extra space between neighbouring openings (finger room)
target_w      = 240;    // overall width; each row is spread evenly across it
                        // (Kobra X bed is 260 mm — leave some room around the part)
tilt          = 10;     // opening tilt from vertical, degrees

// ── Hollow underside ──────────────────────────────────────────────────────────
hollow        = true;
top_skin      = 3.0;    // solid top (labels are engraved into it)
outer_wall    = 2.4;    // perimeter wall
sleeve_t      = 1.6;    // wall around each opening
rib_t         = 1.6;    // rib thickness

// ── Keyholes (wall mount, one per corner, in the bottom face) ─────────────────
shank_w       = 4.8;    // slot width: #8 / 4 mm screw shank + clearance
head_w        = 10.0;   // entry hole and head chamber: screw head (≤ 9 mm) + clearance
slot_len      = 10;     // travel from entry hole to locked position (toward +Y)
lip_t         = 3.0;    // plastic between the wall and the screw head
chamber_h     = 4.5;    // room for the screw head above the lip
screw_proud   = lip_t + 1.0;    // how far the screw heads stick out of the wall
boss_wall     = 3.0;    // solid material around each keyhole
key_inset_x   = 12;     // entry-hole centre from the side edges
key_inset_y   = 12;     // entry-hole centre from the front / back edges
margin_x      = key_inset_x + head_w / 2 + boss_wall + 2;   // side border keeps rows clear

// ── Labels ────────────────────────────────────────────────────────────────────
font_name     = "Liberation Sans:style=Bold";
text_size     = 4.0;    // OpenSCAD font size (≈ digit height in mm)
text_h        = 1.05 * text_size;
engrave_depth = 0.8;   // a little deeper: this face is the first layer
label_gap     = 1.8;    // space between a label and its opening
char_w        = 0.78;   // width of one character, × text_size (measured, incl. spacing)
slash_w       = 0.45;   // width of "/", × text_size

// ── Fits ──────────────────────────────────────────────────────────────────────
round_clear   = 0.6;    // added to drill-bit diameter (FDM holes print small)
hex_af        = 6.35;   // 1/4" hex across flats
hex_clear     = 0.5;    // added to across-flats
slot_clear    = 0.8;    // added to blade thickness
pencil_d      = 8.8;    // standard hex pencil is ≈ 8 mm across corners
chamfer       = 1.2;    // lead-in chamfer at every opening (each side)

// ── Inventory ─────────────────────────────────────────────────────────────────
//  Twist drills: [label, diameter in inches], small to large
//  Standard 29-piece set: 1/16" to 1/2" in 1/64" steps
drills = [
    ["1/16", 1/16], ["5/64", 5/64], ["3/32", 3/32], ["7/64", 7/64], ["1/8", 1/8],
    ["9/64", 9/64], ["5/32", 5/32], ["11/64", 11/64], ["3/16", 3/16], ["13/64", 13/64],

    ["7/32", 7/32], ["15/64", 15/64], ["1/4", 1/4], ["17/64", 17/64], ["9/32", 9/32],
    ["19/64", 19/64], ["5/16", 5/16], ["21/64", 21/64], ["11/32", 11/32], ["23/64", 23/64],

    ["3/8", 3/8], ["25/64", 25/64], ["13/32", 13/32], ["27/64", 27/64], ["7/16", 7/16],
    ["29/64", 29/64], ["15/32", 15/32], ["31/64", 31/64], ["1/2", 1/2],
];
drill_rows   = [10, 10, 9];     // how many drills go in each of the 3 drill rows
drill_depth  = 20;            // vertical depth of drill holes

hex_bits     = ["PH1", "PH2", "PH3", "SQ1", "SQ2", "SQ3", "SL4", "SL6"];
hex_depth    = 12;            // 1" insert bits stay easy to grab

spade_bits   = ["3/8", "1/2", "5/8", "3/4", "7/8", "1"];   // paddle width, inches
spade_depth  = 20;            // stays within the 1" hex part of the shank
spade_pitch  = 18;            // turn the paddles front-to-back

blade_count  = 4;
blade_w      = 1.25 * in + 1.5;   // 1-1/4" blades + clearance
blade_t      = 1.0;               // blade thickness
blade_pitch  = 9;
blade_depth  = 18;

pencil_count = 3;
mix_d        = 0.5 * in + 1.0;   // 1/2" hole for mixed drill bits (a few at once)
mix_label    = "MIX";
pencil_depth = 20;

// ── Rows ──────────────────────────────────────────────────────────────────────
//  cell = [label, shape, size_x, size_y, min_pitch]
//    shape "round": size_x = size_y = diameter
//    shape "hex"  : size_x = across corners, size_y = across flats
//    shape "slot" : size_x = thickness, size_y = length (front-to-back)
hex_ac = (hex_af + hex_clear) / cos(30);
hex_fl =  hex_af + hex_clear;

function sum(v, i = 0) = i >= len(v) ? 0 : v[i] + sum(v, i + 1);
function prefix(v, n)  = n <= 0 ? 0 : v[n - 1] + prefix(v, n - 1);
function drill_cell(d) = [d[0], "round", d[1] * in + round_clear, d[1] * in + round_clear, 0];
function drill_slice(r) = [for (i = [prefix(drill_rows, r) : prefix(drill_rows, r + 1) - 1])
                               drill_cell(drills[i])];

rows = [
    // [vertical depth, cells]
    [drill_depth, drill_slice(0)],
    [drill_depth, drill_slice(1)],
    [drill_depth, drill_slice(2)],
    [hex_depth,   [for (b = hex_bits)   [b, "hex", hex_ac, hex_fl, 0]]],
    [spade_depth, [for (b = spade_bits) [b, "hex", hex_ac, hex_fl, spade_pitch]]],
    [blade_depth, concat(
        [for (i = [1 : blade_count])  ["", "slot", blade_t + slot_clear, blade_w, blade_pitch]],
        [for (i = [1 : pencil_count]) ["", "round", pencil_d, pencil_d, 0]],
        [[mix_label, "round", mix_d, mix_d, 0]])],
];
n_rows = len(rows);

// ── Derived sizes ─────────────────────────────────────────────────────────────
function n_slash(s) = len([for (c = s) if (c == "/") c]);
function label_w(s) = ((len(s) - n_slash(s)) * char_w + n_slash(s) * slash_w) * text_size;
function cell_pitch(c) = max(c[2] + 2 * chamfer + finger_gap, label_w(c[0]) + 3, c[4]);
function row_pitches(r) = [for (c = rows[r][1]) cell_pitch(c)];
function row_open_d(r)  = max([for (c = rows[r][1]) c[3]]) + 2 * chamfer;
function row_depth(r)   = row_open_d(r) + label_gap + text_h;
row_depths = [for (r = [0 : n_rows - 1]) row_depth(r)];
row_lens   = [for (r = [0 : n_rows - 1]) sum(row_pitches(r))];

// The deepest opening drifts toward the front by depth·tan(tilt); keep it inside.
front_drift = drill_depth * tan(tilt) + sleeve_t;

block_w = max(max(row_lens) + 2 * margin_x, target_w);
usable_w = block_w - 2 * margin_x;   // width available to every row
block_d = sum(row_depths) + (n_rows - 1) * row_gap + 2 * margin_y + front_drift;

function row_y(r)     = margin_y + front_drift + prefix(row_depths, r) + r * row_gap;
// "Space evenly": the leftover width of a row is split into equal gaps before,
// between and after its openings, so every row spans the whole block.
function row_gap_x(r)  = (usable_w - sum(row_pitches(r))) / (len(rows[r][1]) + 1);
function cell_x(r, i) = let (p = row_pitches(r))
    margin_x + row_gap_x(r) * (i + 1) + prefix(p, i) + p[i] / 2;
// centre of an opening's mouth on the top face
function mouth(r, i)  = [cell_x(r, i), row_y(r) + text_h + label_gap + row_open_d(r) / 2];

// keyhole entry centres (slot runs toward +Y from there)
key_pts = [for (x = [key_inset_x, block_w - key_inset_x],
                y = [key_inset_y, block_d - key_inset_y - slot_len]) [x, y]];

// ── Geometry ──────────────────────────────────────────────────────────────────
module outline_2d(inset = 0) {
    offset(r = corner_r - inset) offset(delta = -corner_r)
        square([block_w, block_d]);
}

module shape_2d(c, grow = 0) {
    if (c[1] == "round") circle(d = c[2] + grow);
    else if (c[1] == "hex") circle(d = c[2] + grow / cos(30), $fn = 6);
    else square([c[2] + grow, c[3] + grow], center = true);
}

// Place children on the tilted axis of an opening; local z = 0 at the top face.
module on_axis(p) {
    translate([p[0], p[1], block_h]) rotate([-tilt, 0, 0]) children();
}

// Hole along the tilted axis, with a lead-in chamfer at the mouth.
module opening(c, p, depth_v) {
    axial = depth_v / cos(tilt);
    on_axis(p) {
        translate([0, 0, -axial]) linear_extrude(axial + 5) shape_2d(c);
        hull() {
            translate([0, 0, -chamfer]) linear_extrude(0.01) shape_2d(c);
            linear_extrude(5) shape_2d(c, 2 * chamfer + 10 * tan(tilt));
        }
    }
}

// Solid sleeve kept around an opening when the underside is hollowed.
module sleeve(c, p) {
    on_axis(p) translate([0, 0, -2 * block_h])
        linear_extrude(2 * block_h) shape_2d(c, 2 * (chamfer + sleeve_t));
}

module label(s, x, y) {
    if (s != "")
        translate([x, y, block_h - engrave_depth])
            linear_extrude(engrave_depth + 1)
                text(s, size = text_size, font = font_name, halign = "center", valign = "bottom");
}

module keyhole() {
    // entry hole: the head goes in here
    translate([0, 0, -1]) cylinder(d = head_w, h = lip_t + chamber_h + 1);
    // narrow slot through the lip: the shank slides along it
    translate([0, 0, -1]) hull() {
        cylinder(d = shank_w, h = lip_t + 1.01);
        translate([0, slot_len, 0]) cylinder(d = shank_w, h = lip_t + 1.01);
    }
    // head chamber behind the lip
    translate([0, 0, lip_t]) hull() {
        cylinder(d = head_w, h = chamber_h);
        translate([0, slot_len, 0]) cylinder(d = head_w, h = chamber_h);
    }
}

// Solid boss around a keyhole, widened out to the nearest side wall.
module key_boss(k) {
    side = k[0] < block_w / 2 ? -1 : 1;
    translate(k) hull() {
        for (dy = [0, slot_len], dx = [0, side * key_inset_x])
            translate([dx, dy, 0]) cylinder(d = head_w + 2 * boss_wall, h = block_h);
    }
}

// A thin line along the tilted axis of an opening (mouth at top-face point p);
// the hull of two of them is a rib joining the two openings.
module axis_line(p) {
    on_axis(p) translate([0, 0, -2 * block_h])
        cylinder(d = rib_t, h = 2 * block_h + 1, $fn = 8);
}
module rib(p, q) { hull() { axis_line(p); axis_line(q); } }

function argmin(v, i = 0, best = 0) =
    i >= len(v) ? best : argmin(v, i + 1, v[i] < v[best] ? i : best);
function n_cells(r) = len(rows[r][1]);
function nearest(r, x) = argmin([for (i = [0 : n_cells(r) - 1]) abs(cell_x(r, i) - x)]);

module ribs() {
    for (r = [0 : n_rows - 1]) {
        n = n_cells(r);
        // along the row, and out to both side walls
        for (i = [0 : n - 2]) rib(mouth(r, i), mouth(r, i + 1));
        rib([0, mouth(r, 0)[1]], mouth(r, 0));
        rib(mouth(r, n - 1), [block_w, mouth(r, n - 1)[1]]);
        // each opening to the closest opening in the next row, and back
        if (r < n_rows - 1) {
            for (i = [0 : n - 1])
                rib(mouth(r, i), mouth(r + 1, nearest(r + 1, cell_x(r, i))));
            for (j = [0 : n_cells(r + 1) - 1])
                rib(mouth(r + 1, j), mouth(r, nearest(r, cell_x(r + 1, j))));
        }
    }
    // front row to the front wall, back row to the back wall
    for (i = [0 : n_cells(0) - 1]) rib(mouth(0, i), [cell_x(0, i), 0]);
    for (i = [0 : n_cells(n_rows - 1) - 1])
        rib(mouth(n_rows - 1, i), [cell_x(n_rows - 1, i), block_d + 5]);
}
module cavity() {
    difference() {
        translate([0, 0, -1]) linear_extrude(block_h - top_skin + 1) outline_2d(outer_wall);
        for (r = [0 : n_rows - 1], i = [0 : len(rows[r][1]) - 1])
            sleeve(rows[r][1][i], mouth(r, i));
        for (k = key_pts) key_boss(k);
        ribs();
    }
}

module holder() {
    difference() {
        linear_extrude(block_h) outline_2d();
        if (hollow) cavity();
        for (r = [0 : n_rows - 1], i = [0 : len(rows[r][1]) - 1]) {
            c = rows[r][1][i];
            p = mouth(r, i);
            opening(c, p, rows[r][0]);
            label(c[0], p[0], row_y(r));
        }
        for (k = key_pts) translate(k) keyhole();
    }
}

// ── Preview stand-ins (not printed) ───────────────────────────────────────────
// jobber drill length, roughly linear from 1-7/8" (1/16) to 6-1/4" (1/2)
function drill_len(d_in) = (1.875 + (d_in - 1/16) / (1/2 - 1/16) * (6.25 - 1.875)) * in;

module bit_at(r, i) {
    seat = rows[r][0] / cos(tilt);
    on_axis(mouth(r, i)) translate([0, 0, -seat]) children();
}

module stand_ins() {
    // drills
    for (r = [0 : 2], i = [0 : len(rows[r][1]) - 1]) {
        d = rows[r][1][i][2] - round_clear;
        color("silver") bit_at(r, i) cylinder(d = d, h = drill_len(d / in));
    }
    // 1" screwdriver insert bits
    for (i = [0 : len(hex_bits) - 1])
        color("goldenrod") bit_at(3, i) {
            cylinder(d = hex_af / cos(30), h = 18, $fn = 6);
            translate([0, 0, 18]) cylinder(d1 = 5, d2 = 1.5, h = 7);
        }
    // spade bits: 6" long, paddle front-to-back
    for (i = [0 : len(spade_bits) - 1]) {
        w = [3/8, 1/2, 5/8, 3/4, 7/8, 1][min(i, 5)] * in;
        color("steelblue") bit_at(4, i) {
            cylinder(d = hex_af / cos(30), h = 25.4, $fn = 6);
            cylinder(d = 6, h = 6 * in - 30);
            translate([-1, -w / 2, 6 * in - 30]) cube([2, w, 30]);
        }
    }
    // multi-tool blades and pencils
    for (i = [0 : blade_count - 1])
        color("dimgray") bit_at(5, i)
            translate([-blade_t / 2, -blade_w / 2 + 0.75, 0]) cube([blade_t, blade_w - 1.5, 65]);
    for (i = [0 : pencil_count - 1])
        color("gold") bit_at(5, blade_count + i) cylinder(d = 8, h = 175, $fn = 6);
}

if (orient == "print") {
    translate([0, block_d, block_h]) rotate([180, 0, 0]) holder();
} else {
    color("burlywood") holder();
    if (show_bits) stand_ins();
}

echo(str("Block: ", block_w, " x ", block_d, " x ", block_h, " mm"));
for (r = [0 : n_rows - 1])
    echo(str("Row ", r + 1, ": ", len(rows[r][1]), " openings, extra gap ", row_gap_x(r), " mm"));
