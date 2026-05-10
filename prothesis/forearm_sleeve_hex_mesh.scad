$fn = 96;

part_to_render = "both";   // "both", "dorsal", "volar"
exploded_view = true;
explode_distance = 95;

// Default anthropometry for a regular adult male forearm.
forearm_length = 250;
wrist_inner_radius = 34;
elbow_inner_radius = 48;
shell_thickness = 3.2;
forearm_scale = [1.06, 0.92, 1.00];

part_span = 172;
end_band_width = 12;
side_band_angle = 8;

hex_side = 14;
strut_diameter = 5.4;

usable_length = forearm_length - (2 * end_band_width);
hex_width = sqrt(3) * hex_side;
hex_row_pitch = 1.5 * hex_side;
surface_radius = ((wrist_inner_radius + elbow_inner_radius) / 2) + (shell_thickness / 2);
usable_arc = surface_radius * (part_span - (2 * side_band_angle)) * PI / 180;
mesh_radius = (strut_diameter + shell_thickness) / 2;

module forearm_sleeve() {
    if (part_to_render == "both") {
        render_part("dorsal", 90, exploded_view ? [-explode_distance, 0, 0] : [0, 0, 0]);
        render_part("volar", 270, exploded_view ? [explode_distance, 0, 0] : [0, 0, 0]);
    } else if (part_to_render == "dorsal") {
        render_part("dorsal", 90, [0, 0, 0]);
    } else if (part_to_render == "volar") {
        render_part("volar", 270, [0, 0, 0]);
    } else {
        echo("Unsupported part_to_render value.");
    }
}

module render_part(label, center_angle, offset) {
    translate(offset)
        scale(forearm_scale)
            color(label == "dorsal" ? [0.82, 0.86, 0.92] : [0.88, 0.82, 0.78])
                sleeve_part(center_angle);
}

module sleeve_part(center_angle) {
    union() {
        shell_frame(center_angle);
        mesh_panel(center_angle);
    }
}

module shell_frame(center_angle) {
    union() {
        z_band(center_angle, 0, end_band_width);
        z_band(center_angle, forearm_length - end_band_width, forearm_length);
        angular_band(center_angle - ((part_span - side_band_angle) / 2), side_band_angle);
        angular_band(center_angle + ((part_span - side_band_angle) / 2), side_band_angle);
    }
}

module mesh_panel(center_angle) {
    intersection() {
        shell_sector(center_angle, part_span);
        union() {
            for (row = [0 : floor(usable_length / hex_row_pitch)]) {
                zc = end_band_width + hex_side + (row * hex_row_pitch);
                if (zc <= forearm_length - end_band_width - hex_side) {
                    row_offset = (row % 2 == 0) ? 0 : hex_width / 2;
                    for (col = [0 : floor((usable_arc - row_offset) / hex_width)]) {
                        uc = (-usable_arc / 2) + (hex_width / 2) + row_offset + (col * hex_width);
                        if (abs(uc) <= usable_arc / 2 - (hex_width / 2)) {
                            hex_cell_edges(center_angle, uc, zc);
                        }
                    }
                }
            }
        }
    }
}

module hex_cell_edges(center_angle, uc, zc) {
    v0 = [uc - (hex_width / 2), zc];
    v1 = [uc, zc - hex_side];
    v2 = [uc + (hex_width / 2), zc - (hex_side / 2)];
    v3 = [uc + (hex_width / 2), zc + (hex_side / 2)];
    v4 = [uc, zc + hex_side];
    v5 = [uc - (hex_width / 2), zc + (hex_side / 2)];

    mesh_edge(center_angle, v0, v1);
    mesh_edge(center_angle, v1, v2);
    mesh_edge(center_angle, v2, v3);
    mesh_edge(center_angle, v3, v4);
    mesh_edge(center_angle, v4, v5);
    mesh_edge(center_angle, v5, v0);
}

module mesh_edge(center_angle, p1, p2) {
    hull() {
        translate(surface_point(center_angle, p1[0], p1[1]))
            sphere(r = mesh_radius);
        translate(surface_point(center_angle, p2[0], p2[1]))
            sphere(r = mesh_radius);
    }
}

module z_band(center_angle, z0, z1) {
    intersection() {
        shell_sector(center_angle, part_span);
        translate([-150, -150, z0])
            cube([300, 300, z1 - z0]);
    }
}

module angular_band(center_angle, span) {
    shell_sector(center_angle, span);
}

module shell_sector(center_angle, span) {
    rotate([0, 0, center_angle - (span / 2)])
        rotate_extrude(angle = span, convexity = 10)
            polygon([
                [wrist_inner_radius, 0],
                [wrist_inner_radius + shell_thickness, 0],
                [elbow_inner_radius + shell_thickness, forearm_length],
                [elbow_inner_radius, forearm_length]
            ]);
}

function surface_point(center_angle, u, z) =
    let(
        radius = lerp(wrist_inner_radius + (shell_thickness / 2), elbow_inner_radius + (shell_thickness / 2), z / forearm_length),
        theta = center_angle + ((u / radius) * 180 / PI)
    )
    [radius * cos(theta), radius * sin(theta), z];

function lerp(a, b, t) = a + ((b - a) * t);

forearm_sleeve();
