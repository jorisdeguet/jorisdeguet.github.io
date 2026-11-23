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
import json
import codecs
import tempfile
import shutil
import unicodedata
import subprocess
import concurrent.futures
from datetime import date, datetime, timedelta, timezone

# Import rich elements for high-fidelity UI
from rich.console import Console
from rich.markup import escape
from rich.table import Table
from rich.rule import Rule
from rich.prompt import Prompt as RichPrompt, Confirm as RichConfirm
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

# Signature copies per file: a formatter or an edited line only erases some of them
SIGNATURE_COPIES = 5

# Work rhythm report. 10 lines/min is about 60 words/min of non-stop typing with no thinking.
MAX_LINES_PER_MINUTE = 10
MIN_BURST_LINES = 50
BURST_GAP_SECONDS = 10 * 60

# Only hand-written code counts: data and documents can legitimately be pasted in bulk
RHYTHM_EXTENSIONS = TEXT_EXTENSIONS - {
    ".txt", ".md", ".rst", ".json", ".xml", ".yaml", ".yml", ".sql",
}
GENERATED_PATH = re.compile(
    r"(?:^|/)(?:bin|obj|node_modules|dist|build|packages|Migrations|\.vs|\.idea)/"
    r"|\.min\.(?:js|css)$|\.Designer\.cs$|\.g\.(?:i\.)?cs$",
    re.IGNORECASE
)

GIT_LOG_FORMAT = "%x1e%H%x1f%P%x1f%ct%x1f%ae%x1f%an%x1f%ce%x1f%cn%x1f%B%x1f"

# Explicit traces only. "Claude" alone is not one: it is also a first name.
AI_COMMIT_PATTERN = re.compile(
    r"noreply@anthropic\.com|claude code|claude (?:opus|sonnet|haiku|fable)|claude\[bot\]"
    r"|copilot\[bot\]|copilot-swe-agent|cursoragent"
    r"|co-authored-by:[^\n]*(?:copilot|cursor|chatgpt|openai|codex|gemini|aider|devin|windsurf)"
    r"|generated (?:with|by)[^\n]*(?:chatgpt|copilot|gemini|cursor|codex)"
    r"|^aider: ",
    re.IGNORECASE | re.MULTILINE
)
AI_FILE_PATTERN = re.compile(
    r"(?:^|/)(?:CLAUDE\.md|AGENTS\.md|GEMINI\.md|\.cursorrules|\.windsurfrules|\.clinerules"
    r"|\.aider[^/]*|copilot-instructions\.md)$"
    r"|(?:^|/)\.(?:claude|cursor|windsurf|continue|codex|roo|cline)/"
)
AI_CONTENT_PATTERN = (
    r"(generated|written) (with|by|using) (chatgpt|copilot|gemini|cursor|claude code)"
    r"|as an ai (language )?model|en tant qu.(ia|intelligence artificielle)"
    r"|chatgpt\.com/(share|c/)|claude\.ai/(chat|share)|utm_source=chatgpt|oaicite"
)

# Official repository naming convention
# Pattern: {Session}-{Cours}-{Travail}-{Groupe}-{Matricule}-{NomFamille}-{Prenom}
# e.g.: A26-SN1-TP2-1050-1234567-DUPONT-MARC
REPO_NAME_PATTERN = re.compile(
    r"^([HAE]\d{2})-([A-Z0-9]+)-([A-Z0-9]+)-(\d+)-(\d+)-([A-Z0-9]+)-([A-Z0-9]+)$",
    re.IGNORECASE
)
# Previous convention, without group nor student ID: H26-4N6-TP1-DUPONT-MARC
LEGACY_REPO_NAME_PATTERN = re.compile(
    r"^([HAE]\d{2})-([A-Z0-9]+)-([A-Z0-9]+)-([A-Z0-9]+)-([A-Z0-9]+)$",
    re.IGNORECASE
)

# Matches the {Session}-{Cours}-{Travail} part shared by every repo of a TP
WORK_PREFIX_PATTERN = re.compile(r"^[HAE]\d{2}-[A-Z0-9]+-[A-Z0-9]+(?=-)", re.IGNORECASE)

# `gh repo list` has no "unlimited" option: this is high enough to never be reached
REPO_LIST_LIMIT = 1_000_000

# Build output and IDE state that must never reach a student repo
TEMPLATE_IGNORED = (".git", ".idea", ".vs", "bin", "obj")

# GitHub logins of the students, per organization and repo, to reinvite them without the list
LOGIN_STORE = os.path.join(os.path.expanduser("~"), ".ghtcls")

# Accepted column titles for pasted student lists
NOM_HEADERS = {"nom", "nom de famille", "lastname", "last name"}
PRENOM_HEADERS = {"prénom", "prenom", "firstname", "first name", "given name"}
MATRICULE_HEADERS = {"matricule", "da", "no da", "numéro de da", "student id", "id"}
GROUPE_HEADERS = {"groupe", "gr", "gr.", "group", "no groupe"}
LOGIN_HEADERS = {"login", "github", "username", "login github"}

# Column order of a list pasted without a header row
STUDENT_FIELDS = ("nom", "prenom", "matricule", "groupe", "login")

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


def build_repo_name(session: str, cours: str, travail: str, student: dict) -> str:
    """Build standardized repo name from metadata."""
    return "-".join(normalize_slug(part) for part in (
        session, cours, travail,
        student["groupe"], student["matricule"], student["nom"], student["prenom"],
    ))


def parse_repo_name(name: str):
    """Split a repo name following the convention (current or legacy). Return None otherwise."""
    m = REPO_NAME_PATTERN.match(name)
    if m:
        session, cours, travail, groupe, matricule, nom, prenom = m.groups()
    else:
        m = LEGACY_REPO_NAME_PATTERN.match(name)
        if not m:
            return None
        session, cours, travail, nom, prenom = m.groups()
        groupe = matricule = ""
        if nom.isdigit():
            # Session-Cours-Travail-Matricule-NomPrénom, e.g. A26-SN1-TP1RACINE-2554729-BEAUDRYLOUISFELIX
            matricule, nom, prenom = nom, prenom, ""
    return {
        "session": session.upper(), "cours": cours.upper(), "travail": travail.upper(),
        "groupe": groupe, "matricule": matricule, "nom": nom.upper(), "prenom": prenom.upper(),
    }


def student_signature(student: dict) -> str:
    """Identifier hidden in a student's files: the student ID, short and unique."""
    return student["matricule"]


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
    # End on a tab: two trailing spaces would be a line break in Markdown
    chars.append('\t')
    return "".join(chars)


