# Repository Guidelines

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
