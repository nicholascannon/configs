# Configs

Personal dotfiles for macOS (Apple Silicon), managed with [GNU Stow](https://www.gnu.org/software/stow/). Each directory under `packages/` is a stow package that links into `$HOME`.

## Setting up a new machine

Do steps 1–5 **before** running `install.sh`. Do steps 6–10 **after**.

### Before `install.sh`

1. **Install the Xcode Command Line Tools** (provides `git`):
   ```sh
   xcode-select --install
   ```
2. **Install [Homebrew](https://brew.sh/)** and make sure `brew` is on your `PATH` in the current shell:
   ```sh
   eval "$(/opt/homebrew/bin/brew shellenv)"
   brew --version
   ```
3. **Install the apps you use.** `install.sh` does not install them: Ghostty, VS Code (with the `code` command on `PATH`: command palette → "Shell Command: Install 'code' command in PATH"), and any others.
4. **Install [oh-my-zsh](https://ohmyz.sh/)** without letting it overwrite `.zshrc`:
   ```sh
   RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   ```
   `install.sh` clones powerlevel10k and the zsh plugins into `~/.oh-my-zsh/custom` and fails if that directory does not exist.
5. **Clone this repo**:
   ```sh
   git clone https://github.com/nicholascannon/configs.git ~/configs
   cd ~/configs
   ```

Then run it. It is safe to re-run at any time:

```sh
./install.sh
```

### After `install.sh`

6. **Open a new terminal** so `.zshrc` loads (it expects `fnm`, `fzf`, `zoxide` and powerlevel10k).
7. **Install Node** (`fnm` installs no version by itself; the omp MCP servers and project tooling need `node` and `npx`):
   ```sh
   fnm install --lts
   fnm default lts-latest
   ```
8. **Set up GitHub access:**
   ```sh
   gh auth login
   ```
   The credential helper is already in `packages/git`, so choose HTTPS and decline the offer to configure git.
9. **Set up your git identity and commit signing** (see the next section).
10. **Recreate machine-local files** that are deliberately not in this repo:
    - `~/.zshrc.local` — secrets and work-specific aliases, env vars and PATH entries. `.zshrc` sources it only if it exists.
    - `~/.aws/config` and `aws sso login` for the AWS profiles you use.
    - User-scoped Claude Code MCP servers (see "Claude Code" below), after you install Claude Code.

## Git identity and signing

`packages/git` stows shared settings to `~/.config/git/config` (pager, push, fetch, `gh` credential helper) and the global ignore file. Identity and signing are per-machine and stay out of this public repo. They go in `~/.gitconfig`, which git reads after the stowed file.

Use `git config --file ~/.gitconfig`, not `--global`. When `~/.gitconfig` does not exist yet, `--global` writes into the stowed file in this repo.

1. Create or import a GPG key.

   New key:
   ```sh
   gpg --quick-generate-key "Your Name <you@example.com>" ed25519 sign 2y
   ```
   Existing key from the old machine:
   ```sh
   # old machine
   gpg --export-secret-keys --armor <KEYID> > key.asc
   # new machine
   gpg --import key.asc && rm key.asc
   ```
2. Find the long key ID: `gpg --list-secret-keys --keyid-format=long` (the part after `ed25519/`).
3. Write the per-machine config:
   ```sh
   git config --file ~/.gitconfig user.name  "Your Name"
   git config --file ~/.gitconfig user.email "you@example.com"
   git config --file ~/.gitconfig user.signingkey <KEYID>
   git config --file ~/.gitconfig commit.gpgsign true
   ```
4. Add the public key to GitHub (Settings → SSH and GPG keys → New GPG key):
   ```sh
   gpg --armor --export <KEYID>
   ```
   The email on the key must be a verified email on your GitHub account.
5. Restart the agent so it reads the stowed `gpg-agent.conf` (pinentry-mac and a long passphrase cache): `gpgconf --kill gpg-agent`.
6. Check: `git commit --allow-empty -m "test" && git log --show-signature -1`, then undo it with `git reset --hard HEAD~1`.

SSH keys are not tracked. If you use one for a private repo, create it, add it to GitHub, and add a `Host github.com` block with `AddKeysToAgent yes` and `UseKeychain yes` to `~/.ssh/config`.

## What `install.sh` does

Runs these steps in order with a progress line per step:

1. Installs Homebrew formulae (see `BREW_PACKAGES` in the script) and the Meslo Nerd Font cask.
2. Clones powerlevel10k, lazy.nvim and the zsh plugins if missing.
3. Stows these packages into `$HOME`: `claude`, `cursor`, `git`, `gnupg`, `nvim`, `omp`, `p10k`, `pi`, `tmux`, `vscode`, `zed`, `zsh`.
4. Symlinks `packages/ghostty/config` into `~/Library/Application Support/com.mitchellh.ghostty/`.
5. Installs the omp `superpowers` plugin if `omp` is on `PATH`.
6. Installs missing VS Code extensions if `code` is on `PATH`.

**This repo is the source of truth.** Before stowing, `install.sh` deletes any real file (or stray symlink) sitting where a tracked file should link, because tools such as aicodemetricsd replace symlinks with plain files and stow refuses to link over them. Local edits to such files are lost. Untracked files are never touched. Stow runs with `--no-folding`, so it links individual files and tools cannot write runtime state into this repo through a directory symlink.

## Claude Code

Install Claude Code yourself. `packages/claude` stows its settings, global `CLAUDE.md`, statusline, output styles and skills into `~/.claude/`.

User-scoped MCP servers live in `~/.claude.json`, which is private per-machine state and cannot be stowed. Register them once per machine:

```sh
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp --api-key <your-context7-key>
```

Get a key at [context7.com](https://context7.com). Never commit it. The allow-rules for its tools are in `packages/claude/.claude/settings.json` and do carry across machines.

## omp

The `omp` package stows `~/.omp/agent/config.yml`. Everything else under `~/.omp/` (databases, sessions, logs, caches, `plugins/`, `marketplaces.json`) is runtime state and stays untracked.

- `~/.omp/agent/AGENTS.md` links to `packages/claude/.claude/CLAUDE.md`, so the global instructions apply to omp too.
- `install.sh` registers `anthropics/claude-plugins-official` and installs `superpowers` from it, so omp and Claude Code share one pinned version.
- `~/.omp/agent/mcp.json` holds omp's user MCP servers (context7, sequential-thinking).

## Scripts

`scripts/` holds helpers that `install.sh` does not run:

- `vim-install.sh` — legacy vim setup, kept but unused.
- `bake-bust.py <model.glb> [out.bin]` — bakes the mesh the nvim splash rasterizes.
