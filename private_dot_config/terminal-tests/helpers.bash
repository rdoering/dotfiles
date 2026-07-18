# shellcheck shell=bash
#
# helpers.bash — Plumbing für die BATS-Tests der kitty/tmux/ssh-Tastatur-Kette.
#
# Die Tests zerfallen in zwei Ebenen (siehe README.md):
#
#   Tier A  Vertrags-Tests (statisch). Prüfen, dass die Config-Dateien die
#           bekannten Fixes DEKLARIEREN. Kein laufendes Terminal nötig.
#
#   Tier B  Verhaltens-Tests (live). Schießen echte Bytes per kitty-Remote-
#           Control durch den kompletten Stack kitty -> tmux -> (ssh) -> Shell
#           und prüfen das SICHTBARE Ergebnis via `tmux capture-pane`.
#
# Warum diese Trennung? `kitty @ send-key` UMGEHT die `map`-Regeln (empirisch
# belegt: `send-key shift+enter` liefert das Default-CR 0x0d, nicht die
# gemappten Bytes \x1b[13;2u). kitty bietet keinen Weg, ein Hardware-Key-Event
# durch die Mapping-Pipeline zu simulieren. Deshalb lassen sich die `map`-Zeilen
# NICHT über Verhalten testen — nur statisch (Tier A). Testbar über Verhalten
# ist dagegen alles, was von rohen Bytes abwärts passiert (Tier B) — und genau
# dort saß der Backspace-Bug (Remote-terminfo), den wir absichern wollen.

# Pfade zu den zu prüfenden Config-Dateien. Überschreibbar per Env, damit man
# die Tests auch gegen den chezmoi-Source statt gegen $HOME laufen lassen kann.
: "${KITTY_CONF:=$HOME/.config/kitty/kitty.conf}"
: "${TMUX_CONF:=$HOME/.config/tmux/tmux.conf}"
: "${SSH_CONF:=$HOME/.ssh/config}"

# Wartezeit, bis sich der Bildschirm nach einer Eingabe beruhigt hat. Bei
# langsamen Verbindungen hochsetzen: `SETTLE=1.5 bats keybindings.bats`.
: "${SETTLE:=0.9}"

# ---------------------------------------------------------------------------
# Tier-A-Assertions (rein textuell)
# ---------------------------------------------------------------------------

# assert_eq ACTUAL EXPECTED — String-Gleichheit mit lesbarer Fehlermeldung.
assert_eq() {
  if [ "$1" != "$2" ]; then
    printf 'expected: [%s]\n' "$2" >&2
    printf 'actual:   [%s]\n' "$1" >&2
    return 1
  fi
}

