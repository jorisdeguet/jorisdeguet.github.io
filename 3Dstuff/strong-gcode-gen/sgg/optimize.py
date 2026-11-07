"""Optimiseurs : algorithme génétique (réel, SBX + mutation polynomiale) et
recherche aléatoire (référence à budget égal).

Problème : minimiser la masse totale (pièce + supports, meilleure
orientation) sous contraintes (indice de rupture <= 1 à la charge de calcul,
traction de vis, flèche). Les contraintes sont traitées par les règles de
Deb (2000) : un faisable bat toujours un infaisable ; entre infaisables, la
plus petite violation gagne ; entre faisables, la plus petite masse gagne.
L'orientation est optimisée exhaustivement (liste de candidates) à
l'intérieur de chaque évaluation.
"""
from __future__ import annotations

import json
import os
import time
from concurrent.futures import ProcessPoolExecutor
from dataclasses import dataclass, field

import numpy as np

from .evaluate import EvalConfig, Evaluation, evaluate
from .hook import BOUNDS, HookParams, HookSpec

NAMES = HookParams.names()
LO = np.array([BOUNDS[n][0] for n in NAMES])
HI = np.array([BOUNDS[n][1] for n in NAMES])


def decode(x: np.ndarray) -> HookParams:
    v = LO + np.clip(x, 0, 1) * (HI - LO)
    v = np.round(v, 2)  # résolution 0.01 mm (et clé de cache)
    return HookParams(**dict(zip(NAMES, map(float, v))))


def encode(p: HookParams) -> np.ndarray:
    v = np.array([getattr(p, n) for n in NAMES])
    return (v - LO) / (HI - LO)


def key(ev: Evaluation) -> tuple:
    """Clé de tri (plus petit = meilleur), règles de Deb."""
    if ev is None:
        return (2, np.inf)
    return (0, ev.objective) if ev.feasible else (1, ev.best.violation)


def _eval_job(args):
    params, spec, cfg = args
    try:
        return evaluate(params, spec, cfg)
    except Exception as exc:  # géométrie dégénérée, etc.
        return exc


@dataclass
class History:
    method: str
    evals: list = field(default_factory=list)  # (n_eval, params, objective, feasible, violation)
    best_curve: list = field(default_factory=list)  # (n_eval, meilleure masse faisable)
    best: Evaluation | None = None
    seconds: float = 0.0

    def record(self, ev: Evaluation | Exception, params: HookParams):
        n = len(self.evals) + 1
        if isinstance(ev, Exception):
            self.evals.append((n, params.to_dict(), None, False, None))
        else:
            self.evals.append((n, params.to_dict(), ev.objective, ev.feasible, ev.best.violation))
            if key(ev) < key(self.best):
                self.best = ev
        b = self.best
        self.best_curve.append((n, b.objective if (b is not None and b.feasible) else None))

    def to_dict(self) -> dict:
        return {
            "method": self.method,
            "seconds": self.seconds,
            "n_evals": len(self.evals),
            "best": self.best.to_dict() if self.best else None,
            "best_curve": self.best_curve,
            "evals": self.evals,
        }


class Evaluator:
    """Évalue des lots de génomes (parallèle), avec cache."""

    def __init__(self, spec: HookSpec, cfg: EvalConfig, workers: int = 1):
        self.spec, self.cfg = spec, cfg
        self.cache: dict[tuple, Evaluation | Exception] = {}
        if workers > 1:
            # un thread BLAS par processus, sinon sur-souscription des cœurs
            for v in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"):
                os.environ.setdefault(v, "1")
        self.pool = ProcessPoolExecutor(workers) if workers > 1 else None

    def __call__(self, X: np.ndarray, hist: History) -> list:
        params = [decode(x) for x in X]
        todo = []
        for p in params:
            k = tuple(p.to_dict().values())
            if k not in self.cache and k not in [tuple(q.to_dict().values()) for q in todo]:
                todo.append(p)
        jobs = [(p, self.spec, self.cfg) for p in todo]
        results = list(self.pool.map(_eval_job, jobs)) if self.pool else [_eval_job(j) for j in jobs]
        for p, r in zip(todo, results):
            self.cache[tuple(p.to_dict().values())] = r
            hist.record(r, p)
        out = []
        for p in params:
            r = self.cache[tuple(p.to_dict().values())]
            out.append(None if isinstance(r, Exception) else r)
        return out

    def close(self):
        if self.pool:
            self.pool.shutdown()


