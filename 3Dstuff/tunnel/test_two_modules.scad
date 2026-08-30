// Test 3D assembly of 2 interlocking modules
module_height_in = 10;
module_width_in = 8;
module_depth_in = 6;

wall_thickness = 3.5;
back_thickness = 4.0;
zig_cycle_height = 25.4;
zig_amplitude = 10;
interlock_clearance = 0.25;

H = module_height_in * 25.4;
W = module_width_in * 25.4;
D = module_depth_in * 25.4;

num_cycles = max(1, round(H / zig_cycle_height));

function zig_x(z, H, num_cycles, amp) = 
    let (
        cycle_h = H / num_cycles,
        phase = (z % cycle_h) / cycle_h,
        tri = (phase < 0.5) ? (phase * 2) : ((1 - phase) * 2)
    ) tri * amp;

function outer_profile(W, H, num_cycles, amp, clearance) =
    concat(
        [ for (i = [0 : num_cycles * 2]) 
            let (z = i * (H / (num_cycles * 2)))
            [ zig_x(z, H, num_cycles, amp), z ] 
        ],
        [ for (i = [num_cycles * 2 : -1 : 0]) 
            let (z = i * (H / (num_cycles * 2)))
            [ W + zig_x(z, H, num_cycles, amp) - clearance, z ] 
        ]
    );

function inner_profile(W, H, wall, num_cycles, amp, clearance) =
    concat(
        [ for (i = [0 : num_cycles * 2]) 
            let (z = wall + i * ((H - 2*wall) / (num_cycles * 2)))
            [ wall + zig_x(z, H, num_cycles, amp), z ] 
        ],
        [ for (i = [num_cycles * 2 : -1 : 0]) 
            let (z = wall + i * ((H - 2*wall) / (num_cycles * 2)))
            [ W - wall + zig_x(z, H, num_cycles, amp) - clearance, z ] 
        ]
    );

module module_box() {
    union() {
        // Main hollow shell extruded along Y
        linear_extrude(height = D) {
            difference() {
                polygon(outer_profile(W, H, num_cycles, zig_amplitude, interlock_clearance));
                polygon(inner_profile(W, H, wall_thickness, num_cycles, zig_amplitude, interlock_clearance));
            }
        }
        // Back wall plate
        linear_extrude(height = back_thickness) {
            polygon(outer_profile(W, H, num_cycles, zig_amplitude, interlock_clearance));
        }
    }
}

// Render Module 1 (Cyan)
color([0.2, 0.7, 0.9]) module_box();

// Render Module 2 (Orange) - placed at X = W
translate([W, 0, 0])
color([0.9, 0.5, 0.2]) module_box();
