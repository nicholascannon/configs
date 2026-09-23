---
name: cleanup-merged-branch
description: Use when a feature branch's PR has been merged on GitHub and the local repo should catch up to match.
disable-model-invocation: true
---

# Cleanup Merged Branch

Run the bundled script once from the repo. It is the whole task:

```bash
bash <this skill's base directory>/cleanup.sh
```

It switches to the default branch, pulls with `--ff-only --prune`, and deletes the previous branch only if it is merged. On the default branch it only pulls. On a detached HEAD or with uncommitted changes it changes nothing.

## Reporting

Reply with the script's final line and nothing else. Git's own output is expected, including anything about merge commits, upstreams, or pruned remote refs.

## When the script keeps the branch or fails

Report its message and stop. The branch was kept on purpose. Deleting it is the user's call, made by hand:

- Never `git branch -D`, `git branch -d --force`, or `git update-ref -d`.
- Never delete the remote branch.
- Never stash, reset, or commit to get past a dirty-tree stop.
