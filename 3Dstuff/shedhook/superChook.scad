// Parametric ceiling hook — print on side.
//
// PRINT ORIENTATION
//   Lay flat: profile in XY, hook_width_mm in Z (print height).
//   Layer lines wrap around the C-arc perimeter — strongest for bending/tension.
//
// INSTALLATION  (switch render_mode to "installed" to visualise)
//   1. rotate([90,0,0]) stands the profile vertical; C hangs straight down.
//   2. Press the flat top face of the mount pad (max-Y in print = max-Z
//      installed) flush against the ceiling joist face.
//   3. Drive the drywall screw upward through the clearance hole into the joist.
//      The bugle/cone head bears on the 5 mm pad face and self-embeds into PLA
//      under drive torque — do not overtighten.  Pre-drill a pilot hole.
//   4. Lift the item up into the open-bottom C-cradle; gravity retains it.
//
// FORCE ALIGNMENT
//   Screw centreline and item centre are both at X = 0 in both orientations.
//   The hung load creates no bending moment on the screw.
//
// SCREW NOTE
//   The screw runs through the 5 mm hook thickness (print-Z = installed-Y).
//   A standard drywall screw shank (≤ hook_width_mm) fits; the head overhangs
//   the narrow edge and bears on the wider pad face — this is intentional.

$fn = 96;
eps = 0.01;

render_mode = "print"; // "print" or "installed"

// ── Core sizing ──────────────────────────────────────────────────────────────
hook_width_mm          = 5;   // extruded depth (print Z = installed front-to-back)
thing_diameter_mm      = 55;  // outside diameter of the object to hang
fit_clearance_mm       = 3;   // extra air-gap inside the arc
hook_wall_mm           = 7;   // radial wall thickness of the ring

// Distance below the ring centre at which the C mouth opens.
//   0  → 180 ° semicircle (widest entry, shallowest cradle).
//   ↑  → deeper wrap, narrower entry gap.
//   max ≈ sqrt(inner_r² − (thing_dia/2)²)  so gap ≥ thing_diameter.
mouth_below_centre_mm  = 8;   // default: ≈ 55.7 mm gap, ≈ 212 ° wrap

// ── Mount pad & fastener ─────────────────────────────────────────────────────
mount_pad_radius_mm    = 10;  // radius of the circular ceiling plate
// Clearance hole only — no countersink (head is wider than 5 mm hook edge).
// Use a #6 drywall screw (≈ 3.5 mm shank).  Larger screws risk splitting
// the thin PLA wall around the hole.
screw_shank_dia_mm     = 3.5;

// ── Web ──────────────────────────────────────────────────────────────────────
web_thickness_mm       = 11;  // width of the neck connecting pad to ring

// ── Derived ──────────────────────────────────────────────────────────────────
clear_diameter_mm  = thing_diameter_mm + fit_clearance_mm;
inner_radius_mm    = clear_diameter_mm / 2;
outer_radius_mm    = inner_radius_mm + hook_wall_mm;
// Ring sits below the mount pad, outer top tangent to the pad bottom (Y = −pad_r).
ring_center_y_mm   = -(mount_pad_radius_mm + outer_radius_mm);
web_anchor_y_mm    = ring_center_y_mm + outer_radius_mm * 0.55;

mouth_gap_mm = 2 * sqrt(max(0,
    inner_radius_mm * inner_radius_mm
    - mouth_below_centre_mm * mouth_below_centre_mm));

// ── Assertions ───────────────────────────────────────────────────────────────
assert(hook_width_mm > 0);
assert(thing_diameter_mm > 0);
assert(fit_clearance_mm >= 0);
assert(hook_wall_mm > 0);
assert(mount_pad_radius_mm > 0);
assert(web_thickness_mm > 0);
assert(screw_shank_dia_mm > 0);
assert(screw_shank_dia_mm < hook_width_mm,
    "screw_shank_dia_mm must be less than hook_width_mm.");
assert(mouth_below_centre_mm >= 0 && mouth_below_centre_mm < inner_radius_mm,
    "mouth_below_centre_mm must be in [0, inner_radius_mm).");
assert(mouth_gap_mm >= thing_diameter_mm,
    str("Mouth gap ", mouth_gap_mm,
        " mm < thing_diameter_mm. Reduce mouth_below_centre_mm."));

echo(str("Clear inside diameter: ", clear_diameter_mm, " mm"));
echo(str("Outer diameter:        ", 2 * outer_radius_mm, " mm"));
echo(str("Mouth gap (opening):   ", mouth_gap_mm,
         " mm  (need >= ", thing_diameter_mm, " mm ✓)"));
echo(str("Arc wrap:              ~",
         180 + 2 * asin(mouth_below_centre_mm / inner_radius_mm), " °"));
echo(str("Screw hole: along Y (print) = vertical into ceiling when installed,",
         " Ø", screw_shank_dia_mm, " mm clearance hole."));

// ── 2-D profile ───────────────────────────────────────────────────────────────
module ring_2d() {
    difference() {
        circle(r = outer_radius_mm);
        circle(r = inner_radius_mm);
    }
}

module c_hook_2d() {
    // Downward-opening C: ring centred at ring_center_y_mm with its bottom
    // cut away.  Item enters from below; gravity keeps it seated at the top
    // of the inner arc.
    translate([0, ring_center_y_mm])
        difference() {
            ring_2d();
            // Remove everything below (-mouth_below_centre_mm) in ring-local Y.
            translate([-(outer_radius_mm + eps), -(outer_radius_mm + eps)])
                square([2 * (outer_radius_mm + eps),
                        outer_radius_mm + eps - mouth_below_centre_mm]);
        }
}

module hook_profile_2d() {
    union() {
        c_hook_2d();

        // Circular ceiling pad.  Its +Y face (max-Y) contacts the ceiling.
        circle(r = mount_pad_radius_mm);

        // Tapered web neck bridging pad to ring body.
        hull() {
            circle(r = mount_pad_radius_mm);
            translate([0, web_anchor_y_mm])
                circle(r = web_thickness_mm / 2);
        }
    }
}

// ── 3-D solid ─────────────────────────────────────────────────────────────────
module hook_body() {
    linear_extrude(height = hook_width_mm, convexity = 10)
        hook_profile_2d();
}

// Screw clearance hole along +Y at (X = 0, Z = hook_width / 2).
// After rotate([90,0,0]) for installation, +Y maps to +Z → straight into ceiling.
module screw_cut() {
    translate([0, -(mount_pad_radius_mm + eps), hook_width_mm / 2])
        rotate([-90, 0, 0])
            cylinder(d = screw_shank_dia_mm,
                     h = 2 * mount_pad_radius_mm + 2 * eps);
}

module printable_hook() {
    difference() {
        hook_body();
        screw_cut();
    }
}

// ── Render modes ──────────────────────────────────────────────────────────────
module installed_hook() {
    // rotate([90,0,0]): old +Y → new +Z (up toward ceiling),
    //                   old +Z → new -Y (hook depth, front-to-back).
    // Result: pad top face against ceiling, C hangs straight down.
    rotate([90, 0, 0])
        printable_hook();
}

if (render_mode == "print")
    printable_hook();
else if (render_mode == "installed")
    installed_hook();
else
    assert(false, "render_mode must be \"print\" or \"installed\".");
