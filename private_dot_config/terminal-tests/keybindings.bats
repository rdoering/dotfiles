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

@test "A: tmux aktiviert extended-keys als CSI-u (modifizierte Tasten in Apps)" {
  # Gewollter Zustand: extended-keys on + csi-u. Damit reicht tmux der inneren
  # App (auf Anforderung) das CSI-u-Keyboard-Protokoll durch, sodass
  # modifizierte Tasten wie Ctrl/Shift+Pfeile erkannt werden. Shift+Enter als
  # CSI-u funktioniert hiervon UNABHAENGIG via kitty-map (siehe Test oben).
  assert_line "$TMUX_CONF" '^set[[:space:]]+-s[[:space:]]+extended-keys[[:space:]]+on'
  assert_line "$TMUX_CONF" '^set[[:space:]]+-s[[:space:]]+extended-keys-format[[:space:]]+csi-u'
  assert_line "$TMUX_CONF" '^set[[:space:]]+-as[[:space:]]+terminal-features[[:space:]].*xterm\*:extkeys'
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

@test "B: Escape verlaesst Insert-Modus in vi ueber ssh zu s1.local (voller Stack)" {
  # Regressionstest fuer den stillen Bug: in vi auf s1.local liess sich der
  # Insert-Modus nicht verlassen, weil Escape nicht als solches ankam (CSI-u-
  # Codierung durch extended-keys). Der Test injiziert rohe \x1b-Bytes durch
  # den kompletten Stack kitty -> tmux -> ssh -> vi und prueft SICHTBAR, dass
  # vi in den Normalmodus zurueckkehrt: nur dann beendet :q! den Editor und
  # der Shell-Prompt wird wieder sichtbar. Bleibt vi im Insert-Modus, wird
  # ":q!" als Text in den Puffer getippt und der Editor bleibt offen -> FAIL.
  #
  # Verbindlich (ROT, nicht skip): fehlt s1.local, ist der Test wertlos —
  # genau dann schweigt die Regression wieder. Daher require_ssh_host_mandatory
  # statt require_ssh_host.
  require_live
  require_ssh_host_mandatory s1.local
  _new_window viEsc 'ssh s1.local'
  _wait_for viEsc 'robert@s1' 12 || skip "remote prompt did not appear in time"
  # vi mit leerem Puffer starten; auf den Leerzeilen-Marker ~ warten
  # (erscheint bei vi/vim/nvi in der linken Spalte fuer nicht-existente Zeilen)
  prev="$(tmux display-message -p '#{window_id}')"
  tmux select-window -t viEsc
  sleep 0.3
  printf '%b' 'vi\n' | kitty @ --to "$KITTY_SOCK" send-text --match "id:$KITTY_WIN" --stdin
  _wait_for viEsc '^~' 8 || {
    tmux select-window -t "$prev" 2>/dev/null || true
    skip "vi did not open (no ~ marker) in time"
  }
  # i = Insert-Modus, "abc" tippen, ESC (\x1b), :q! beendet vi nur im Normalmodus.
  # WICHTIG: ESC und die Folgetasten MUSS zeitlich getrennt werden (sleep >
  # escape-time). tmux' escape-time (10 ms) fasst \x1b + sofort folgende Bytes
  # als potenzielle Control-Sequenz auf und liefert kein nacktes ESC aus.
  # send-text schreibt den gesamten String in einem Burst — ohne Pause wuerde
  # der Test die Burst-Pathologie messen, nicht die echte Regression. Bei
  # echtem Tippen liegt zwischen ESC und :q! eine menschliche Pause.
  printf '%b' 'iabc' | kitty @ --to "$KITTY_SOCK" send-text --match "id:$KITTY_WIN" --stdin
  sleep 0.1
  printf '%b' '\x1b' | kitty @ --to "$KITTY_SOCK" send-text --match "id:$KITTY_WIN" --stdin
  # > escape-time (10 ms): 50 ms reichen, echtes Tippen simuliert groesszuegiger
  sleep 0.05
  printf '%b' ':q!\n' | kitty @ --to "$KITTY_SOCK" send-text --match "id:$KITTY_WIN" --stdin
  sleep "$SETTLE"
  local pane
  pane="$(tmux capture-pane -t viEsc -p)"
  tmux select-window -t "$prev" 2>/dev/null || true
  # Erwartung: vi wurde verlassen, Shell-Prompt wieder sichtbar
  printf '%s' "$pane" | grep -Eq 'robert@s1' \
    || { printf 'visible pane:\n%s\n' "$pane" >&2; false; }
}
