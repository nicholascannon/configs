#!/bin/bash
echo "🔄 Installing configs..."
stow --target="$HOME" claude tmux vim zsh
ln -sf $(pwd)/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
echo "✅ done"
