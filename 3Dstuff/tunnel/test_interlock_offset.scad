// Test script for 16-inch 2-block interlocked span with half-tooth Z-offset
num_teeth = 5;
tooth_height = 26.0;
tooth_depth = 10.0;
corner_bevel = 20.0;
clearance = 0.25;

// Calculated width for 2 interlocked blocks to span exactly 16 inches (406.4 mm)
span_16in = 16.0 * 25.4; // 406.4 mm
W = (span_16in + tooth_depth + clearance) / 2; // 208.325 mm (~8.20 inches)

h_wall = num_teeth * tooth_height;
H = 2 * corner_bevel + h_wall;

// Half-tooth Z offset for alternating modules
z_offset_alt = tooth_height / 2;

echo(str("CALCULATED MODULE WIDTH: ", W, " mm (", W/25.4, " inches)"));
echo(str("2-BLOCK INTERLOCKED SPAN: ", 2*W - tooth_depth - clearance, " mm (", (2*W - tooth_depth - clearance)/25.4, " inches)"));

// Render 2 interlocking modules
// Module 1 (Cyan) at X=0, Z=0
color([0.25, 0.55, 0.85])
translate([0, 0, 0])
cube([W, 10, H]); // placeholder bounding box check

// Module 2 (Orange) at X = W - tooth_depth, Z = z_offset_alt
color([0.90, 0.45, 0.25])
translate([W - tooth_depth, 0, z_offset_alt])
cube([W, 10, H]);