def decode_watermarks(text: str) -> list:
    """Decode every distinct student identifier hidden in space and tab characters."""
    prefix = "\t \t \t \t "
    signatures = []
    for match in re.finditer(re.escape(prefix) + r"([ \t]*)", text):
        bits = match.group(1)
        b_array = bytearray()
        for i in range(len(bits) // 8):
            b_val = 0
            for b_idx, c in enumerate(bits[i*8:(i+1)*8]):
                if c == '\t':
                    b_val |= (1 << (7 - b_idx))
            b_array.append(b_val)

        decoded = b_array.decode('utf-8', errors='ignore').strip()
        if decoded and decoded.isprintable() and decoded not in signatures:
            signatures.append(decoded)
    return signatures


def repo_owner_from_path(file_path: str):
    """Return the signature slug expected in a student repo holding a file, or None if not in one."""
    folders = os.path.dirname(os.path.abspath(file_path)).split(os.sep)
    for folder in reversed(folders):
        parsed = parse_repo_name(folder)
        if parsed:
            # Legacy repos have no student ID: they were signed "Nom,Prénom"
            return parsed["matricule"] or parsed["nom"] + parsed["prenom"]
    return None


def scan_signatures(path: str) -> list:
    """Return the files under a folder that hide at least one signature."""
    findings = []
    for root, _, files in os.walk(path):
        for file in files:
            if os.path.splitext(file)[1].lower() not in TEXT_EXTENSIONS:
                continue
            full_path = os.path.join(root, file)
            if is_likely_binary(full_path):
                continue
            try:
                with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
                    signatures = decode_watermarks(f.read())
            except Exception:
                continue
            if signatures:
                findings.append({
                    "file": file,
                    "rel_path": os.path.relpath(full_path, path),
                    "signatures": signatures,
                    "full_path": full_path,
                })
    return findings


def signature_status(finding: dict) -> str:
    """'ok' if every signature matches the repo holding the file, 'suspect' or 'unknown' otherwise."""
    owner = repo_owner_from_path(finding["full_path"])
    if owner is None:
        return "unknown"
    if all(normalize_slug(sig) == owner for sig in finding["signatures"]):
        return "ok"
    return "suspect"


def print_signature_findings(findings: list, title: str):
    """Print signature findings as a table."""
    labels = {
        "ok": "[green]OK[/]",
        "unknown": "[dim]? Repo non reconnu[/]",
        "suspect": "[bold red]⚠ Discordance / Copie suspectée ![/]",
    }
    table = Table(title=f"[cyan]{title}[/]", show_header=True, header_style="bold")
    table.add_column("Fichier")
    table.add_column("Signature détectée")
    table.add_column("Chemin relatif")
    table.add_column("Statut / Alerte")
    for f in findings:
        table.add_row(
            escape(f["file"]),
            f"[bold cyan]{escape(' + '.join(f['signatures']))}[/]",
            escape(f["rel_path"]),
            labels[signature_status(f)]
        )
    console.print(table)


def is_likely_binary(file_path: str) -> bool:
    """Check if a file is likely binary by checking for null bytes in first 512 bytes."""
    try:
        with open(file_path, 'rb') as f:
            chunk = f.read(512)
            return b'\x00' in chunk
    except Exception:
        return True


def signable_lines(lines: list, ext: str) -> list:
    """Return indexes of lines where trailing whitespace cannot change what the file means."""
    safe = []
    in_double_quotes = in_backticks = in_triple_single = False
    heredoc_end = None
    yaml_block_indent = None

    for i, line in enumerate(lines):
        body = line.rstrip('\r')
        stripped = body.strip()
        inside_before = in_double_quotes or in_backticks or in_triple_single

        if heredoc_end is not None:
            if stripped == heredoc_end:
                heredoc_end = None
            continue
        if ext in (".sh", ".rb", ".php"):
            heredoc = re.search(r"<<[-~<]*\s*['\"]?(\w+)", body)
            if heredoc:
                heredoc_end = heredoc.group(1)
                continue

        if ext in (".yaml", ".yml"):
            indent = len(body) - len(body.lstrip())
            if yaml_block_indent is not None:
                if not stripped or indent > yaml_block_indent:
                    continue
                yaml_block_indent = None
            if re.search(r"(?::|^\s*-)\s+[|>][-+0-9]*\s*$", body):
                yaml_block_indent = indent
                continue

        unescaped = re.sub(r"\\.", "", body)
        if unescaped.count('"') % 2:
            in_double_quotes = not in_double_quotes
        if unescaped.count('`') % 2:
            in_backticks = not in_backticks
        if unescaped.count("'''") % 2:
            in_triple_single = not in_triple_single
        inside_after = in_double_quotes or in_backticks or in_triple_single

        if inside_before or inside_after or not stripped or body != body.rstrip():
            continue
        if i == 0 and body.startswith("#!"):
            continue
        # Line continuations, and a PHP closing tag whose next bytes are sent to the browser
        if stripped.endswith(("\\", "^", "`")) or "?>" in body:
            continue
        # Trailing whitespace is part of "set X=value", and YAML parsers reject tabs after a value
        if ext == ".bat" and not re.match(r"\s*(rem\b|::)", body, re.IGNORECASE):
            continue
        if ext in (".yaml", ".yml") and not stripped.startswith("#"):
            continue
        safe.append(i)
    return safe


def sign_file(path: str, watermark: str) -> bool:
    """Hide the watermark at the end of several lines. Return False if the file stays unsigned."""
    if os.path.islink(path):
        return False
    with open(path, 'rb') as f:
        raw = f.read()
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError:
        return False

    # Working on \n only keeps \r\n endings and any BOM exactly as they were
    lines = text.split('\n')
    safe = signable_lines(lines, os.path.splitext(path)[1].lower())
    if not safe:
        return False

    copies = min(SIGNATURE_COPIES, len(safe))
    for n in range(copies):
        i = safe[n * len(safe) // copies]
        body = lines[i].rstrip('\r')
        lines[i] = body + watermark + lines[i][len(body):]

    with open(path, 'wb') as f:
        f.write('\n'.join(lines).encode('utf-8'))
    return True


def inject_signatures_in_directory(dir_path: str, student_id: str) -> list:
    """Recursively sign text files. Return the relative paths of files left unsigned."""
    watermark = encode_watermark(student_id)
    unsigned = []
    for root, _, files in os.walk(dir_path):
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext not in TEXT_EXTENSIONS:
                continue
            full_path = os.path.join(root, file)
            if not os.path.islink(full_path) and is_likely_binary(full_path):
                continue
            try:
                signed = sign_file(full_path, watermark)
            except Exception:
                signed = False
            if not signed:
                unsigned.append(os.path.relpath(full_path, dir_path))
    return unsigned


# ── Student List Loaders ──────────────────────────────────────────────────────

def split_cells(line: str) -> list:
    """Split a pasted line: tabs (copied from a spreadsheet), otherwise commas or semicolons."""
    if '\t' in line:
        cells = line.split('\t')
    else:
        cells = re.split(r'[,;]', line)
    return [cell.strip() for cell in cells]


def parse_header(cells: list):
    """Return {field: column index} for a header row, or None if it is not one."""
    aliases = {
        "nom": NOM_HEADERS, "prenom": PRENOM_HEADERS, "matricule": MATRICULE_HEADERS,
        "groupe": GROUPE_HEADERS, "login": LOGIN_HEADERS,
    }
    lowered = [cell.lower() for cell in cells]
    columns = {}
    for field, names in aliases.items():
        idx = next((i for i, cell in enumerate(lowered) if cell in names), None)
        if idx is not None:
            columns[field] = idx
    return columns or None


def student_from_cells(cells: list, columns: dict):
    """Build a student from a row. Return (student, None) or (None, reason)."""
    def cell(field):
        idx = columns.get(field)
        return cells[idx] if idx is not None and idx < len(cells) else ""

    student = {field: cell(field) for field in STUDENT_FIELDS}
    missing = [f for f in ("nom", "prenom", "matricule", "groupe") if not normalize_slug(student[f])]
    if missing:
        return None, f"champ(s) manquant(s) : {', '.join(missing)}"
    for field in ("matricule", "groupe"):
        if not student[field].isdigit():
            return None, f"{field} non numérique : {student[field]}"
    login = student["login"].lstrip("@")
    if any(c.isspace() for c in login):
        return None, f"login invalide : {login}"
    student["login"] = login or None
    return student, None


def students_from_lines(lines: list) -> list:
    """Parse pasted lines, the first one being an optional header row."""
    rows = [split_cells(line) for line in lines if line.strip() and not line.lstrip().startswith('#')]
    if not rows:
        return []

    columns = parse_header(rows[0])
    if columns:
        missing = [f for f in ("nom", "prenom", "matricule", "groupe") if f not in columns]
        if missing:
            console.print(f"[red]✘ Colonne(s) absente(s) de l'en-tête : {', '.join(missing)}.[/]")
            return []
        rows = rows[1:]
    else:
        columns = {field: i for i, field in enumerate(STUDENT_FIELDS)}

    students, seen = [], set()
    for row in rows:
        student, reason = student_from_cells(row, columns)
        if not student:
            console.print(f"[yellow]⚠ Ligne ignorée ({escape(reason)}) : {escape(' | '.join(row))}[/]")
            continue
        if student["matricule"] in seen:
            console.print(f"[yellow]⚠ Matricule en double ignoré : {escape(student['matricule'])}[/]")
            continue
        seen.add(student["matricule"])
        students.append(student)

    if students and not any(s["login"] for s in students):
        console.print("[yellow]⚠ Aucun login fourni : aucune invitation ne sera envoyée.[/]")
    return students


def load_students_interactive() -> list:
    """Read students pasted (or typed) in the terminal, until an empty line."""
    console.print("[dim]Coller les lignes copiées de Google Sheets (ligne vide pour terminer).[/]")
    console.print("[dim]Colonnes : Nom, Prénom, Matricule, Groupe, Login (facultatif).[/]")
    console.print("[dim]Séparateur : tabulation, virgule ou point-virgule. En-tête facultatif.[/]")
    console.print("[dim]Échap puis Entrée pour annuler.[/]")
    lines = []
    while True:
        # Builtin input: a pasted block must not be read key by key
        line = input("  > ")
        if "\x1b" in line:
            raise BackToMenu
        if not line.strip():
            break
        lines.append(line)
    return students_from_lines(lines)


def load_students_from_file(file_path: str) -> list:
    """Load students from a text file in the same format as the pasted list."""
    try:
        with open(file_path, encoding='utf-8-sig') as f:
            return students_from_lines(f.read().splitlines())
    except Exception as ex:
        console.print(f"[red]Erreur de lecture du fichier : {escape(str(ex))}[/]")
        return []


# ── Keyboard Input (Escape returns to the menu) ───────────────────────────────

class BackToMenu(Exception):
    """Escape pressed at a prompt: the current action is abandoned."""


def read_line_posix() -> str:
    """Read a line in cbreak mode, so that a lone Escape is seen at once."""
    import termios, tty, select
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
    chars = []
    out = sys.stdout
    try:
        # TCSANOW: TCSAFLUSH (the default) would drop the rest of a pasted text
        tty.setcbreak(fd, termios.TCSANOW)
        while True:
            b = os.read(fd, 1)
            if not b:
                raise EOFError
            if b == b"\x1b":
                if not select.select([fd], [], [], 0.05)[0]:
                    raise BackToMenu
                # Arrow keys and other escape sequences: ignored
                if os.read(fd, 1) in (b"[", b"O"):
                    while True:
                        c = os.read(fd, 1)
                        if not c or 0x40 <= c[0] <= 0x7e:
                            break
                continue
            if b in (b"\n", b"\r"):
                out.write("\n")
                out.flush()
                return "".join(chars)
            if b in (b"\x7f", b"\x08"):
                if chars:
                    chars.pop()
                    out.write("\b \b")
                    out.flush()
                continue
            if b == b"\x04" and not chars:
                raise EOFError
            ch = decoder.decode(b)
            if not ch or (ch < " " and ch != "\t"):
                continue
            chars.append(ch)
            out.write(ch)
            out.flush()
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, old)


def read_line_windows() -> str:
    import msvcrt
    chars = []
    while True:
        ch = msvcrt.getwch()
        if ch == "\x1b":
            raise BackToMenu
        if ch in ("\x00", "\xe0"):
            msvcrt.getwch()  # arrow keys and function keys
            continue
        if ch == "\x03":
            raise KeyboardInterrupt
        if ch in ("\r", "\n"):
            sys.stdout.write("\n")
            sys.stdout.flush()
            return "".join(chars)
        if ch == "\x08":
            if chars:
                chars.pop()
                sys.stdout.write("\b \b")
                sys.stdout.flush()
            continue
        if ch < " " and ch != "\t":
            continue
        chars.append(ch)
        sys.stdout.write(ch)
        sys.stdout.flush()


def read_line() -> str:
    """Read a typed line. Escape raises BackToMenu (only in a real terminal)."""
    if not sys.stdin.isatty():
        return input()
    sys.stdout.flush()
    try:
        if os.name == "nt":
            return read_line_windows()
        return read_line_posix()
    except (ImportError, OSError):
        return input()


class Prompt(RichPrompt):
    @classmethod
    def get_input(cls, console, prompt, password, stream=None):
        if password or stream:
            return console.input(prompt, password=password, stream=stream)
        console.print(prompt, end="")
        return read_line()


class Confirm(RichConfirm):
    @classmethod
    def get_input(cls, console, prompt, password, stream=None):
        console.print(prompt, end="")
        return read_line()


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


def current_session(today: date = None) -> str:
    """Session of a date: H (January to May), E (June, July), A (August to December), then the year."""
    today = today or date.today()
    code = "H" if today.month <= 5 else "E" if today.month <= 7 else "A"
    return f"{code}{today.year % 100:02d}"


def prompt_session() -> str:
    """Prompt for CEGEP session (e.g. H26 for Hiver 2026), the current one by default."""
    while True:
        session = Prompt.ask("Session (H, A ou E + année, ex: H27)", default=current_session()).strip().upper()
        if re.fullmatch(r"[HAE]\d{2}", session):
            return session
        console.print("[red]Format attendu : H, A ou E suivi de 2 chiffres (ex: A26)[/]")


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
        ["📋 Coller la liste", "📄 Charger un fichier texte (même format)"]
    )
    if "fichier" in mode:
        path = clean_path(Prompt.ask("Chemin du fichier"))
        if not os.path.exists(path):
            console.print("[red]✘ Fichier introuvable.[/]")
            return []
        return load_students_from_file(path)
    return load_students_interactive()


