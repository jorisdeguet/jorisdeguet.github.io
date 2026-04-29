$fn = 96;

export_part = "all";

tag_width = 40;
tag_height = 22;
tag_thickness = 1.0;
text_height = 0.8;

hole_diameter = 4.5;
hole_margin = 1.5;

name_size = 4.0;
phone_size = 3.8;
font_name = "DejaVu Sans:style=Bold";

module oval_tag_2d() {
    scale([tag_width / tag_height, 1])
        circle(d = tag_height);
}

module collar_hole_2d() {
    translate([0, tag_height / 2 - hole_margin - hole_diameter / 2])
        circle(d = hole_diameter);
}

module tag_base() {
    linear_extrude(height = tag_thickness)
        difference() {
            oval_tag_2d();
            collar_hole_2d();
        }
}

module raised_text() {
    translate([0, -1.2, 0])
        linear_extrude(height = text_height)
            union() {
                translate([-2.5, 6.6])
                    text("miku", size = name_size, font = font_name, halign = "right", valign = "center");
                translate([0, 0.8])
                    text("514 2491501", size = phone_size, font = font_name, halign = "center", valign = "center");
                translate([0, -3.4])
                    text("514 9380071", size = phone_size, font = font_name, halign = "center", valign = "center");
            }
}

if (export_part == "base") {
    tag_base();
} else if (export_part == "text") {
    translate([0, 0, tag_thickness])
        raised_text();
} else {
    tag_base();
    translate([0, 0, tag_thickness])
        raised_text();
}
