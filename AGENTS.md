# Repository Guidelines

## Tool installation policy

Dev tools (CLIs, language runtimes, GitHub-release binaries) are managed by
**mise** via `private_dot_config/mise/config.toml`. mise is the preferred
installation path for any new dev tool.

- Check the mise registry first: `mise registry | grep <tool>`
- If the tool is in the registry, add it to `~/.config/mise/config.toml`
  (source: `private_dot_config/mise/config.toml` in chezmoi). Use `latest`
  unless a specific version is required.
- mise bootstrap + `mise install` is driven by
  `run_onchange_20_install_mise_tools.sh.tmpl` (hash-triggered on
  `mise.toml` changes).
- Only fall back to the shell installer (`dot_local/bin/executable_install_my_tools.sh`)
  for tools that mise cannot manage:
  - System packages that need `apt`/`brew` directly (zsh, unzip, p7zip, sysbench)
  - Tools not in the mise registry (globalping on Linux)
  - Tools with macOS GUI integration logic (tailscale standalone/app-store wrapper)

Do not add new `install_X()` shell functions or `curl | bash` installers for
tools that mise can manage. Use mise instead.

## CLI output style

Setup scripts should use a clean, aligned status format without emojis:

```text
[skip] starship     already installed
[skip] ripgrep      already installed
[ ok ] tools        all processed successfully
[skip] shell        default already zsh
```

Format:

```text
[status] package     message
```

Guidelines:

- Status is short and easy to scan: `ok`, `skip`, `warn`, `fail`, `run`.
- Package or area name is left-aligned for readability.
- Message is concise and starts lowercase where possible.
- Do not use trailing `...`.
- Do not use emojis.

## Terminal-Tests

Die Tastatur-Kette kitty -> tmux -> (ssh) -> Shell ist fragil. Konfigurations-
änderungen an diesen Dateien MÜSSEN die Regressionstests erfüllen (grün):

- `private_dot_config/kitty/kitty.conf`
- `private_dot_config/tmux/tmux.conf`
- `~/.ssh/config` (insb. der `s1.local`-Block)
- `private_dot_config/terminal-tests/` selbst (bei Test-Anpassungen)

Ausführen:

```bash
bats ~/.config/terminal-tests/keybindings.bats
# bei langsamer SSH-Verbindung mehr Puffer geben:
SETTLE=1.5 bats ~/.config/terminal-tests/keybindings.bats
```

Zwei Ebenen (Details in `private_dot_config/terminal-tests/README.md`):

- **Tier A** (statische Config-Verträge) MUSS immer grün sein — kein Laufzeit-
  ambiente nötig.
- **Tier B** (Live-Verhalten) wird sauber übersprungen, wenn kitty/tmux/ssh
  fehlen, außer bei explizit als verbindlich markierten Tests (z. B.
  Escape-in-vi-über-ssh); diese werden ROT, wenn die Umgebung nicht
  erreichbar ist, weil die gefangene Regression sonst still bliebe.

Vorrang-Regel bei rot: der Test hat Vorrang vor der Config. Zwei legitime
Wege zum Grün:

1. Config-Fehler beheben — der Standardfall bei versehentlichen Edits.
2. Bei bewussten Funktionswechseln (z. B. `extended-keys` von `off` auf
   `on`) Test **und** Rationale (README.md) aktualisieren; der Test
   spiegelt dann den neuen Soll-Zustand.

Schlupfloch-Verbot: ein Test darf nie allein gelöscht oder verwässert werden,
um ihn grün zu bekommen. Bei Weg 2 muss die Rationale in README.md die
Entscheidung dokumentieren.
