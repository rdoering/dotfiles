#!/usr/bin/env bats
#
# keybindings.bats — Regressionstests für die kitty/tmux/ssh-Tastatur-Kette.
#
# Ausführen:   bats keybindings.bats
# Verbose:     bats --verbose-run keybindings.bats
# Langsamer Link:  SETTLE=1.5 bats keybindings.bats
#
# Zwei Ebenen (Details in README.md und helpers.bash):
#   Tier A  statische Vertrags-Tests der Config-Deklarationen (laufen überall).
#   Tier B  Live-Verhaltenstests durch den echten Stack; werden sauber
#           übersprungen, wenn kitty/tmux/ssh-Voraussetzungen fehlen.

load helpers.bash

setup() {
  CREATED_WINDOWS=()
}

teardown() {
  kill_created_windows
}

# ===========================================================================
# Tier A — Config-Verträge (statisch, keine Laufzeitumgebung nötig)
#
# `kitty @ send-key` umgeht die `map`-Regeln, daher lassen sich diese Mappings
# nur über ihre Deklaration absichern. Jeder Test fixiert Taste + erzeugte
# Bytes, damit ein versehentliches Edit (falsche Bytes, gelöschte Zeile) sofort
# auffällt. Das führende `.` in den Regexes matcht den Backslash von `\x..`.
# ===========================================================================

@test "A: kitty mappt Shift+Enter auf CSI-u 13;2u (Newline in Claude Code)" {
  assert_line "$KITTY_CONF" 'map[[:space:]]+shift\+enter[[:space:]]+send_text[[:space:]]+all[[:space:]]+.x1b\[13;2u'
}

@test "A: kitty mappt Cmd+Left auf Home (\x1b[H)" {
  assert_line "$KITTY_CONF" 'map[[:space:]]+cmd\+left[[:space:]]+send_text[[:space:]]+all[[:space:]]+.x1b\[H'
}

@test "A: kitty mappt Cmd+Right auf End (\x1b[F)" {
  assert_line "$KITTY_CONF" 'map[[:space:]]+cmd\+right[[:space:]]+send_text[[:space:]]+all[[:space:]]+.x1b\[F'
}

@test "A: kitty mappt Cmd+T auf tmux new-window (Ctrl-B c = \x02c)" {
  assert_line "$KITTY_CONF" 'map[[:space:]]+cmd\+t[[:space:]]+send_text[[:space:]]+all[[:space:]]+.x02c'
}

@test "A: kitty hat Remote-Control aktiv (Voraussetzung für Tier B)" {
  assert_line "$KITTY_CONF" '^allow_remote_control[[:space:]]+yes'
}

@test "A: tmux hat extended-keys=off (sonst CSI-u-Bytes, die tmux verschluckt)" {
  assert_line "$TMUX_CONF" '^set[[:space:]]+-s[[:space:]]+extended-keys[[:space:]]+off'
}

@test "A: tmux erlaubt Passthrough (OSC an das aeussere kitty)" {
  assert_line "$TMUX_CONF" '^set[[:space:]]+-g[[:space:]]+allow-passthrough[[:space:]]+on'
}

@test "A: ssh setzt fuer s1.local ein bekanntes TERM (Backspace-Echo-Fix)" {
  # Nur relevant, wo s1.local überhaupt konfiguriert ist. Ohne diesen Host
  # ist der Test bedeutungslos und wird übersprungen.
  grep -Eq '^Host[[:space:]].*\bs1\.local\b' "$SSH_CONF" 2>/dev/null \
    || skip "no s1.local host in $SSH_CONF"
  assert_line "$SSH_CONF" '^[[:space:]]*SetEnv[[:space:]]+TERM=xterm-256color'
}

# ===========================================================================
# Tier B — End-to-End-Verhalten (live)
#
# Rohe Bytes werden per kitty-Remote-Control durch den echten Stack geschossen
# und das SICHTBARE Ergebnis geprüft. Das ist die einzige Ebene, die den
# tatsächlichen Backspace-Bug fängt: das 0x7f kam immer an, aber die Remote-
# Shell konnte die Lösch-Sequenz ohne passendes TERM nicht rendern.
# ===========================================================================

@test "B: Backspace (0x7f) loescht lokal in kanonischem Modus (kitty->tmux->tty)" {
  require_live
  # `cat` erbt den cooked+echo-Modus des tty; die Line-Discipline verarbeitet
  # 0x7f als erase. Prompt-unabhängig, daher robust.
  _new_window bsL 'cat'
  sleep 0.5
  run type_and_read bsL 'abc\x7f'
  # sichtbar muss "ab" stehen, nicht "abc"
  [[ "$output" == *ab && "$output" != *abc ]] || {
    printf 'visible line: [%s]\n' "$output" >&2
    false
  }
}

@test "B: Backspace-Echo ist ueber ssh zu s1.local sichtbar (voller Stack)" {
  require_live
  require_ssh_host s1.local
  _new_window bsS 'ssh s1.local'
  _wait_for bsS 'robert@s1' 12 || skip "remote prompt did not appear in time"
  run type_and_read bsS 'abc\x7f'
  [[ "$output" == *ab && "$output" != *abc ]] || {
    printf 'visible line: [%s]\n' "$output" >&2
    false
  }
}
