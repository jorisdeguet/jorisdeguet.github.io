"""Matériau PLA imprimé FDM : rigidité isotrope, résistance anisotrope.

Hypothèses v1 (voir README pour les sources) :
- rigidité isotrope (E, nu) : l'anisotropie de rigidité du PLA FDM plein est
  faible (~10-20 %) devant celle de la résistance ;
- résistance isotrope transverse : le plan des couches (perpendiculaire à la
  direction de construction ``n``) est « fort », la direction ``n`` est faible
  en traction (adhésion inter-couches) et en cisaillement inter-couches.

Critère de rupture (type Tsai-Hill simplifié, sans termes croisés) ::

    FI = sqrt( (vm_plan / X_t)^2 + (<s_n>+ / Z_t)^2 + (<s_n>- / X_c)^2 + (tau_n / S_z)^2 )

avec ``s_n = n.S.n`` (contrainte normale aux couches), ``tau_n`` le cisaillement
sur le plan des couches, ``vm_plan`` le von Mises de l'état de contrainte projeté
dans le plan des couches. FI <= 1 : la pièce tient.
"""
from __future__ import annotations

from dataclasses import dataclass, asdict

import numpy as np


@dataclass(frozen=True)
class PLA:
    E: float = 3000.0  # MPa, module d'Young (PLA FDM plein ~2.8-3.5 GPa)
    nu: float = 0.35
    density: float = 1.24e-3  # g/mm^3
    X_t: float = 40.0  # MPa, traction dans le plan des couches
    X_c: float = 60.0  # MPa, compression
    Z_t: float = 18.0  # MPa, traction normale aux couches (adhésion inter-couches)
    S_z: float = 18.0  # MPa, cisaillement inter-couches

    def to_dict(self) -> dict:
        return asdict(self)

    @property
    def lame(self) -> tuple[float, float]:
        lam = self.E * self.nu / ((1 + self.nu) * (1 - 2 * self.nu))
        mu = self.E / (2 * (1 + self.nu))
        return lam, mu


def von_mises(s: np.ndarray) -> np.ndarray:
    """von Mises de tenseurs (..., 3, 3)."""
    dev = s - np.trace(s, axis1=-2, axis2=-1)[..., None, None] * np.eye(3) / 3.0
    return np.sqrt(1.5 * np.einsum("...ij,...ij->...", dev, dev))


def failure_index(stress: np.ndarray, n: np.ndarray, mat: PLA) -> np.ndarray:
    """Indice de rupture par élément.

    stress : (N, 3, 3) en MPa ; n : direction de construction (normale aux
    couches) dans le repère de la pièce.
    """
    n = np.asarray(n, float)
    n = n / np.linalg.norm(n)
    t = stress @ n  # vecteur contrainte sur le plan des couches, (N,3)
    s_n = t @ n
    tau = np.sqrt(np.maximum(np.einsum("ij,ij->i", t, t) - s_n**2, 0.0))
    P = np.eye(3) - np.outer(n, n)
    s_plane = P @ stress @ P
    vm_p = von_mises(s_plane)
    return np.sqrt(
        (vm_p / mat.X_t) ** 2
        + (np.maximum(s_n, 0) / mat.Z_t) ** 2
        + (np.maximum(-s_n, 0) / mat.X_c) ** 2
        + (tau / mat.S_z) ** 2
    )
