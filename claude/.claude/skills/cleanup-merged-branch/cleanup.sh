#!/usr/bin/env bash
# Deletes only with `git branch -d`, never -D: refusing unmerged branches is the point.
set -euo pipefail

main() {
  local branch default
  branch=$(current_branch)
  default=$(default_branch)

  if [[ -z "$branch" ]]; then
    echo "Detached HEAD: no changes made."
    exit 0
  fi
  if [[ "$branch" == "$default" ]]; then
    sync_default "$default"
    echo "On $default: pulled to $(git log -1 --format='%h %s'). No branch deleted."
    exit 0
  fi

  require_clean_tree "$branch"
  sync_default "$default"
  delete_if_merged "$branch" "$default"
}

current_branch() {
  git symbolic-ref --quiet --short HEAD || true
}

default_branch() {
  local ref
  ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  ref=${ref:-origin/main}
  echo "${ref#origin/}"
}

require_clean_tree() {
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Kept $1: uncommitted changes would move to the default branch. No changes made."
    exit 1
  fi
}

sync_default() {
  git checkout --quiet "$1"
  git pull --ff-only --prune --quiet
}

delete_if_merged() {
  local branch=$1 default=$2
  # `git branch -d` also accepts a branch that is merged only into its upstream,
  # so a pushed-but-unmerged PR branch would be deleted. Check the default branch.
  if ! git merge-base --is-ancestor "$branch" "$default"; then
    echo "Kept $branch: not merged into $default. Now on $default."
    exit 1
  fi
  git branch -d "$branch"
  echo "On $default at $(git log -1 --format='%h %s'). Deleted $branch."
}

main "$@"
