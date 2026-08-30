use <single_module.scad>

num_teeth = 5;
tooth_height = 26.0;
tooth_depth = 10.0;
corner_bevel = 20.0;
clearance = 0.25;

span_16in = 16.0 * 25.4; // 406.4 mm
calc_W_in = (span_16in + tooth_depth + clearance) / 2 / 25.4; // ~8.20177 inches

// Render Module 1 (Blue) at X=0, Z=0
color([0.25, 0.55, 0.85])
translate([0, 0, 0])
single_module(
    width_in = calc_W_in,
    depth_in = 6.0,
    n_teeth = num_teeth,
    t_h = tooth_height,
    t_d = tooth_depth,
    bevel = corner_bevel,
    clr = clearance,
    flat_l = true,
    flat_r = false
);

// Render Module 2 (Orange) shifted X = (W_mm - tooth_depth), Z = tooth_height / 2
color([0.90, 0.45, 0.25])
translate([calc_W_in * 25.4 - tooth_depth, 0, tooth_height / 2])
single_module(
    width_in = calc_W_in,
    depth_in = 6.0,
    n_teeth = num_teeth,
    t_h = tooth_height,
    t_d = tooth_depth,
    bevel = corner_bevel,
    clr = clearance,
    flat_l = false,
    flat_r = true
);
