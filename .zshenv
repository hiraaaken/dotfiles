[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PATH="$HOME/dev/flutter/bin:$PATH"

# mise (non-interactive shells only source .zshenv, not .zshrc)
export PATH="$HOME/.local/share/mise/shims:$PATH"

# Vite+ bin (https://viteplus.dev)
[ -f "$HOME/.config/vite-plus/env" ] && . "$HOME/.config/vite-plus/env"
