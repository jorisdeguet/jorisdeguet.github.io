$fn = 48;

case_file = "iphone-luna.stl";
render_mode = "split"; // "split", "assembled", "case", "accents"
split_gap = 12;

// Measured from the imported STL bounds.
case_length = 150.129;
case_width = 75.252;

// Back decoration.
dot_rows = 8;
dot_cols = 5;
dot_diameter = 2.4;
dot_height = 0.9;
grid_left_margin = 20;
grid_right_margin = 11;
grid_top_margin = 38;
grid_bottom_margin = 18;

// Side text on the edge opposite the camera cutout.
text_string = "#finoallafine";
text_size = 16;
text_height = 0.8;
text_side_margin = 172.5;
text_bottom_margin = 50;
text_font = "Liberation Sans:style=Bold";
text_rotation_z = 0;

module imported_case() {
    import(case_file);
}

module dot_matrix(
    rows,
    cols,
    diameter,
    height,
    left_margin,
    right_margin,
    top_margin,
    bottom_margin
) {
    usable_x = case_length - left_margin - right_margin;
    usable_y = case_width - top_margin - bottom_margin;
    step_x = cols > 1 ? usable_x / (cols - 1) : 0;
    step_y = rows > 1 ? usable_y / (rows - 1) : 0;

    for (row = [0 : rows - 1]) {
        for (col = [0 : cols - 1]) {
            translate([
                left_margin + col * step_x,
                top_margin + row * step_y,
                -height
            ])
                cylinder(h = height, d = diameter);
        }
    }
}

module back_text(
    label,
    size,
    height,
    side_margin,
    bottom_margin,
    font_name,
    rotation_z
) {
    translate([case_length - side_margin, bottom_margin, -height])
        rotate([0, 0, rotation_z])
            mirror([1, 0, 0])
                linear_extrude(height = height)
                    text(label, size = size, font = font_name, halign = "left", valign = "baseline");
}

module accents() {
    

    back_text(
        text_string,
        text_size,
        text_height,
        text_side_margin,
        text_bottom_margin,
        text_font,
        text_rotation_z
    );
}

module split_layout() {
    imported_case();

    translate([case_length + split_gap, 0, 0])
        accents();
}

if (render_mode == "case") {
    imported_case();
} else if (render_mode == "accents") {
    accents();
} else if (render_mode == "assembled") {
    imported_case();
    accents();
} else {
    split_layout();
}
