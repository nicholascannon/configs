---
name: cleanup-merged-branches
description: Use when feature branches' PRs have been merged on GitHub and the local repos should catch up to match.
disable-model-invocation: true
---

# Cleanup Merged Branches

The bundled script cleans up one branch:

```bash
cd <repo> && bash <this skill's base directory>/cleanup.sh [branch]
```

The branch is deletable only when `gh` shows a merged PR whose head is exactly the local tip. Then the script switches to the default branch, fast-forwards it, and deletes the branch. Otherwise it changes nothing. With no branch it targets the current branch.

## Targets

Targets are the feature branches this conversation created, in any repo: every `git checkout -b`, `git switch -c`, `git worktree add -b`, or first `git push -u` of a branch.

- Targets found: run the script once per target, from that target's repo, passing the branch.
- No targets found: run the script once in the working directory with no branch.

## Reporting

Reply with the last line of each run, one line per run, and nothing else. Git's own output is expected and needs no comment.

## When the script keeps a branch or fails

Report its message and stop. Kept branches were kept on purpose. Deleting them is the user's call, made by hand. The script's own `-D` after the GitHub check is the only force-delete allowed:

- Never run `git branch -D`, `git branch -d --force`, or `git update-ref -d` yourself.
- Never delete a remote branch.
- Never stash, reset, or commit to get past a dirty-tree stop.
