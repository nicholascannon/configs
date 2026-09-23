#!/usr/bin/env bash
# Usage: cleanup.sh [branch]    (default: the current branch)
# Deletes the branch only when GitHub reports a merged PR whose head is exactly
# the local tip. Squash merges leave git itself no way to see that, hence -D.
# Every check runs before any change, so a kept branch leaves the repo untouched.
set -euo pipefail

main() {
  local repo default branch pr
  repo=$(basename "$(git rev-parse --show-toplevel)")
  default=$(default_branch)
  [[ $# -le 1 ]] || stop "$repo: usage: cleanup.sh [branch]. No changes made."
  branch=${1:-$(git symbolic-ref --quiet --short HEAD || true)}

  [[ -n "$branch" ]] || stop "$repo: detached HEAD. No changes made."
  [[ "$branch" != "$default" ]] || stop "$repo: on $default, nothing to delete. No changes made."
  git show-ref --verify --quiet "refs/heads/$branch" \
    || stop "$repo: no local branch $branch. No changes made."
  pr=$(merged_pr_at_tip "$branch") || stop "$repo: kept $branch, gh lookup failed. No changes made."
  [[ -n "$pr" ]] || stop "$repo: kept $branch, no merged PR has its current tip. No changes made."
  [[ -z "$(git status --porcelain --untracked-files=no)" ]] \
    || stop "$repo: kept $branch, uncommitted changes. No changes made."
  git fetch --quiet origin "$default"
  git merge-base --is-ancestor "$default" "origin/$default" \
    || stop "$repo: kept $branch, local $default has commits not on origin/$default. No changes made."

  git checkout --quiet "$default"
  git merge --quiet --ff-only "origin/$default"
  git branch --quiet -D "$branch"
  echo "$repo: on $default at $(git log -1 --format='%h %s'). Deleted $branch (#$pr)."
}

default_branch() {
  local ref
  ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  ref=${ref:-origin/main}
  echo "${ref#origin/}"
}

merged_pr_at_tip() {
  local branch=$1 tip prs number head
  tip=$(git rev-parse "refs/heads/$branch")
  prs=$(gh pr list --head "$branch" --state merged --json number,headRefOid \
    --jq '.[] | "\(.number) \(.headRefOid)"') || return 1
  while read -r number head; do
    if [[ "$head" == "$tip" ]]; then
      echo "$number"
      return
    fi
  done <<< "$prs"
}

stop() {
  echo "$1"
  exit 1
}

main "$@"
