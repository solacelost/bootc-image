# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

# Start Sway on TTY1
if [ "$(tty)" = "/dev/tty1" ]; then
	export QT_QPA_PLATFORM=wayland
	export MOZ_ENABLE_WAYLAND=1
	export MOZ_WEBRENDER=1
	exec sway
fi
