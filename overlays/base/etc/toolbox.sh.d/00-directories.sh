for localdir in home bin libexec share/nvim-config share/xdg-terminal-exec; do
    src="/run/host/usr/local/$localdir"
    dest="/usr/local/$localdir"
    if [ -e "$src" ]; then
        if [ -e "$dest" ]; then
            if sudo rmdir "$dest" 2>/dev/null; then
                sudo ln -s "$src" "$dest"
            fi
        else
            sudo ln -s "$src" "$dest"
        fi
    fi
done
