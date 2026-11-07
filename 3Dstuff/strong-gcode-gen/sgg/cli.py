"""Point d'entrée en ligne de commande : ``python -m sgg <commande>``.

Commandes :
  evaluate   évalue un design (paramètres par défaut ou --set b=8 ...)
  validate   compare la FEA à la théorie des poutres (console encastrée)
  optimize   GA (+ recherche aléatoire de référence), puis finalisation
             (vérif FEA fine, STL orienté, gcode Orca, résumé)
  slice      tranche un design donné (JSON de paramètres)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from dataclasses import replace
from pathlib import Path

import numpy as np


def _parse_set(items) -> dict:
    out = {}
    for it in items or []:
        k, v = it.split("=")
        out[k] = float(v)
    return out


def _spec(args):
    from .hook import HookSpec

    return HookSpec(mass_kg=args.mass, safety_factor=args.sf)


def _cfg(args):
    from .evaluate import EvalConfig

    return EvalConfig(fea_pitch=args.pitch, support_density=args.support_density, overhang_deg=args.overhang,
                      tcd_radius=args.tcd)


def print_eval(ev, n_orient: int = 8):
    print(f"paramètres          : {ev.params}")
    print(f"volume / masse pièce: {ev.part_volume:.0f} mm3 / {ev.part_mass:.2f} g")
    print(f"flèche (service)    : {ev.deflection_service:.3f} mm")
    print(f"traction vis (calc.): {ev.screw_tension_design:.0f} N")
    print(f"tige sigma_zz       : poutre {ev.stem_stress_beam:.1f} MPa / FEA {ev.stem_stress_fea:.1f} MPa")
    print(f"DDL FEA             : {ev.fea_dofs}")
    print(f"{'orientation':48s} {'FI':>5s} {'supp g':>7s} {'total g':>8s} {'h mm':>5s} ok")
    for o in ev.orientations[:n_orient]:
        print(f"{o.label:48s} {o.FI:5.2f} {o.support_mass:7.2f} {o.total_mass:8.2f} {o.height:5.0f} {'✓' if o.feasible else '✗'}")
    b = ev.best
    print(f"=> meilleure : {b.label}  total {b.total_mass:.2f} g  FI {b.FI:.2f}  "
          f"capacité prédite {ev.capacity_kg:.1f} kg  faisable={ev.feasible}")


def cmd_evaluate(args):
    from .evaluate import evaluate
    from .hook import HookParams

    p = HookParams(**{**HookParams().to_dict(), **_parse_set(args.set)})
    t = time.time()
    ev = evaluate(p, _spec(args), _cfg(args))
    print_eval(ev, args.n)
    print(f"({time.time() - t:.1f} s)")


def cmd_validate(args):
    from .validation import cantilever_check, hook_stem_check

    for pitch in args.pitches:
        r = cantilever_check(pitch)
        print(f"console L=40 b=8 h=6, pas {pitch}: flèche FEA/théorie {r['defl_ratio']:.3f}, "
              f"sigma FEA/théorie {r['stress_ratio']:.3f} ({r['dofs']} DDL)")
    r = hook_stem_check(args.pitch)
    print(f"crochet par défaut, tige : poutre {r['beam']:.1f} MPa, FEA {r['fea']:.1f} MPa (ratio {r['ratio']:.3f})")


def _orient(ev, d):
    return min(ev.orientations, key=lambda o: np.linalg.norm(np.subtract(o.d, d)))


def finalize(params, spec, cfg, outdir: Path, verify_pitch: float = 0.5, do_slice: bool = True,
             opt_eval=None, max_repairs: int = 5) -> dict:
    """Vérification FEA fine du meilleur design, réparation si besoin, STL, gcode.

    La FEA de l'optimisation (voxels grossiers) peut sous-estimer les pics de
    contrainte dans les congés. Si le design n'est pas faisable au pas fin, on
    l'épaissit (b, h_s, h_c, t_p multipliés par FI^(1/3), contrainte de
    flexion ~ 1/(b h^2)) jusqu'à ce qu'il le soit."""
    from .evaluate import evaluate
    from .hook import BOUNDS, Hook, HookParams

    outdir.mkdir(parents=True, exist_ok=True)
    fine_cfg = replace(cfg, fea_pitch=verify_pitch)
    ev_fine = evaluate(params, spec, fine_cfg)
    info = {"verify": ev_fine.to_dict(), "repairs": []}
    if opt_eval is not None:
        o = _orient(ev_fine, opt_eval.best.d)
        info["verify_opt_orientation"] = {"label": o.label, "FI": o.FI, "support_mass": o.support_mass,
                                          "total_mass": o.total_mass, "feasible": o.feasible}
    ev, p = ev_fine, params
    for _ in range(max_repairs):
        if ev.feasible:
            break
        s = max(ev.best.FI, 1.0) ** (1 / 3) * 1.03
        q = p.to_dict()
        for k in ("b", "h_s", "h_c", "t_p"):
            q[k] = round(float(np.clip(q[k] * s, *BOUNDS[k])), 2)
        if ev.screw_tension_design > spec.max_screw_tension_N:
            q["pad_back"] = round(float(np.clip(q["pad_back"] + 3.0, *BOUNDS["pad_back"])), 2)
        p = HookParams(**q)
        ev = evaluate(p, spec, fine_cfg)
        info["repairs"].append({"params": p.to_dict(), "FI": ev.best.FI, "total_mass": ev.best.total_mass,
                                "feasible": ev.feasible, "orientation": ev.best.label})
    info["final"] = ev.to_dict()
    best = ev.best
    d = np.array(best.d)
    info["orientation"] = {"d": best.d, "label": best.label}
    hook = Hook(p, spec)
    mesh = hook.mesh(0.3)
    mesh.export(outdir / "best_hook.stl")
    if do_slice:
        from .slicer import find_orca, oriented_mesh, slice_stl

        if find_orca() is None:
            info["slice"] = "OrcaSlicer introuvable : gcode non généré"
        else:
            om = oriented_mesh(mesh, d)
            stl = outdir / "gcode" / "best_hook_oriented.stl"
            stl.parent.mkdir(parents=True, exist_ok=True)
            om.export(stl)
            with_sup = slice_stl(stl, outdir / "gcode", cfg.overhang_deg, support=True)
            no_sup = slice_stl(stl, outdir / "gcode_nosupport", cfg.overhang_deg, support=False)
            g = with_sup["gcode"].rename(outdir / "best_hook_kobra_x.gcode")
            gs, gn = with_sup["stats"], no_sup["stats"]
            info["slice"] = {
                "gcode": str(g.relative_to(outdir)),
                "orca_total_g": float(gs.get("filament_g", "nan")),
                "orca_part_only_g": float(gn.get("filament_g", "nan")),
                "orca_support_g": float(gs.get("filament_g", "nan")) - float(gn.get("filament_g", "nan")),
                "print_time": gs.get("print_time"),
                "stats": gs,
            }
    return info


def write_summary(outdir: Path, spec, cfg, hists: list, final: dict):
    from .material import PLA

    L = []
    L.append("# Résultats — crochet de plafond\n")
    L.append(f"Généré le {time.strftime('%Y-%m-%d %H:%M')} par `python -m sgg optimize`.\n")
    L.append("## Cahier des charges\n")
    L.append(f"- charge de service {spec.mass_kg} kg, coefficient de sécurité {spec.safety_factor} "
             f"→ charge de calcul {spec.design_load_N:.1f} N")
    L.append(f"- C : rayon intérieur {spec.R_in} mm, ouverture {spec.sweep_deg}°, tige {spec.L_stem} mm, "
             f"vis Ø{spec.hole_d - 0.5:.0f} (tête Ø{spec.head_d}), congés R{spec.fillet}")
    L.append(f"- traction de vis ≤ {spec.max_screw_tension_N} N, flèche ≤ {spec.max_deflection_mm} mm")
    m = PLA()
    L.append(f"- PLA : E={m.E} MPa, X_t={m.X_t}, Z_t={m.Z_t}, S_z={m.S_z}, X_c={m.X_c} MPa")
    L.append(f"- FEA voxels {cfg.fea_pitch} mm pendant l'optimisation, surplomb max {cfg.overhang_deg}° "
             f"de la verticale, densité supports {cfg.support_density}\n")
    L.append("## Optimiseurs\n")
    L.append("| méthode | évaluations | temps (s) | meilleure masse (g) | faisable |")
    L.append("|---|---|---|---|---|")
    for h in hists:
        b = h.best
        L.append(f"| {h.method} | {len(h.evals)} | {h.seconds:.0f} | "
                 f"{b.objective:.2f} | {b.feasible} |" if b else f"| {h.method} | {len(h.evals)} | | | |")
    best = min(hists, key=lambda h: (not h.best.feasible, h.best.objective)).best
    v, f = final["verify"], final["final"]
    fb = f["best"]
    vo = final.get("verify_opt_orientation", {})
    L.append("\n## Meilleur design\n")
    L.append(f"Optimisation (voxels {cfg.fea_pitch} mm) : orientation **{best.best.label}**, "
             f"FI {best.best.FI:.2f}, total {best.best.total_mass:.2f} g.")
    if vo:
        L.append(f"Vérification (voxels fins), même orientation : FI {vo['FI']:.2f}, total {vo['total_mass']:.2f} g, "
                 f"faisable={vo['feasible']}.")
    if final["repairs"]:
        L.append(f"\nRéparation (épaississement) en {len(final['repairs'])} étape(s) :\n")
        L.append("| étape | b | h_s | h_c | t_p | FI | total (g) | faisable |\n|---|---|---|---|---|---|---|---|")
        for i, r in enumerate(final["repairs"], 1):
            q = r["params"]
            L.append(f"| {i} | {q['b']:.2f} | {q['h_s']:.2f} | {q['h_c']:.2f} | {q['t_p']:.2f} | {r['FI']:.2f} | "
                     f"{r['total_mass']:.2f} | {r['feasible']} |")
    else:
        L.append("\nAucune réparation nécessaire.")
    L.append("\n**Design final**\n")
    L.append("| paramètre | valeur (mm) |\n|---|---|")
    for k, val in f["params"].items():
        L.append(f"| {k} | {val:.2f} |")
    L.append(f"\nOrientation d'impression : **{final['orientation']['label']}** (d = {final['orientation']['d']}).\n")
    L.append("| grandeur | design final (voxels fins) |\n|---|---|")
    L.append(f"| masse pièce (g) | {f['part_mass']:.2f} |")
    L.append(f"| masse supports estimée (g) | {fb['support_mass']:.2f} |")
    L.append(f"| indice de rupture FI (charge de calcul) | {fb['FI']:.2f} |")
    L.append(f"| capacité prédite (kg, sans SF) | {f['capacity_kg']:.1f} |")
    L.append(f"| flèche en service (mm) | {f['deflection_service']:.2f} |")
    L.append(f"| traction de vis (N, charge de calcul) | {f['screw_tension_design']:.0f} |")
    L.append(f"| σ tige poutre / FEA (MPa) | {f['stem_stress_beam']:.1f} / {f['stem_stress_fea']:.1f} |")
    L.append("\n### Comparaison des orientations (design final)\n")
    L.append("| orientation | FI | supports (g) | total (g) | hauteur (mm) | OK |\n|---|---|---|---|---|---|")
    for o in f["orientations"]:
        L.append(f"| {o['label']} | {o['FI']:.2f} | {o['support_mass']:.2f} | {o['total_mass']:.2f} | "
                 f"{o['height']:.0f} | {'✓' if o['feasible'] else '✗'} |")
    v, vb = f, fb
    s = final.get("slice")
    L.append("\n## Gcode (OrcaSlicer CLI, profil Kobra X)\n")
    if isinstance(s, dict):
        L.append(f"- fichier : `{s['gcode']}` — temps estimé {s['print_time']}")
        L.append(f"- filament Orca : total {s['orca_total_g']:.2f} g, pièce seule {s['orca_part_only_g']:.2f} g, "
                 f"supports {s['orca_support_g']:.2f} g")
        L.append(f"- estimation interne : pièce {v['part_mass']:.2f} g, supports {vb['support_mass']:.2f} g")
        L.append(f"- réglages : {s['stats'].get('wall_loops')} périmètres, remplissage "
                 f"{s['stats'].get('sparse_infill_density')}, couches {s['stats'].get('layer_height')} mm, "
                 f"saveur {s['stats'].get('gcode_flavor')}")
    else:
        L.append(f"- {s}")
    (outdir / "summary.md").write_text("\n".join(L) + "\n")


def cmd_optimize(args):
    from .optimize import genetic_algorithm, random_search, save_history

    spec, cfg = _spec(args), _cfg(args)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    hists = []
    if args.method in ("ga", "both"):
        print(f"== GA : population {args.pop}, {args.gens} générations")
        h = genetic_algorithm(spec, cfg, args.pop, args.gens, args.seed, workers=args.workers)
        save_history(h, out / "history_ga.json")
        hists.append(h)
    if args.method in ("random", "both"):
        budget = args.budget or len(hists[0].evals) if hists else args.budget or 60
        print(f"== recherche aléatoire : {budget} évaluations")
        h = random_search(spec, cfg, budget, args.seed, workers=args.workers)
        save_history(h, out / "history_random.json")
        hists.append(h)
    best = min(hists, key=lambda h: (not h.best.feasible, h.best.objective)).best
    from .hook import HookParams

    params = HookParams(**best.params)
    (out / "best_params.json").write_text(json.dumps(best.to_dict(), indent=1, default=float))
    print("== finalisation (FEA fine, STL, gcode)")
    final = finalize(params, spec, cfg, out, args.verify_pitch, not args.no_slice, opt_eval=best)
    (out / "final.json").write_text(json.dumps(final, indent=1, default=str))
    write_summary(out, spec, cfg, hists, final)
    _plot(hists, out)
    print((out / "summary.md").read_text())


def _plot(hists, out: Path):
    """Courbe de convergence en SVG minimal (sans matplotlib)."""
    pts = {h.method: [(n, v) for n, v in h.best_curve if v is not None] for h in hists}
    allv = [v for p in pts.values() for _, v in p]
    if not allv:
        return
    nmax = max(n for p in pts.values() for n, _ in p)
    vmin, vmax = min(allv), max(allv)
    vmax = vmax if vmax > vmin else vmin + 1
    W, H, M = 560, 300, 50
    sx = lambda n: M + (W - 2 * M) * n / nmax  # noqa: E731
    sy = lambda v: H - M - (H - 2 * M) * (v - vmin) / (vmax - vmin)  # noqa: E731
    colors = {"ga": "#2a6fdb", "random": "#d9822b"}
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="sans-serif" font-size="12">',
         f'<rect width="{W}" height="{H}" fill="white"/>',
         f'<line x1="{M}" y1="{H-M}" x2="{W-M}" y2="{H-M}" stroke="#333"/><line x1="{M}" y1="{M}" x2="{M}" y2="{H-M}" stroke="#333"/>',
         f'<text x="{W/2}" y="{H-12}" text-anchor="middle">évaluations</text>',
         f'<text x="14" y="{H/2}" transform="rotate(-90 14 {H/2})" text-anchor="middle">meilleure masse faisable (g)</text>',
         f'<text x="{M-4}" y="{sy(vmin)+4}" text-anchor="end">{vmin:.1f}</text>',
         f'<text x="{M-4}" y="{sy(vmax)+4}" text-anchor="end">{vmax:.1f}</text>',
         f'<text x="{W-M}" y="{H-M+16}" text-anchor="end">{nmax}</text>']
    for i, (meth, p) in enumerate(pts.items()):
        if not p:
            continue
        path = " ".join(f"{sx(n):.1f},{sy(v):.1f}" for n, v in p + [(nmax, p[-1][1])])
        c = colors.get(meth, "#555")
        s.append(f'<polyline points="{path}" fill="none" stroke="{c}" stroke-width="2"/>')
        s.append(f'<text x="{W-M-80}" y="{M+16*i}" fill="{c}">{meth}</text>')
    s.append("</svg>")
    (out / "convergence.svg").write_text("\n".join(s))


def cmd_slice(args):
    from .hook import HookParams

    data = json.loads(Path(args.params).read_text())
    p = HookParams(**data.get("params", data))
    final = finalize(p, _spec(args), _cfg(args), Path(args.out), args.verify_pitch, True)
    print(json.dumps(final.get("slice"), indent=1, default=str))


def main(argv=None):
    ap = argparse.ArgumentParser(prog="sgg", description="Générateur de crochet imprimé optimisé (Kobra X, PLA)")
    ap.add_argument("--mass", type=float, default=2.0, help="charge de service (kg)")
    ap.add_argument("--sf", type=float, default=3.0, help="coefficient de sécurité")
    ap.add_argument("--pitch", type=float, default=0.75, help="taille de voxel FEA (mm)")
    ap.add_argument("--overhang", type=float, default=50.0, help="surplomb max sans support (° / verticale)")
    ap.add_argument("--support-density", type=float, default=0.25)
    ap.add_argument("--tcd", type=float, default=1.0, help="rayon de moyenne des contraintes (mm), 0 = pic")
    sub = ap.add_subparsers(dest="cmd", required=True)

    e = sub.add_parser("evaluate")
    e.add_argument("--set", nargs="*", help="ex. b=8 h_s=6")
    e.add_argument("-n", type=int, default=10, help="orientations affichées")
    e.set_defaults(func=cmd_evaluate)

    v = sub.add_parser("validate")
    v.add_argument("--pitches", type=float, nargs="*", default=[1.0, 0.5])
    v.set_defaults(func=cmd_validate)

    o = sub.add_parser("optimize")
    o.add_argument("--method", choices=["ga", "random", "both"], default="both")
    o.add_argument("--pop", type=int, default=12)
    o.add_argument("--gens", type=int, default=6)
    o.add_argument("--budget", type=int, default=0, help="évals recherche aléatoire (0 = comme le GA)")
    o.add_argument("--seed", type=int, default=0)
    o.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) // 2))
    o.add_argument("--verify-pitch", type=float, default=0.5)
    o.add_argument("--no-slice", action="store_true")
    o.add_argument("--out", default="results")
    o.set_defaults(func=cmd_optimize)

    s = sub.add_parser("slice")
    s.add_argument("params", help="JSON (best_params.json ou dict de paramètres)")
    s.add_argument("--verify-pitch", type=float, default=0.75)
    s.add_argument("--out", default="out/slice")
    s.set_defaults(func=cmd_slice)

    args = ap.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    sys.exit(main())
