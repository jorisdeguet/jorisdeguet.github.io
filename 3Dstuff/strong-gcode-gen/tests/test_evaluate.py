from sgg.evaluate import evaluate
from sgg.hook import HookParams, HookSpec


def test_evaluate_default_and_anisotropy():
    ev = evaluate(HookParams())
    by = {o.label: o for o in ev.orientations}
    flat = by["à plat (plan du crochet sur le plateau)"]
    upright = by["semelle sur le plateau (debout)"]
    # debout, la tige travaille en traction normale aux couches : plus faible
    assert upright.FI > 1.2 * flat.FI
    assert ev.part_mass > 0 and ev.best.total_mass >= ev.part_mass


def test_failure_index_scales_with_load():
    a = evaluate(HookParams(), HookSpec(mass_kg=1.0))
    b = evaluate(HookParams(), HookSpec(mass_kg=2.0))
    fa = {o.label: o.FI for o in a.orientations}
    for o in b.orientations:
        assert abs(o.FI / fa[o.label] - 2.0) < 1e-6


def test_tcd_average_preserves_uniform_field():
    import numpy as np

    from sgg.evaluate import tcd_average

    c = np.stack(np.meshgrid(*[np.arange(5.0)] * 3, indexing="ij"), -1).reshape(-1, 3)
    s = np.tile(np.diag([3.0, 1.0, 2.0]), (len(c), 1, 1))
    assert np.allclose(tcd_average(c, s, 1.0), s)
    # un pic isolé est étalé sur ses 6 voisins
    s2 = np.zeros_like(s)
    s2[62] = np.eye(3) * 7
    assert np.isclose(tcd_average(c, s2, 1.0)[62, 0, 0], 1.0)
