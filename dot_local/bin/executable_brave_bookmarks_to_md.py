#!/usr/bin/env python3
"""
Exportiert Brave-Bookmarks (Chromium-Bookmarks-JSON) in eine Markdown-Datei.

Nutzung:
    python3 brave_bookmarks_to_md.py [Pfad-zur-Bookmarks-Datei] Ausgabedatei.md

Die Ausgabedatei muss angegeben werden. Wird nur ein Argument übergeben,
gilt es als Ausgabedatei und das Skript sucht die Bookmarks-Datei
automatisch am Standardpfad deines Betriebssystems.
"""

import json
import sys
import os
import platform
from pathlib import Path


def is_wsl() -> bool:
    """Erkennt, ob das Skript innerhalb von WSL läuft."""
    try:
        with open("/proc/version", "r") as f:
            return "microsoft" in f.read().lower()
    except FileNotFoundError:
        return False


def find_default_bookmarks_path() -> Path | None:
    system = platform.system()
    home = Path.home()

    candidates = []

    if is_wsl():
        # Brave läuft unter Windows, nicht in der WSL-Umgebung selbst.
        # Windows-Nutzerverzeichnisse liegen unter /mnt/c/Users/<Name>/...
        users_dir = Path("/mnt/c/Users")
        if users_dir.exists():
            for user_dir in users_dir.iterdir():
                candidate = (
                    user_dir
                    / "AppData/Local/BraveSoftware/Brave-Browser/User Data/Default/Bookmarks"
                )
                try:
                    if candidate.exists():
                        candidates.append(candidate)
                except OSError:
                    # Systemprofile wie "defaultuser0" sind aus WSL nicht lesbar.
                    continue
    elif system == "Linux":
        candidates.append(home / ".config/BraveSoftware/Brave-Browser/Default/Bookmarks")
    elif system == "Darwin":  # macOS
        candidates.append(home / "Library/Application Support/BraveSoftware/Brave-Browser/Default/Bookmarks")
    elif system == "Windows":
        local_appdata = os.environ.get("LOCALAPPDATA", "")
        if local_appdata:
            candidates.append(Path(local_appdata) / "BraveSoftware/Brave-Browser/User Data/Default/Bookmarks")

    for c in candidates:
        if c.exists():
            return c
    return None


def node_to_markdown(node: dict, depth: int, lines: list[str]) -> None:
    """Rekursiv durch Ordner/Bookmarks laufen und Markdown-Zeilen erzeugen."""
    node_type = node.get("type")

    if node_type == "folder":
        name = node.get("name", "Unbenannter Ordner")
        # Root-Container ("Lesezeichenleiste", "Andere Lesezeichen", ...) als H1,
        # tiefere Ordner als entsprechend kleinere Überschriften (max H6).
        level = min(depth + 1, 6)
        lines.append(f"\n{'#' * level} {name}\n")
        for child in node.get("children", []):
            node_to_markdown(child, depth + 1, lines)

    elif node_type == "url":
        name = node.get("name", "Ohne Titel")
        url = node.get("url", "")
        lines.append(f"- [{name}]({url})")


def convert(bookmarks_path: Path, output_path: Path) -> None:
    with open(bookmarks_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    roots = data.get("roots", {})
    lines: list[str] = ["#Top #Organizational/Quentic"]

    # Reihenfolge: Lesezeichenleiste, Andere Lesezeichen, Synchronisierte Lesezeichen
    for key in ("bookmark_bar", "other", "synced"):
        root = roots.get(key)
        if root:
            node_to_markdown(root, depth=0, lines=lines)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines).strip() + "\n")

    print(f"Fertig: {output_path} ({sum(1 for l in lines if l.startswith('- ['))} Bookmarks exportiert)")


def main():
    args = sys.argv[1:]

    if len(args) == 0 or len(args) > 2:
        print("Nutzung:")
        print("  python3 brave_bookmarks_to_md.py [Pfad-zur-Bookmarks-Datei] Ausgabedatei.md")
        print("Die Ausgabedatei muss angegeben werden.")
        sys.exit(1)

    if len(args) == 2:
        bookmarks_path = Path(args[0]).expanduser()
        output_path = Path(args[1]).expanduser()
    else:
        output_path = Path(args[0]).expanduser()
        found = find_default_bookmarks_path()
        if not found:
            print("Konnte die Bookmarks-Datei nicht automatisch finden.")
            print("Bitte Pfad manuell angeben, z.B.:")
            print("  python3 brave_bookmarks_to_md.py /pfad/zur/Bookmarks bookmarks.md")
            sys.exit(1)
        bookmarks_path = found

    if not bookmarks_path.exists():
        print(f"Datei nicht gefunden: {bookmarks_path}")
        sys.exit(1)

    convert(bookmarks_path, output_path)


if __name__ == "__main__":
    main()
