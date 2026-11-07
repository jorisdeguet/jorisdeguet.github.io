import pytest

from sgg import slicer


@pytest.mark.skipif(slicer.find_orca() is None, reason="OrcaSlicer absent")
def test_profiles_resolve(tmp_path):
    orca = slicer.find_orca()
    m, p, f = slicer.flat_profiles(orca, 50.0, tmp_path)
    import json

    mach = json.loads(m.read_text())
    proc = json.loads(p.read_text())
    assert mach["gcode_flavor"] == "klipper"
    assert mach["printable_area"] == ["0x0", "260x0", "260x260", "0x260"]
    assert proc["sparse_infill_density"] == "100%"
    assert proc["support_threshold_angle"] == "40"
    assert "wall_generator" in proc  # hérité de fdm_process_common


def test_gcode_stats(tmp_path):
    g = tmp_path / "a.gcode"
    g.write_text("; filament used [g] = 7.49\n; gcode_flavor = klipper\n; wall_loops = 6\n")
    s = slicer.gcode_stats(g)
    assert s["filament_g"] == "7.49" and s["gcode_flavor"] == "klipper"
