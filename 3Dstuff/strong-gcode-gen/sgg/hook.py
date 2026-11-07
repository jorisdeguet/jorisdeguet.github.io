"""Géométrie paramétrique du crochet de plafond.

Repère « d'usage » (mm) : le plafond est le plan z = 0, la pièce pend vers
z < 0. Le crochet est dans le plan XZ, symétrique en y.

    plafond  z=0  ───────────────────────────────
                  [====== semelle (pad) ======]     vis en x = 0 (trou)
                     ^ vis          ||  tige (stem) en x = e
                                    ||
                                    \\        /   <- pointe du C
                                     \\______/
                                        ^ charge (bas du C)

Variables de conception (``HookParams``) : largeur ``b`` (y), épaisseur de la
tige ``h_s`` (x), épaisseur radiale du C ``h_c``, épaisseur de semelle ``t_p``,
demi-largeur de semelle ``r_p`` et prolongement de la semelle derrière la vis
``pad_back``.  Les cotes fonctionnelles (rayon intérieur du C, longueur de la
tige, vis...) sont dans ``HookSpec``.

Deux représentations cohérentes :
- ``sdf(points)`` : distance signée (approx., < 0 dedans), pour le voxelisage
  (FEA) et l'estimation des supports ;
- ``mesh()`` : maillage de surface (marching cubes sur la même SDF) pour le
  volume et l'export STL — une seule source de vérité géométrique.

Les raccords tige/semelle et tige/C sont congés (union lisse de rayon
``HookSpec.fillet``) : sans congé, l'angle rentrant est une singularité de
contrainte (la FEA ne converge pas en raffinant) — et la pièce réelle casse là.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict, fields

import numpy as np


@dataclass(frozen=True)
class HookSpec:
    """Cahier des charges (fixe pendant l'optimisation)."""

    mass_kg: float = 2.0  # charge de service
    safety_factor: float = 3.0  # PLA flue sous charge permanente : SF >= 3 conseillé
    R_in: float = 12.0  # rayon intérieur du C (passage d'une sangle/cintre)
    L_stem: float = 15.0  # longueur libre de la tige sous la semelle
    sweep_deg: float = 220.0  # ouverture angulaire du C
    hole_d: float = 4.5  # trou de vis (vis 4 mm)
    head_d: float = 8.0  # tête de vis
    clearance: float = 1.0  # jeu tête de vis / tige (accès tournevis)
    max_screw_tension_N: float = 300.0  # arrachement admissible (cheville/bois)
    fillet: float = 2.0  # rayon de congé tige/semelle et tige/C
    edge_r: float = 1.0  # arrondi des arêtes de la tige et du C
    max_deflection_mm: float = 3.0  # flèche au point de charge, en service
    g: float = 9.81

    @property
    def service_load_N(self) -> float:
        return self.mass_kg * self.g

    @property
    def design_load_N(self) -> float:
        return self.mass_kg * self.g * self.safety_factor


@dataclass(frozen=True)
class HookParams:
    b: float = 8.0  # largeur (y)
    h_s: float = 6.0  # épaisseur de tige (x)
    h_c: float = 6.0  # épaisseur radiale du C
    t_p: float = 4.0  # épaisseur de semelle
    r_p: float = 8.0  # demi-largeur de semelle (rayon des extrémités)
    pad_back: float = 5.0  # longueur de semelle derrière l'axe de vis

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def names(cls) -> list[str]:
        return [f.name for f in fields(cls)]


# bornes de recherche (mm)
BOUNDS: dict[str, tuple[float, float]] = {
    "b": (3.0, 20.0),
    "h_s": (3.0, 14.0),
    "h_c": (3.0, 14.0),
    "t_p": (2.0, 10.0),
    "r_p": (5.5, 16.0),
    "pad_back": (0.0, 30.0),
}


def _sd_box2(qx, qy, hx, hy):
    dx = np.abs(qx) - hx
    dy = np.abs(qy) - hy
    out = np.hypot(np.maximum(dx, 0), np.maximum(dy, 0))
    return out + np.minimum(np.maximum(dx, dy), 0)


def _smin(a, b, r):
    """Union arrondie (hg_sdf ``fOpUnionRound``) : vrai congé circulaire de
    rayon r entre deux surfaces orthogonales (le smin polynomial donnait un
    rayon effectif bien plus petit que r, donc une concentration de
    contrainte que seuls des voxels fins voyaient)."""
    if r <= 0:
        return np.minimum(a, b)
    ux = np.maximum(r - a, 0.0)
    uy = np.maximum(r - b, 0.0)
    return np.maximum(r, np.minimum(a, b)) - np.hypot(ux, uy)


def _sd_box3(q, half):
    d = np.abs(q) - half
    out = np.linalg.norm(np.maximum(d, 0), axis=-1)
    return out + np.minimum(d.max(axis=-1), 0)


class Hook:
    def __init__(self, params: HookParams, spec: HookSpec = HookSpec()):
        self.p = params
        self.spec = spec
        p, s = params, spec
        # position de la tige : la tête de vis doit rester accessible
        self.e = s.head_d / 2 + s.clearance + p.h_s / 2
        self.rho = s.R_in + p.h_c / 2  # rayon moyen du C
        self.z0 = -(p.t_p + s.L_stem)  # bas de la tige / début du C
        self.xc = self.e + self.rho  # centre du C (x) ; charge sur cette verticale
        self.sweep = np.radians(s.sweep_deg)

    # ------------------------------------------------------------------ SDF
    def sdf(self, pts: np.ndarray) -> np.ndarray:
        p, s = self.p, self.spec
        x, y, z = pts[:, 0], pts[:, 1], pts[:, 2]
        # semelle : obround (capsule 2D) extrudé de z=-t_p à 0
        ax, bx = -p.pad_back, self.e
        tx = np.clip((x - ax) / max(bx - ax, 1e-9), 0, 1)
        d2 = np.hypot(x - (ax + tx * (bx - ax)), y) - p.r_p
        dz = np.abs(z + p.t_p / 2) - p.t_p / 2
        pad = np.hypot(np.maximum(d2, 0), np.maximum(dz, 0)) + np.minimum(np.maximum(d2, dz), 0)
        # tige (remonte jusqu'au plafond : le congé ne bombe pas la face d'appui)
        ztop = 0.0
        zc = (ztop + self.z0) / 2
        # section rectangulaire à arêtes arrondies (rayon re) : sans cela le
        # congé tige/semelle forme un pli rentrant au droit des arêtes vives
        # (singularité : FI x1,4 entre voxels de 0,75 et 0,5 mm).
        re = min(s.edge_r, 0.45 * min(p.h_s, p.b))
        d2s = _sd_box2(x - self.e, y, p.h_s / 2 - re, p.b / 2 - re) - re
        dzs = np.abs(z - zc) - (ztop - self.z0) / 2
        stem = np.hypot(np.maximum(d2s, 0), np.maximum(dzs, 0)) + np.minimum(np.maximum(d2s, dzs), 0)
        # C : secteur de tore à section rectangulaire, angles [pi, pi+sweep]
        dx, dzc = x - self.xc, z - self.z0
        r = np.hypot(dx, dzc)
        rc = min(s.edge_r, 0.45 * min(p.h_c, p.b))
        sec = _sd_box2(r - self.rho, y, p.h_c / 2 - rc, p.b / 2 - rc) - rc
        a = np.arctan2(dzc, dx)
        t = np.mod(a - np.pi, 2 * np.pi)
        inside = t <= self.sweep
        dang = np.where(inside, -np.minimum(t, self.sweep - t), np.minimum(t - self.sweep, 2 * np.pi - t))
        wedge = dang * np.maximum(r, 1e-6)
        arc = np.maximum(sec, wedge)
        solid = _smin(_smin(pad, stem, s.fillet), arc, s.fillet)
        solid = np.maximum(solid, z)  # face d'appui plane au plafond
        hole = s.hole_d / 2 - np.hypot(x, y)
        return np.maximum(solid, hole)

    def sdf_grad(self, pts: np.ndarray, eps: float = 0.05) -> np.ndarray:
        g = np.empty_like(pts)
        for k in range(3):
            dp = np.zeros(3)
            dp[k] = eps
            g[:, k] = (self.sdf(pts + dp) - self.sdf(pts - dp)) / (2 * eps)
        n = np.linalg.norm(g, axis=1, keepdims=True)
        return g / np.maximum(n, 1e-12)

    def bbox(self, margin: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
        p = self.p
        lo = np.array([-p.pad_back - p.r_p, -max(p.r_p, p.b / 2), self.z0 - self.rho - p.h_c / 2])
        hi = np.array([max(self.e + p.r_p, self.xc + self.rho + p.h_c / 2), max(p.r_p, p.b / 2), 0.0])
        return lo - margin, hi + margin

    # -------------------------------------------------------------- maillage
    def mesh(self, pitch: float = 0.25):
        """Maillage de surface étanche (marching cubes sur la SDF)."""
        import trimesh
        from skimage.measure import marching_cubes

        lo, hi = self.bbox(margin=2 * pitch)
        lo = lo + 0.2917 * pitch  # évite des zéros exacts de la SDF sur la grille
        ax = [np.arange(lo[i], hi[i] + pitch, pitch) for i in range(3)]
        G = np.stack(np.meshgrid(*ax, indexing="ij"), -1)
        V = self.sdf(G.reshape(-1, 3)).reshape(G.shape[:3])
        v, f, _, _ = marching_cubes(V, 0.0, spacing=(pitch,) * 3)
        return trimesh.Trimesh(v + lo, f)

    def volume(self, pitch: float = 0.4) -> float:
        return float(self.mesh(pitch).volume)

    # ------------------------------------------------- conditions aux limites
    def fixed_nodes(self, nodes: np.ndarray, tol: float) -> np.ndarray:
        """Encastrement : face supérieure de la semelle, côté vis/arrière
        (x <= rayon de tête). Le côté avant (x > 0) tend à décoller du plafond
        sous le moment F*xc, il n'est donc pas bloqué."""
        x, z = nodes[:, 0], nodes[:, 2]
        return (np.abs(z) < tol) & (x <= self.spec.head_d / 2)

    def load_nodes(self, nodes: np.ndarray, tol: float, half_angle_deg: float = 12.0) -> np.ndarray:
        """Nœuds de la face intérieure du C autour du point bas (sangle)."""
        dx, dz = nodes[:, 0] - self.xc, nodes[:, 2] - self.z0
        r = np.hypot(dx, dz)
        ang = np.degrees(np.arctan2(dz, dx))  # -90 = point bas
        return (np.abs(ang + 90) <= half_angle_deg) & (r <= self.spec.R_in + tol) & (r >= self.spec.R_in - tol)

    def screw_tension(self, F: float) -> float:
        """Traction dans la vis (équilibre de la semelle rigide, pivot sur le
        bord arrière de la semelle)."""
        arm_back = self.p.pad_back + self.p.r_p
        return F * (self.xc + arm_back) / arm_back

    def beam_stem_stress(self, F: float) -> float:
        """Contrainte max (théorie des poutres) dans la tige : traction + flexion."""
        b, h = self.p.b, self.p.h_s
        return F / (b * h) + 6 * F * self.rho / (b * h**2)
