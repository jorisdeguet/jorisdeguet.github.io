// Test script for key-teeth 45-degree zig-zag profile
num_teeth = 5;          // Number of key teeth along side wall
tooth_height = 26.0;    // Height per tooth in mm
corner_bevel = 20.0;    // Bevel size at 4 corners in mm
tooth_depth = 10.0;     // Tooth depth (amplitude) in mm (ramp height = depth for 45 deg)
clearance = 0.25;

h_wall = num_teeth * tooth_height;
H = 2 * corner_bevel + h_wall; // Total module height
W = 8.0 * 25.4;               // Module width (203.2 mm)

// Function to generate key-tooth offset X for height Z
function key_tooth_x(z, z_start, z_end, n_teeth, depth) = 
    let (
        h_total = z_end - z_start,
        t_height = h_total / n_teeth,
        z_rel = z - z_start,
        tooth_idx = min(n_teeth - 1, floor(z_rel / t_height)),
        z_in_tooth = z_rel - tooth_idx * t_height,
        ramp = depth, // 45 degree angle means ramp height == depth
        flat_h = max(0, t_height - 2 * ramp)
    )
    (z_in_tooth < ramp) ? (z_in_tooth) :
    (z_in_tooth < ramp + flat_h) ? (depth) :
    (depth - (z_in_tooth - ramp - flat_h));

// Generate outer 2D profile points
function outer_profile_key(W, H, bevel, n_teeth, depth, clr, flat_l=false, flat_r=false) =
    let (
        z_b = bevel,
        z_t = H - bevel,
        h_wall = z_t - z_b,
        t_height = h_wall / n_teeth,
        ramp = min(depth, t_height / 2)
    )
    concat(
        // 1. Bottom flat edge
        [ [ bevel, 0 ] ],
        [ [ W - bevel - clr, 0 ] ],
        
        // 2. Bottom-right chamfer
        [ [ W - clr, z_b ] ],
        
        // 3. Right side wall (key teeth going up)
        flat_r ? [ [ W - clr, z_t ] ] :
        [ for (k = [0 : n_teeth - 1]) for (pt = [
            [ W - clr, z_b + k * t_height ],
            [ W - ramp - clr, z_b + k * t_height + ramp ],
            [ W - ramp - clr, z_b + (k + 1) * t_height - ramp ],
            [ W - clr, z_b + (k + 1) * t_height ]
        ]) pt ],
        
        // 4. Top-right chamfer
        [ [ W - bevel - clr, H ] ],
        
        // 5. Top flat edge
        [ [ bevel, H ] ],
        
        // 6. Top-left chamfer
        [ [ 0, z_t ] ],
        
        // 7. Left side wall (key teeth going down)
        flat_l ? [ [ 0, z_b ] ] :
        [ for (k = [n_teeth - 1 : -1 : 0]) for (pt = [
            [ 0, z_b + (k + 1) * t_height ],
            [ ramp, z_b + (k + 1) * t_height - ramp ],
            [ ramp, z_b + k * t_height + ramp ],
            [ 0, z_b + k * t_height ]
        ]) pt ]
    );

polygon(outer_profile_key(W, H, corner_bevel, num_teeth, tooth_depth, clearance));
