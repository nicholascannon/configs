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

# superpowers skills for omp via its plugin manager (needs bun)
if ! command -v bun &>/dev/null; then
  brew install bun
fi
if ! omp plugin list 2>/dev/null | grep -q superpowers; then
  omp plugin install git:github.com/obra/superpowers
fi

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

ln -sf $(pwd)/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

echo "✅ done"