def _sbx(a, b, rng, eta=15.0):
    u = rng.random(a.size)
    beta = np.where(u <= 0.5, (2 * u) ** (1 / (eta + 1)), (1 / (2 * (1 - u))) ** (1 / (eta + 1)))
    c1 = 0.5 * ((1 + beta) * a + (1 - beta) * b)
    c2 = 0.5 * ((1 - beta) * a + (1 + beta) * b)
    swap = rng.random(a.size) < 0.5  # échange gène à gène
    c1[swap], c2[swap] = c2[swap].copy(), c1[swap].copy()
    return np.clip(c1, 0, 1), np.clip(c2, 0, 1)


def _poly_mut(x, rng, pm, eta=20.0):
    x = x.copy()
    for i in range(x.size):
        if rng.random() < pm:
            u = rng.random()
            d = (2 * u) ** (1 / (eta + 1)) - 1 if u < 0.5 else 1 - (2 * (1 - u)) ** (1 / (eta + 1))
            x[i] = np.clip(x[i] + d, 0, 1)
    return x


def genetic_algorithm(
    spec: HookSpec = HookSpec(),
    cfg: EvalConfig = EvalConfig(),
    pop_size: int = 12,
    generations: int = 6,
    seed: int = 0,
    elite: int = 2,
    workers: int = 1,
    seed_designs: list[HookParams] | None = None,
    log=print,
) -> History:
    rng = np.random.default_rng(seed)
    hist = History("ga")
    ev = Evaluator(spec, cfg, workers)
    t0 = time.time()
    try:
        X = rng.random((pop_size, len(NAMES)))
        for i, p in enumerate(seed_designs or []):
            X[i] = encode(p)
        F = ev(X, hist)
        for g in range(generations):
            order = sorted(range(pop_size), key=lambda i: key(F[i]))
            X, F = X[order], [F[i] for i in order]
            b = F[0]
            log(
                f"gen {g:2d}  évals {len(hist.evals):4d}  meilleur: "
                + (f"{b.objective:.2f} g ({'faisable' if b.feasible else f'viol {b.best.violation:.2f}'})" if b else "—")
            )

            def tournament():
                i, j = rng.integers(pop_size, size=2)
                return X[i] if key(F[i]) < key(F[j]) else X[j]

            children = [X[k].copy() for k in range(elite)]
            while len(children) < pop_size:
                c1, c2 = _sbx(tournament(), tournament(), rng)
                children += [_poly_mut(c1, rng, 1 / len(NAMES)), _poly_mut(c2, rng, 1 / len(NAMES))]
            Xc = np.array(children[:pop_size])
            Fc = ev(Xc, hist)
            X, F = Xc, Fc
        order = sorted(range(pop_size), key=lambda i: key(F[i]))
        b = F[order[0]]
        log(f"fin    évals {len(hist.evals):4d}  meilleur: {b.objective:.2f} g faisable={b.feasible}" if b else "fin")
    finally:
        ev.close()
    hist.seconds = time.time() - t0
    return hist


def random_search(
    spec: HookSpec = HookSpec(),
    cfg: EvalConfig = EvalConfig(),
    budget: int = 60,
    seed: int = 0,
    workers: int = 1,
    log=print,
) -> History:
    rng = np.random.default_rng(seed + 1000)
    hist = History("random")
    ev = Evaluator(spec, cfg, workers)
    t0 = time.time()
    try:
        ev(rng.random((budget, len(NAMES))), hist)
    finally:
        ev.close()
    hist.seconds = time.time() - t0
    b = hist.best
    log(f"random: {budget} évals, meilleur {b.objective:.2f} g faisable={b.feasible}" if b else "random: rien")
    return hist


def save_history(hist: History, path):
    with open(path, "w") as f:
        json.dump(hist.to_dict(), f, indent=1, default=float)
