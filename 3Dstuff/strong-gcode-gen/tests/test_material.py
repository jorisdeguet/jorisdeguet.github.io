import numpy as np

from sgg.material import PLA, failure_index, von_mises


def _s(**kw):
    s = np.zeros((1, 3, 3))
    idx = {"xx": (0, 0), "yy": (1, 1), "zz": (2, 2)}
    for k, v in kw.items():
        if k in idx:
            s[0][idx[k]] = v
        elif k == "xz":
            s[0, 0, 2] = s[0, 2, 0] = v
    return s


def test_uniaxial_limits():
    m = PLA()
    z = np.array([0, 0, 1.0])
    assert np.isclose(failure_index(_s(xx=m.X_t), z, m)[0], 1.0)  # dans le plan
    assert np.isclose(failure_index(_s(zz=m.Z_t), z, m)[0], 1.0)  # inter-couches
    assert np.isclose(failure_index(_s(zz=-m.X_c), z, m)[0], 1.0)  # compression
    assert np.isclose(failure_index(_s(xz=m.S_z), z, m)[0], 1.0)  # cisaillement inter-couches


def test_anisotropy_orientation():
    """La même traction est plus critique normale aux couches."""
    m = PLA()
    s = _s(zz=10.0)
    assert failure_index(s, [0, 0, 1], m)[0] > failure_index(s, [1, 0, 0], m)[0]


def test_von_mises_uniaxial():
    assert np.isclose(von_mises(_s(xx=7.0))[0], 7.0)
