// Test script for octagonal chamfered module profile with both flat end walls
H = 6.75 * 25.4; // 6.75 inches (~171.45 mm)
W = 8.0 * 25.4;  // 8.0 inches (203.2 mm)
wall_t = 3.5;
back_t = 4.0;
corner_bevel = 20.0; // Corner chamfer size in mm
amp = 12.0;
clearance = 0.25;

flat_left_wall = true;
flat_right_wall = true;

// Zig-zag wave function bounded between z = corner_bevel and z = H - corner_bevel
function zig_inward_offset(z, z_start, z_end, num_cycles, amp) = 
    let (
        h_eff = z_end - z_start,
        z_rel = z - z_start
    ) (amp / 2) * (1 - cos(360 * num_cycles * z_rel / h_eff));

function outer_profile(W, H, bevel, amp, clr, flat_left, flat_right, steps=80) =
    let (
        z_bot = bevel,
        z_top = H - bevel,
        h_eff = z_top - z_bot,
        num_cycles = max(1, round(h_eff / 20.0))
    )
    concat(
        // 1. Bottom edge (left to right)
        [ [ bevel, 0 ] ],
        [ [ W - bevel - clr, 0 ] ],
        
        // 2. Bottom-right chamfer
        [ [ W - clr, z_bot ] ],
        
        // 3. Right side wall (bottom to top)
        flat_right ? [ [ W - clr, z_top ] ] :
        [ for (i = [0 : steps])
            let (z = z_bot + i * h_eff / steps)
            [ W - amp + zig_inward_offset(z, z_bot, z_top, num_cycles, amp) - clr, z ]
        ],
        
        // 4. Top-right chamfer
        [ [ W - bevel - clr, H ] ],
        
        // 5. Top edge (right to left)
        [ [ bevel, H ] ],
        
        // 6. Top-left chamfer
        [ [ 0, z_top ] ],
        
        // 7. Left side wall (top to bottom)
        flat_left ? [ [ 0, z_bot ] ] :
        [ for (i = [steps : -1 : 0])
            let (z = z_bot + i * h_eff / steps)
            [ zig_inward_offset(z, z_bot, z_top, num_cycles, amp), z ]
        ]
    );

polygon(outer_profile(W, H, corner_bevel, amp, clearance, flat_left_wall, flat_right_wall));
