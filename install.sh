#!/bin/bash
# Idempotent: safe to re-run on every machine whenever configs change.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Packages under packages/ that get symlinked into $HOME. ghostty lives outside
# $HOME and is linked separately; vim is legacy (see scripts/vim-install.sh).
STOW_PACKAGES=(claude cursor nvim omp p10k pi tmux zed zsh)

# Homebrew formulae the configs depend on.
BREW_PACKAGES=(
  stow            # symlinks packages/ into $HOME
  neovim
  tree-sitter-cli # nvim-treesitter's main branch compiles parsers with it
)

BREW_CASKS=(
  font-meslo-lg-nerd-font # used by ghostty and cursor
)

# Run in order; the label shown is the function name.
STEPS=(
  install_brew_packages
  clone_dependencies
  link_configs
  link_ghostty_config
  install_omp_plugins
)

main() {
  local total=${#STEPS[@]} n=0 step
  for step in "${STEPS[@]}"; do
    n=$((n + 1))
    run_step "$n" "$total" "$step"
  done
}

install_brew_packages() {
  install_missing --formula "${BREW_PACKAGES[@]}"
  install_missing --cask "${BREW_CASKS[@]}"
}

clone_dependencies() {
  # Powerlevel10k theme, loaded by .zshrc.
  clone_if_missing "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" \
    --depth=1 https://github.com/romkatv/powerlevel10k.git

  # lazy.nvim plugin manager; nvim installs the plugins themselves on first launch.
  clone_if_missing "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim" \
    --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git
}

link_configs() {
  remove_drifted_targets
  # --no-folding links files individually instead of linking whole directories,
  # so tools writing runtime state next to a config (logs, caches) don't write
  # into this repo.
  stow --no-folding --dir=packages --target="$HOME" --restow "${STOW_PACKAGES[@]}"
}

link_ghostty_config() {
  local dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
  mkdir -p "$dir"
  ln -sf "$REPO_DIR/packages/ghostty/config" "$dir/config"
}

install_omp_plugins() {
  command -v omp &>/dev/null || return 0
  [ -d "$HOME/.omp/plugins/node_modules/superpowers" ] && return 0

  omp plugin marketplace add obra/superpowers-marketplace
  omp plugin install superpowers@superpowers-marketplace
}

# Stow aborts if a real file sits where it wants a symlink. Tools do this to us:
# aicodemetricsd rewrites ~/.claude/settings.json atomically, replacing the
# symlink with a plain file. The repo is the source of truth, so delete such
# files. Only paths tracked in packages/ are touched, never untracked files.
# `-ef` (same inode) protects the repo file itself if the target path happens to
# resolve to it, e.g. through a leftover directory symlink from an older stow.
remove_drifted_targets() {
  local pkg src target
  for pkg in "${STOW_PACKAGES[@]}"; do
    while IFS= read -r -d '' src; do
      target="$HOME/${src#packages/$pkg/}"
      if { [ -e "$target" ] || [ -L "$target" ]; } && [ ! "$target" -ef "$src" ]; then
        echo "removed drifted $target"
        rm -f "$target"
      fi
    done < <(find "packages/$pkg" -type f -print0)
  done
}

install_missing() {
  local kind=$1; shift
  local installed pkg
  installed=$(brew list "$kind")
  for pkg in "$@"; do
    grep -qx "$pkg" <<<"$installed" || brew install "$kind" "$pkg"
  done
}

clone_if_missing() {
  local dest=$1; shift
  [ -d "$dest" ] || git clone "$@" "$dest"
}

# Shows a live progress line, hides the step's output when it succeeds quietly,
# and dumps it when the step fails or has something to report.
run_step() {
  local n=$1 total=$2 step=$3
  local label="${step//_/ }" log status

  log=$(mktemp)
  printf '%s %d/%d %s...' "$(progress_bar "$((n - 1))" "$total")" "$n" "$total" "$label"

  # `set -e` is ignored inside functions called from conditions, so the step
  # runs in a subshell that re-enables it and we read its status explicitly.
  set +e
  ( set -e; "$step" ) >"$log" 2>&1
  status=$?
  set -e

  printf '\r\033[K'
  if [ "$status" -eq 0 ]; then
    printf '%s %d/%d %s ✓\n' "$(progress_bar "$n" "$total")" "$n" "$total" "$label"
    [ -s "$log" ] && sed 's/^/    /' "$log"
  else
    printf '%s %d/%d %s ✗\n' "$(progress_bar "$n" "$total")" "$n" "$total" "$label"
    sed 's/^/    /' "$log"
    rm -f "$log"
    exit "$status"
  fi
  rm -f "$log"
}

progress_bar() {
  local done=$1 total=$2 i bar=""
  for ((i = 1; i <= total; i++)); do
    if ((i <= done)); then bar+="█"; else bar+="░"; fi
  done
  printf '%s' "$bar"
}

main
