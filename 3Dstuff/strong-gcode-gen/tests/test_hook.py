import numpy as np

from sgg.hook import Hook, HookParams, HookSpec


def test_mesh_watertight_and_volume_matches_voxels():
    h = Hook(HookParams())
    m = h.mesh(0.3)
    assert m.is_watertight
    lo, hi = h.bbox(1)
    p = 0.4
    ax = [np.arange(lo[i], hi[i], p) + p / 2 for i in range(3)]
    P = np.stack(np.meshgrid(*ax, indexing="ij"), -1).reshape(-1, 3)
    vox = (h.sdf(P) < 0).sum() * p**3
    assert abs(vox - m.volume) / m.volume < 0.02


def test_functional_features():
    s = HookSpec()
    h = Hook(HookParams(), s)
    m = h.mesh(0.3)
    assert abs(m.bounds[1, 2]) < 0.05  # face d'appui plane à z = 0
    assert h.sdf(np.array([[0, 0, -1.0]]))[0] > 0  # trou de vis traversant
    # accès tournevis : rien sous la tête de vis
    col = np.array([[x, 0, z] for x in np.linspace(-s.head_d / 2 + 0.1, s.head_d / 2 - 0.1, 9) for z in np.linspace(-60, -h.p.t_p - 0.3, 40)])
    assert (h.sdf(col) > 0).all()
    # intérieur du C libre au rayon R_in - 0.5
    a = np.radians(np.linspace(185, 175 + s.sweep_deg, 30))
    pts = np.stack([h.xc + (s.R_in - 0.5) * np.cos(a), 0 * a, h.z0 + (s.R_in - 0.5) * np.sin(a)], 1)
    assert (h.sdf(pts) > 0).all()


def test_screw_tension_lever():
    h = Hook(HookParams(pad_back=0.0, r_p=8.0))
    F = 10.0
    assert np.isclose(h.screw_tension(F), F * (h.xc + 8) / 8)
