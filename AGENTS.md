# Repository Guidelines

## Tool installation policy

Guiding principle: **one declarative package manager for everything.**
All tools — dev CLIs, language runtimes, system utilities, GitHub-release
binaries — are managed by **Nix Home Manager** via the flake in
`home-manager/` (source: `home-manager/home.nix`). The flake is the single
source of truth for the user environment; `flake.lock` is committed for
reproducibility.

Decision tree for any new tool:

1. Is the tool in nixpkgs? → add it to `home.packages` in `home.nix`.
   Check with `nix run nixpkgs#nix-search -- <tool>` or
   https://search.nixos.org/packages (channel: unstable).

2. Not in nixpkgs, but a fetchable release artifact (tarball/binary)?
   → write a small derivation under `home-manager/` and register it as an
   overlay in `flake.nix` (see `globalping.nix` as the reference pattern).
   This mirrors the old `curl | tar | install` shell logic in a
   reproducible, hash-pinned form.

3. Only fall back to the shell installer
   (`dot_local/bin/executable_install_my_tools.sh`) for tools that are
   fundamentally outside Nix's reach — specifically macOS GUI integration
   logic that Nix cannot model (tailscale standalone/app-store wrapper:
   bundleIdentifier lookup, _MASReceipt sandbox detection, daemon-conflict
   avoidance). This is the sole remaining exception, not a general path.

Do NOT add new `install_X()` shell functions, `curl | bash` installers, or
brew/apt calls for any tool that Nix can manage (steps 1 or 2). Homebrew is
kept only as a minimized fallback for Casks/GUI apps; it is not a primary
installation path.

Nix itself is bootstrapped by `run_onchange_30_install_nix_bootstrap.sh.tmpl`
(Determinate Systems installer, idempotent). Home Manager is driven by
`run_onchange_40_home_manager_switch.sh.tmpl` (hash-triggered on `flake.nix`,
`home.nix`, and `flake.lock` changes). The flake lives in the chezmoi source
dir (git-tracked, `flake.lock` committed) and is excluded from target
materialization via `.chezmoiignore`; the switch script references it through
`{{ .chezmoi.sourceDir }}/home-manager#robert`.

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
