#!/usr/bin/env python3
"""Regroupe les mises à jour habituelles de mon mac.

    python3 updates.py            # tout
    python3 updates.py --dry-run  # affiche seulement les commandes
    python3 updates.py --no-sudo  # saute les étapes qui demandent sudo
"""
import shutil
import subprocess
import sys
import threading
import time

DRY = "--dry-run" in sys.argv
NO_SUDO = "--no-sudo" in sys.argv

# (nom, outil requis, commande, besoin de sudo)
STEPS = [
    ("brew update",         "brew",     ["brew", "update"],                              False),
    ("brew formules",       "brew",     ["brew", "upgrade"],                             False),
    # --greedy : inclut les casks qui se mettent à jour eux-mêmes (copilot-cli, ...)
    ("brew casks",          "brew",     ["brew", "upgrade", "--cask", "--greedy"],       False),
    ("brew cleanup",        "brew",     ["brew", "cleanup", "--prune=all"],              False),
    # pip, python, node, npm et cocoapods (brew install cocoapods) sont gérés par brew.
    # Ne pas toucher au gem du système (/usr/bin/gem, Ruby 2.6 d'Apple).
    ("npm global",          "npm",      ["npm", "update", "-g"],                         False),
    ("pipx",                "pipx",     ["pipx", "upgrade-all"],                         False),
    ("flutter",             "flutter",  ["flutter", "upgrade"],                          False),
    ("flutter precache",    "flutter",  ["flutter", "precache", "--ios"],                False),
    ("tlmgr (basictex)",    "tlmgr",    ["tlmgr", "update", "--self", "--all"],          True),
    # met à jour macOS et les Command Line Tools d'Xcode (pas de redémarrage auto)
    ("macOS / CLT",         "softwareupdate", ["softwareupdate", "--install", "--all"],  True),
]


def sudo_keepalive():
    """Demande le mot de passe une fois et garde le ticket sudo actif."""
    if subprocess.run(["sudo", "-v"]).returncode != 0:
        return False

    def loop():
        while True:
            time.sleep(50)
            subprocess.run(["sudo", "-n", "-v"], stderr=subprocess.DEVNULL)

    threading.Thread(target=loop, daemon=True).start()
    return True


def main():
    results = []
    needs_sudo = any(s for *_, s in STEPS) and not NO_SUDO and not DRY
    have_sudo = sudo_keepalive() if needs_sudo else False

    for name, tool, cmd, sudo in STEPS:
        if shutil.which(tool) is None:
            results.append((name, "absent"))
            continue
        if sudo:
            if NO_SUDO or (not DRY and not have_sudo):
                results.append((name, "sauté (sudo)"))
                continue
            cmd = ["sudo"] + cmd
        print(f"\n\033[1;34m==> {name}: {' '.join(cmd)}\033[0m", flush=True)
        if DRY:
            results.append((name, "dry-run"))
            continue
        code = subprocess.run(cmd).returncode
        if code != 0:  # souvent réseau / miroir capricieux : on réessaie une fois
            print(f"\033[33m--> échec ({code}), nouvel essai dans 5 s\033[0m", flush=True)
            time.sleep(5)
            code = subprocess.run(cmd).returncode
        results.append((name, "ok" if code == 0 else f"ÉCHEC ({code})"))

    print("\n\033[1m==> Résumé\033[0m")
    for name, status in results:
        color = "32" if status == "ok" else "31" if status.startswith("ÉCHEC") else "33"
        print(f"  \033[{color}m{status:<14}\033[0m {name}")
    if any(s.startswith("ÉCHEC") for _, s in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
