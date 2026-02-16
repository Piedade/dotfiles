if command -v wl-copy &>/dev/null; then
    alias pbcopy='wl-copy'
elif command -v xclip &>/dev/null; then
    alias pbcopy='xclip -selection clipboard'
fi
