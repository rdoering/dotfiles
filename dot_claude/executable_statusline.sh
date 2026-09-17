#!/usr/bin/env bash
# Claude Code Statuszeile — Modell, Verzeichnis/Repo, Nutzungsperiode, Sitzungskosten.
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "unbekannt"')
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')
repo=$(printf '%s' "$input" | jq -r '.workspace.repo // empty')
dir_base=$(basename "$dir" 2>/dev/null)

# Letzte zwei Pfadsegmente für etwas mehr Kontext als nur den Leaf-Ordner.
dir_short=$(printf '%s' "$dir" | awk -F/ '{ if (NF>2) print $(NF-1)"/"$NF; else print $0 }')

if [ -n "$repo" ] && [ "$repo" != "$dir_base" ]; then
  location="$repo ($dir_short)"
else
  location="$dir_short"
fi
[ -z "$location" ] && location="$dir_base"

fmt_reset() {
  # $1 = Unix-Epoch-Sekunden -> " (reset in Xh)" / " (reset in Xd)"
  local resets_at="$1"
  [ -z "$resets_at" ] && return
  local now diff
  now=$(printf '%(%s)T' -1 2>/dev/null || date +%s)
  diff=$((resets_at - now))
  [ "$diff" -le 0 ] && return
  if [ "$diff" -ge 86400 ]; then
    printf ' (reset in %dd)' "$((diff / 86400))"
  else
    printf ' (reset in %dh)' "$((diff / 3600 + 1))"
  fi
}

five_hour=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
spend_limit=$(printf '%s' "$input" | jq -r '.rate_limits.spend_limit.used_percentage // empty')
session_cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')

# Reset-Hinweis nur an das relevanteste Fenster anhängen: Spend-Limit > 7 Tage > 5 Stunden.
if [ -n "$spend_limit" ]; then
  spend_reset=$(fmt_reset "$(printf '%s' "$input" | jq -r '.rate_limits.spend_limit.resets_at // empty')")
elif [ -n "$seven_day" ]; then
  seven_day_reset=$(fmt_reset "$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')")
elif [ -n "$five_hour" ]; then
  five_hour_reset=$(fmt_reset "$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')")
fi

usage_parts=()
[ -n "$five_hour" ] && usage_parts+=("$(printf '5h: %.0f%%%s' "$five_hour" "$five_hour_reset")")
[ -n "$seven_day" ] && usage_parts+=("$(printf '7d: %.0f%%%s' "$seven_day" "$seven_day_reset")")
[ -n "$spend_limit" ] && usage_parts+=("$(printf 'Budget: %.0f%%%s' "$spend_limit" "$spend_reset")")

printf '%s' "$model"
[ -n "$location" ] && printf ' | %s' "$location"
if [ "${#usage_parts[@]}" -gt 0 ]; then
  joined="${usage_parts[0]}"
  for part in "${usage_parts[@]:1}"; do
    joined="$joined · $part"
  done
  printf ' | %s' "$joined"
fi
[ -n "$session_cost" ] && printf ' | Session: $%.2f' "$session_cost"
