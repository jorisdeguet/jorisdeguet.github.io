use <fonts/LobsterTwo-Bold.ttf>

// Digit "8" sign — 150 mm tall, Lobster Two Bold, FDM black.
// Front face at z=0; magnet pocket opens from back.
// Requires OpenSCAD 2021.01+ for textmetrics().

plate_size     = [260, 260];
plate_margin   = 4;
sign_thickness = 6;
min_front_skin = 0.8;
target_height  = 150;    // glyph height in mm
base_font_size = 200;
glyph_fatten   = 0.5;

font_name = "Lobster Two:style=Bold";
digit     = "8";

// Magnet: 30 mm round × 4 mm thick
magnet_type  = "square";
magnet_size  = 10;
magnet_thick = 2;

magnet_xy_clearance = 0.6;
magnet_z_clearance  = 0.25;

// Pocket offset from glyph center (mm) — adjust to land on solid material.
px = 75;
py = 18;

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

module sign() {
    difference() {
        color("black")
            linear_extrude(sign_thickness)
                glyph_2d();
        intersection() {
            linear_extrude(sign_thickness + 0.1)
                glyph_2d();
            translate([px, py, sign_thickness - pocket_depth])
                if (magnet_type == "round")
                    cylinder(h = pocket_depth + 0.02, d = pocket_size);
                else
                    linear_extrude(pocket_depth + 0.02)
                        square([pocket_size, pocket_size], center = true);
        }
    }
}

sign();
