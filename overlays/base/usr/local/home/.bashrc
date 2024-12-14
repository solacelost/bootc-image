if [[ $PATH != *"$HOME/bin"* ]]; then
	PATH="$HOME/bin:$PATH"
fi
if [[ $PATH != *"$HOME/.local/bin"* ]]; then
	PATH="$HOME/.local/bin:$PATH"
fi
if [[ $PATH != *"$HOME/.cargo/bin"* ]]; then
	PATH="$HOME/.cargo/bin:$PATH"
fi
if [[ $PATH != *"$HOME/go/bin"* ]]; then
	PATH="$HOME/go/bin:$PATH"
fi
if [[ $PATH != *"$HOME/.krew/bin"* ]]; then
	PATH="$HOME/.krew/bin:$PATH"
fi
export PATH

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

if [ -n "${_do_tmux}" ]; then
	if tmux_worthy; then
		tmux -2 new-session -A -s "$(hostname -s)"
	fi

	if [ -z "$TMUX" ] && [ -n "$SSH_CLIENT" ]; then
		tmux new-session -A -s ssh
	fi
fi
