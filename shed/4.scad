use <fonts/LobsterTwo-Bold.ttf>

// Digit "4" sign — 150 mm tall, Lobster Two Bold, FDM black.
// Front face at z=0; magnet pockets open from back.
// Requires OpenSCAD 2021.01+ for textmetrics().

plate_size     = [260, 260];
plate_margin   = 4;
sign_thickness = 6;
min_front_skin = 0.8;
target_height  = 150;    // glyph height in mm
base_font_size = 200;
glyph_fatten   = 0.5;

font_name = "Lobster Two:style=Bold";
digit     = "4";

// Magnets: 2× 20 mm round × 3 mm thick
magnet_size  = 20;
magnet_thick = 3;

magnet_xy_clearance = 0.6;
magnet_z_clearance  = 0.25;

// Pocket offsets from glyph center (mm) — adjust to land on solid material.
// Pocket 1: upper area of the stem
px1 = -42;  py1 =  80;
// Pocket 2: lower area of the stem
px2 = -95;  py2 = -20;

$fn = 96;

function m()   = textmetrics(text=digit, font=font_name, size=base_font_size, halign="left", valign="center");
function sc()  = min(target_height / m().size[1],
                     (plate_size[0] - 2*plate_margin - 2*glyph_fatten) / m().size[0]);
function bcx() = m().position[0] + m().size[0] / 2;
function bcy() = m().position[1] + m().size[1] / 2;

module glyph_2d() {
    s = sc();
    offset(r = glyph_fatten)
        mirror([1,0])
            scale([s, s])
                translate([-bcx(), -bcy()])
                    text(digit, font=font_name, size=base_font_size, halign="left", valign="center");
}

pocket_depth = min(magnet_thick + magnet_z_clearance, sign_thickness - min_front_skin);
pocket_size  = magnet_size + magnet_xy_clearance;

module magnet_pocket(px, py) {
    intersection() {
        linear_extrude(sign_thickness + 0.1)
            glyph_2d();
        translate([px, py, sign_thickness - pocket_depth])
            cylinder(h = pocket_depth + 0.02, d = pocket_size);
    }
}

module sign() {
    difference() {
        color("black")
            linear_extrude(sign_thickness)
                glyph_2d();
        magnet_pocket(px1, py1);
        magnet_pocket(px2, py2);
    }
}

sign();

