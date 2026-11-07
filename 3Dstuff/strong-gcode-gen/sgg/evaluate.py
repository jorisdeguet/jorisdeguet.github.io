"""Évaluation d'un candidat : matière (pièce + supports) et résistance, pour
chaque orientation candidate ; on retient la meilleure orientation.

La FEA ne dépend pas de l'orientation (rigidité isotrope) : un seul calcul
par géométrie, puis le critère anisotrope est réévalué pour chaque normale
aux couches ``d`` (peu coûteux).
"""
from __future__ import annotations

from dataclasses import dataclass, field, asdict

import numpy as np
import scipy.sparse as sp
from scipy.spatial import cKDTree

from .fea import solve_elasticity
from .hook import Hook, HookParams, HookSpec
from .material import PLA, failure_index
from .orientation import candidate_directions, describe, estimate_support


def tcd_average(centers: np.ndarray, stress: np.ndarray, radius: float) -> np.ndarray:
    """Moyenne des tenseurs (Ne,3,3) sur les éléments à moins de ``radius``."""
    n = len(centers)
    pairs = cKDTree(centers).query_pairs(radius, output_type="ndarray")
    i = np.r_[pairs[:, 0], pairs[:, 1], np.arange(n)]
    j = np.r_[pairs[:, 1], pairs[:, 0], np.arange(n)]
    A = sp.csr_matrix((np.ones(i.size), (i, j)), shape=(n, n))
    w = np.asarray(A.sum(axis=1)).ravel()
    return (A @ stress.reshape(n, 9) / w[:, None]).reshape(n, 3, 3)


@dataclass(frozen=True)
class EvalConfig:
    fea_pitch: float = 0.75  # mm, taille des voxels FEA
    support_pitch: float = 1.0
    overhang_deg: float = 50.0
    support_density: float = 0.25
    in_plane_step_deg: float = 22.5
    mesh_pitch: float = 0.4  # marching cubes pour volume / bbox
    # la frontière bloqué/libre de l'encastrement est une singularité
    # numérique (artefact de modélisation) : on exclut du critère les
    # éléments à moins de cette distance (mm) de la zone encastrée.
    clamp_exclusion: float = 1.5
    # Théorie des distances critiques (méthode volumique, Taylor 2007) : la
    # contrainte de calcul est la moyenne sur une boule de ce rayon (mm).
    # Les pics sur les surfaces en escalier des voxels ne convergent pas ;
    # la moyenne, si. Pour le PLA L = (K_IC/sigma_0)^2/pi ~ 1 mm et la méthode
    # volumique moyenne sur ~1,8 L : 1 mm est donc prudent. 0 = pic aux coins.
    tcd_radius: float = 1.0


@dataclass
class OrientationResult:
    d: tuple
    label: str
    FI: float  # indice de rupture à la charge de calcul (<= 1 OK)
    support_volume: float
    support_mass: float
    total_mass: float
    height: float
    feasible: bool
    violation: float


@dataclass
class Evaluation:
    params: dict
    part_volume: float
    part_mass: float
    deflection_service: float
    screw_tension_design: float
    stem_stress_beam: float  # contrainte poutre dans la tige (charge de calcul)
    stem_stress_fea: float  # sigma_zz max FEA dans la tige (charge de calcul)
    fea_dofs: int
    best: OrientationResult
    orientations: list[OrientationResult] = field(default_factory=list)

    @property
    def objective(self) -> float:
        return self.best.total_mass

    @property
    def feasible(self) -> bool:
        return self.best.feasible

    @property
    def capacity_kg(self) -> float:
        """Masse à rupture prédite (résistance moyenne, sans coefficient)."""
        return self.design_load_kg / max(self.best.FI, 1e-9)

    design_load_kg: float = 0.0

    def to_dict(self) -> dict:
        d = asdict(self)
        d["capacity_kg"] = self.capacity_kg
        d["objective"] = self.objective
        d["feasible"] = self.feasible
        return d


def evaluate(
    params: HookParams,
    spec: HookSpec = HookSpec(),
    cfg: EvalConfig = EvalConfig(),
    mat: PLA = PLA(),
    keep_fea: bool = False,
):
    hook = Hook(params, spec)
    F = spec.design_load_N
    lo, hi = hook.bbox(margin=cfg.fea_pitch)
    res = solve_elasticity(
        hook.sdf, lo, hi, cfg.fea_pitch, hook.fixed_nodes, hook.load_nodes, np.array([0.0, 0.0, -F]), mat
    )
    stress = res.stress
    mask = np.ones(len(stress), bool)
    if cfg.clamp_exclusion > 0:
        c = res.centers
        mask &= ~((c[:, 2] > -cfg.clamp_exclusion) & (c[:, 0] < spec.head_d / 2 + cfg.clamp_exclusion))
    if cfg.tcd_radius > 0:
        S = tcd_average(res.centers, stress.mean(axis=1), cfg.tcd_radius)[mask]
    else:
        S = stress[mask].reshape(-1, 3, 3)

    tm = hook.mesh(cfg.mesh_pitch)
    vol = float(tm.volume)
    verts = np.asarray(tm.vertices)
    part_mass = vol * mat.density
    defl = float(-res.load_disp[2]) * spec.service_load_N / F
    T = hook.screw_tension(F)

    # vérif poutre : sigma_zz dans la tige à mi-hauteur
    zc = (hook.z0 - params.t_p) / 2
    in_stem = (np.abs(res.centers[:, 0] - hook.e) < params.h_s / 2) & (np.abs(res.centers[:, 2] - zc) < cfg.fea_pitch)
    stem_fea = float(stress[in_stem][..., 2, 2].max()) if in_stem.any() else float("nan")

    common_viol = max(0.0, T / spec.max_screw_tension_N - 1) + max(0.0, defl / spec.max_deflection_mm - 1)
    ors = []
    for d in candidate_directions(cfg.in_plane_step_deg):
        FI = float(failure_index(S, d, mat).max())
        sup = estimate_support(
            hook.sdf, hook.sdf_grad, verts, d, cfg.support_pitch, cfg.overhang_deg, cfg.support_density
        )
        fits = sup.height <= 250 and max(sup.extent_xy) <= 250
        viol = max(0.0, FI - 1) + common_viol + (0 if fits else 1.0)
        sm = sup.volume * mat.density
        ors.append(
            OrientationResult(
                tuple(float(v) for v in np.round(d, 4)), describe(d), FI, sup.volume, sm, part_mass + sm, sup.height, viol == 0, viol
            )
        )
    # meilleure orientation : faisable de masse minimale, sinon violation minimale
    best = min(ors, key=lambda o: (not o.feasible, o.violation if not o.feasible else 0, o.total_mass))
    ev = Evaluation(
        params=params.to_dict(),
        part_volume=vol,
        part_mass=part_mass,
        deflection_service=defl,
        screw_tension_design=T,
        stem_stress_beam=hook.beam_stem_stress(F),
        stem_stress_fea=stem_fea,
        fea_dofs=res.n_dofs,
        best=best,
        orientations=sorted(ors, key=lambda o: o.total_mass + 1000 * o.violation),
        design_load_kg=spec.mass_kg * spec.safety_factor,
    )
    return (ev, res, hook) if keep_fea else ev
