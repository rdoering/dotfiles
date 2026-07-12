# terminal-tests — Regressionstests für die Tastatur-Kette

Absicherung der fragilen Tastenpfade durch **kitty → tmux → (ssh) → Shell**.
Diese Behaviors brechen still bei kitty-/tmux-Upgrades oder versehentlichen
Config-Edits; die Tests machen aus den Kommentaren in `kitty.conf`/`tmux.conf`
ausführbare Zusicherungen.

## Ausführen

```bash
bats ~/.config/terminal-tests/keybindings.bats
# bei langsamer SSH-Verbindung mehr Puffer geben:
SETTLE=1.5 bats ~/.config/terminal-tests/keybindings.bats
```

`bats` wird über `~/.local/bin/install_my_tools.sh` (bzw. `chezmoi apply`)
installiert (`bats-core` via brew, `bats` via apt).

## Zwei Ebenen

| Tier | Was | Voraussetzung | Fängt |
|------|-----|---------------|-------|
| **A** | Statische Config-Verträge: die `map`-Zeilen und tmux/ssh-Settings sind mit den exakten Bytes deklariert | keine | versehentliche Edits, falsche Bytes, gelöschte Zeilen |
| **B** | Live-Verhalten: rohe Bytes durch den echten Stack, sichtbares Ergebnis geprüft | laufendes kitty+tmux, für den ssh-Test `s1.local` erreichbar | Regressionen im Zusammenspiel der Schichten — v. a. der Backspace-/terminfo-Bug |

Tier B wird **sauber übersprungen** (`skip`), wenn die Umgebung fehlt (kein
kitty-Socket, nicht in tmux, Host nicht erreichbar) — die Suite bleibt damit
auch in CI oder auf fremden Rechnern grün.

## Warum diese Aufteilung — die zentrale Einschränkung

`kitty @ send-key` **umgeht die `map`-Regeln**. Empirisch belegt:
`send-key shift+enter` liefert das Default-CR `0x0d`, nicht die gemappten Bytes
`\x1b[13;2u`. kitty bietet keinen Weg, ein Hardware-Key-Event durch die
Mapping-Pipeline zu simulieren.

Folge: Die `map`-Zeilen sind **nicht über Verhalten testbar** — nur statisch
(Tier A). Testbar über Verhalten ist alles ab rohen Bytes abwärts (Tier B), und
genau dort saß der reale Bug: Das Backspace-`0x7f` kam stets an, aber die
Remote-Shell auf `s1.local` konnte die Lösch-Sequenz ohne ihr bekanntes `TERM`
(`tmux-256color` war unbekannt) nicht rendern — es *sah* kaputt aus, obwohl die
Eingabe-Bytes korrekt waren. Ein reiner Input-Byte-Test wäre grün gewesen;
deshalb prüft Tier B den **sichtbaren** Pane-Inhalt via `tmux capture-pane`.

## Nicht abgedeckt (bewusst)

- **Physische Tasten.** Tier B injiziert Bytes per Remote-Control, kein echtes
  GUI-Key-Event. Fokus-Klau (opencode), macOS-F-Tasten-Modus und die volle
  Keyboard-Protokoll-Verhandlung bleiben **manuelle** Checks.
- **Wirkung der CSI-u-Bytes in der App.** Dass `\x1b[13;2u` in Claude Code als
  Newline gilt, ist app-spezifisch und wird nicht automatisiert.
- **Versions-Bindung.** Grün ist nur gegen die aktuell installierten
  kitty-/tmux-Versionen aussagekräftig. Ein *nach* einem Upgrade rot werdender
  Test ist selbst das wertvolle Signal.

## Offener Punkt: SSH-Config

Der Test `A: ssh setzt für s1.local ein bekanntes TERM` prüft
`~/.ssh/config`. Diese Datei ist derzeit **nicht** von chezmoi verwaltet — der
Fix (`SetEnv TERM=xterm-256color` im `Host s1.local`-Block) liegt nur lokal.
Soll er reproduzierbar sein, muss `~/.ssh/config` (oder ein `Include`-Fragment)
unter chezmoi-Verwaltung gebracht werden.

## Dateien

- `keybindings.bats` — die Testfälle (Tier A + Tier B).
- `helpers.bash` — Plumbing: Socket-/Fenster-Auflösung, Byte-Injektion,
  capture-pane-Auslesen, Skip-Guards.
