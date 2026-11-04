#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Git Classroom Tool
A Python port of GitService.cs from OutilsProfs, providing interactive GitHub Classroom-like management
using the GitHub CLI (gh) and Git, styled beautifully with the rich library.
"""

import os
import sys
import re
import io
import csv
import json
import tempfile
import shutil
import unicodedata
import subprocess
import concurrent.futures
from datetime import datetime, timezone

# Import rich elements for high-fidelity UI
from rich.console import Console
from rich.markup import escape
from rich.table import Table
from rich.rule import Rule
from rich.prompt import Prompt, Confirm
from rich.progress import Progress, BarColumn, TextColumn, TaskProgressColumn, SpinnerColumn

# Initialize rich console with standard styling
console = Console()

# File extensions that can contain steganographic watermarks
TEXT_EXTENSIONS = {
    ".cs", ".py", ".java", ".js", ".ts", ".jsx", ".tsx",
    ".html", ".css", ".scss", ".txt", ".md", ".rst",
    ".cpp", ".c", ".h", ".hpp", ".php", ".rb", ".go",
    ".vb", ".sql", ".sh", ".bat", ".ps1", ".xml", ".json", ".yaml", ".yml",
}

# Regex to match official repository naming convention
# Pattern: {Session}-{Cours}-{Travail}-{NomFamille}-{Prenom}
# e.g.: H26-4N6-TP1-DUPONT-MARC
REPO_NAME_PATTERN = re.compile(
    r"^([HAE]\d{2})-([A-Z0-9]+)-([A-Z0-9]+)-([A-Z0-9]+)-([A-Z0-9]+)$",
    re.IGNORECASE
)

# Matches the {Session}-{Cours}-{Travail} part shared by every repo of a TP
WORK_PREFIX_PATTERN = re.compile(r"^[HAE]\d{2}-[A-Z0-9]+-[A-Z0-9]+(?=-)", re.IGNORECASE)

# `gh repo list` has no "unlimited" option: this is high enough to never be reached
REPO_LIST_LIMIT = 1_000_000

# Build output and IDE state that must never reach a student repo
TEMPLATE_IGNORED = (".git", ".idea", ".vs", "bin", "obj")

# Accepted column titles for student lists (CSV and Excel)
NOM_HEADERS = {"nom", "nom de famille", "lastname", "last name"}
PRENOM_HEADERS = {"prénom", "prenom", "firstname", "first name", "given name"}
LOGIN_HEADERS = {"login", "github", "username", "login github"}

# Letters that Unicode decomposition does not reduce to ASCII
SLUG_TRANSLITERATION = str.maketrans({
    "Œ": "OE", "œ": "oe", "Æ": "AE", "æ": "ae", "ß": "ss",
    "Ø": "O", "ø": "o", "Đ": "D", "đ": "d", "Ł": "L", "ł": "l",
})


# ── Slug Helpers ─────────────────────────────────────────────────────────────

def normalize_slug(s: str) -> str:
    """Normalize input string to match our slug/naming convention."""
    if not s:
        return ""
    # Decompose unicode to separate characters from combining accents/diacritics
    normalized = unicodedata.normalize('NFKD', s.translate(SLUG_TRANSLITERATION))
    no_accents = "".join([c for c in normalized if not unicodedata.combining(c)])
    # Keep only ASCII alphanumeric characters (GitHub rejects the others), uppercase
    cleaned = "".join([c for c in no_accents if c.isascii() and c.isalnum()])
    return cleaned.upper()


def build_repo_name(session: str, cours: str, travail: str, nom_famille: str, prenom: str) -> str:
    """Build standardized repo name from metadata."""
    return (
        f"{normalize_slug(session)}-{normalize_slug(cours)}-{normalize_slug(travail)}"
        f"-{normalize_slug(nom_famille)}-{normalize_slug(prenom)}"
    )


# ── Subprocess Helpers ────────────────────────────────────────────────────────

def run_process(cmd: str, args: list, cwd: str = None) -> tuple:
    """Run an external command and return returncode, stdout, and stderr."""
    try:
        res = subprocess.run(
            [cmd] + list(args),
            capture_output=True,
            text=True,
            cwd=cwd,
            encoding='utf-8',
            errors='ignore'
        )
        return res.returncode, res.stdout, res.stderr
    except Exception as ex:
        return -1, "", str(ex)


def run_gh(*args) -> tuple:
    """Run a GitHub CLI (gh) command."""
    return run_process("gh", list(args))


def run_git(work_dir: str, *args) -> tuple:
    """Run a Git command inside a specific working directory."""
    return run_process("git", list(args), cwd=work_dir)


# ── Scope Verification Helpers ────────────────────────────────────────────────

def has_gh_scope(scope: str) -> bool:
    """Check if the authenticated GitHub CLI token has the requested scope."""
    rc, stdout, _ = run_gh("api", "user", "-i")
    if rc != 0:
        return False
    for line in stdout.splitlines():
        if line.lower().startswith("x-oauth-scopes:"):
            return scope.lower() in line.lower()
    return False


def ensure_gh_scope(scope: str) -> bool:
    """Ensure the GitHub token has the required scope. If not, refresh interactively."""
    if has_gh_scope(scope):
        return True

    console.print(f"[yellow]⚠  Le token gh n'a pas le scope [bold]{scope}[/].[/]")
    console.print(f"[dim]Commande requise :[/] [white]gh auth refresh -h github.com -s {scope}[/]")
    console.print()

    if not Confirm.ask("Lancer [bold]gh auth refresh[/] maintenant ?", default=True):
        return False

    try:
        # Run interactively so the user can complete the browser-based authorization
        res = subprocess.run(["gh", "auth", "refresh", "-h", "github.com", "-s", scope])
        if res.returncode == 0 and has_gh_scope(scope):
            return True
    except Exception as ex:
        console.print(f"[red]Erreur lors du refresh : {escape(str(ex))}[/]")
        return False

    console.print(f"[red]Le scope {scope} n'est toujours pas disponible. Action annulée.[/]")
    return False


# ── Steganography (Watermark) ────────────────────────────────────────────────

def encode_watermark(student_id: str) -> str:
    """Encode student identifier into space and tab characters (invisible watermark)."""
    # space = 0, tab = 1
    # Prefix to identify the watermark: 4 pairs of tab-space (\t \t \t \t )
    prefix = "\t \t \t \t "
    data_bytes = student_id.encode('utf-8')
    chars = [prefix]
    for b in data_bytes:
        for i in range(7, -1, -1):
            chars.append('\t' if (b & (1 << i)) != 0 else ' ')
    return "".join(chars)


def decode_watermark(text: str) -> str:
    """Decode student identifier from space and tab characters."""
    prefix = "\t \t \t \t "
    idx = 0
    while True:
        idx = text.find(prefix, idx)
        if idx == -1:
            break
        
        watermark_part = ""
        for char in text[idx + len(prefix):]:
            if char in (' ', '\t'):
                watermark_part += char
            else:
                break
                
        num_bytes = len(watermark_part) // 8
        if num_bytes > 0:
            b_array = bytearray()
            for i in range(num_bytes):
                byte_chars = watermark_part[i*8:(i+1)*8]
                b_val = 0
                for b_idx, c in enumerate(byte_chars):
                    if c == '\t':
                        b_val |= (1 << (7 - b_idx))
                b_array.append(b_val)
            
            try:
                decoded = b_array.decode('utf-8', errors='ignore').strip()
                if decoded:
                    return decoded
            except Exception:
                pass
        
        idx += len(prefix) + len(watermark_part)
    return ""


def repo_owner_from_path(file_path: str):
    """Return the NOMPRENOM slug of the student repo holding a file, or None if not in one."""
    folders = os.path.dirname(os.path.abspath(file_path)).split(os.sep)
    for folder in reversed(folders):
        m = REPO_NAME_PATTERN.match(folder)
        if m:
            return (m.group(4) + m.group(5)).upper()
    return None


def is_likely_binary(file_path: str) -> bool:
    """Check if a file is likely binary by checking for null bytes in first 512 bytes."""
    try:
        with open(file_path, 'rb') as f:
            chunk = f.read(512)
            return b'\x00' in chunk
    except Exception:
        return True


def inject_signatures_in_directory(dir_path: str, student_id: str):
    """Recursively inject invisible steganographic signatures into text files."""
    watermark = encode_watermark(student_id)
    for root, _, files in os.walk(dir_path):
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext not in TEXT_EXTENSIONS:
                continue
            full_path = os.path.join(root, file)
            if is_likely_binary(full_path):
                continue
            try:
                # Read original contents
                with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                # Add watermark as the first line of the file, followed by a newline
                new_content = watermark + '\n' + content
                
                with open(full_path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
            except Exception:
                pass


# ── Student List Loaders ──────────────────────────────────────────────────────

def parse_student_line(line: str):
    """Parse 'Nom Prénom [@login]' or 'Nom, Prénom[, login]'. Return None if ambiguous."""
    if ',' in line or ';' in line:
        parts = [p.strip() for p in re.split(r'[,;]', line)]
        if len(parts) not in (2, 3) or not parts[0] or not parts[1]:
            return None
        login = parts[2] if len(parts) == 3 else ""
    else:
        parts = line.split()
        if len(parts) == 2:
            login = ""
        elif len(parts) == 3 and parts[2].startswith("@"):
            login = parts[2]
        else:
            return None
    login = login.lstrip("@")
    if any(c.isspace() for c in login):
        return None
    return {"nom": parts[0], "prenom": parts[1], "login": login or None}


def load_students_interactive() -> list:
    """Manually input students via terminal."""
    expected = "Nom Prénom \\[@login]  ou  Nom composé, Prénom\\[, login]"
    students = []
    console.print("[dim]Entrer les étudiants (ligne vide pour terminer).[/]")
    console.print(f"[dim]Format : {expected}[/]")
    while True:
        line = input("  > ").strip()
        if not line:
            break
        student = parse_student_line(line)
        if not student:
            console.print(f"[yellow]Format attendu : {expected}[/]")
            continue
        students.append(student)
    return students


def parse_header(cells: list):
    """Return the (nom, prenom, login) column indexes of a header row, or None if it is not one."""
    lowered = [cell.lower() for cell in cells]

    def find(aliases):
        return next((i for i, cell in enumerate(lowered) if cell in aliases), None)

    columns = (find(NOM_HEADERS), find(PRENOM_HEADERS), find(LOGIN_HEADERS))
    return None if columns == (None, None, None) else columns


def students_from_rows(rows: list) -> list:
    """Build students from rows of stripped strings, first row being an optional header."""
    rows = [row for row in rows if any(row) and not row[0].startswith('#')]
    if not rows:
        return []

    columns = parse_header(rows[0])
    if columns:
        nom_col, prenom_col, login_col = columns
        if nom_col is None or prenom_col is None:
            console.print("[red]✘ L'en-tête doit contenir une colonne Nom et une colonne Prénom.[/]")
            return []
        rows = rows[1:]
    else:
        # Without a header, a third column could be anything: only names are positional
        nom_col, prenom_col, login_col = 0, 1, None

    if login_col is None:
        console.print("[yellow]⚠ Aucune colonne de login reconnue : aucune invitation ne sera envoyée.[/]")

    def cell(row, col):
        return row[col] if col is not None and col < len(row) else ""

    students = []
    for row in rows:
        nom, prenom = cell(row, nom_col), cell(row, prenom_col)
        if nom and prenom:
            students.append({"nom": nom, "prenom": prenom, "login": cell(row, login_col) or None})
    return students


def load_students_from_csv(file_path: str) -> list:
    """Load and parse students from a CSV file with auto-detected separators."""
    try:
        with open(file_path, 'rb') as f:
            raw = f.read()
        try:
            text = raw.decode('utf-8-sig')
        except UnicodeDecodeError:
            # Excel on Windows saves "CSV" files as ANSI
            text = raw.decode('cp1252', errors='replace')
        delim = ';' if ';' in text[:2048] else ','
        reader = csv.reader(io.StringIO(text, newline=''), delimiter=delim)
        rows = [[cell.strip() for cell in row] for row in reader]
    except Exception as ex:
        console.print(f"[red]Erreur de lecture du fichier CSV : {escape(str(ex))}[/]")
        return []
    return students_from_rows(rows)


def load_students_from_excel(file_path: str) -> list:
    """Load students from an Excel (.xlsx) file using openpyxl."""
    try:
        import openpyxl
    except ImportError:
        console.print("[red]Le module 'openpyxl' est requis pour lire les fichiers Excel (.xlsx).[/]")
        console.print("[dim]Veuillez l'installer avec : pip install openpyxl[/]")
        return []

    try:
        wb = openpyxl.load_workbook(file_path, read_only=True, data_only=True)
        try:
            rows = [
                ["" if cell is None else str(cell).strip() for cell in row]
                for row in wb.worksheets[0].iter_rows(values_only=True)
            ]
        finally:
            wb.close()
    except Exception as ex:
        console.print(f"[red]Erreur de lecture du fichier Excel : {escape(str(ex))}[/]")
        return []
    return students_from_rows(rows)


# ── Interactive Helpers ───────────────────────────────────────────────────────

def prompt_selection(title: str, choices: list) -> str:
    """Displays a custom selection menu to the user."""
    console.print(f"\n[bold]{title}[/]")
    for idx, choice in enumerate(choices, 1):
        console.print(f"  [cyan]{idx:>2}[/] · {choice}")
    console.print()
    while True:
        val = Prompt.ask(f"Votre choix (1-{len(choices)})")
        try:
            num = int(val)
            if 1 <= num <= len(choices):
                return choices[num - 1]
        except ValueError:
            pass
        console.print("[red]Choix invalide. Veuillez entrer un nombre valide.[/]")


def prompt_multi_selection(title: str, choices: list) -> list:
    """Prompt user to select multiple items using ranges and comma-separated numbers."""
    console.print(f"\n[bold red]{title}[/]")
    for idx, choice in enumerate(choices, 1):
        console.print(f"  [[cyan]{idx:>2}[/]] {choice}")
    console.print()
    console.print("[dim]Entrez les numéros séparés par des virgules (ex: 1,3,5) ou une plage (ex: 2-5).[/]")
    console.print("[dim]Laissez vide pour ne rien sélectionner.[/]")
    
    while True:
        val = Prompt.ask("Votre sélection", default="").strip()
        if not val:
            return []
        
        selected_indices = set()
        parts = val.split(',')
        valid = True
        for part in parts:
            part = part.strip()
            if not part:
                continue
            if '-' in part:
                subparts = part.split('-')
                if len(subparts) == 2:
                    try:
                        start = int(subparts[0].strip())
                        end = int(subparts[1].strip())
                        if 1 <= start <= end <= len(choices):
                            selected_indices.update(range(start - 1, end))
                        else:
                            valid = False
                    except ValueError:
                        valid = False
                else:
                    valid = False
            else:
                try:
                    num = int(part)
                    if 1 <= num <= len(choices):
                        selected_indices.add(num - 1)
                    else:
                        valid = False
                except ValueError:
                    valid = False
        
        if valid:
            return [choices[i] for i in sorted(list(selected_indices))]
        console.print("[red]Sélection invalide. Veuillez réessayer.[/]")


def prompt_session() -> str:
    """Prompt for CEGEP session (e.g. H26 for Hiver 2026)."""
    saison = prompt_selection("Saison", ["H – Hiver", "A – Automne", "E – Été"])
    code = saison[0]
    while True:
        annee = Prompt.ask("Année (2 chiffres, ex: 26)").strip()
        if len(annee) == 2 and annee.isdigit():
            return f"{code}{annee}"
        console.print("[red]2 chiffres requis (ex: 26)[/]")


def prompt_visibility() -> str:
    """Prompt for GitHub repository visibility."""
    choice = prompt_selection("Visibilité du repo", ["🔒 Privé (recommandé)", "🌐 Public"])
    return "--private" if "🔒" in choice else "--public"


def clean_path(path: str) -> str:
    """Normalize a path typed at a prompt: outer quotes removed, ~ expanded."""
    return os.path.expanduser(path.strip().strip('"'))


def prompt_and_load_students() -> list:
    """Determine the student source and load them."""
    mode = prompt_selection(
        "Source de la liste d'étudiants",
        ["✏  Saisir interactivement", "📄 Charger un CSV", "📊 Charger un Excel (.xlsx)"]
    )
    if "CSV" in mode:
        path = clean_path(Prompt.ask("Chemin du fichier CSV"))
        if not os.path.exists(path):
            console.print("[red]✘ Fichier introuvable.[/]")
            return []
        return load_students_from_csv(path)
    if "Excel" in mode:
        path = clean_path(Prompt.ask("Chemin du fichier Excel (.xlsx)"))
        if not os.path.exists(path):
            console.print("[red]✘ Fichier introuvable.[/]")
            return []
        return load_students_from_excel(path)
    return load_students_interactive()


# ── Organization & Repos List Helpers ─────────────────────────────────────────

def fetch_user_orgs() -> list:
    """Fetch GitHub organizations the authenticated user belongs to."""
    rc, stdout, stderr = run_gh("api", "/user/orgs", "--paginate", "-q", ".[].login")
    if rc != 0:
        return []
    return [line.strip() for line in stdout.splitlines() if line.strip()]


def extract_year(prefix: str) -> str:
    """Try to extract a 2-digit school year (20-35) from the prefix."""
    m = re.match(r'^[a-zA-Z]?(\d{2})(?!\d)', prefix)
    if not m:
        return ""
    try:
        yr = int(m.group(1))
        if 20 <= yr <= 35:
            return m.group(1)
    except Exception:
        pass
    return ""


def detect_work_groups(repos: list) -> list:
    """Group repositories based on common hyphen-separated prefixes."""
    if not repos:
        return []
    
    prefix_map = {}
    for r in repos:
        name = r["name"]
        parts = name.split('-')
        for length in range(1, len(parts)):
            prefix = "-".join(parts[:length])
            prefix_lower = prefix.lower()
            if prefix_lower not in prefix_map:
                prefix_map[prefix_lower] = {"prefix": prefix, "repos": []}
            prefix_map[prefix_lower]["repos"].append(r)
            
    assignment = {}
    for r in repos:
        name = r["name"]
        # A repo following the convention always belongs to its TP, whatever the student's
        # name: two DUPONT in a class must not split into their own group.
        work_prefix = WORK_PREFIX_PATTERN.match(name)
        if work_prefix:
            assignment[name] = work_prefix.group(0)
            continue
        parts = name.split('-')
        best = None
        for length in range(len(parts) - 1, 0, -1):
            candidate = "-".join(parts[:length]).lower()
            if candidate in prefix_map and len(prefix_map[candidate]["repos"]) >= 2:
                best = prefix_map[candidate]["prefix"]
                break
        assignment[name] = best if best else name
        
    groups = {}
    for r in repos:
        name = r["name"]
        key = assignment[name]
        key_lower = key.lower()
        if key_lower not in groups:
            groups[key_lower] = {"prefix": key, "repos": []}
        groups[key_lower]["repos"].append(r)
        
    grouped_works = []
    for g in groups.values():
        prefix = g["prefix"]
        sorted_repos = sorted(g["repos"], key=lambda x: x["name"])
        year = extract_year(prefix)
        grouped_works.append({
            "prefix": prefix,
            "year": year,
            "repos": sorted_repos
        })
        
    def sort_key(g):
        y_val = g["year"]
        y_key = -int(y_val) if y_val else 999999
        return (y_key, g["prefix"].lower())
        
    return sorted(grouped_works, key=sort_key)


# ── ThreadPool Commits Checker ────────────────────────────────────────────────

def check_repo_commits(r: dict, org: str) -> dict:
    """Helper used to inspect if a student has pushed commits to their repo."""
    rc, stdout, _ = run_gh(
        "api", f"repos/{org}/{r['repo']['name']}/commits", "-X", "GET", "-F", "per_page=2"
    )
    if rc == 0:
        try:
            data = json.loads(stdout)
            if isinstance(data, list) and len(data) > 1:
                return r
        except Exception:
            pass
    return None


# ── Git Classroom Application Class ───────────────────────────────────────────

class GitClassroomApp:
    def __init__(self):
        self.org = None

    def get_or_prompt_org(self) -> str:
        """Reuse or prompt for the target GitHub organization."""
        if self.org and Confirm.ask(f"Utiliser l'organisation [cyan]{self.org}[/] ?", default=True):
            return self.org
        self.org = self.pick_org()
        return self.org

    def pick_org(self) -> str:
        """Select org from a fetched list, or type manually."""
        autre_option = "✏  Saisir manuellement..."
        console.print("[dim]Récupération des organisations...[/]")
        orgs = fetch_user_orgs()
        
        if orgs:
            choices = list(sorted(orgs)) + [autre_option]
            picked = prompt_selection("Organisation GitHub", choices)
            if picked != autre_option:
                return picked
        else:
            console.print("[dim](Impossible de récupérer les organisations — saisie manuelle)[/]")
            
        return Prompt.ask("Organisation GitHub (ex: departement-info-cem)").strip()

    def fetch_org_repos(self, org: str) -> list:
        """Fetch all repositories within the target organization."""
        rc, stdout, stderr = run_gh(
            "repo", "list", org, "--json", "name,createdAt", "--limit", str(REPO_LIST_LIMIT)
        )
        if rc != 0:
            console.print(f"[red]✘ gh repo list : {escape(stderr.strip())}[/]")
            return []
        try:
            return json.loads(stdout)
        except Exception:
            console.print("[red]✘ Erreur de lecture du JSON.[/]")
            return []

    def invite_collaborateur(self, org: str, repo_name: str, login: str):
        """Invite a student as a collaborator with push permissions."""
        rc, _, stderr = run_gh(
            "api", f"repos/{org}/{repo_name}/collaborators/{login}",
            "-X", "PUT", "-f", "permission=push"
        )
        if rc == 0:
            console.print(f"  [green]✔ Collaborateur invité : {escape(login)}[/]")
        else:
            console.print(f"  [yellow]⚠ Invitation échouée ({escape(login)}) : {escape(stderr.strip())}[/]")

    def seed_repo(self, org: str, repo_name: str, template_dir: str, hide_signature: bool, student_id: str) -> bool:
        """Seed a repo from a local template, with optional invisible signatures. Return True once pushed."""
        tmp_dir = tempfile.mkdtemp(prefix=f"git_{repo_name}_")
        try:
            if template_dir:
                try:
                    for item in os.listdir(template_dir):
                        s = os.path.join(template_dir, item)
                        d = os.path.join(tmp_dir, item)
                        if item in TEMPLATE_IGNORED:
                            continue
                        if os.path.isdir(s):
                            shutil.copytree(s, d, symlinks=True, ignore=shutil.ignore_patterns(*TEMPLATE_IGNORED))
                        else:
                            shutil.copy2(s, d)
                except Exception as ex:
                    # Never push a partial template to a student
                    console.print(f"[yellow]  ⚠ Erreur de copie du modèle : {escape(str(ex))}[/]")
                    return False

            if hide_signature:
                inject_signatures_in_directory(tmp_dir, student_id)
                
            repo_url = f"https://github.com/{org}/{repo_name}.git"
            run_git(tmp_dir, "init")
            run_git(tmp_dir, "branch", "-M", "main")
            run_git(tmp_dir, "remote", "add", "origin", repo_url)
            run_git(tmp_dir, "add", ".")
            rc, stdout, stderr = run_git(tmp_dir, "commit", "-m", "Initial commit")
            if rc != 0:
                # git explains "nothing to commit" on stdout
                reason = stderr.strip() or stdout.strip()
                console.print(f"[yellow]  ⚠ Commit échoué pour {repo_name}: {escape(reason)}[/]")
                return False
            rc, _, stderr = run_git(tmp_dir, "push", "-u", "origin", "main")
            if rc != 0:
                console.print(f"[yellow]  ⚠ Push échoué pour {repo_name}: {escape(stderr.strip())}[/]")
                return False
            return True
        finally:
            try:
                shutil.rmtree(tmp_dir)
            except Exception:
                pass

    # ── Menu Operations ───────────────────────────────────────────────────────

    def check_tool(self, tool: str):
        """Check if tool is in PATH and output version."""
        rc, stdout, _ = run_process(tool, ["--version"])
        if rc == 0:
            ver = stdout.splitlines()[0].strip() if stdout else ""
            console.print(f"[green]✔ {tool}[/] : {ver}")
        else:
            console.print(f"[red]✘ {tool}[/] : non trouvé dans le PATH")

    def diagnostic(self):
        """Diagnostic to check tool setups and authentication scopes."""
        console.print(Rule("[cyan]Diagnostic Git / GitHub CLI[/]", style="cyan"))
        console.print()
        self.check_tool("git")
        self.check_tool("gh")
        console.print()
        console.print("[cyan]Authentification GitHub :[/]")
        rc, stdout, stderr = run_gh("auth", "status")
        output = stdout if stdout.strip() else stderr
        for line in output.splitlines():
            line_str = line.strip()
            if not line_str:
                continue
            if rc != 0:
                console.print(f"[red]  {escape(line_str)}[/]")
            else:
                console.print(f"[green]  {escape(line_str)}[/]")

    def tester_creation_repo(self):
        """Test creating a single repository."""
        console.print(Rule("[cyan]Test – Création d'un repo[/]", style="cyan"))
        console.print()
        
        org = self.get_or_prompt_org()
        default_name = f"TEST-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M')}"
        
        repo_name = Prompt.ask("Nom du repo de test", default=default_name).strip()
        visibility = prompt_visibility()
        
        collaborateur = Prompt.ask("Login GitHub du collaborateur (Entrée pour ignorer)", default="").strip()
        collaborateur = collaborateur if collaborateur else None
        
        console.print(f"[dim]Création de [cyan]{org}/{repo_name}[/]...[/]")
        rc, _, stderr = run_gh("repo", "create", f"{org}/{repo_name}", visibility)
        if rc == 0:
            console.print(f"[green]✔ Repo créé : https://github.com/{org}/{repo_name}[/]")
            if collaborateur:
                self.invite_collaborateur(org, repo_name, collaborateur)
                
            if Confirm.ask("Supprimer ce repo de test maintenant ?", default=True):
                if not ensure_gh_scope("delete_repo"):
                    return
                rc2, _, stderr2 = run_gh("repo", "delete", f"{org}/{repo_name}", "--yes")
                if rc2 == 0:
                    console.print("[green]✔ Repo supprimé.[/]")
                else:
                    console.print(f"[red]✘ Erreur suppression : {escape(stderr2.strip())}[/]")
        else:
            console.print(f"[red]✘ Échec de création : {escape(stderr.strip())}[/]")

    def creer_repos_etudiants(self):
        """Create a collection of repositories for students in the organization."""
        console.print(Rule("[cyan]Créer les repos d'un TP[/]", style="cyan"))
        console.print()
        
        org = self.get_or_prompt_org()
        session = prompt_session()
        cours = Prompt.ask("Code du cours (ex: 4N6)").strip()
        travail = Prompt.ask("Identifiant du travail (ex: TP1)").strip()
        
        visibility = prompt_visibility()
        
        use_template = Confirm.ask("Copier le contenu d'un dossier local ?", default=False)
        template_dir = None
        if use_template:
            while True:
                template_dir = clean_path(Prompt.ask("Chemin du dossier local contenant le modèle"))
                if os.path.exists(template_dir) and os.path.isdir(template_dir):
                    break
                console.print(f"[red]✘ Dossier introuvable ou invalide : {escape(template_dir)}[/]")

        # Signatures live inside the template's files: without a template there is nothing to sign
        hide_signature = use_template and Confirm.ask(
            "Cacher une signature stéganographique dans les fichiers ?", default=False
        )

        students = prompt_and_load_students()
        if not students:
            console.print("[yellow]⚠ Aucun étudiant chargé.[/]")
            return
            
        # Preview Table
        console.print()
        with_login = sum(1 for e in students if e["login"])
        console.print(f"[cyan]{len(students)} repo(s) à créer dans [bold]{org}[/]"
                      f"{f' · {with_login} login(s) GitHub fourni(s)' if with_login > 0 else ''}[/]")
                      
        preview = Table(show_header=False, border_style="dim")
        preview.add_column("Repo")
        preview.add_column("Étudiant")
        preview.add_column("Login")
        for e in students:
            name = build_repo_name(session, cours, travail, e["nom"], e["prenom"])
            preview.add_row(
                name,
                escape(f"{e['nom']} {e['prenom']}"),
                f"[dim]{escape(e['login'])}[/]" if e["login"] else "[dim]–[/]"
            )
        console.print(preview)
        
        if not Confirm.ask("Confirmer la création ?", default=False):
            console.print("[dim]Annulé.[/]")
            return
            
        ok, failed = 0, 0
        with Progress(
            TextColumn("[dim]{task.description}[/]"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Création des repos", total=len(students))
            for e in students:
                repo_name = build_repo_name(session, cours, travail, e["nom"], e["prenom"])
                progress.update(task, description=repo_name)
                
                rc, _, stderr = run_gh("repo", "create", f"{org}/{repo_name}", visibility)
                if rc != 0:
                    console.print(f"[red]  ✘ {repo_name} : {escape(stderr.strip())}[/]")
                    failed += 1
                    progress.advance(task, 1)
                    continue
                    
                if use_template:
                    student_id = f"{e['nom']},{e['prenom']}"
                    if not self.seed_repo(org, repo_name, template_dir, hide_signature, student_id):
                        console.print(f"[red]  ✘ {repo_name} : repo créé mais vide, invitation non envoyée.[/]")
                        failed += 1
                        progress.advance(task, 1)
                        continue

                if e["login"]:
                    self.invite_collaborateur(org, repo_name, e["login"])
                    
                ok += 1
                progress.advance(task, 1)
                
        console.print()
        if ok > 0:
            console.print(f"[green]✔ {ok} repo(s) créé(s).[/]")
        if failed > 0:
            console.print(f"[red]✘ {failed} échec(s).[/]")

    def lister_repos(self):
        """List and group all repositories within the target organization."""
        console.print(Rule("[cyan]Lister les repos[/]", style="cyan"))
        console.print()
        
        org = self.get_or_prompt_org()
        console.print("[dim]Récupération...[/]")
        
        repos = self.fetch_org_repos(org)
        if not repos:
            console.print("[yellow]Aucun repo trouvé.[/]")
            return
            
        groups = detect_work_groups(repos)
        
        table = Table(
            title=f"[cyan]Repos de {org} — {len(repos)} repo(s), {len(groups)} groupe(s)[/]",
            show_header=True,
            header_style="bold"
        )
        table.add_column("Groupe / Préfixe")
        table.add_column("Année", justify="center")
        table.add_column("Nb", justify="right")
        table.add_column("Suffixe étudiant")
        table.add_column("Créé le")
        
        for group in groups:
            first = True
            prefix = group["prefix"]
            for r in group["repos"]:
                name = r["name"]
                suffix = name[len(prefix)+1:] if len(name) > len(prefix) + 1 else name
                
                created_at_str = r["createdAt"]
                try:
                    dt = datetime.strptime(created_at_str[:19], "%Y-%m-%dT%H:%M:%S")
                    date_display = dt.strftime("%Y-%m-%d")
                except Exception:
                    date_display = created_at_str
                
                table.add_row(
                    f"[white]{prefix}[/]" if first else "",
                    f"[cyan]20{group['year']}[/]" if first and group["year"] else ("[dim]–[/]" if first else ""),
                    f"[dim]{len(group['repos'])}[/]" if first else "",
                    suffix,
                    date_display
                )
                first = False
            # Empty separator row between groups
            table.add_row("", "", "", "", "")
            
        console.print(table)

    def cloner_repos_tp(self):
        """Clone all repositories belonging to a work group prefix."""
        console.print(Rule("[cyan]Cloner les repos d'un TP[/]", style="cyan"))
        console.print()
        
        org = self.get_or_prompt_org()
        console.print("[dim]Récupération des repos...[/]")
        
        repos = self.fetch_org_repos(org)
        if not repos:
            console.print("[yellow]Aucun repo trouvé.[/]")
            return
            
        groups = detect_work_groups(repos)
        manual_entry = "✏  Saisir un préfixe manuellement..."
        
        choices = []
        for g in groups:
            yr_suffix = f" · 20{g['year']}" if g['year'] else ""
            choices.append(f"{g['prefix']}  ({len(g['repos'])} repos{yr_suffix})")
        choices.append(manual_entry)
        
        picked = prompt_selection("Choisir le groupe / préfixe à cloner :", choices)
        
        to_clone = []
        if picked == manual_entry:
            prefix = Prompt.ask("Préfixe (les repos commençant par ce texte)").strip()
            to_clone = [r for r in repos if r["name"].lower().startswith(prefix.lower())]
            to_clone = sorted(to_clone, key=lambda x: x["name"])
        else:
            prefix = picked.split("  (")[0]
            for g in groups:
                if g["prefix"].lower() == prefix.lower():
                    to_clone = g["repos"]
                    break
                    
        if not to_clone:
            console.print("[yellow]Aucun repo trouvé pour ce préfixe.[/]")
            return
            
        dest_dir = clean_path(Prompt.ask("Dossier de destination", default=os.getcwd()))
        os.makedirs(dest_dir, exist_ok=True)

        console.print(f"[cyan]{len(to_clone)} repo(s) → {escape(dest_dir)}[/]")
        if not Confirm.ask("Confirmer ?", default=True):
            return
            
        ok, skipped, failed = 0, 0, 0
        with Progress(
            TextColumn("[dim]{task.description}[/]"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Clonage", total=len(to_clone))
            for r in to_clone:
                name = r["name"]
                progress.update(task, description=name)
                repo_dest_dir = os.path.join(dest_dir, name)
                if os.path.exists(repo_dest_dir):
                    skipped += 1
                    progress.advance(task, 1)
                    continue
                    
                rc, _, stderr = run_gh("repo", "clone", f"{org}/{name}", repo_dest_dir)
                if rc == 0:
                    ok += 1
                else:
                    failed += 1
                    console.print(f"[red]  ✘ {name}: {escape(stderr.strip())}[/]")
                progress.advance(task, 1)
                
        console.print()
        if ok > 0:
            console.print(f"[green]✔ {ok} cloné(s).[/]")
        if skipped > 0:
            console.print(f"[yellow]⏭  {skipped} déjà présent(s) (ignoré(s)).[/]")
        if failed > 0:
            console.print(f"[red]✘ {failed} échec(s).[/]")

    def lister_repos_avec_commits(self):
        """List repositories matching filters that contain active student commits."""
        console.print(Rule("[cyan]Repos avec commits étudiants[/]", style="cyan"))
        console.print()
        
        org = self.get_or_prompt_org()
        session = Prompt.ask("Session (ex: H26) — laisser vide pour toutes", default="").strip()
        cours = Prompt.ask("Cours — laisser vide pour tous", default="").strip()
        travail = Prompt.ask("Travail (ex: TP1) — laisser vide pour tous", default="").strip()
        
        console.print("[dim]Récupération des repos...[/]")
        repos = self.fetch_org_repos(org)
        if not repos:
            console.print("[yellow]Aucun repo trouvé.[/]")
            return
            
        ses_slug = normalize_slug(session)
        cour_slug = normalize_slug(cours)
        trav_slug = normalize_slug(travail)
        
        candidates = []
        for r in repos:
            m = REPO_NAME_PATTERN.match(r["name"])
            if m:
                ses, cour, trav, nom, pren = m.groups()
                if (not ses_slug or ses.upper() == ses_slug) and \
                   (not cour_slug or cour.upper() == cour_slug) and \
                   (not trav_slug or trav.upper() == trav_slug):
                    candidates.append({
                        "session": ses,
                        "cours": cour,
                        "travail": trav,
                        "nom": nom,
                        "prenom": pren,
                        "repo": r
                    })
                    
        if not candidates:
            console.print("[yellow]Aucun repo correspondant trouvé.[/]")
            return
            
        console.print(f"[dim]Vérification de {len(candidates)} repo(s) (max 5 en parallèle)...[/]")
        
        with_commits = []
        with Progress(
            TextColumn("[dim]{task.description}[/]"),
            BarColumn(),
            TaskProgressColumn(),
            SpinnerColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Vérification", total=len(candidates))
            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(check_repo_commits, c, org): c for c in candidates}
                for f in concurrent.futures.as_completed(futures):
                    res = f.result()
                    if res:
                        with_commits.append(res)
                    progress.advance(task, 1)
                    
        console.print()
        if not with_commits:
            console.print("[yellow]Aucun repo avec commit étudiant trouvé.[/]")
            return
            
        sorted_list = sorted(with_commits, key=lambda x: (x["session"], x["cours"], x["travail"], x["nom"]))
        
        table = Table(
            title=f"[cyan]{len(sorted_list)} repo(s) avec commits étudiants[/]",
            show_header=True,
            header_style="bold"
        )
        table.add_column("Session")
        table.add_column("Cours")
        table.add_column("Travail")
        table.add_column("Étudiant")
        
        last_group = None
        for r in sorted_list:
            group = f"{r['session']}-{r['cours']}-{r['travail']}"
            if last_group and group != last_group:
                table.add_row("", "", "", "")
            last_group = group
            table.add_row(r["session"], r["cours"], r["travail"], f"{r['nom']} {r['prenom']}")
            
        console.print(table)

    def supprimer_repos(self):
        """Select and delete repositories of the organization, oldest listed first."""
        console.print(Rule("[cyan]Supprimer des repos[/]", style="cyan"))
        console.print()
        
        org = self.get_or_prompt_org()
        console.print("[dim]Récupération...[/]")
        
        repos = self.fetch_org_repos(org)
        if not repos:
            console.print("[green]✔ Aucun repo trouvé dans cette organisation.[/]")
            return
            
        # Parse and sort by oldest first
        repos_sorted = sorted(repos, key=lambda x: x["createdAt"])
        
        choices = []
        for r in repos_sorted:
            created_at_str = r["createdAt"]
            try:
                dt = datetime.strptime(created_at_str[:19], "%Y-%m-%dT%H:%M:%S")
                date_display = dt.strftime("%Y-%m-%d")
            except Exception:
                date_display = created_at_str
            choices.append(f"{r['name']}  ({date_display})")
            
        selected = prompt_multi_selection(
            f"Sélectionner les repos à supprimer ({len(repos)} repos, plus anciens en premier)",
            choices
        )
        if not selected:
            console.print("[dim]Aucun repo sélectionné. Annulé.[/]")
            return
            
        to_delete_names = [s.split(' ')[0] for s in selected]

        console.print()
        for s in selected:
            console.print(f"[red]  • {escape(s)}[/]")
        console.print()
        console.print(f"[red bold]⚠  Ces {len(to_delete_names)} repo(s) seront supprimés définitivement.[/]")
        console.print("[red]Cette action est irréversible.[/]")
        console.print()
        
        confirm = Prompt.ask("[red]Taper [bold]SUPPRIMER[/] pour confirmer[/]")
        if confirm != "SUPPRIMER":
            console.print("[dim]Annulé.[/]")
            return
            
        # Ensure the gh token has the delete_repo scope before attempting any deletion
        if not ensure_gh_scope("delete_repo"):
            return
            
        ok, failed = 0, 0
        with Progress(
            TextColumn("[dim]{task.description}[/]"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Suppression", total=len(to_delete_names))
            for name in to_delete_names:
                progress.update(task, description=name)
                rc, _, stderr = run_gh("repo", "delete", f"{org}/{name}", "--yes")
                if rc == 0:
                    ok += 1
                else:
                    failed += 1
                    console.print(f"[red]  ✘ {name}: {escape(stderr.strip())}[/]")
                progress.advance(task, 1)
                
        console.print()
        if ok > 0:
            console.print(f"[green]✔ {ok} repo(s) supprimé(s).[/]")
        if failed > 0:
            console.print(f"[red]✘ {failed} échec(s).[/]")

    def detecter_signatures(self):
        """Scan a folder recursively to detect and decode steganographic signatures."""
        console.print(Rule("[cyan]Détecter les signatures stéganographiques[/]", style="cyan"))
        console.print()
        
        path_to_scan = clean_path(Prompt.ask("Dossier à analyser", default=os.getcwd()))
        if not os.path.exists(path_to_scan):
            console.print(f"[red]✘ Dossier introuvable : {escape(path_to_scan)}[/]")
            return
            
        console.print("[dim]Analyse en cours...[/]")
        
        findings = []
        for root, _, files in os.walk(path_to_scan):
            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext not in TEXT_EXTENSIONS:
                    continue
                full_path = os.path.join(root, file)
                if is_likely_binary(full_path):
                    continue
                try:
                    with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    sig = decode_watermark(content)
                    if sig:
                        rel_path = os.path.relpath(full_path, path_to_scan)
                        findings.append({
                            "file": file,
                            "rel_path": rel_path,
                            "signature": sig,
                            "full_path": full_path
                        })
                except Exception:
                    pass
                    
        if not findings:
            console.print("[yellow]Aucune signature stéganographique détectée dans ce dossier.[/]")
            return
            
        table = Table(
            title=f"[cyan]{len(findings)} signature(s) détectée(s)[/]",
            show_header=True,
            header_style="bold"
        )
        table.add_column("Fichier")
        table.add_column("Signature détectée")
        table.add_column("Chemin relatif")
        table.add_column("Statut / Alerte")
        
        for f in findings:
            owner = repo_owner_from_path(f["full_path"])
            if owner is None:
                status = "[dim]? Repo non reconnu[/]"
            elif normalize_slug(f["signature"]) == owner:
                status = "[green]OK[/]"
            else:
                status = "[bold red]⚠ Discordance / Copie suspectée ![/]"

            table.add_row(
                escape(f["file"]),
                f"[bold cyan]{escape(f['signature'])}[/]",
                escape(f["rel_path"]),
                status
            )
            
        console.print(table)

    def run(self):
        """Submenu execution loop."""
        retour = "← Retour"
        while True:
            console.clear()
            console.print(Rule("[cyan]Git Classroom (Python)[/]", style="cyan"))
            if self.org:
                console.print(f"[dim]Organisation active : {self.org}[/]")
            console.print()
            
            choice = prompt_selection(
                "Choisir une action",
                [
                    "🔍 Diagnostic (gh, git, authentification)",
                    "🧪 Tester la création d'un repo",
                    "➕ Créer les repos d'un TP",
                    "📋 Lister les repos",
                    "📥 Cloner les repos d'un TP",
                    "💬 Repos avec commits étudiants",
                    "🗑  Supprimer des repos",
                    "🕵️  Détecter les signatures stéganographiques",
                    retour
                ]
            )
            
            console.print()
            if choice == retour:
                break
            elif "Diagnostic" in choice:
                self.diagnostic()
            elif "Tester" in choice:
                self.tester_creation_repo()
            elif "Créer" in choice:
                self.creer_repos_etudiants()
            elif "Lister les repos" in choice:
                self.lister_repos()
            elif "Cloner" in choice:
                self.cloner_repos_tp()
            elif "commits" in choice:
                self.lister_repos_avec_commits()
            elif "Supprimer" in choice:
                self.supprimer_repos()
            elif "signatures" in choice:
                self.detecter_signatures()
                
            console.print("\n[dim]Appuyez sur Entrée pour revenir au menu principal...[/]")
            input()


if __name__ == "__main__":
    try:
        app = GitClassroomApp()
        app.run()
    except KeyboardInterrupt:
        console.print("\n[dim]Fermeture de l'application.[/]")
        sys.exit(0)
