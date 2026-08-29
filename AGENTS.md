# Repository Guidelines

## Tool installation policy

Guiding principle: **mise first, Ansible only for what mise categorically
cannot do.**

The stack is a small cascade: chezmoi (dotfiles, entry point) → mise
(language runtimes and CLI tools) → Python (installed by mise) → Ansible
(installed as a `pipx:ansible` mise tool, drives the native OS package
manager for the few things mise can't handle). This replaced Nix Home
Manager (flake + custom derivations + a manually maintained 5-host matrix),
which was too complex for day-to-day maintenance.

Decision tree for any new tool — deliberately just two branches:

1. **Default, always try first:** add it to `private_dot_config/mise/config.toml`.
   - Check `mise registry <tool>` / `mise search <tool>` for a direct entry.
   - If it's not in mise's registry but ships prebuilt GitHub release
     binaries, use the generic `github:owner/repo` backend in the same file —
     **pin an exact version, never `"latest"`**, since `github:` only pins by
     git tag (not a content hash like Nix derivations did; `mise.lock` could
     add hashes but is deliberately not used — this is an accepted, explicit
     trade-off, not a silent one).
   - This covers essentially all CLI tools and language runtimes.

2. **Exception, only for Ansible's fixed scope:** `ansible/playbook.yml`
   handles exactly:
   - Tools mise's registry/github backend cannot install as a standalone
     binary (e.g. `unzip`, `p7zip`, `sysbench` — no suitable GitHub release
     artifact exists for them). `btop` belongs here too: upstream ships
     linux-only binaries (no darwin release artifact at all), so mise can
     only cover Linux; it is installed via the OS package manager on every
     platform for consistency.
   - OS-level integration mise cannot do at all: setting the login shell
     (`zsh` must be a real, `/etc/shells`-registered OS package for `chsh`
     to work — a mise shim doesn't qualify), fonts, daemons.

   This list is intentionally short and should only grow when a tool
   genuinely fails one of the two tests above — not because a tool "feels"
   system-level. Do not add apt/brew entries for anything mise can install.

Only fall back to the shell installer
(`dot_local/bin/executable_install_my_tools.sh`) for tools that are
fundamentally outside both mise and Ansible's reach — specifically macOS
GUI integration logic (tailscale standalone/app-store wrapper:
bundleIdentifier lookup, _MASReceipt sandbox detection, daemon-conflict
avoidance). This is the sole remaining exception, not a general path.

mise itself is bootstrapped by `run_onchange_30_mise_setup.sh.tmpl`
(installs mise if missing, then runs `mise install`; hash-triggered on
`private_dot_config/mise/config.toml`). Ansible is driven by
`run_onchange_40_ansible_playbook.sh.tmpl` (hash-triggered on
`ansible/playbook.yml` and `ansible/requirements.yml`). The playbook lives
in the chezmoi source dir (git-tracked) and is excluded from target
materialization via `.chezmoiignore`; the script references it through
`{{ .chezmoi.sourceDir }}/ansible`.

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
