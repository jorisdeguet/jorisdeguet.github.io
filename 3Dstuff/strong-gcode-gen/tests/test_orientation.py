import numpy as np

from sgg.orientation import basis_for, candidate_directions, estimate_support


def test_basis():
    for d in candidate_directions():
        R = basis_for(d)
        assert np.allclose(R @ R.T, np.eye(3), atol=1e-9)
        assert np.allclose(R @ d, [0, 0, 1])
        assert np.isclose(np.linalg.det(R), 1)


def _box(c, half):
    return lambda P: np.max(np.abs(P - c) - half, axis=1)


def _grad(sdf):
    def g(P, eps=0.05):
        G = np.stack([(sdf(P + e) - sdf(P - e)) / (2 * eps) for e in np.eye(3) * eps], 1)
        return G / np.linalg.norm(G, axis=1, keepdims=True)
    return g


def test_cube_needs_no_support():
    sdf = _box(np.zeros(3), np.array([5, 5, 5.0]))
    V = np.array([[x, y, z] for x in (-5, 5) for y in (-5, 5) for z in (-5, 5)], float)
    s = estimate_support(sdf, _grad(sdf), V, np.array([0, 0, 1.0]), 0.5, density=1.0)
    assert s.volume == 0


def test_table_support_volume():
    """Plateau 20x20x2 à 10 mm sur un pied 4x4 : support ~ (400-16) * 10."""
    post = _box(np.array([0, 0, 5.0]), np.array([2, 2, 5.0]))
    top = _box(np.array([0, 0, 11.0]), np.array([10, 10, 1.0]))
    sdf = lambda P: np.minimum(post(P), top(P))  # noqa: E731
    V = np.array([[x, y, z] for x in (-10, 10) for y in (-10, 10) for z in (0, 12)], float)
    s = estimate_support(sdf, _grad(sdf), V, np.array([0, 0, 1.0]), 0.5, density=1.0)
    assert abs(s.volume - 384 * 10) / 3840 < 0.08
    # retourné (plateau sur le plateau d'impression) : rien à supporter
    s2 = estimate_support(sdf, _grad(sdf), V, np.array([0, 0, -1.0]), 0.5, density=1.0)
    assert s2.volume == 0
