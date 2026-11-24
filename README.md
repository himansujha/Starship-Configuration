# term-config

Interactive terminal setup scripts for macOS, Linux and Windows. Each script opens a checklist menu and installs only what you select. Everything is selected by default.

| Script | Platform | Shell it sets up |
|---|---|---|
| `term-config-mac.sh` | macOS | zsh + Oh My Zsh |
| `term-config-linux.sh` | Linux | zsh + Oh My Zsh |
| `term-config-win.ps1` | Windows 10/11 | PowerShell 7 |

All three end with the same [Starship](https://starship.rs) prompt using the **gruvbox-rainbow** preset, and the **JetBrainsMono Nerd Font** for its icons.

## Using the menu

| Key | Action |
|---|---|
| ↑ / ↓ | Move between items |
| Space | Select or deselect the current item |
| A | Select or deselect all |
| Enter | Start installing |

On Windows, Esc cancels. On macOS and Linux, Ctrl-C cancels.

---

## macOS

**Needs:** macOS on Apple Silicon or Intel, and an admin account. If Homebrew isn't installed, the script installs it, along with the Xcode Command Line Tools.

```bash
cd path/to/terminal_config
chmod +x term-config-mac.sh
./term-config-mac.sh
```

Run it with `./` or `bash`, not with `sh` or `zsh`.

**What it installs** (through Homebrew):
- zsh (Homebrew's newer zsh, alongside the built-in `/bin/zsh`)
- Oh My Zsh, plus the zsh-syntax-highlighting and zsh-autosuggestions plugins
- Starship, with the preset written to `~/.config/starship.toml`
- JetBrainsMono Nerd Font
- Homebrew's zsh as your default shell (it is added to `/etc/shells` first)

**Passwords:** you're asked once for your admin password, for the Homebrew installs and for editing `/etc/shells`. `chsh` may ask for your login password when it changes your shell.

**Afterwards:**
1. Set the font: Terminal → Settings (⌘ ,) → Profiles → Text → Font → Change… → **JetBrainsMono Nerd Font**. In iTerm2 it's Profiles → Text.
2. Open a new terminal window, or run `exec zsh`.

---

## Linux

**Needs:** a distro that uses `apt`, `dnf`, `pacman` or `zypper`, and an account with `sudo` rights. On apt-based distros (Debian, Ubuntu, Mint), the script installs `nala` and uses it in place of apt.

```bash
cd path/to/terminal_config
chmod +x term-config-linux.sh
./term-config-linux.sh
```

**What it installs:**
- git, curl, plus unzip and fontconfig if you chose the font (only what's missing)
- zsh, Oh My Zsh, zsh-syntax-highlighting and zsh-autosuggestions
- Starship (official installer), with the preset written to `~/.config/starship.toml`
- JetBrainsMono Nerd Font, in `~/.local/share/fonts/JetBrainsMonoNerdFont`
- zsh as your default shell, through `chsh`

**Afterwards:**
1. Select **JetBrainsMono Nerd Font** in your terminal app's preferences (GNOME Terminal, Konsole, Alacritty, and so on).
2. Log out and back in so the new default shell takes effect, or run `exec zsh` for the current window.

---

## Windows

**Needs:** Windows 10 (version 1809 or newer) or Windows 11, and **winget**. winget ships with Windows 11; on Windows 10, install "App Installer" from the Microsoft Store. Administrator rights are not needed.

Open **Windows PowerShell** or **Windows Terminal** and run:

```powershell
cd path\to\terminal_config
powershell -ExecutionPolicy Bypass -File .\term-config-win.ps1
```

If you downloaded the file from the internet and Windows blocks it, run this first:

```powershell
Unblock-File .\term-config-win.ps1
```

**What it installs:**
- PowerShell 7 (`winget install Microsoft.PowerShell`)
- PSReadLine: grey suggestions from your history (press → to accept), syntax colors, Tab menu completion, and ↑ / ↓ history search
- Terminal-Icons: file and folder icons in `ls` / `Get-ChildItem`
- Starship (`winget install Starship.Starship`), with the preset written to `%USERPROFILE%\.config\starship.toml`
- JetBrainsMono Nerd Font, installed for your user only
- Windows Terminal: PowerShell 7 as the default profile and the Nerd Font as the default font. `settings.json` is backed up first.

**Profile changes:** the script adds a block marked `# >>> term-config >>>` to both PowerShell 7's and Windows PowerShell's profile files, backing up any existing profile first. If profile scripts aren't allowed to run yet, it sets the **RemoteSigned** execution policy for your user account only.

**Afterwards:** close and reopen Windows Terminal, or run `. $PROFILE`.

> The Windows script hasn't been run on a Windows machine yet. If a step fails, the spinner prints the error output; please report it.

---

## Re-running and undoing

- **Re-running is safe:** components that are already installed are skipped, and config lines are never added twice.
- **Backups:**
  - macOS / Linux: `~/.zshrc.bak.<date>`, and Oh My Zsh's own `~/.zshrc.pre-oh-my-zsh`
  - Windows: `<profile>.bak.<date>` and `settings.json.bak.<date>`
- **To go back to your old shell:**
  - macOS: `chsh -s /bin/zsh`
  - Linux: `chsh -s /bin/bash`
  - Windows: pick another default profile in Windows Terminal → Settings → Startup
- **To remove the prompt:**
  - macOS / Linux: delete the `eval "$(starship init zsh)"` line from `~/.zshrc`
  - Windows: delete the `term-config` block from your PowerShell profile
