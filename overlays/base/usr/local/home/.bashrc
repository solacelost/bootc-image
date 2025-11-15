include_path=(
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "$HOME/.krew/bin"
)
for newpath in "${include_path[@]}"; do
    if [[ $PATH != *"$newpath"* ]]; then
	    PATH="$PATH:$newpath"
    fi
done
export PATH
unset newpath include_path

case $- in
*i*) ;;
*) return ;;
esac

function tmux_worthy() {
	[ "$(tty)" = "/dev/tty1" ] && return 1      # no tmux default on TTY1
	command -v tmux &>/dev/null || return 1     # we have no tmux
	[ -z "$TMUX" ] || return 1                  # we are in tmux already
	[ -z "$SSH_CLIENT" ] || return 1            # we need an ssh session
	[ "${EUID:--1}" -ne 0 ] || return 1         # we are root
	[ "$TERM_PROGRAM" != "vscode" ] || return 1 # we are in VSCode
	[ -z "$SWAYSOCK" ] || return 1              # we are in sway (tiling)
	[ -z "$NIRI_SOCKET" ] || return 1           # we are in niri (tiling)
	[ -f /run/.toolboxenv ] && return 1         # we are in a toolbox
	return 0
}

_do_tmux=true

# Shared aliases and functions
for rc in /usr/local/home/.bashrc.d/*; do
	if [ -f "$rc" ]; then
		. "$rc"
	fi
done

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
	for rc in ~/.bashrc.d/*; do
		if [ -f "$rc" ]; then
			. "$rc"
		fi
	done
fi
unset rc

if [ -n "${_do_tmux}" ] && "${_do_tmux}"; then
	if tmux_worthy; then
		tmux -2 new-session -A -s "$(hostname -s)"
	fi

	if [ -z "$TMUX" ] && [ -n "$SSH_CLIENT" ]; then # spin up a specific session for SSH
		tmux new-session -A -s ssh
	fi
fi
