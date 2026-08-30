// Test script for inward-zag profile and horizontal screw slit
H = 6.75 * 25.4; // 6.75 inches (~171.45 mm)
W = 8.0 * 25.4;  // 8.0 inches (203.2 mm)
wall_t = 3.5;
back_t = 4.0;
amp = 12.0;
num_cycles = 4;
clearance = 0.25;

// Horizontal Slit Cutter module
module horizontal_screw_slit(x, z, shaft_d, head_d, slot_w, wall_t) {
    translate([x, -0.1, z])
    rotate([-90, 0, 0])
    union() {
        // Horizontal slot for screw shaft (allows left-right adjustment)
        hull() {
            translate([-slot_w/2, 0, 0])
                cylinder(d = shaft_d + 0.3, h = wall_t + 0.5, $fn = 32);
            translate([slot_w/2, 0, 0])
                cylinder(d = shaft_d + 0.3, h = wall_t + 0.5, $fn = 32);
        }
        // Counterbore / head recess slot for screw head
        hull() {
            translate([-slot_w/2, 0, -0.1])
                cylinder(d = head_d + 0.5, h = wall_t/2 + 0.1, $fn = 32);
            translate([slot_w/2, 0, -0.1])
                cylinder(d = head_d + 0.5, h = wall_t/2 + 0.1, $fn = 32);
        }
    }
}

// Inward-zag wave function (0 at z=0 and z=H, going inward into box)
function zig_inward(z, H, num_cycles, amp) = 
    (amp / 2) * (1 - cos(360 * num_cycles * z / H));

// Left outer wall points: X_left = zig_inward(z) (starts at 0, goes +X inward into box)
// Right outer wall points: X_right = W - amp + zig_inward(z) - clearance
function outer_profile_inward(W, H, num_cycles, amp, clearance, steps=100) =
    concat(
        [ for (i = [0 : steps]) 
            let (z = i * H / steps)
            [ zig_inward(z, H, num_cycles, amp), z ] 
        ],
        [ for (i = [steps : -1 : 0]) 
            let (z = i * H / steps)
            [ W - amp + zig_inward(z, H, num_cycles, amp) - clearance, z ] 
        ]
    );

function inner_profile_inward(W, H, wall, num_cycles, amp, clearance, steps=100) =
    concat(
        [ for (i = [0 : steps]) 
            let (z = wall + i * (H - 2*wall) / steps)
            [ wall + zig_inward(z, H, num_cycles, amp), z ] 
        ],
        [ for (i = [steps : -1 : 0]) 
            let (z = wall + i * (H - 2*wall) / steps)
            [ W - wall - amp + zig_inward(z, H, num_cycles, amp) - clearance, z ] 
        ]
    );

difference() {
    union() {
        linear_extrude(height = 50)
            difference() {
                polygon(outer_profile_inward(W, H, num_cycles, amp, clearance));
                polygon(inner_profile_inward(W, H, wall_t, num_cycles, amp, clearance));
            }
        linear_extrude(height = back_t)
            polygon(outer_profile_inward(W, H, num_cycles, amp, clearance));
    }
    horizontal_screw_slit(W/2, H/2, 4.5, 9.0, 25.0, back_t);
}
