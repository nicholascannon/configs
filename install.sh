#!/bin/bash
echo "🔄 Installing configs..."

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

if ! command -v terminal-notifier &>/dev/null; then
  brew install terminal-notifier
fi

# Remove drifted targets so this repo stays source of truth.
# (e.g. aicodemetricsd rewrites ~/.claude/settings.json atomically, replacing the symlink with a real file)
rm -f "$HOME/.claude/settings.json"
# omp's config.yml lives inside its runtime dir (~/.omp/agent) next to databases; same drift-repair pattern
rm -f "$HOME/.omp/agent/config.yml"
# omp plugin commands can rewrite the tracked manifest in place, breaking the symlink
rm -f "$HOME/.omp/plugins/package.json"

mkdir -p "$HOME/.pi-lens"

stow --target="$HOME" --verbose --restow \
  claude \
  cursor \
  nvim \
  omp \
  p10k \
  pi \
  tmux \
  vim \
  zed \
  zsh

# omp plugins are declared in the tracked plugins/package.json and materialized by bun
if ! command -v bun &>/dev/null; then
  brew install bun
fi
if [ ! -d "$HOME/.omp/plugins/node_modules" ]; then
  (cd "$HOME/.omp/plugins" && bun install)
fi

ln -sf $(pwd)/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

echo "✅ done"
