// Test script for rounded zig-zag profile
H = 254; // 10 inches
W = 203.2; // 8 inches
wall_thickness = 3.5;
amp = 12;
num_cycles = 6;
clearance = 0.25;

// Rounded wave function (sine wave based)
function zig_x_rounded(z, H, num_cycles, amp) = 
    (amp / 2) * (1 - cos(360 * num_cycles * z / H));

// Generate 2D outer boundary points for rounded left & right walls
function outer_profile_rounded(W, H, num_cycles, amp, clearance, steps=100) =
    concat(
        // Left outer wall going up from Z=0 to Z=H
        [ for (i = [0 : steps]) 
            let (z = i * H / steps)
            [ zig_x_rounded(z, H, num_cycles, amp), z ] 
        ],
        // Right outer wall going down from Z=H to Z=0
        [ for (i = [steps : -1 : 0]) 
            let (z = i * H / steps)
            [ W + zig_x_rounded(z, H, num_cycles, amp) - clearance, z ] 
        ]
    );

polygon(outer_profile_rounded(W, H, num_cycles, amp, clearance));
