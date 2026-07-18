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
