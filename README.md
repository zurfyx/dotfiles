# dotfiles

macOS dotfiles for two Macs, managed with chezmoi. The parts worth stealing: a tailscaled/brew drift resync, a clauded wrapper for Claude Code, a pre-update app quitter, tmux status-bar scripts that never block, an incognito shell, and a prompt that shows colored pipestatus.

**This is personal config. Fork it, read it, take what you want. Don't apply it blind.**

## Things worth stealing

| Problem | File | Fix |
|---|---|---|
| `brew upgrade tailscale` swaps the binary but leaves the running daemon on the old version | [`bin/tailscaled-resync`](dot_local/bin/executable_tailscaled-resync) | Detects the drift between installed and running versions and bounces the daemon |
| Claude Code under cmux inherits environment it shouldn't, and flag support varies by version | [`bin/clauded`](dot_local/bin/executable_clauded) | Wrapper that scrubs the inherited env and probes which flags the installed version accepts |
| macOS update restarts reopen every app, regardless of the "reopen windows" checkbox | [`bin/preupdate`](dot_local/bin/executable_preupdate) | Quits apps cleanly before you hit Restart, so nothing comes back uninvited |
| VCS calls in the status bar can hang tmux redraws | [`bin/tmux-scm`](dot_local/bin/executable_tmux-scm), [`bin/tmux-metrics`](dot_local/bin/executable_tmux-metrics) | Serve a cached answer instantly, refresh detached in the background; git and Sapling |
| Sensitive commands end up in shell history | `incognito()` in [`dot_zshrc`](dot_zshrc) | Drops into a shell that writes no history, marked in the prompt |
| `$?` only reports the last stage of a pipeline | the pipestatus prompt in [`dot_zshrc`](dot_zshrc) | Prompt prints every stage's exit code, failures in color |
| Claude Code's default statusline says nothing about context or quota | [`dot_claude/executable_statusline.sh`](dot_claude/executable_statusline.sh) | Statusline with context-window and quota bars |

## Install

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --source ~/Code/dotfiles --apply zurfyx
```

Or look first:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --source ~/Code/dotfiles zurfyx
chezmoi diff
chezmoi apply
```

Note that `chezmoi apply` also runs `brew bundle` against a short Brewfile. Later, `chezmoi update` pulls the latest and applies it.

The source lives at `~/Code/dotfiles` (set via `sourceDir` in the config template), so the repo is a normal project directory rather than hidden under `~/.local/share`.

## Layout

| Repo | Installed | What |
|---|---|---|
| [`dot_zshrc`](dot_zshrc) | `~/.zshrc` | Interactive shell: prompt (pipestatus), aliases, `incognito()` |
| [`dot_zprofile`](dot_zprofile) | `~/.zprofile` | Login shell: PATH and environment |
| [`dot_gitconfig.tmpl`](dot_gitconfig.tmpl) | `~/.gitconfig` | Git config; email filled in from chezmoi data |
| [`dot_tmux.conf`](dot_tmux.conf) | `~/.tmux.conf` | tmux config and status-bar wiring |
| [`dot_local/bin/`](dot_local/bin) | `~/.local/bin/` | Standalone scripts (the table above) |
| [`Library/Application Support/com.mitchellh.ghostty/config`](Library/Application%20Support/com.mitchellh.ghostty/config) | same path under `~` | Ghostty terminal config |
| [`Library/Application Support/Code/User/`](Library/Application%20Support/Code/User) | same path under `~` | VS Code settings and keybindings |
| [`dot_claude/executable_statusline.sh`](dot_claude/executable_statusline.sh) | `~/.claude/statusline.sh` | Claude Code statusline |
| [`.chezmoiscripts/`](.chezmoiscripts) | not installed | Setup scripts run by `chezmoi apply` |
| [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl) | `~/.config/chezmoi/chezmoi.toml` | Prompts for machine identity on first init |

How chezmoi filenames map: `dot_` becomes a leading `.` on install,
`executable_` becomes `chmod +x`, and a `.tmpl` suffix marks a Go template
rendered with local data. `run_once_` scripts run a single time ever;
`run_onchange_` scripts run whenever their content changes.
Anything under `.chezmoiscripts/` runs during `chezmoi apply` but is never installed to `$HOME`.

## Local overrides

- `~/.zshrc.local` is sourced last, if present.
- `~/.gitconfig.local` is included, if present.
- Machine identity (the git email) is prompted once by chezmoi on first apply.

Private and work-specific config lives in those files, outside this repo.

## Guardrails

- [gitleaks](https://github.com/gitleaks/gitleaks) runs as a pre-commit hook and in CI, with custom vocabulary rules on top of the defaults.
- Commits use a GitHub noreply address.
- The repo contains no secrets, no hostnames, no identity.

## License

[MIT](LICENSE).