# assert_line FILE ERE — mindestens eine Zeile in FILE matcht die Regex ERE.
assert_line() {
  local file="$1" ere="$2"
  if [ ! -r "$file" ]; then
    printf 'file not readable: %s\n' "$file" >&2
    return 1
  fi
  if ! grep -Eq -- "$ere" "$file"; then
    printf 'no line matching /%s/ in %s\n' "$ere" "$file" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Tier-B-Plumbing: kitty-Remote-Control finden und ansteuern
# ---------------------------------------------------------------------------

# _kitty_socket — gibt das erste ANTWORTENDE Remote-Control-Socket als
# `unix:/pfad` aus. $KITTY_LISTEN_ON kann durch die tmux-Server-Umgebung
# veraltet sein (zeigt auf eine tote kitty-PID), daher wird jeder Kandidat
# real gegen `kitty @ ls` geprobt statt blind übernommen.
_kitty_socket() {
  local cands=() c
  [ -n "${KITTY_LISTEN_ON:-}" ] && cands+=("${KITTY_LISTEN_ON#unix:}")
  for c in /tmp/kitty.sock-* /tmp/kitty.sock; do
    [ -S "$c" ] && cands+=("$c")
  done
  for c in "${cands[@]}"; do
    if kitty @ --to "unix:$c" ls >/dev/null 2>&1; then
      printf 'unix:%s' "$c"
      return 0
    fi
  done
  return 1
}

# _kitty_window_id SOCKET — id des Ziel-kitty-Fensters. Bevorzugt das
# fokussierte Fenster; sonst das erste (Ein-Fenster-Setup, der Normalfall).
# Ans Fenster gepinnt (statt "an das gerade fokussierte" zu senden), damit ein
# Fokuswechsel während des Tests die Eingabe nicht umleitet.
_kitty_window_id() {
  kitty @ --to "$1" ls 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
ws = [w for osw in d for t in osw["tabs"] for w in t["windows"]]
foc = [w for w in ws if w.get("is_focused")]
pick = foc or ws
print(pick[0]["id"] if pick else "")
'
}

# require_live — Skip-Guard für Tier B. Setzt bei Erfolg die Globals
# KITTY_SOCK und KITTY_WIN; ruft sonst `skip` mit klarem Grund auf.
require_live() {
  command -v kitty  >/dev/null 2>&1 || skip "kitty binary not found"
  command -v tmux   >/dev/null 2>&1 || skip "tmux not found"
  command -v python3 >/dev/null 2>&1 || skip "python3 not found (socket parsing)"
  [ -n "${TMUX:-}" ] || skip "not running inside tmux"
  KITTY_SOCK="$(_kitty_socket)" || skip "no responsive kitty remote-control socket"
  KITTY_WIN="$(_kitty_window_id "$KITTY_SOCK")"
  [ -n "$KITTY_WIN" ] || skip "could not resolve target kitty window id"
}

# require_ssh_host HOST — Skip, wenn HOST nicht schlüsselbasiert erreichbar ist
# (BatchMode verhindert Passwort-Prompts, die den Test aufhängen würde).
require_ssh_host() {
  ssh -o BatchMode=yes -o ConnectTimeout=4 "$1" true >/dev/null 2>&1 \
    || skip "ssh host '$1' not reachable non-interactively"
}

# require_ssh_host_mandatory HOST — wie require_ssh_host, aber ROT statt skip.
# Für Tests, deren Regression still bliebe, wenn der Host einfach fehlt (z. B.
# Escape-in-vi: das ist genau der Bug, der nur über das Live-Verhalten auf
# s1.local fassbar ist). Ein fehlender Host macht den Test wertlos, daher muss
# er bewusst failen, nicht übersprungen werden.
require_ssh_host_mandatory() {
  ssh -o BatchMode=yes -o ConnectTimeout=4 "$1" true >/dev/null 2>&1 \
    || { echo "mandatory ssh host '$1' not reachable non-interactively" >&3; \
         false; }
}

# ---------------------------------------------------------------------------
# Tier-B-Plumbing: tmux-Fenster erzeugen, füttern, auslesen
# ---------------------------------------------------------------------------

# _new_window NAME CMD — erzeugt ein detached tmux-Fenster und merkt sich seinen
# Namen in CREATED_WINDOWS zum Aufräumen im teardown.
_new_window() {
  local name="$1" cmd="$2"
  tmux new-window -d -n "$name" "$cmd"
  CREATED_WINDOWS+=("$name")
}

# _wait_for WINDOW ERE [TIMEOUT_S] — pollt capture-pane, bis eine Zeile ERE
# matcht (z. B. der Shell-Prompt). Verhindert Race-Conditions gegenüber festen
# Sleeps beim Aufbau einer (ssh-)Verbindung.
_wait_for() {
  local win="$1" ere="$2" timeout="${3:-8}"
  local deadline=$((SECONDS + timeout))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if tmux capture-pane -t "$win" -p 2>/dev/null | grep -Eq -- "$ere"; then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

# type_and_read WINDOW PRINTF_BYTES — der Kern von Tier B:
#   1. das Ziel-tmux-Fenster aktiv schalten (deterministisch, kein GUI-Fokus),
#   2. rohe Bytes via kitty-Remote-Control an das gepinnte kitty-Fenster senden
#      (send-text --stdin ist byte-genau und map-UNABHÄNGIG),
#   3. kurz warten, dann die letzte nicht-leere sichtbare Zeile zurückgeben,
#   4. das vorherige Fenster wiederherstellen.
# PRINTF_BYTES wird von printf interpretiert, z. B. 'abc\x7f' für a b c <DEL>.
type_and_read() {
  local win="$1" bytes="$2" prev
  prev="$(tmux display-message -p '#{window_id}')"
  tmux select-window -t "$win"
  sleep 0.3
  printf '%b' "$bytes" | kitty @ --to "$KITTY_SOCK" send-text --match "id:$KITTY_WIN" --stdin
  sleep "$SETTLE"
  local out
  out="$(tmux capture-pane -t "$win" -p | grep -v '^$' | tail -1)"
  tmux select-window -t "$prev" 2>/dev/null || true
  printf '%s' "$out"
}

# teardown-Hilfe: alle in diesem Test erzeugten Fenster schließen.
kill_created_windows() {
  local w
  for w in "${CREATED_WINDOWS[@]:-}"; do
    [ -n "$w" ] && tmux kill-window -t "$w" 2>/dev/null || true
  done
  CREATED_WINDOWS=()
}
