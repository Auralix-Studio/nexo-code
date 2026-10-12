#!/usr/bin/env python3
"""Pasos de publicación que antes hacían a mano build_release.ps1,
generate_release_notes.ps1 y update_site.ps1. Lo usa release.yml.

  python3 scripts/release_assets.py sums  DIST
      SHA256SUMS.txt con el hash de cada artefacto de DIST (formato
      `sha256  nombre`, el que lee el actualizador de la app).

  python3 scripts/release_assets.py notes DIST VERSION [--repo OWNER/REPO]
      RELEASE_NOTES.md (notas del CHANGELOG + tabla de descargas con tamaño y
      hash + verificación + instalación) y release-meta.json, como
      generate_release_notes.ps1.

  python3 scripts/release_assets.py site  SITE_DIR VERSION [--date YYYY-MM-DD]
      Agrega la versión a CHANGELOG.md y changelog.html del sitio
      (repo Auralix-Studio/nexo), como update_site.ps1. No duplica si ya está.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import html
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from auto_version import changelog_section  # noqa: E402

# Lo público (notas del release y sitio) no nombra los sistemas internos de
# la universidad: el CHANGELOG del código puede hacerlo, aquí se traduce.
RULES = [
    (r"\bentre SIGMA e (?:la )?Intranet\b", "entre los sistemas de la universidad"),
    (r"\bSIGMA (?:e|y) (?:la )?Intranet\b", "los sistemas de la universidad"),
    (r"\b[Ee]n SIGMA\b", "en el sistema académico"),
    (r"\ba SIGMA\b", "al sistema académico"),
    (r"\bde SIGMA\b", "del sistema académico"),
    (r"\bcon SIGMA\b", "con el sistema académico"),
    (r"(^|[.]\s*|<li>|<strong>|- )SIGMA\b", r"\1El sistema académico"),
    (r"\bSIGMA\b", "el sistema académico"),
    (r"\bde (?:la )?Intranet\b", "del portal web"),
    (r"\ben (?:la )?Intranet\b", "en el portal web"),
    (r"\ba (?:la )?Intranet\b", "al portal web"),
    (r"(^|[.]\s*|<li>|<strong>|- )(?:La )?Intranet\b", r"\1El portal web"),
    (r"\b(?:la )?Intranet\b", "el portal web"),
]
def neutral(t: str) -> str:
    for a, b in RULES:
        t = re.sub(a, b, t, flags=re.M)
    return t


META_FILES = {"SHA256SUMS.txt", "RELEASE_NOTES.md", "release-meta.json"}
# Se compilan pero no se publican (solo pruebas internas).
NOT_PUBLISHED = (".ipa",)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


ORDER = (
    "universal.apk", "arm64.apk", "armv7.apk", "x86_64.apk",
    "setup-x64.exe", "windows-x64.zip", "linux-x64.tar.gz", "macos.zip",
    "ios-unsigned.ipa",
)


def _rank(p: pathlib.Path) -> tuple[int, str]:
    n = p.name.lower()
    for i, key in enumerate(ORDER):
        if n.endswith(key):
            return i, n
    return len(ORDER), n


def artifacts(dist: pathlib.Path) -> list[pathlib.Path]:
    """Artefactos descargables, en el orden en que se muestran (Android y
    Windows primero, como en la página de descargas)."""
    return sorted(
        (p for p in dist.iterdir()
         if p.is_file() and p.name not in META_FILES and not p.name.startswith("SHA256SUMS")
         and not p.name.lower().endswith(NOT_PUBLISHED)),
        key=_rank,
    )


def cmd_sums(dist: pathlib.Path) -> None:
    lines = [f"{sha256(p)}  {p.name}" for p in artifacts(dist)]
    (dist / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii")
    print("\n".join(lines))


def read_sums(dist: pathlib.Path) -> dict[str, str]:
    out: dict[str, str] = {}
    f = dist / "SHA256SUMS.txt"
    if f.exists():
        for line in f.read_text(encoding="ascii").splitlines():
            parts = line.split(None, 1)
            if len(parts) == 2:
                out[parts[1].strip()] = parts[0].strip()
    return out


def describe(name: str) -> str:
    n = name.lower()
    table = [
        ("universal.apk", "Android (recomendado)"),
        ("arm64.apk", "Android ARM64"),
        ("armv7.apk", "Android ARMv7 (equipos antiguos)"),
        ("x86_64.apk", "Android x86_64 (emuladores)"),
        ("setup-x64.exe", "Windows, instalador (recomendado)"),
        ("windows-x64.zip", "Windows, portable"),
        ("linux-x64.tar.gz", "Linux x64"),
        ("macos.zip", "macOS"),
        ("ios-unsigned.ipa", "iOS (sin firmar)"),
    ]
    for key, label in table:
        if n.endswith(key):
            return label
    return ""


def cmd_notes(dist: pathlib.Path, version: str, repo: str) -> None:
    tag = f"v{version}"
    sums = read_sums(dist)
    rows, meta_artifacts = [], []
    for p in artifacts(dist):
        size = p.stat().st_size
        url = f"https://github.com/{repo}/releases/download/{tag}/{p.name}"
        sha = sums.get(p.name)
        label = describe(p.name)
        rows.append(
            f"| [{p.name}]({url}) | {label} | {size / 1048576:.0f} MB | "
            + (f"`{sha[:16]}…`" if sha else "—")
            + " |"
        )
        meta_artifacts.append(
            {"name": p.name, "size": size, "sizeMB": round(size / 1048576), "sha256": sha, "url": url}
        )

    body = [f"# Nexo {version}", "", neutral(changelog_section(version)), ""]
    if rows:
        body += [
            "## Descarga",
            "",
            "| Archivo | Plataforma | Tamaño | SHA-256 |",
            "|---------|------------|--------|---------|",
            *rows,
            "",
        ]
    body += [
        "## Verificación",
        "",
        "Los hashes completos están en `SHA256SUMS.txt`.",
        "",
        "**PowerShell:**",
        "```",
        f"Get-FileHash -Algorithm SHA256 .\\nexo-{tag}-universal.apk",
        "```",
        "**Bash:**",
        "```",
        f"sha256sum nexo-{tag}-universal.apk",
        "```",
        "",
        "## Instalación",
        "",
        "- **Usuarios con versión anterior:** la app detecta esta versión al próximo arranque, "
        "la descarga en segundo plano y avisa cuando está lista para instalar.",
        "- **Instalación limpia en Android:** la primera vez se pide autorizar «fuentes desconocidas» para Nexo.",
        "- **Windows:** ejecutar `nexo-" + tag + "-setup-x64.exe`; no requiere permisos de administrador.",
        "",
    ]
    (dist / "RELEASE_NOTES.md").write_text("\n".join(body), encoding="utf-8")
    meta = {
        "version": version,
        "tag": tag,
        "date": _dt.date.today().isoformat(),
        "artifacts": meta_artifacts,
    }
    (dist / "release-meta.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("\n".join(body))


# ── Sitio ───────────────────────────────────────────────────────────────────

def inline_md_to_html(text: str) -> str:
    out = html.escape(text, quote=False)
    out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', out)
    return out


def section_to_html(version: str, section: str) -> str:
    lines = section.splitlines()
    tagline = ""
    blocks: list[tuple[str, list[str]]] = []
    current: tuple[str, list[str]] | None = None
    for raw in lines:
        line = raw.rstrip()
        if not line.strip():
            continue
        m = re.match(r"^###\s+(.+)$", line)
        if m:
            current = (m.group(1).strip(), [])
            blocks.append(current)
            continue
        m = re.match(r"^\s*[-*]\s+(.+)$", line)
        if m:
            if current is None:
                current = ("", [])
                blocks.append(current)
            current[1].append(m.group(1).strip())
            continue
        if current is None and not tagline:
            tagline = line.strip()
        elif current and current[1]:
            # Continuación de un ítem en varias líneas.
            current[1][-1] += " " + line.strip()
    out = ["    <section data-reveal>", f"      <h2>Versión {html.escape(version)}</h2>"]
    if tagline:
        out.append(f"      <p>{inline_md_to_html(tagline)}</p>")
    for title, items in blocks:
        if not items:
            continue
        out.append("")
        if title:
            out.append(f"      <h3>{inline_md_to_html(title)}</h3>")
        out.append("      <ul>")
        out += [f"        <li>{inline_md_to_html(i)}</li>" for i in items]
        out.append("      </ul>")
    out.append("    </section>")
    return "\n".join(out) + "\n"


def cmd_site(site: pathlib.Path, version: str, date: str) -> bool:
    section = neutral(changelog_section(version))
    changed = False

    html_path = site / "changelog.html"
    if html_path.exists():
        text = html_path.read_text(encoding="utf-8")
        if f"Versión {version}<" not in text:
            anchor = '<div class="split-content">'
            if anchor not in text:
                raise SystemExit("changelog.html no tiene <div class=\"split-content\">")
            text = text.replace(anchor, anchor + "\n\n" + section_to_html(version, section), 1)
            html_path.write_text(text, encoding="utf-8")
            changed = True

    md_path = site / "CHANGELOG.md"
    if md_path.exists():
        text = md_path.read_text(encoding="utf-8")
        if not re.search(rf"^## \[{re.escape(version)}\]", text, re.M):
            entry = f"## [{version}] - {date}\n\n{section}\n\n"
            m = re.search(r"^---\s*$\n+", text, re.M) or re.search(r"^## \[", text, re.M)
            if m:
                pos = m.end() if m.group(0).startswith("---") else m.start()
                text = text[:pos] + entry + text[pos:]
            else:
                text = text.rstrip() + "\n\n" + entry
            md_path.write_text(text, encoding="utf-8")
            changed = True

    print("sitio actualizado" if changed else "el sitio ya tenía esta versión")
    return changed


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("sums")
    s.add_argument("dist", type=pathlib.Path)
    n = sub.add_parser("notes")
    n.add_argument("dist", type=pathlib.Path)
    n.add_argument("version")
    n.add_argument("--repo", default="Auralix-Studio/nexo")
    w = sub.add_parser("site")
    w.add_argument("site", type=pathlib.Path)
    w.add_argument("version")
    w.add_argument("--date", default=_dt.date.today().isoformat())
    a = ap.parse_args(argv)
    if a.cmd == "sums":
        cmd_sums(a.dist)
    elif a.cmd == "notes":
        cmd_notes(a.dist, a.version.lstrip("v"), a.repo)
    else:
        cmd_site(a.site, a.version.lstrip("v"), a.date)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