# ── Login Store (~/.ghtcls) ────────────────────────────────────────────────────

def load_login_store() -> dict:
    """{org: {repo name: login}}, all in lowercase except the logins."""
    try:
        with open(LOGIN_STORE, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except FileNotFoundError:
        return {}
    except Exception as ex:
        console.print(f"[yellow]⚠ {escape(LOGIN_STORE)} illisible : {escape(str(ex))}[/]")
        return {}


def stored_logins(org: str) -> dict:
    """{repo name (lowercase): login} remembered for an organization."""
    return load_login_store().get(org.lower(), {})


def remember_logins(org: str, logins: dict):
    """Remember {repo name: login}, the newest login of a repo replacing the old one."""
    logins = {name.lower(): login for name, login in logins.items() if login}
    if not logins:
        return
    store = load_login_store()
    repos = store.setdefault(org.lower(), {})
    if all(repos.get(name) == login for name, login in logins.items()):
        return
    repos.update(logins)
    tmp = LOGIN_STORE + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(store, f, indent=1, sort_keys=True, ensure_ascii=False)
        os.chmod(tmp, 0o600)
        os.replace(tmp, LOGIN_STORE)
    except Exception as ex:
        console.print(f"[yellow]⚠ Logins non enregistrés dans {escape(LOGIN_STORE)} : {escape(str(ex))}[/]")


# ── Organization & Repos List Helpers ─────────────────────────────────────────

def short_date(iso: str) -> str:
    """'2026-09-16T14:00:27Z' -> '2026-09-16'."""
    try:
        return datetime.strptime(iso[:19], "%Y-%m-%dT%H:%M:%S").strftime("%Y-%m-%d")
    except Exception:
        return iso


def clone_repo(org: str, name: str, dest: str, shallow: bool = False) -> tuple:
    """Clone a repo. Return (returncode, stderr)."""
    args = ["repo", "clone", f"{org}/{name}", dest]
    if shallow:
        # Signatures only matter in the latest version: the history is not needed
        args += ["--", "--depth", "1", "--quiet"]
    rc, _, stderr = run_gh(*args)
    return rc, stderr


# ── Due Date ──────────────────────────────────────────────────────────────────

def eastern_utc_offset(day: date) -> timedelta:
    """UTC offset of Eastern time (Montréal) at the end of a day.

    EDT from the second Sunday of March to the first Sunday of November (the change happens
    at 2 a.m., so 23:59 on those Sundays already uses the new offset). No tzdata needed.
    """
    def nth_sunday(month: int, n: int) -> date:
        first = date(day.year, month, 1)
        return first + timedelta(days=(6 - first.weekday()) % 7 + 7 * (n - 1))
    summer = nth_sunday(3, 2) <= day < nth_sunday(11, 1)
    return timedelta(hours=-4 if summer else -5)


def parse_due_date(text: str, today: date = None):
    """'2026-11-04' (or empty for today) -> date. Return None if the text is not a date."""
    text = text.strip()
    if not text:
        return today or date.today()
    try:
        return datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        return None


def due_deadline(day: date) -> datetime:
    """23:59:59, Eastern time, on the due date."""
    return datetime(day.year, day.month, day.day, 23, 59, 59, tzinfo=timezone(eastern_utc_offset(day)))


def git_date(moment: datetime) -> str:
    """A date git parses without ambiguity: '2026-11-04 23:59:59 -0500'."""
    return moment.strftime("%Y-%m-%d %H:%M:%S %z")


def checkout_at_deadline(repo_dir: str, deadline: datetime) -> dict:
    """Put a clone on the last commit of the default branch made before the deadline.

    Dates are those of the commits (committer date): git cannot tell when they were pushed.
    Return {"commit", "date", "late"} or {"error"}; "commit" is None if nothing was committed in time.
    """
    branch = "origin/HEAD"
    if run_git(repo_dir, "rev-parse", "--verify", "--quiet", branch)[0] != 0:
        branch = "HEAD"
    rc, stdout, stderr = run_git(
        repo_dir, "rev-list", "-1", "--date-order", f"--before={git_date(deadline)}", branch
    )
    if rc != 0:
        return {"error": stderr.strip()}
    sha = stdout.strip()
    if not sha:
        rc, stdout, _ = run_git(repo_dir, "rev-list", "--count", branch)
        return {"commit": None, "date": None, "late": int(stdout.strip()) if rc == 0 and stdout.strip() else 0}

    rc, _, stderr = run_git(repo_dir, "checkout", "--quiet", "--detach", sha)
    if rc != 0:
        return {"error": stderr.strip()}
    _, when, _ = run_git(repo_dir, "log", "-1", "--format=%ci", sha)
    _, late, _ = run_git(repo_dir, "rev-list", "--count", f"{sha}..{branch}")
    return {"commit": sha, "date": when.strip(), "late": int(late.strip() or 0)}


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


def github_user_exists(login: str) -> bool:
    """True if a GitHub account has this login (inviting an unknown login fails with a 404)."""
    rc, _, _ = run_gh("api", f"users/{login}", "--silent")
    return rc == 0


def repo_access(org: str, repo_name: str) -> dict:
    """Direct collaborators and invitations (pending or expired) of a repo, or an error."""
    rc, stdout, stderr = run_gh(
        "api", f"repos/{org}/{repo_name}/collaborators?affiliation=direct&per_page=100",
        "-q", "[.[].login]"
    )
    if rc != 0:
        return {"error": stderr.strip()}
    collaborators = json.loads(stdout or "[]")
    rc, stdout, stderr = run_gh(
        "api", f"repos/{org}/{repo_name}/invitations?per_page=100",
        "-q", "[.[] | {id, login: .invitee.login, expired, created_at}]"
    )
    if rc != 0:
        return {"error": stderr.strip()}
    invitations = [i for i in json.loads(stdout or "[]") if i["login"]]
    return {"collaborators": collaborators, "invitations": invitations}


def repo_is_empty(org: str, repo_name: str) -> bool:
    """True if the repo has no commit yet (e.g. created by a run whose push failed)."""
    rc, stdout, _ = run_gh("repo", "view", f"{org}/{repo_name}", "--json", "isEmpty", "-q", ".isEmpty")
    return rc == 0 and stdout.strip() == "true"


# ── Work Rhythm & AI Traces ───────────────────────────────────────────────────

def parse_git_log(text: str) -> list:
    """Parse the output of `git log` with GIT_LOG_FORMAT and --numstat, oldest commit first."""
    commits = []
    for entry in text.split("\x1e")[1:]:
        fields = entry.split("\x1f")
        if len(fields) < 9:
            continue
        lines, paths = 0, []
        for row in fields[8].splitlines():
            parts = row.split("\t")
            if len(parts) != 3:
                continue
            # Renames appear as "src/{a => b}/c.cs"
            path = parts[2].split(" => ")[-1].replace("}", "")
            paths.append(path)
            if parts[0] == "-" or parts[1] == "-":
                continue
            if os.path.splitext(path)[1].lower() in RHYTHM_EXTENSIONS and not GENERATED_PATH.search(path):
                # Net lines: code moved between files adds nothing
                lines += max(0, int(parts[0]) - int(parts[1]))
        commits.append({
            "hash": fields[0].strip(),
            "parents": fields[1].split(),
            "time": int(fields[2]),
            "email": fields[3].strip().lower(),
            "identity": f"{fields[4]} <{fields[3]}> {fields[5]} <{fields[6]}>",
            "message": fields[7].strip(),
            "lines": lines,
            "paths": paths,
        })
    return sorted(commits, key=lambda c: c["time"])


def find_bursts(commits: list, teacher_email: str) -> list:
    """Merge student commits made close together, and measure the time available to write them.

    Students often commit a long session in several quick commits: rating those one by one
    would be unfair, so a burst is rated against the time since the previous activity.
    """
    bursts = []
    current = None
    last_activity = None
    for c in commits:
        if c["email"] == teacher_email:
            current = None
        elif current and c["time"] - current["end"] <= BURST_GAP_SECONDS:
            current["end"] = c["time"]
            current["lines"] += c["lines"]
        else:
            current = {"since": last_activity, "end": c["time"], "lines": c["lines"]}
            bursts.append(current)
        last_activity = c["time"]

    for b in bursts:
        b["minutes"] = None if b["since"] is None else max(b["end"] - b["since"], 1) / 60
        b["rate"] = None if b["minutes"] is None else b["lines"] / b["minutes"]
        b["impossible"] = (
            b["rate"] is not None
            and b["lines"] >= MIN_BURST_LINES
            and b["rate"] > MAX_LINES_PER_MINUTE
        )
    return bursts


def grep_ai_content(repo_dir: str, rev: str) -> set:
    """Return (path, text) pairs of the explicit AI mentions found in a revision."""
    rc, stdout, _ = run_git(repo_dir, "grep", "-I", "-i", "-E", "-e", AI_CONTENT_PATTERN, rev, "--")
    if rc != 0:
        return set()
    found = set()
    for line in stdout.splitlines():
        parts = line.split(":", 2)
        if len(parts) == 3:
            found.add((parts[1], parts[2].strip()))
    return found


def analyze_repo(repo_dir: str, teacher_email: str) -> dict:
    """Analyze a local clone: student work rhythm and explicit AI traces."""
    rc, stdout, stderr = run_git(
        repo_dir, "-c", "core.quotepath=off", "log", "--all", "--no-merges", "-M",
        f"--format={GIT_LOG_FORMAT}", "--numstat"
    )
    if rc != 0:
        return {"error": stderr.strip()}

    commits = parse_git_log(stdout)
    student_commits = [c for c in commits if c["email"] != teacher_email]
    traces = []

    for c in student_commits:
        if AI_COMMIT_PATTERN.search(f"{c['message']}\n{c['identity']}"):
            subject = c["message"].splitlines()[0] if c["message"] else ""
            traces.append(f"Commit : {subject[:70]}")

    ai_files = {p for c in student_commits for p in c["paths"] if AI_FILE_PATTERN.search(p)}
    traces.extend(f"Fichier : {p}" for p in sorted(ai_files))

    mentions = grep_ai_content(repo_dir, "HEAD")
    seed = next((c for c in commits if c["email"] == teacher_email and not c["parents"]), None)
    if seed and mentions:
        mentions -= grep_ai_content(repo_dir, seed["hash"])
    traces.extend(f"Contenu : {path} : {text[:70]}" for path, text in sorted(mentions))

    bursts = find_bursts(commits, teacher_email)
    rated = [b for b in bursts if b["rate"] is not None and b["lines"] >= MIN_BURST_LINES]
    return {
        "commits": len(student_commits),
        "lines": sum(c["lines"] for c in student_commits),
        "fastest": max(rated, key=lambda b: b["rate"]) if rated else None,
        "impossible": sum(1 for b in bursts if b["impossible"]),
        "traces": traces,
    }


def find_local_repos(path: str) -> list:
    """Return the git repos directly inside a folder, or the folder itself if it is one."""
    if os.path.exists(os.path.join(path, ".git")):
        return [path]
    return sorted(
        os.path.join(path, d) for d in os.listdir(path)
        if os.path.exists(os.path.join(path, d, ".git"))
    )


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
                unsigned = inject_signatures_in_directory(tmp_dir, student_id)
                if unsigned:
                    console.print(f"[dim]  {len(unsigned)} fichier(s) non signé(s) : {escape(', '.join(sorted(unsigned)))}[/]")
                
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
        cours = Prompt.ask("Code du cours (ex: SN1)").strip()
        travail = Prompt.ask("Identifiant du travail (ex: TP2)").strip()
        
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
            
        console.print("[dim]Vérification des repos existants et des logins GitHub...[/]")
        existing = {r["name"].lower() for r in self.fetch_org_repos(org)}
        logins = sorted({e["login"] for e in students if e["login"]})
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            unknown_logins = {
                login for login, found in zip(logins, executor.map(github_user_exists, logins))
                if not found
            }

        # Preview Table
        console.print()
        names = {e["matricule"]: build_repo_name(session, cours, travail, e) for e in students}
        n_existing = sum(1 for name in names.values() if name.lower() in existing)
        console.print(f"[cyan]{len(students) - n_existing} repo(s) à créer dans [bold]{org}[/]"
                      f"{f' · {n_existing} déjà existant(s)' if n_existing else ''}"
                      f" · {len(logins) - len(unknown_logins)} login(s) GitHub valide(s)[/]")

        preview = Table(show_header=False, border_style="dim")
        preview.add_column("Repo")
        preview.add_column("Groupe")
        preview.add_column("Matricule")
        preview.add_column("Étudiant")
        preview.add_column("Login")
        for e in students:
            name = names[e["matricule"]]
            if not e["login"]:
                login_cell = "[dim]–[/]"
            elif e["login"] in unknown_logins:
                login_cell = f"[red]{escape(e['login'])} (introuvable)[/]"
            else:
                login_cell = f"[dim]{escape(e['login'])}[/]"
            preview.add_row(
                f"[yellow]{name} (existe)[/]" if name.lower() in existing else name,
                escape(e["groupe"]),
                escape(e["matricule"]),
                escape(f"{e['nom']} {e['prenom']}"),
                login_cell
            )
        console.print(preview)
        if n_existing:
            console.print("[dim]Repos existants : pas recréés ; remplis s'ils sont vides, puis invitation.[/]")
        if unknown_logins:
            console.print(f"[red]⚠ {len(unknown_logins)} login(s) sans compte GitHub : "
                          f"aucune invitation pour ces étudiants. Corriger la liste et relancer.[/]")

        if not Confirm.ask("Confirmer la création ?", default=False):
            console.print("[dim]Annulé.[/]")
            return

        # Kept on this computer to reinvite later without the student list
        remember_logins(org, {
            names[e["matricule"]]: e["login"] for e in students
            if e["login"] and e["login"] not in unknown_logins
        })

        ok, reused, failed = 0, 0, 0
        not_invited = []
        with Progress(
            TextColumn("[dim]{task.description}[/]"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Création des repos", total=len(students))
            for e in students:
                repo_name = names[e["matricule"]]
                progress.update(task, description=repo_name)

                already = repo_name.lower() in existing
                if not already:
                    rc, _, stderr = run_gh("repo", "create", f"{org}/{repo_name}", visibility)
                    if rc != 0:
                        console.print(f"[red]  ✘ {repo_name} : {escape(stderr.strip())}[/]")
                        failed += 1
                        progress.advance(task, 1)
                        continue

                if use_template and (not already or repo_is_empty(org, repo_name)):
                    if not self.seed_repo(org, repo_name, template_dir, hide_signature, student_signature(e)):
                        console.print(f"[red]  ✘ {repo_name} : repo vide, invitation non envoyée.[/]")
                        failed += 1
                        progress.advance(task, 1)
                        continue

                if e["login"] in unknown_logins:
                    not_invited.append(e)
                elif e["login"]:
                    self.invite_collaborateur(org, repo_name, e["login"])

                if already:
                    reused += 1
                else:
                    ok += 1
                progress.advance(task, 1)
                
        console.print()
        if ok > 0:
            console.print(f"[green]✔ {ok} repo(s) créé(s).[/]")
        if reused > 0:
            console.print(f"[yellow]⏭  {reused} repo(s) déjà existant(s), réutilisé(s).[/]")
        if failed > 0:
            console.print(f"[red]✘ {failed} échec(s).[/]")
        if not_invited:
            console.print(f"[red]✘ {len(not_invited)} invitation(s) non envoyée(s), login GitHub introuvable :[/]")
            for e in not_invited:
                console.print(f"[red]  • {escape(e['nom'])} {escape(e['prenom'])} ({escape(e['matricule'])}) : "
                              f"{escape(e['login'])}[/]")

    def choisir_repos_tp(self, repos: list):
        """Pick a TP, then a group if the TP has several. Return (label, repos) or None."""
        groups = detect_work_groups(repos)
        manual_entry = "✏  Saisir un préfixe manuellement..."
        choices = []
        for g in groups:
            yr_suffix = f" · 20{g['year']}" if g['year'] else ""
            choices.append(f"{g['prefix']}  ({len(g['repos'])} repos{yr_suffix})")
        choices.append(manual_entry)

        picked = prompt_selection("Choisir le TP", choices)
        if picked == manual_entry:
            label = Prompt.ask("Préfixe (les repos commençant par ce texte)").strip()
            selected = sorted(
                (r for r in repos if r["name"].lower().startswith(label.lower())),
                key=lambda x: x["name"]
            )
        else:
            group = groups[choices.index(picked)]
            label, selected = group["prefix"], group["repos"]

        if not selected:
            console.print("[yellow]Aucun repo trouvé pour ce préfixe.[/]")
            return None

        by_group = {}
        for r in selected:
            parsed = parse_repo_name(r["name"])
            by_group.setdefault(parsed["groupe"] if parsed else "", []).append(r)
        if len(by_group) < 2:
            return label, selected

        keys = sorted(k for k in by_group if k) + ([""] if "" in by_group else [])
        group_choices = [f"Tous les groupes  ({len(selected)} repos)"] + [
            f"{f'Groupe {k}' if k else 'Sans groupe'}  ({len(by_group[k])} repos)" for k in keys
        ]
        idx = group_choices.index(prompt_selection("Choisir le groupe", group_choices))
        if idx == 0:
            return label, selected
        key = keys[idx - 1]
        return f"{label} · {f'groupe {key}' if key else 'sans groupe'}", by_group[key]

    def afficher_repos_tp(self, label: str, repos: list):
        """Show the repos of a TP, one line per student."""
        table = Table(title=f"[cyan]{escape(label)} — {len(repos)} repo(s)[/]", show_header=True, header_style="bold")
        table.add_column("Groupe")
        table.add_column("Matricule")
        table.add_column("Étudiant")
        table.add_column("Créé le")
        for r in sorted(repos, key=lambda x: x["name"]):
            parsed = parse_repo_name(r["name"])
            if parsed:
                table.add_row(
                    parsed["groupe"] or "[dim]–[/]", parsed["matricule"] or "[dim]–[/]",
                    f"{parsed['nom']} {parsed['prenom']}", short_date(r["createdAt"])
                )
            else:
                table.add_row("[dim]–[/]", "[dim]–[/]", escape(r["name"]), short_date(r["createdAt"]))
        console.print(table)

    def parcourir_repos(self):
        """Browse the repos of a TP (and group), then act on them."""
        console.print(Rule("[cyan]Parcourir les repos d'un TP[/]", style="cyan"))
        console.print()

        org = self.get_or_prompt_org()
        console.print("[dim]Récupération des repos...[/]")
        repos = self.fetch_org_repos(org)
        if not repos:
            console.print("[yellow]Aucun repo trouvé.[/]")
            return

        selection = self.choisir_repos_tp(repos)
        if not selection:
            return
        label, selected = selection
        console.print()
        self.afficher_repos_tp(label, selected)

        retour = "← Retour"
        while True:
            action = prompt_selection(
                f"Action sur {escape(label)} ({len(selected)} repo(s))",
                ["📥 Cloner", "🕵️  Chercher les signatures suspectes (clone temporaire)",
                 "✉️  Réinviter les étudiants (invitations expirées)", retour]
            )
            console.print()
            if action == retour:
                return
            try:
                if "Cloner" in action:
                    self.cloner_repos(org, selected)
                elif "Réinviter" in action:
                    self.reinviter_etudiants(org, selected)
                else:
                    self.chercher_signatures_suspectes(org, selected)
            except BackToMenu:
                console.print("\n[dim]Annulé.[/]")

    def reinviter_etudiants(self, org: str, repos: list):
        """Resend the invitations of students who have not accepted yet (GitHub expires them after 7 days).

        An expired invitation is deleted then sent again. A repo with neither collaborator nor
        invitation (login missing at creation) can be invited from the student list, by matricule.
        """
        accepted, pending, expired, nobody, errors = [], [], [], [], []
        with Progress(
            TextColumn("[dim]{task.description}[/]"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Lecture des invitations", total=len(repos))
            with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                futures = {executor.submit(repo_access, org, r["name"]): r["name"] for r in repos}
                for future in concurrent.futures.as_completed(futures):
                    name = futures[future]
                    access = future.result()
                    if "error" in access:
                        errors.append((name, access["error"]))
                    else:
                        if access["collaborators"]:
                            accepted.append(name)
                        for inv in access["invitations"]:
                            (expired if inv["expired"] else pending).append((name, inv))
                        if not access["collaborators"] and not access["invitations"]:
                            nobody.append(name)
                    progress.advance(task, 1)

        for name, err in sorted(errors):
            console.print(f"[red]  ✘ {name}: {escape(err)}[/]")

        # An invitation names the student of the repo: remembered for the next reinvitation
        remember_logins(org, {name: inv["login"] for name, inv in sorted(
            expired + pending, key=lambda x: x[1]["created_at"]
        )})

        table = Table(title="[cyan]Invitations à renvoyer ou en attente[/]", show_header=True, header_style="bold")
        table.add_column("Repo")
        table.add_column("Login")
        table.add_column("Invité le")
        table.add_column("État")
        for name, inv in sorted(expired + pending, key=lambda x: x[0]):
            state = "[red]expirée[/]" if inv["expired"] else "[yellow]en attente[/]"
            table.add_row(name, escape(inv["login"]), short_date(inv["created_at"]), state)
        for name in sorted(nobody):
            table.add_row(name, "[dim]–[/]", "[dim]–[/]", "[dim]aucune invitation[/]")
        if expired or pending or nobody:
            console.print(table)
        console.print(f"[green]✔ {len(accepted)} repo(s) avec invitation acceptée[/] · "
                      f"[red]{len(expired)} expirée(s)[/] · [yellow]{len(pending)} en attente[/] · "
                      f"[dim]{len(nobody)} sans invitation[/]")

        to_send = [(name, inv["login"], inv["id"]) for name, inv in expired]
        if pending and Confirm.ask(
            f"Renvoyer aussi les {len(pending)} invitation(s) en attente (repart pour 7 jours) ?", default=False
        ):
            to_send += [(name, inv["login"], inv["id"]) for name, inv in pending]

        known = stored_logins(org)
        remembered = [(name, known[name.lower()]) for name in nobody if name.lower() in known]
        unknown = [name for name in nobody if name.lower() not in known]
        if remembered:
            console.print(f"[cyan]{len(remembered)} repo(s) sans invitation dont le login est connu "
                          f"({escape(LOGIN_STORE)}) :[/]")
            for name, login in sorted(remembered):
                console.print(f"  [dim]{name}[/] → {escape(login)}")
            if Confirm.ask("Les inviter ?", default=True):
                to_send += [(name, login, None) for name, login in remembered]

        if unknown and Confirm.ask(
            f"Inviter les {len(unknown)} repo(s) sans invitation ni login connu à partir de la liste d'étudiants ?",
            default=False
        ):
            by_matricule = {s["matricule"]: s for s in prompt_and_load_students() if s["login"]}
            found = {}
            for name in unknown:
                parsed = parse_repo_name(name)
                student = by_matricule.get(parsed["matricule"]) if parsed and parsed["matricule"] else None
                if not student:
                    console.print(f"[yellow]  ⚠ {name}: matricule absent de la liste ou sans login.[/]")
                elif not github_user_exists(student["login"]):
                    console.print(f"[red]  ✘ {name}: login GitHub introuvable ({escape(student['login'])}).[/]")
                else:
                    found[name] = student["login"]
                    to_send.append((name, student["login"], None))
            remember_logins(org, found)

        if not to_send:
            console.print("[dim]Aucune invitation à envoyer.[/]")
            return
        if not Confirm.ask(f"Envoyer {len(to_send)} invitation(s) ?", default=True):
            console.print("[dim]Annulé.[/]")
            return

        for name, login, invitation_id in sorted(to_send):
            console.print(f"[dim]{name}[/]")
            if invitation_id is not None:
                # Without deleting it first, GitHub keeps the old (expired) invitation and sends nothing
                rc, _, stderr = run_gh("api", "-X", "DELETE", f"repos/{org}/{name}/invitations/{invitation_id}")
                if rc != 0:
                    console.print(f"  [yellow]⚠ Ancienne invitation non supprimée : {escape(stderr.strip())}[/]")
            self.invite_collaborateur(org, name, login)

    def cloner_repos(self, org: str, repos: list):
        """Clone repos into a folder, then put each one on its last commit before the due date.

        Repos already in the folder are not cloned again, only updated and put on that commit.
        """
        dest_dir = clean_path(Prompt.ask("Dossier de destination", default=os.getcwd()))
        while True:
            due = parse_due_date(Prompt.ask("Date de remise (AAAA-MM-JJ, Entrée pour aujourd'hui)", default=""))
            if due:
                break
            console.print("[red]Format attendu : AAAA-MM-JJ (ex: 2026-11-04)[/]")
        deadline = due_deadline(due)
        os.makedirs(dest_dir, exist_ok=True)

        console.print(f"[cyan]{len(repos)} repo(s) → {escape(dest_dir)}[/]")
        console.print(f"[cyan]Dernier commit avant le {due:%Y-%m-%d} à 23 h 59 (heure de l'Est, "
                      f"UTC{deadline:%z}).[/]")
        if not Confirm.ask("Confirmer ?", default=True):
            return

        ok, skipped, failed = 0, 0, 0
        positions = {}
        with Progress(
            TextColumn("[dim]{task.description}[/]"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Clonage", total=len(repos))
            for r in repos:
                name = r["name"]
                progress.update(task, description=name)
                repo_dest_dir = os.path.join(dest_dir, name)
                if os.path.exists(os.path.join(repo_dest_dir, ".git")):
                    skipped += 1
                    rc, _, stderr = run_git(repo_dest_dir, "fetch", "--quiet", "origin")
                    if rc != 0:
                        console.print(f"[yellow]  ⚠ {name}: fetch échoué, position selon la copie locale "
                                      f"({escape(stderr.strip())})[/]")
                elif os.path.exists(repo_dest_dir):
                    failed += 1
                    console.print(f"[red]  ✘ {name}: le dossier existe mais n'est pas un repo git.[/]")
                    progress.advance(task, 1)
                    continue
                else:
                    rc, stderr = clone_repo(org, name, repo_dest_dir)
                    if rc != 0:
                        failed += 1
                        console.print(f"[red]  ✘ {name}: {escape(stderr.strip())}[/]")
                        progress.advance(task, 1)
                        continue
                    ok += 1
                positions[name] = checkout_at_deadline(repo_dest_dir, deadline)
                progress.advance(task, 1)

        console.print()
        self.afficher_positions(positions, due)
        if ok > 0:
            console.print(f"[green]✔ {ok} cloné(s).[/]")
        if skipped > 0:
            console.print(f"[yellow]⏭  {skipped} déjà présent(s) : mis à jour, pas reclonés.[/]")
        if failed > 0:
            console.print(f"[red]✘ {failed} échec(s).[/]")

    def afficher_positions(self, positions: dict, due: date):
        """Show the commit each clone was put on, and what was committed after the due date."""
        if not positions:
            return
        table = Table(title=f"[cyan]Remise du {due:%Y-%m-%d}[/]", show_header=True, header_style="bold")
        table.add_column("Repo")
        table.add_column("Commit remis")
        table.add_column("Date du commit")
        table.add_column("Commits après", justify="right")
        for name in sorted(positions):
            p = positions[name]
            if "error" in p:
                table.add_row(escape(name), f"[red]{escape(p['error'])}[/]", "", "")
            elif p["commit"] is None:
                table.add_row(escape(name), "[bold red]Aucun commit avant la date[/]",
                              "[dim]repo laissé tel quel[/]", str(p["late"]))
            else:
                late = f"[yellow]{p['late']}[/]" if p["late"] else "[dim]0[/]"
                table.add_row(escape(name), p["commit"][:8], escape(p["date"]), late)
        console.print(table)
        console.print("[dim]Repos en HEAD détaché sur le commit remis. Pour revenir à la dernière "
                      "version : git switch main (ou master).[/]")
        console.print("[dim]La date est celle du commit, pas du push : un commit daté d'avant "
                      "mais poussé en retard n'est pas détecté.[/]")

    def chercher_signatures_suspectes(self, org: str, repos: list):
        """Clone repos into a temporary folder, report suspicious signatures, then delete everything."""
        tmp_dir = tempfile.mkdtemp(prefix="git_classroom_sig_")
        try:
            failed = {}
            with Progress(
                TextColumn("[dim]{task.description}[/]"),
                BarColumn(),
                TaskProgressColumn(),
                console=console
            ) as progress:
                task = progress.add_task("Clonage temporaire", total=len(repos))
                with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                    futures = {
                        executor.submit(clone_repo, org, r["name"], os.path.join(tmp_dir, r["name"]), True): r["name"]
                        for r in repos
                    }
                    for future in concurrent.futures.as_completed(futures):
                        rc, stderr = future.result()
                        if rc != 0:
                            failed[futures[future]] = stderr.strip()
                        progress.advance(task, 1)

            for name, err in sorted(failed.items()):
                console.print(f"[red]  ✘ {name}: {escape(err)}[/]")

            findings = scan_signatures(tmp_dir)
            suspects = [f for f in findings if signature_status(f) != "ok"]
            signed_repos = {f["rel_path"].split(os.sep)[0] for f in findings}
            unsigned = sorted(r["name"] for r in repos if r["name"] not in signed_repos and r["name"] not in failed)

            console.print()
            if suspects:
                print_signature_findings(suspects, f"{len(suspects)} fichier(s) suspect(s)")
            else:
                console.print("[green]✔ Aucune signature suspecte.[/]")
            console.print(f"[dim]{len(findings) - len(suspects)} fichier(s) signé(s) conforme(s) "
                          f"dans {len(signed_repos)} repo(s).[/]")
            if unsigned:
                console.print(f"[dim]Aucune signature trouvée dans {len(unsigned)} repo(s) "
                              f"(normal si le TP a été créé sans signature) :[/]")
                for name in unsigned:
                    console.print(f"[dim]  • {escape(name)}[/]")
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    def lister_repos_avec_commits(self):
        """List repositories matching filters that contain active student commits."""
        console.print(Rule("[cyan]Repos avec commits étudiants[/]", style="cyan"))
        console.print()
        
        org = self.get_or_prompt_org()
        session = Prompt.ask("Session (ex: H26) — laisser vide pour toutes", default="").strip()
        cours = Prompt.ask("Cours — laisser vide pour tous", default="").strip()
        travail = Prompt.ask("Travail (ex: TP2) — laisser vide pour tous", default="").strip()
        groupe = Prompt.ask("Groupe (ex: 1050) — laisser vide pour tous", default="").strip()
        
        console.print("[dim]Récupération des repos...[/]")
        repos = self.fetch_org_repos(org)
        if not repos:
            console.print("[yellow]Aucun repo trouvé.[/]")
            return
            
        ses_slug = normalize_slug(session)
        cour_slug = normalize_slug(cours)
        trav_slug = normalize_slug(travail)
        grp_slug = normalize_slug(groupe)
        
        candidates = []
        for r in repos:
            parsed = parse_repo_name(r["name"])
            if parsed and \
               (not ses_slug or parsed["session"] == ses_slug) and \
               (not cour_slug or parsed["cours"] == cour_slug) and \
               (not trav_slug or parsed["travail"] == trav_slug) and \
               (not grp_slug or parsed["groupe"] == grp_slug):
                parsed["repo"] = r
                candidates.append(parsed)
                    
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
            
        sorted_list = sorted(
            with_commits, key=lambda x: (x["session"], x["cours"], x["travail"], x["groupe"], x["nom"])
        )
        
        table = Table(
            title=f"[cyan]{len(sorted_list)} repo(s) avec commits étudiants[/]",
            show_header=True,
            header_style="bold"
        )
        table.add_column("Session")
        table.add_column("Cours")
        table.add_column("Travail")
        table.add_column("Groupe")
        table.add_column("Matricule")
        table.add_column("Étudiant")
        
        last_group = None
        for r in sorted_list:
            group = f"{r['session']}-{r['cours']}-{r['travail']}-{r['groupe']}"
            if last_group and group != last_group:
                table.add_row("", "", "", "", "", "")
            last_group = group
            table.add_row(
                r["session"], r["cours"], r["travail"],
                r["groupe"] or "[dim]–[/]", r["matricule"] or "[dim]–[/]",
                f"{r['nom']} {r['prenom']}"
            )
            
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
        findings = scan_signatures(path_to_scan)
        if not findings:
            console.print("[yellow]Aucune signature stéganographique détectée dans ce dossier.[/]")
            return
        print_signature_findings(findings, f"{len(findings)} signature(s) détectée(s)")

    def analyser_rythme(self):
        """Report impossible work rhythms and explicit AI traces in locally cloned repos."""
        console.print(Rule("[cyan]Rythme de travail et traces d'IA[/]", style="cyan"))
        console.print()

        path = clean_path(Prompt.ask("Dossier des repos clonés", default=os.getcwd()))
        if not os.path.isdir(path):
            console.print(f"[red]✘ Dossier introuvable : {escape(path)}[/]")
            return

        repos = find_local_repos(path)
        if not repos:
            console.print("[yellow]Aucun repo git trouvé dans ce dossier.[/]")
            return

        _, stdout, _ = run_git(path, "config", "user.email")
        teacher_email = Prompt.ask(
            "Courriel git de l'enseignant (ses commits sont ignorés)", default=stdout.strip()
        ).strip().lower()

        table = Table(
            title=f"[cyan]{len(repos)} repo(s) analysé(s)[/]",
            show_header=True,
            header_style="bold"
        )
        table.add_column("Repo")
        table.add_column("Commits", justify="right")
        table.add_column("Lignes", justify="right")
        table.add_column("Rythme max")
        table.add_column("Signal")

        details = []
        for repo_dir in repos:
            name = os.path.basename(os.path.abspath(repo_dir))
            report = analyze_repo(repo_dir, teacher_email)
            if "error" in report:
                table.add_row(escape(name), "", "", "", f"[red]{escape(report['error'])}[/]")
                continue

            fastest = report["fastest"]
            rhythm = "[dim]–[/]"
            if fastest:
                rhythm = f"{fastest['lines']} lignes en {fastest['minutes']:.0f} min ({fastest['rate']:.0f}/min)"

            signals = []
            if report["impossible"]:
                signals.append(f"[bold red]{report['impossible']} rafale(s) impossible(s) à la frappe[/]")
            if report["traces"]:
                signals.append(f"[bold red]{len(report['traces'])} trace(s) d'IA[/]")
                details.append((name, report["traces"]))

            table.add_row(
                escape(name),
                str(report["commits"]),
                str(report["lines"]),
                rhythm,
                " · ".join(signals) if signals else "[dim]–[/]"
            )

        console.print(table)
        for name, traces in details:
            console.print(f"\n[bold]{escape(name)}[/]")
            for trace in traces:
                console.print(f"  • {escape(trace)}")

        console.print()
        console.print(f"[dim]Impossible : plus de {MAX_LINES_PER_MINUTE} lignes/min sur au moins "
                      f"{MIN_BURST_LINES} lignes. Du code collé ou écrit hors du repo donne le même résultat.[/]")
        console.print("[dim]Ce sont des sujets à aborder à l'oral, pas des preuves. "
                      "L'absence de signal ne prouve rien non plus.[/]")

    def run(self):
        """Submenu execution loop."""
        retour = "← Retour"
        while True:
            console.clear()
            console.print(Rule("[cyan]Git Classroom (Python)[/]", style="cyan"))
            if self.org:
                console.print(f"[dim]Organisation active : {self.org}[/]")
            console.print("[dim]Échap à une question : abandonner l'action et revenir au menu.[/]")
            try:
                choice = prompt_selection(
                    "Choisir une action",
                    [
                        "🔍 Diagnostic (gh, git, authentification)",
                        "🧪 Tester la création d'un repo",
                        "➕ Créer les repos d'un TP",
                        "📋 Parcourir les repos d'un TP (cloner, signatures, réinviter)",
                        "💬 Repos avec commits étudiants",
                        "🗑  Supprimer des repos",
                        "🕵️  Détecter les signatures stéganographiques",
                        "⏱  Rythme de travail et traces d'IA",
                        retour
                    ]
                )
            except BackToMenu:
                continue

            console.print()
            if choice == retour:
                break
            try:
                if "Diagnostic" in choice:
                    self.diagnostic()
                elif "Tester" in choice:
                    self.tester_creation_repo()
                elif "Créer" in choice:
                    self.creer_repos_etudiants()
                elif "Parcourir" in choice:
                    self.parcourir_repos()
                elif "commits" in choice:
                    self.lister_repos_avec_commits()
                elif "Supprimer" in choice:
                    self.supprimer_repos()
                elif "signatures" in choice:
                    self.detecter_signatures()
                elif "Rythme" in choice:
                    self.analyser_rythme()
            except BackToMenu:
                continue

            console.print("\n[dim]Appuyez sur Entrée pour revenir au menu principal...[/]")
            try:
                read_line()
            except BackToMenu:
                pass


if __name__ == "__main__":
    try:
        app = GitClassroomApp()
        app.run()
    except KeyboardInterrupt:
        console.print("\n[dim]Fermeture de l'application.[/]")
        sys.exit(0)
