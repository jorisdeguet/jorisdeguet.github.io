"""Orientation d'impression : directions candidates, supports, transformations.

Une orientation est définie par ``d`` : la direction (dans le repère d'usage de
la pièce) qui pointe vers le haut de l'imprimante (+Z machine). ``d`` est donc
aussi la normale aux couches. La rotation autour de Z machine ne change ni
les supports ni la résistance (plan des couches supposé isotrope) et est
ignorée.

Estimation des supports (méthode par colonnes de voxels, repère machine) :
pour chaque colonne verticale, chaque face inférieure d'un segment plein
(hors plateau) dont la pente est en surplomb (angle à la verticale > limite)
demande un support jusqu'au plein suivant en dessous ou au plateau.
Volume de support = volume de ces colonnes x ``density`` (densité équivalente
des supports arborescents + interfaces).
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np


def candidate_directions(in_plane_step_deg: float = 22.5) -> np.ndarray:
    """Directions « haut » candidates. La pièce est symétrique en y, donc on
    ne garde que d_y >= 0. Plan XZ échantillonné finement (c'est là que se
    jouent les compromis), plus +y (crochet à plat) et des diagonales."""
    dirs = []
    for a in np.arange(0, 360, in_plane_step_deg):
        r = np.radians(a)
        dirs.append((np.cos(r), 0.0, np.sin(r)))
    dirs.append((0.0, 1.0, 0.0))
    for v in [(1, 1, 0), (-1, 1, 0), (0, 1, 1), (0, 1, -1), (1, 1, 1), (-1, 1, 1), (1, 1, -1), (-1, 1, -1)]:
        dirs.append(v)
    d = np.array(dirs, float)
    return d / np.linalg.norm(d, axis=1, keepdims=True)


def describe(d: np.ndarray) -> str:
    d = np.round(np.asarray(d, float), 3)
    names = {
        (0.0, 0.0, 1.0): "semelle en haut (crochet tête en bas)",
        (0.0, 0.0, -1.0): "semelle sur le plateau (debout)",
        (0.0, 1.0, 0.0): "à plat (plan du crochet sur le plateau)",
        (1.0, 0.0, 0.0): "sur la tranche, pointe du C en haut",
        (-1.0, 0.0, 0.0): "sur la tranche, arrière de la semelle en haut",
    }
    return names.get(tuple(d + 0.0), f"d=({d[0]:+.2f},{d[1]:+.2f},{d[2]:+.2f})")


def basis_for(d: np.ndarray) -> np.ndarray:
    """Matrice R (3x3) dont les lignes sont (u, v, d) : x_machine = R @ x_usage."""
    d = np.asarray(d, float)
    d = d / np.linalg.norm(d)
    a = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(a, d)
    u /= np.linalg.norm(u)
    v = np.cross(d, u)
    return np.stack([u, v, d])


@dataclass
class SupportEstimate:
    volume: float  # mm^3 de matière de support (densité appliquée)
    footprint: float  # mm^2 de surface en surplomb à supporter
    height: float  # hauteur d'impression (mm)
    extent_xy: tuple[float, float]


def estimate_support(
    sdf,
    sdf_grad,
    vertices: np.ndarray,
    d: np.ndarray,
    pitch: float = 1.0,
    overhang_deg: float = 50.0,
    density: float = 0.25,
) -> SupportEstimate:
    """``overhang_deg`` : angle à la verticale au-delà duquel un surplomb doit
    être supporté (règle des 45-50° ; en pente depuis l'horizontale cela
    correspond au ``support_threshold_angle`` = 90 - overhang_deg d'Orca)."""
    R = basis_for(d)
    vb = vertices @ R.T
    lo = vb.min(axis=0)
    hi = vb.max(axis=0)
    n = np.maximum(np.ceil((hi - lo) / pitch).astype(int), 1)
    axes = [lo[i] + pitch * (np.arange(n[i]) + 0.5) for i in range(3)]
    G = np.stack(np.meshgrid(*axes, indexing="ij"), -1)  # (nx,ny,nz,3) machine
    P = G.reshape(-1, 3) @ R  # -> repère d'usage
    occ = (sdf(P) < 0).reshape(n)
    # faces inférieures : plein en k, vide en k-1 (k >= 1, hors plateau)
    bottom = np.zeros_like(occ)
    bottom[:, :, 1:] = occ[:, :, 1:] & ~occ[:, :, :-1]
    idx = np.argwhere(bottom)
    if idx.size == 0:
        return SupportEstimate(0.0, 0.0, float(hi[2] - lo[2]), (float(hi[0] - lo[0]), float(hi[1] - lo[1])))
    # normale de la surface (repère usage) au bas du voxel
    pts = G[idx[:, 0], idx[:, 1], idx[:, 2]] - np.array([0, 0, pitch / 2])
    nrm = sdf_grad(pts @ R)
    nz = nrm @ R[2]  # composante verticale machine
    need = -nz > np.sin(np.radians(overhang_deg))
    # indice du dernier voxel plein strictement sous k (-1 = plateau)
    kk = np.arange(n[2])
    last = np.maximum.accumulate(np.where(occ, kk, -1), axis=2)
    last_below = np.full_like(last, -1)
    last_below[:, :, 1:] = last[:, :, :-1]
    i, j, k = idx[need].T
    vol_cells = int((k - (last_below[i, j, k] + 1)).sum())
    return SupportEstimate(
        volume=float(vol_cells * pitch**3 * density),
        footprint=float(need.sum() * pitch**2),
        height=float(hi[2] - lo[2]),
        extent_xy=(float(hi[0] - lo[0]), float(hi[1] - lo[1])),
    )
