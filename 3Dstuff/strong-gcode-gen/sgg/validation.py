"""Validation de la FEA voxel contre la théorie des poutres."""
from __future__ import annotations

import numpy as np

from .fea import solve_elasticity
from .material import PLA


def cantilever_check(pitch: float = 1.0, L=40.0, b=8.0, h=6.0, F=10.0, mat=PLA()) -> dict:
    """Console encastrée en x=0, charge F (-z) répartie sur la face x=L.
    Théorie : flèche F L^3 / (3 E I) ; contrainte de flexion à mi-portée
    6 F (L/2) / (b h^2)."""
    sdf = lambda P: np.max(np.abs(P - np.array([L / 2, 0, 0])) - np.array([L / 2, b / 2, h / 2]), axis=1)  # noqa: E731
    r = solve_elasticity(
        sdf, [0, -b / 2, -h / 2], [L, b / 2, h / 2], pitch,
        lambda n, t: n[:, 0] < t, lambda n, t: n[:, 0] > L - t, np.array([0, 0, -F]), mat,
    )
    I = b * h**3 / 12
    mid = np.abs(r.centers[:, 0] - L / 2) < 0.6 * pitch
    return {
        "dofs": r.n_dofs,
        "defl_ratio": float(-r.load_disp[2] / (F * L**3 / (3 * mat.E * I))),
        "stress_ratio": float(r.stress[mid][..., 0, 0].max() / (6 * F * (L / 2) / (b * h**2))),
    }


def hook_stem_check(pitch: float = 1.0) -> dict:
    """Contrainte axiale + flexion dans la tige du crochet par défaut."""
    from .evaluate import EvalConfig, evaluate
    from .hook import HookParams

    ev = evaluate(HookParams(), cfg=EvalConfig(fea_pitch=pitch))
    return {"beam": ev.stem_stress_beam, "fea": ev.stem_stress_fea, "ratio": ev.stem_stress_fea / ev.stem_stress_beam}
