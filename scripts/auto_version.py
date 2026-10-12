#!/usr/bin/env python3
"""Versionado automático de Nexo (lo usa .github/workflows/auto-version.yml).

Decide la siguiente versión a partir de los commits desde el último tag
`vX.Y.Z`, siguiendo Conventional Commits (lo que ya usa el repo):

  - `feat!:` / `fix(x)!:` / "BREAKING CHANGE" en el cuerpo  -> major
  - `feat:`                                                  -> minor
  - `fix:`, `perf:`, `refactor:`, `chore:`, `build:`, `revert:`
    o cualquier mensaje que no siga la convención            -> patch
  - Solo `docs:`, `ci:`, `test:` o `style:`                  -> sin release

Escribe la versión en pubspec.yaml (el build `+N` siempre sube 1) y en
lib/core/config.dart, y mueve las notas a CHANGELOG.md: si existe la sección
`## [Sin publicar]` se renombra a la versión nueva; si no, se genera a partir
de los commits.

Uso:
  python3 scripts/auto_version.py next   [--bump auto|patch|minor|major]
      Imprime `version=X.Y.Z` y `tag=vX.Y.Z` (o `release=false`) sin tocar nada.
  python3 scripts/auto_version.py apply  [--bump ...] [--date YYYY-MM-DD]
      Igual que `next`, pero además escribe los archivos.
  python3 scripts/auto_version.py notes X.Y.Z
      Imprime la sección del CHANGELOG de esa versión (notas del release).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
CONFIG = ROOT / "lib" / "core" / "config.dart"
CHANGELOG = ROOT / "CHANGELOG.md"

UNRELEASED_RE = re.compile(r"^## \[(Sin publicar|Unreleased)\][^\n]*$", re.M | re.I)
CONVENTIONAL_RE = re.compile(r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]*)\))?(?P<bang>!)?:\s*(?P<desc>.+)$")
NO_RELEASE_TYPES = {"docs", "ci", "test", "tests", "style"}
LEVELS = {"none": 0, "patch": 1, "minor": 2, "major": 3}


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=ROOT, check=True, capture_output=True, text=True
    ).stdout


# ── Versión actual ──────────────────────────────────────────────────────────

def read_pubspec_version() -> tuple[str, int]:
    for line in PUBSPEC.read_text(encoding="utf-8-sig").splitlines():
        m = re.match(r"^\s*version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$", line)
        if m:
            return m.group(1), int(m.group(2) or 0)
    raise SystemExit("No se encontró 'version: X.Y.Z+N' en pubspec.yaml")


def last_tag() -> str | None:
    tags = [t for t in git("tag", "--list", "v*", "--merged", "HEAD").split() if re.fullmatch(r"v\d+\.\d+\.\d+", t)]
    if not tags:
        return None
    return max(tags, key=lambda t: tuple(int(x) for x in t[1:].split(".")))


def parse_semver(v: str) -> tuple[int, int, int]:
    a, b, c = (int(x) for x in v.split("."))
    return a, b, c


# ── Commits ─────────────────────────────────────────────────────────────────

class Commit:
    def __init__(self, sha: str, subject: str, body: str):
        self.sha = sha
        self.subject = subject.strip()
        self.body = body.strip()
        m = CONVENTIONAL_RE.match(self.subject)
        self.type = m.group("type").lower() if m else None
        self.scope = m.group("scope") if m else None
        self.desc = m.group("desc").strip() if m else self.subject
        self.breaking = bool(m and m.group("bang")) or "BREAKING CHANGE" in self.body

    @property
    def is_merge_noise(self) -> bool:
        s = self.subject
        return s.startswith("Merge pull request") or s.startswith("Merge branch") or s.startswith("Merge remote")

    @property
    def is_release_commit(self) -> bool:
        return self.subject.startswith("chore(release)")

    def level(self) -> str:
        if self.is_merge_noise or self.is_release_commit:
            return "none"
        if self.breaking:
            return "major"
        if self.type == "feat":
            return "minor"
        if self.type in NO_RELEASE_TYPES:
            return "none"
        return "patch"


def commits_since(tag: str | None) -> list[Commit]:
    rng = f"{tag}..HEAD" if tag else "HEAD"
    raw = git("log", rng, "--no-merges", "--format=%H%x1f%s%x1f%b%x1e")
    out = []
    for chunk in raw.split("\x1e"):
        chunk = chunk.strip("\n")
        if not chunk:
            continue
        sha, subject, body = (chunk.split("\x1f") + ["", ""])[:3]
        out.append(Commit(sha, subject, body))
    return out


def decide_bump(commits: list[Commit], forced: str) -> str:
    if forced != "auto":
        return forced
    level = max((LEVELS[c.level()] for c in commits), default=0)
    return {v: k for k, v in LEVELS.items()}[level]


def bump_version(current: str, kind: str) -> str:
    major, minor, patch = parse_semver(current)
    if kind == "major":
        return f"{major + 1}.0.0"
    if kind == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


def next_version(forced: str) -> tuple[str | None, int, list[Commit], str]:
    """Devuelve (versión nueva o None, build nuevo, commits, tipo de bump)."""
    pub_version, build = read_pubspec_version()
    tag = last_tag()
    commits = commits_since(tag)
    kind = decide_bump(commits, forced)
    if kind == "none":
        return None, build, commits, kind
    base = tag[1:] if tag else pub_version
    candidate = bump_version(base, kind)
    # Si alguien ya subió la versión del pubspec a mano por encima del tag,
    # se respeta (p. ej. 1.7.2 sin publicar con último tag v1.7.1).
    if parse_semver(pub_version) > parse_semver(base) and parse_semver(pub_version) >= parse_semver(candidate):
        candidate = pub_version
    existing = set(git("tag", "--list", "v*").split())
    while f"v{candidate}" in existing:
        candidate = bump_version(candidate, "patch")
    return candidate, build + 1, commits, kind


# ── Escritura de archivos ───────────────────────────────────────────────────

def write_pubspec(version: str, build: int) -> None:
    text = PUBSPEC.read_text(encoding="utf-8-sig")
    new, n = re.subn(r"(?m)^(\s*version:\s*).*$", rf"\g<1>{version}+{build}", text, count=1)
    if n != 1:
        raise SystemExit("No se pudo actualizar la versión en pubspec.yaml")
    PUBSPEC.write_text(new, encoding="utf-8")


def write_config(version: str, build: int) -> None:
    text = CONFIG.read_text(encoding="utf-8-sig")
    text, a = re.subn(r"(appVersion\s*=\s*')[^']+(')", rf"\g<1>{version}\g<2>", text, count=1)
    text, b = re.subn(r"(appBuild\s*=\s*)\d+", rf"\g<1>{build}", text, count=1)
    if a != 1 or b != 1:
        raise SystemExit("No se encontraron appVersion/appBuild en lib/core/config.dart")
    CONFIG.write_text(text, encoding="utf-8")


SECTION_TITLES = (
    ("breaking", "### Cambios importantes"),
    ("feat", "### Novedades"),
    ("fix", "### Correcciones"),
    ("other", "### Otros cambios"),
)


def generated_notes(commits: list[Commit]) -> str:
    groups: dict[str, list[str]] = {k: [] for k, _ in SECTION_TITLES}
    for c in commits:
        if c.level() == "none":
            continue
        desc = c.desc[:1].upper() + c.desc[1:]
        if c.scope:
            desc = f"{c.scope}: {desc}"
        key = "breaking" if c.breaking else c.type if c.type in ("feat", "fix") else "other"
        if desc not in groups[key]:
            groups[key].append(desc)
    parts = []
    for key, title in SECTION_TITLES:
        if groups[key]:
            parts.append(title + "\n" + "\n".join(f"- {d}" for d in groups[key]))
    return "\n\n".join(parts) if parts else "- Mejoras internas y correcciones menores"


def write_changelog(version: str, date: str, commits: list[Commit]) -> None:
    header = f"## [{version}] - {date}"
    text = CHANGELOG.read_text(encoding="utf-8-sig") if CHANGELOG.exists() else "# Changelog\n"
    m = UNRELEASED_RE.search(text)
    if m:
        # Notas escritas a mano: se conservan y solo se les pone versión.
        start = m.end()
        nxt = re.search(r"^## \[", text[start:], re.M)
        body = text[start : start + nxt.start()] if nxt else text[start:]
        if not body.strip():
            body = "\n\n" + generated_notes(commits) + "\n\n"
        text = text[: m.start()] + header + body + (text[start + nxt.start():] if nxt else "")
    else:
        section = f"{header}\n\n{generated_notes(commits)}\n\n"
        first = re.search(r"^## \[", text, re.M)
        text = text[: first.start()] + section + text[first.start():] if first else text.rstrip() + "\n\n" + section
    CHANGELOG.write_text(text, encoding="utf-8")


def changelog_section(version: str) -> str:
    text = CHANGELOG.read_text(encoding="utf-8-sig")
    m = re.search(rf"^## \[{re.escape(version)}\][^\n]*\n", text, re.M)
    if not m:
        return f"Nexo {version}"
    rest = text[m.end():]
    nxt = re.search(r"^## \[", rest, re.M)
    return (rest[: nxt.start()] if nxt else rest).strip() or f"Nexo {version}"


# ── CLI ─────────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("next", "apply"):
        p = sub.add_parser(name)
        p.add_argument("--bump", choices=["auto", *LEVELS.keys() - {"none"}], default="auto")
        p.add_argument("--date", default=_dt.date.today().isoformat())
    n = sub.add_parser("notes")
    n.add_argument("version")
    args = ap.parse_args(argv)

    if args.cmd == "notes":
        print(changelog_section(args.version.lstrip("v")))
        return 0

    version, build, commits, kind = next_version(args.bump)
    if version is None:
        print("release=false")
        print(f"reason=Sin cambios publicables desde {last_tag() or 'el inicio'}", file=sys.stderr)
        return 0
    if args.cmd == "apply":
        write_pubspec(version, build)
        write_config(version, build)
        write_changelog(version, args.date, commits)
    print("release=true")
    print(f"bump={kind}")
    print(f"version={version}")
    print(f"build={build}")
    print(f"tag=v{version}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
