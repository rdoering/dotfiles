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
| **B** | Live-Verhalten: rohe Bytes durch den echten Stack, sichtbares Ergebnis geprüft | laufendes kitty+tmux, für den ssh-Test `s1.local` erreichbar | Regressionen im Zusammenspiel der Schichten — v. a. der Backspace-/terminfo-Bug und die Escape-Codierung bei `extended-keys on` |

Tier B wird **sauber übersprungen** (`skip`), wenn die Umgebung fehlt (kein
kitty-Socket, nicht in tmux, Host nicht erreichbar) — die Suite bleibt damit
auch in CI oder auf fremden Rechnern grün. **Ausnahme:** verbindliche Tier-B-
Tests (s. unten) werden ROT, wenn ihr Host fehlt.

### Verbindliche Tier-B-Tests

`B: Escape verlässt Insert-Modus in vi über ssh zu s1.local` ist verbindlich:
ist `s1.local` nicht erreichbar, wird er ROT (nicht skip). Begründung: die
Escape-Regression war still — sie zeigte sich nur im Live-Verhalten auf dem
Remote-Host. Würde der Test bei fehlendem Host skippen, bliebe die Regression
genau dann unbeachtet, wenn sie ohnehin nicht auffällt. Ein fehlender Host
macht den Test wertlos, daher muss er bewusst failen.

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

## extended-keys und CSI-u

`tmux.conf` aktiviert bewusst:

```text
set -s extended-keys on
set -s extended-keys-format csi-u
set -as terminal-features 'xterm*:extkeys'
```

Damit reicht tmux der inneren App (auf Anforderung) das CSI-u-Keyboard-Protokoll
durch, sodass **modifizierte Tasten** wie Ctrl/Shift+Pfeile in Anwendungen
(vim, nvim, Claude Code) erkannt werden.

Wichtig: **Shift+Enter als CSI-u funktioniert hiervon unabhängig** — die Bytes
`\x1b[13;2u` werden per `map shift+enter send_text all` in kitty roh injiziert
und via `allow-passthrough on` durch tmux gereicht. `extended-keys` wird also
nicht für Shift+Enter gebraucht, sondern nur für die modifizierten Tasten in
Apps, die das Protokoll aktiv anfordern.

Risiko: mit `extended-keys on` codiert tmux die Escape-Taste als `\x1b[27;1u`,
sobald die innere App CSI-u aktiviert hat. Plain `vi`/älteres vim kann das
nicht dekodieren → Insert-Modus lässt sich nicht verlassen. Genau diese
Regression fängt der verbindliche Test `B: Escape ... vi über ssh` ab.

## OSC-Theming (Tag/Nacht-Wechsel)

`set -g allow-passthrough on` in `tmux.conf` reicht OSC-Sequenzen (OSC 11
Hintergrundfarbe, OSC 12 Cursorfarbe) von Remote-Apps durch tmux an das äußere
kitty weiter. Damit kann der macOS Light/Dark-Wechsel (kitty-Theme-Dateien)
auch Remote-Anwendungen signalisiert werden, die ihn abonnieren (z. B. nvim
auto-dark-mode / theme-loader).

`set -g focus-events on` (in `tmux.conf`) sorgt zusätzlich dafür, dass nvim
Focus-Gained/Lost-Events erhält (für autoread etc.).

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
  capture-pane-Auslesen, Skip-Guards (sowie `require_ssh_host_mandatory`
  für verbindliche Tier-B-Tests).
