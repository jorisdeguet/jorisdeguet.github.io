"""Génération du gcode via la CLI d'OrcaSlicer (profil système Anycubic Kobra X).

Les profils système d'Orca héritent les uns des autres (``inherits``) ; la CLI
attend des profils « à plat ». On résout donc la chaîne d'héritage nous-mêmes
puis on applique des réglages orientés résistance :

- périmètres nombreux et remplissage 100 % : le modèle FEA suppose une pièce
  pleine (la masse calculée = volume x densité) ;
- supports arborescents « partout » avec le même angle de surplomb que
  l'estimateur (``support_threshold_angle`` = 90 - overhang_deg) ;
- pas de tour de purge (mono-matière).

La pièce est exportée en STL déjà tournée dans l'orientation choisie
(direction ``d`` vers +Z) et posée sur le plateau.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import numpy as np

from .orientation import basis_for

ORCA_CANDIDATES = [
    os.environ.get("ORCA_SLICER", ""),
    "/Applications/OrcaSlicer.app/Contents/MacOS/OrcaSlicer",
    shutil.which("orca-slicer") or "",
    shutil.which("OrcaSlicer") or "",
]
PRINTER = "Anycubic Kobra X 0.4 nozzle"
PROCESS = "0.20mm Standard @Anycubic Kobra X 0.4 nozzle"
FILAMENT = "Anycubic PLA @Anycubic Kobra X 0.4 nozzle"

STRENGTH_OVERRIDES = {
    "wall_loops": "6",
    "top_shell_layers": "6",
    "bottom_shell_layers": "6",
    "sparse_infill_density": "100%",
    "sparse_infill_pattern": "zig-zag",
    "enable_support": "1",
    "support_type": "tree(auto)",
    "support_on_build_plate_only": "0",
    "enable_prime_tower": "0",
    "brim_type": "auto_brim",
    "seam_position": "back",
    # le profil système pointe sur la plaque froide (35 °C) : plaque PEI texturée
    "curr_bed_type": "Textured PEI Plate",
}


def find_orca() -> str | None:
    for c in ORCA_CANDIDATES:
        if c and Path(c).exists():
            return c
    return None


def profiles_dir(orca: str) -> Path:
    # .../OrcaSlicer.app/Contents/MacOS/OrcaSlicer -> .../Contents/Resources/profiles/Anycubic
    return Path(orca).resolve().parents[1] / "Resources" / "profiles" / "Anycubic"


def resolve_profile(pdir: Path, kind: str, name: str) -> dict:
    """Fusionne la chaîne ``inherits`` d'un profil système Orca."""
    f = pdir / kind / f"{name}.json"
    data = json.loads(f.read_text())
    parent = data.get("inherits")
    base = resolve_profile(pdir, kind, parent) if parent else {}
    base.update(data)
    base.pop("inherits", None)
    return base


def flat_profiles(orca: str, overhang_deg: float, outdir: Path, layer_height: float | None = None) -> list[Path]:
    pdir = profiles_dir(orca)
    machine = resolve_profile(pdir, "machine", PRINTER)
    process = resolve_profile(pdir, "process", PROCESS)
    filament = resolve_profile(pdir, "filament", FILAMENT)
    process.update(STRENGTH_OVERRIDES)
    # bug du profil système Kobra X (Orca 2.4.2) : 0 hors plage [10, 18] ->
    # la CLI refuse de trancher. Valeur inutilisée (enable_long_retraction_when_cut=0).
    machine["retraction_distances_when_cut"] = ["18"]
    process["support_threshold_angle"] = str(int(round(90 - overhang_deg)))
    if layer_height:
        process["layer_height"] = str(layer_height)
    for d in (machine, process, filament):
        d["from"] = "User"
        d["instantiation"] = "true"
    # la CLI vérifie la compatibilité process/imprimante via le nom du profil
    # système parent (``inherits``) : on présente nos profils à plat comme des
    # profils utilisateur héritant des profils système.
    machine["inherits"], process["inherits"], filament["inherits"] = PRINTER, PROCESS, FILAMENT
    machine["name"], process["name"], filament["name"] = "sgg Kobra X", "sgg strength", "sgg PLA"
    paths = []
    for tag, d in (("machine", machine), ("process", process), ("filament", filament)):
        p = outdir / f"{tag}.json"
        p.write_text(json.dumps(d, indent=1))
        paths.append(p)
    return paths


def oriented_mesh(mesh, d: np.ndarray, bed_center=(130.0, 130.0)):
    """Tourne le maillage pour que ``d`` pointe vers +Z et le pose au centre du plateau."""
    m = mesh.copy()
    R = basis_for(d)
    T = np.eye(4)
    T[:3, :3] = R
    m.apply_transform(T)
    lo, hi = m.bounds
    m.apply_translation([bed_center[0] - (lo[0] + hi[0]) / 2, bed_center[1] - (lo[1] + hi[1]) / 2, -lo[2]])
    return m


def slice_stl(stl: Path, outdir: Path, overhang_deg: float = 50.0, support: bool = True, timeout: int = 600) -> dict:
    orca = find_orca()
    if orca is None:
        raise FileNotFoundError("OrcaSlicer introuvable (définir ORCA_SLICER=/chemin/vers/OrcaSlicer)")
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    cfgdir = outdir / "profiles"
    cfgdir.mkdir(exist_ok=True)
    machine, process, filament = flat_profiles(orca, overhang_deg, cfgdir)
    if not support:
        p = json.loads(process.read_text())
        p["enable_support"] = "0"
        process.write_text(json.dumps(p, indent=1))
    cmd = [
        orca,
        "--debug",
        "3",
        "--logfile",
        str(outdir / "orca.log"),
        "--load-settings",
        f"{machine};{process}",
        "--load-filaments",
        str(filament),
        "--arrange",
        "0",
        "--slice",
        "0",
        "--outputdir",
        str(outdir.resolve()),
        str(Path(stl).resolve()),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    gcodes = sorted(outdir.glob("*.gcode"), key=lambda p: p.stat().st_mtime)
    if proc.returncode != 0 or not gcodes:
        log = (outdir / "orca.log").read_text(errors="ignore") if (outdir / "orca.log").exists() else ""
        errs = "\n".join(l for l in log.splitlines() if re.search(r"error|not compatible|invalid|fail", l, re.I))
        raise RuntimeError(f"échec Orca ({proc.returncode}):\n{proc.stdout[-1000:]}\n{proc.stderr[-2000:]}\n{errs[-3000:]}")
    return {"gcode": gcodes[-1], "stats": gcode_stats(gcodes[-1]), "cmd": cmd}


def gcode_stats(path: Path) -> dict:
    """Lit les statistiques d'en-tête/fin de gcode Orca (filament, temps)."""
    text = Path(path).read_text(errors="ignore")
    out = {}
    pats = {
        "filament_mm": r"; (?:total )?filament used \[mm\] = ([\d.]+)",
        "filament_cm3": r"; (?:total )?filament used \[cm3\] = ([\d.]+)",
        "filament_g": r"; (?:total )?filament used \[g\] = ([\d.]+)",
        "print_time": r"; (?:estimated printing time \(normal mode\)|model printing time) = ([^\n;]+)",
        "gcode_flavor": r"; gcode_flavor = (\w+)",
        "layer_height": r"; layer_height = ([\d.]+)",
        "wall_loops": r"; wall_loops = (\d+)",
        "sparse_infill_density": r"; sparse_infill_density = ([\d%]+)",
    }
    for k, p in pats.items():
        m = re.search(p, text)
        if m:
            out[k] = m.group(1).strip()
    out["lines"] = text.count("\n")
    return out
