"""FEA élastique linéaire sur maillage voxel (hexaèdres) avec scikit-fem.

La géométrie (fonction distance signée) est voxelisée sur une grille régulière
de pas ``pitch`` ; chaque voxel plein devient un hexaèdre trilinéaire (Hex1).
Seule la composante connexe (par faces) contenant l'encastrement est gardée.

Résolution : gradient conjugué préconditionné par multigrille algébrique
(pyamg, agrégation lissée avec les 6 modes rigides) — ~25x plus rapide que
SuperLU dès ~50 k DDL. Repli sur ``scipy.sparse.linalg.spsolve`` si pyamg
est absent.

Contraintes : évaluées aux 8 coins de chaque élément (et non au centre), ce
qui récupère la contrainte de surface en flexion (le centre d'un voxel de
peau est à pitch/2 sous la surface). Validé contre la théorie des poutres
dans ``tests/test_fea.py``.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import numpy as np
import scipy.sparse as sp
from scipy.sparse.csgraph import connected_components
from skfem import Basis, ElementHex1, ElementVector, MeshHex, asm, condense
from skfem.models.elasticity import linear_elasticity

from .material import PLA


@dataclass
class FEAResult:
    mesh: MeshHex
    u: np.ndarray  # DDL
    stress: np.ndarray  # (Ne, 8, 3, 3) MPa aux coins des éléments
    centers: np.ndarray  # (Ne, 3)
    load_disp: np.ndarray  # déplacement moyen des nœuds chargés (3,)
    n_dofs: int
    pitch: float
    near_fixed: np.ndarray  # (Ne,) bool : élément touchant l'encastrement

    @property
    def volume(self) -> float:
        return self.centers.shape[0] * self.pitch**3

    @property
    def stress_center(self) -> np.ndarray:
        return self.stress.mean(axis=1)


def voxel_mesh(sdf: Callable, lo: np.ndarray, hi: np.ndarray, pitch: float) -> MeshHex:
    lo = np.asarray(lo, float)
    hi = np.asarray(hi, float)
    n = np.maximum(np.ceil((hi - lo) / pitch - 1e-9).astype(int), 1)
    axes = [lo[i] + pitch * np.arange(n[i] + 1) for i in range(3)]
    cx = [0.5 * (a[1:] + a[:-1]) for a in axes]
    C = np.stack(np.meshgrid(*cx, indexing="ij"), -1).reshape(-1, 3)
    inside = sdf(C) < 0
    mesh = MeshHex.init_tensor(*axes)
    centers = mesh.p[:, mesh.t].mean(axis=1).T
    idx = np.clip(np.floor((centers - lo) / pitch).astype(int), 0, n - 1)
    keep = inside[np.ravel_multi_index(idx.T, n)]
    return mesh.restrict(np.nonzero(keep)[0])


def _keep_component(mesh: MeshHex, seed_nodes: np.ndarray) -> MeshHex:
    f2t = mesh.f2t
    inner = f2t[1] >= 0
    a, b = f2t[0, inner], f2t[1, inner]
    ne = mesh.t.shape[1]
    G = sp.coo_matrix((np.ones(a.size), (a, b)), shape=(ne, ne))
    ncomp, labels = connected_components(G, directed=False)
    if ncomp == 1:
        return mesh
    el_seed = np.isin(mesh.t, seed_nodes).any(axis=0)
    good = np.unique(labels[el_seed])
    return mesh.restrict(np.nonzero(np.isin(labels, good))[0])


def _rigid_modes(basis, I) -> np.ndarray:
    nd = basis.nodal_dofs
    X, Y, Z = basis.doflocs[:, I]
    comp = [np.isin(I, nd[k]) for k in range(3)]
    B = np.zeros((I.size, 6))
    for k in range(3):
        B[comp[k], k] = 1
    B[comp[0], 3], B[comp[1], 3] = -Y[comp[0]], X[comp[1]]
    B[comp[1], 4], B[comp[2], 4] = -Z[comp[1]], Y[comp[2]]
    B[comp[2], 5], B[comp[0], 5] = -X[comp[2]], Z[comp[0]]
    return B


def _linsolve(A, b, basis, I, tol=1e-8):
    try:
        import pyamg
    except ImportError:  # pragma: no cover
        from scipy.sparse.linalg import spsolve

        return spsolve(A.tocsc(), b)
    ml = pyamg.smoothed_aggregation_solver(A.tocsr(), B=_rigid_modes(basis, I))
    return ml.solve(b, tol=tol, accel="cg", maxiter=500)


def solve_elasticity(
    sdf: Callable,
    lo,
    hi,
    pitch: float,
    fixed_fn: Callable[[np.ndarray, float], np.ndarray],
    load_fn: Callable[[np.ndarray, float], np.ndarray],
    force: np.ndarray,
    mat: PLA = PLA(),
) -> FEAResult:
    """Résout K u = f. ``force`` : force totale (N) répartie sur les nœuds chargés."""
    # grille alignée sur des multiples du pas (un plan de nœuds en z = 0)
    lo = pitch * np.floor(np.asarray(lo, float) / pitch)
    hi = pitch * np.ceil(np.asarray(hi, float) / pitch)
    mesh = voxel_mesh(sdf, lo, hi, pitch)
    tol = 0.51 * pitch
    seed = np.nonzero(fixed_fn(mesh.p.T, tol))[0]
    if seed.size == 0:
        raise ValueError("aucun nœud encastré")
    mesh = _keep_component(mesh, seed)
    nodes = mesh.p.T
    fixed_nodes = np.nonzero(fixed_fn(nodes, tol))[0]
    load_nodes = np.nonzero(load_fn(nodes, tol))[0]
    if load_nodes.size == 0:
        raise ValueError("aucun nœud chargé")

    basis = Basis(mesh, ElementVector(ElementHex1()), intorder=2)
    lam, mu = mat.lame
    K = asm(linear_elasticity(lam, mu), basis)
    f = np.zeros(basis.N)
    nd = basis.nodal_dofs
    for k in range(3):
        f[nd[k, load_nodes]] += force[k] / load_nodes.size
    D = nd[:, fixed_nodes].ravel()
    A, b, x, I = condense(K, f, D=D)
    x[I] = _linsolve(A, b, basis, I)
    u = x

    # contraintes aux 8 coins de chaque élément (quadrature « aux coins »)
    corners = np.array(np.meshgrid([0.0, 1.0], [0.0, 1.0], [0.0, 1.0], indexing="ij")).reshape(3, -1)
    cb = Basis(mesh, ElementVector(ElementHex1()), quadrature=(corners, np.full(8, 1 / 8)))
    grad = cb.interpolate(u).grad  # (3, 3, Ne, 8)
    eps = 0.5 * (grad + grad.transpose(1, 0, 2, 3))
    tr = np.einsum("ii...->...", eps)
    sig = 2 * mu * eps + lam * tr[None, None] * np.eye(3)[:, :, None, None]
    stress = sig.transpose(2, 3, 0, 1)  # (Ne, 8, 3, 3)
    centers = mesh.p[:, mesh.t].mean(axis=1).T
    near_fixed = np.isin(mesh.t, fixed_nodes).any(axis=0)
    load_disp = u[nd[:, load_nodes]].mean(axis=1)
    return FEAResult(mesh, u, stress, centers, load_disp, basis.N, pitch, near_fixed)
