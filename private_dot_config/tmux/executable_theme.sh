#!/bin/sh
# Light/dark theme handling for tmux. Single source of truth for the status
# bar colors; used by the theme hooks, the prefix+T toggle, and the watcher.
#
# Usage: theme.sh apply <light|dark> | toggle | watch

apply() {
	case "$1" in
	light)
		tmux set -g @theme light \; \
			set -g status-style 'fg=#665c54' \; \
			set -g window-status-style 'fg=#a89984' \; \
			set -g window-status-current-style 'fg=#3c3836,bold'
		;;
	dark)
		tmux set -g @theme dark \; \
			set -g status-style 'fg=#a89984' \; \
			set -g window-status-style 'fg=#7c6f57' \; \
			set -g window-status-current-style 'fg=#e8bf6a,bold'
		;;
	esac
}

case "$1" in
apply)
	apply "$2"
	;;
toggle)
	if [ "$(tmux show -gv @theme 2>/dev/null)" = dark ]; then
		apply light
	else
		apply dark
	fi
	;;
watch)
	# Dynamic detection: tmux itself only learns the terminal theme at
	# attach (and Windows Terminal does not push mode-2031 updates), so
	# on WSL poll the Windows registry for the OS app theme instead.
	# On hosts without WSL interop (remote servers, macOS) do nothing;
	# prefix+T stays as the manual toggle there.
	command -v reg.exe >/dev/null 2>&1 || exit 0
	exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-theme-watch-$(id -u).lock" || exit 0
	flock -n 9 || exit 0 # already one watcher per user
	while :; do
		v=$(reg.exe query 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' \
			/v AppsUseLightTheme 2>/dev/null | tr -d '\r' | awk '/AppsUseLightTheme/{print $3}')
		case "$v" in
		0x1) want=light ;;
		0x0) want=dark ;;
		*) want= ;;
		esac
		cur=$(tmux show -gv @theme 2>/dev/null) || exit 0 # server gone
		[ -n "$want" ] && [ "$want" != "$cur" ] && apply "$want"
		sleep 3
	done
	;;
esac
