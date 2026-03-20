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
git clone https://github.com/Saschaeh/cc-tmux.git
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
- Set up SSH security with a private key (and display that key for your phone)
- Create a **"Claude Workspace"** shortcut on your Windows desktop
- Verify everything works

That's it. Three steps. The installer handles SSH, security, tunnel setup, tmux configuration, and the desktop shortcut.

---

## Phone Setup

During installation, an SSH private key was displayed on screen. You need to get this key into **Termius** on your phone so it can connect to your PC securely.

1. **Get the key.** If you need to see it again, run this in your Ubuntu terminal:

   ```bash
   cat ~/.cc-tmux/keys/cc-tmux_ed25519
   ```

2. **Copy the key text.** Select everything from `-----BEGIN OPENSSH PRIVATE KEY-----` through `-----END OPENSSH PRIVATE KEY-----` (including those lines).

3. **Import into Termius.** On your phone, open Termius and go to **Keychain** (the key icon). Tap **+**, then **Key**. Paste the key text you copied. Save it.

4. **Create a Host in Termius.** Tap **Hosts**, then **+** to add a new host:
   - **Hostname** and **Port**: shown each time you start the workspace (or scan the QR code that appears on your PC screen)
   - **Username**: your WSL username (the one you created in Step 1)
   - **Key**: select the key you just imported

5. **Note:** The hostname and port change each time you restart the workspace. When you start up, a QR code appears on your PC screen -- scan it with your phone camera and Termius will update the connection details automatically.

---

## Daily Usage

### Starting up

Double-click **"Claude Workspace"** on your desktop. Or open an Ubuntu terminal and run:

```bash
cc-tmux start
```

It starts SSH, the tunnel, and drops you into your tabbed workspace. A QR code appears with the connection address for your phone.

### On your PC

- **Click tabs** at the bottom to switch between projects
- **Click the + button** at the bottom right to open a new tab
- Type `claude` in any tab to start Claude Code
- Just **close the window** when you're done -- everything keeps running in the background

### On your phone

- Open **Termius** and update the port if it changed (or scan the QR code on your PC screen)
- Tap to connect -- you land in your workspace automatically
- Tap tabs at the bottom to switch between projects
- Press **Ctrl+B**, then **Shift+M** for mobile mode (bigger tabs, easier to tap on a small screen)
- Close Termius when done -- everything keeps running

### When you leave

Just walk away. Everything stays running. Open Termius on your phone whenever you want to check in on Claude.

### When you get back

Open the desktop shortcut or run `cc-tmux start` in Ubuntu. Everything is exactly where you left it.

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

This usually means the SSH key isn't imported into Termius. See the **Phone Setup** section above. To display the key again:

```bash
cat ~/.cc-tmux/keys/cc-tmux_ed25519
```

Copy the entire output (including the BEGIN and END lines) and import it into Termius under **Keychain** -> **+** -> **Key**.

---

## Uninstalling

To remove cc-tmux completely, run:

```bash
cc-tmux uninstall
```

This removes all cc-tmux configuration files, bashrc hooks, the desktop shortcut, and the `~/.cc-tmux` directory. It does **not** remove system packages (tmux, openssh-server, ngrok, etc.) that other programs might use.

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
| `~/.cc-tmux/templates/bashrc-hook.sh` | SSH auto-attach hook |
| `~/.tmux.conf` | Deployed tmux configuration |
| `~/startup.sh` | Workspace launcher |
| `Claude Workspace.lnk` (Windows Desktop) | One-click launcher shortcut |
| `/etc/ssh/sshd_config.d/00-cc-tmux.conf` | SSH hardening configuration |
| `/etc/sudoers.d/cc-tmux` | Passwordless SSH service management |
| `/etc/fail2ban/jail.d/cc-tmux.conf` | Brute-force protection rules |

---

## License

MIT
