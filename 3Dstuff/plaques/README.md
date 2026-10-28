# Plaques

Open the desired `.scad` file in OpenSCAD and export it as STL. The models use
millimetres and are oriented with the finished, countersunk face down by
default.

| File | Purpose |
| --- | --- |
| `plaque.scad` | Single decorator/Decora position; edit `gang_count` and `slot_styles` for a custom layout. |
| `plaque_2_outlets.scad` | Two decorator positions (four receptacles when both hold duplex outlets). |
| `plaque_3_outlets.scad` | Three decorator positions. |
| `plaque_4_outlets.scad` | Four decorator positions (eight receptacles or four switches). |
| `plaque_duplex_outlet.scad` | One conventional duplex outlet with two rounded openings. |

Every printable `.scad` file exposes its own outer dimensions, edge rounding,
and back-clearance parameters. In the multi-position files, set an individual
`slot_N_style` to `"flat"` to leave that position completely solid, or
`"decora"` to create the opening and its two countersunk screw holes. Adjust
the dimensions to match the installed device before printing.
