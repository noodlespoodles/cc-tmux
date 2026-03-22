# Claude Code x tmux

Run Claude Code in persistent terminal sessions on Windows. Access your work from your PC **and** your Android phone. Walk away, come back -- everything is exactly where you left it.

The installer handles everything in one command: SSH setup, security hardening, tunnel configuration, tmux workspace, and a desktop shortcut. You don't need to understand any of that -- just follow three steps below.

```
Your PC (Windows)
  +-- WSL2 (Ubuntu running inside Windows)
        +-- tmux (keeps your terminal sessions alive)
              +-- Tab 1: PowerShell -> Claude Code (Project A)
              +-- Tab 2: PowerShell -> Claude Code (Project B)
              +-- Tab 3: PowerShell -> Claude Code (Project C)

Your Phone (Android)
  +-- Termius (SSH app)
        +-- connects via ngrok tunnel
              +-- same tmux tabs as above
```

---

## What You Need

- **Windows 10 or 11**
- **An Android phone** with [Termius](https://play.google.com/store/apps/details?id=com.server.auditor.ssh.client) installed (free SSH app from the Play Store)
- **An ngrok account** (free) -- sign up at [ngrok.com](https://ngrok.com). The free plan requires a credit or debit card on file for verification. They don't charge it -- it's just for abuse prevention.

---

## Setup

### Step 1: Install WSL

WSL (Windows Subsystem for Linux) lets you run Ubuntu inside Windows. Open **PowerShell as Administrator** (right-click the Start button, select **Terminal (Admin)** or **PowerShell (Admin)**) and run:

```powershell
wsl --install
```

Restart your computer when it asks. After the restart, **Ubuntu** will open automatically and ask you to create a username and password. **Remember these -- you will need them throughout the setup.**

### Step 2: Clone this repo

Open **Windows Terminal** (or any terminal). Click the dropdown arrow next to the **+** tab button and select **Ubuntu**. You should see a prompt like:

```
yourname@PCNAME:~$
```

This is your WSL terminal. Run these two commands:

```bash
git clone https://github.com/noodlespoodles/cc-tmux.git
cd cc-tmux
```

### Step 3: Run the installer

Still in that same Ubuntu terminal, run:

```bash
bash install.sh
```

The installer will:

- Install all required software (tmux, SSH server, ngrok, and more)
- Ask for your ngrok auth token (it tells you exactly where to find it)
- Ask you to add your project folders (the directories where your code lives)
- Set up SSH security with a private key (saved to your Desktop for easy transfer)
- Create a **"Claude Workspace"** shortcut on your Windows desktop
- Verify everything works

That's it. Three steps. The installer handles SSH, security, tunnel setup, tmux configuration, and the desktop shortcut.

---

## Phone Setup

During installation, the installer saved your SSH private key to your **Windows Desktop** as `cc-tmux-key.txt`. You need to get this file onto your phone and import it into Termius.

1. **Transfer the key to your phone.** Find `cc-tmux-key.txt` on your Desktop and send it to yourself -- email it, upload to Google Drive or OneDrive, or any method you prefer. Download it on your phone.

2. **Import into Termius.** On your phone, open Termius and go to **Keychain** (the key icon). Tap **+**, then **Key**, then **Import from file**. Select the key file you transferred. Name it something like "cc-tmux" and save.

3. **Create a Host in Termius.** Tap **Hosts**, then **+** to add a new host:
   - **Hostname**: `0.tcp.in.ngrok.io` (this stays the same)
   - **Port**: shown each time you start the workspace (run `cc-tmux tunnel` on your PC to check)
   - **Username**: your WSL username (the one you created in Step 1)
   - **Key**: select the key you just imported

4. **Delete the key file** from your Desktop and phone Downloads after importing. Private keys shouldn't be left lying around.

**Note:** The port number changes each time the workspace restarts (ngrok free tier limitation). Run `cc-tmux tunnel` on your PC to see the current port, and update it in Termius.

**If you can't find the key file**, run this in Ubuntu to put it back on your Desktop:

```bash
cp ~/.cc-tmux/keys/cc-tmux_ed25519 /mnt/c/Users/$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')/Desktop/cc-tmux-key.txt
```

---

## Daily Usage

### Starting up

Double-click **"Claude Workspace"** on your desktop. Or open an Ubuntu terminal and run:

```bash
cc-tmux start
```

It starts SSH, the tunnel, and shows the connection address for your phone. Press Enter to launch the workspace.

### On your PC

- **Click tabs** at the bottom to switch between projects
- **Click the + button** at the bottom right to open a new tab
- **Right-click any folder** in Windows Explorer and select **"Open in CC-TMUX"** to open it as a new tab (see [Context Menu](#windows-explorer-context-menu) below)
- Type `claude` in any tab to start Claude Code
- Just **close the window** when you're done -- everything keeps running in the background

### On your phone

- Open **Termius** and update the port if it changed (run `cc-tmux tunnel` on your PC)
- Tap to connect -- you land in your workspace automatically
- Tap tabs at the bottom to switch between projects
- Press **Ctrl+B**, then **Shift+M** for mobile mode (bigger tabs, easier to tap on a small screen)
- Press **Ctrl+B**, then **Shift+N** to switch back to desktop mode
- Close Termius when done -- everything keeps running

### When you leave

Just walk away. Everything stays running. Open Termius on your phone whenever you want to check in on Claude.

### When you get back

Open the desktop shortcut or run `cc-tmux start` in Ubuntu. Everything is exactly where you left it.

---

## Windows Explorer Context Menu

You can add a right-click option to Windows Explorer so that any folder can be opened as a new tab in your workspace.

### Install it

```bash
cc-tmux context-menu
```

After this, right-click any folder in Windows Explorer and you'll see **"Open in CC-TMUX"**. It creates a new tmux tab pointed at that folder. Your workspace must be running first (`cc-tmux start`).

### Remove it

```bash
cc-tmux remove-context-menu
```

This removes the right-click option from Windows Explorer. It's also removed automatically if you run `cc-tmux uninstall`.

---

## Quick Reference

### cc-tmux Commands

Run these in your Ubuntu terminal.

| Command | What It Does |
|---|---|
| `cc-tmux start` | Start workspace (SSH + tunnel + tmux) |
| `cc-tmux stop` | Stop workspace (kill session + tunnel) |
| `cc-tmux project add <name> <path>` | Add a project tab |
| `cc-tmux project remove <name>` | Remove a project tab |
| `cc-tmux project list` | List configured projects |
| `cc-tmux tunnel` | Show tunnel status and address |
| `cc-tmux doctor` | Check installation health |
| `cc-tmux update` | Check for and apply updates |
| `cc-tmux context-menu` | Add right-click option to Windows Explorer |
| `cc-tmux remove-context-menu` | Remove right-click option |
| `cc-tmux uninstall` | Remove cc-tmux completely |
| `cc-tmux version` | Show cc-tmux version |
| `cc-tmux help` | Show help message |

### Keyboard Shortcuts

These work inside the tmux workspace (on both PC and phone).

| Shortcut | What It Does |
|---|---|
| Click a tab | Switch to that tab |
| Alt + Left/Right arrow | Switch between tabs |
| Click the **+** button | Open a new tab |
| Ctrl+B, then C | Open a new tab (keyboard) |
| Ctrl+B, then comma | Rename the current tab |
| Ctrl+B, then Shift+M | Mobile mode (bigger tabs for phone) |
| Ctrl+B, then Shift+N | Desktop mode (normal tabs) |
| Ctrl+B, then - | Split the screen horizontally |
| Ctrl+B, then \| | Split the screen vertically |
| Ctrl+B, then D | Detach (leave workspace running, exit terminal) |
| Mouse wheel | Scroll up through terminal history |

---

## Troubleshooting

**First step for any issue:** Run `cc-tmux doctor`. It checks every component and tells you exactly what's wrong with a fix suggestion for each problem.

### Can't connect from Termius

- Is your PC on and awake? WSL shuts down when the PC sleeps.
- The port changes each time the workspace restarts. Run `cc-tmux tunnel` on your PC to see the current address and port.
- A VPN on your phone can interfere with the connection. Try disconnecting it.

### SSH won't start

Run these commands in your Ubuntu terminal:

```bash
sudo service ssh restart
sudo service ssh status
```

You should see "active (running)". If not, run `cc-tmux doctor` for more details.

### ngrok isn't running

Run `cc-tmux start` to restart everything, or check `cc-tmux tunnel` to see the current tunnel status. If the tunnel isn't connecting, make sure your ngrok auth token is set up -- the installer would have asked for it during setup.

### tmux session disappeared

Your PC probably restarted or WSL shut down. Double-click the **"Claude Workspace"** desktop shortcut or run `cc-tmux start`. Your project tabs will be recreated, but any running Claude Code sessions will need to be restarted.

### PowerShell won't start in a tab

Check that PowerShell is accessible from WSL:

```bash
which powershell.exe
```

This should return a path like `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe`. If it returns nothing, your WSL might not have Windows path integration enabled.

### I closed the window by accident

No problem. Run `cc-tmux start` in any Ubuntu terminal. Everything is still running -- you just reconnect.

### My PC went to sleep

WSL shuts down when your PC sleeps, which disconnects everything. To prevent this, change your power settings:

**Settings** -> **System** -> **Power & battery** -> **Screen and sleep** -> set "When plugged in, put my device to sleep" to **Never**.

Then run `cc-tmux start` to restart the workspace.

### "Permission denied" on SSH

This means the SSH key isn't imported into Termius correctly. See the **Phone Setup** section above. To get the key file again:

```bash
cp ~/.cc-tmux/keys/cc-tmux_ed25519 /mnt/c/Users/$(cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r')/Desktop/cc-tmux-key.txt
```

Transfer `cc-tmux-key.txt` to your phone and import it in Termius under **Keychain** -> **+** -> **Import from file**.

### "Open in CC-TMUX" doesn't work

Make sure your workspace is running first (`cc-tmux start`). If it still doesn't work, reinstall the context menu:

```bash
cc-tmux remove-context-menu
cc-tmux context-menu
```

---

## Uninstalling

To remove cc-tmux completely, run:

```bash
cc-tmux uninstall
```

This removes all cc-tmux configuration files, bashrc hooks, the desktop shortcut, the context menu, and the `~/.cc-tmux` directory. It does **not** remove system packages (tmux, openssh-server, ngrok, etc.) that other programs might use.

If you also want to remove those packages:

```bash
sudo apt remove tmux openssh-server fail2ban qrencode ngrok
```

---

## Files Reference

| File | Purpose |
|---|---|
| `~/.cc-tmux/config.env` | Configuration (username, distro, tunnel provider) |
| `~/.cc-tmux/projects.conf` | Project list (one project per line) |
| `~/.cc-tmux/keys/cc-tmux_ed25519` | SSH private key (import this into Termius) |
| `~/.cc-tmux/keys/cc-tmux_ed25519.pub` | SSH public key |
| `~/.cc-tmux/tunnel.env` | Current tunnel address (auto-managed) |
| `~/.cc-tmux/tunnel.log` | Tunnel log |
| `~/.cc-tmux/error.log` | Error log |
| `~/.cc-tmux/lib/` | Runtime library modules |
| `~/.cc-tmux/bin/cc-tmux` | CLI entry point |
| `~/.cc-tmux/templates/tmux.conf.tpl` | tmux config template |
| `~/.cc-tmux/templates/mobile-check.sh` | Mobile auto-detection script |
| `~/.cc-tmux/templates/open-in-cctmux.sh` | Context menu helper (WSL side) |
| `~/.cc-tmux/templates/bashrc-hook.sh` | SSH auto-attach hook |
| `~/.tmux.conf` | Deployed tmux configuration |
| `~/startup.sh` | Workspace launcher |
| `Claude Workspace.lnk` (Windows Desktop) | One-click launcher shortcut |
| `C:\Users\X\.cc-tmux\open-in-cctmux.ps1` | Context menu launcher (Windows side) |
| `/etc/ssh/sshd_config.d/00-cc-tmux.conf` | SSH hardening configuration |
| `/etc/sudoers.d/cc-tmux` | Passwordless SSH service management |
| `/etc/fail2ban/jail.d/cc-tmux.conf` | Brute-force protection rules |

---

## License

MIT
