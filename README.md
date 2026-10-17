<div align="center">

<img width="100%" alt="header" src="https://capsule-render.vercel.app/api?type=waving&height=210&text=Nautilus%20Bot&fontAlign=50&fontAlignY=36&fontSize=56&desc=Mining%20Cycle%20%7C%20Rewarded%20Ads%20%7C%20Account%20Tasks&descAlign=50&descAlignY=58"/>

<img alt="typing" src="https://readme-typing-svg.demolab.com?font=Inter&size=18&duration=3000&pause=650&center=true&vCenter=true&width=900&lines=Telegram+initData+Login;Mining+Cycle+Automation;Rewarded+Ads+%7C+Ad+Missions;Daily+Check+In+%7C+Invite+Tasks;Multi-Account+%7C+Sequential+Processing"/>

<p>
  <img alt="nim" src="https://img.shields.io/badge/Nim-1.6%2B-FFE953?logo=nim&logoColor=black"/>
  <img alt="platform" src="https://img.shields.io/badge/Platform-Nautilus%20Miniapp-111111"/>
  <img alt="multi-account" src="https://img.shields.io/badge/Multi--Account-Supported-111111"/>
  <img alt="proxy" src="https://img.shields.io/badge/Proxy-Supported-111111"/>
  <img alt="author" src="https://img.shields.io/badge/by-Yuurisandesu-111111"/>
</p>

<p>
  <b>Nautilus Bot</b> is a full automation bot for the Nautilus Telegram Miniapp.<br/>
  It logs every account in with the Telegram <code>initData</code> from <code>data.txt</code>, claims the account tasks, works the ad missions, watches the rewarded ad slots one by one, runs the mining cycle - starting the session, watching the ad the server asks for and claiming the reward - upgrades the ape when the balance allows it, claims the daily check in and collects the invite tasks the account has unlocked.<br/>
  Built and distributed by <b>Yuurisandesu</b>.
</p>

</div>

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Bot](#running-the-bot)
- [Features](#features)
- [File Structure](#file-structure)
- [Disclaimer](#disclaimer)

---

## Requirements

- Nim `1.6+`
- Git

---

## Installation

### Install Nim

**Windows:**

1. Download and run the installer from https://nim-lang.org/install_windows.html, or install it with a package manager:

```cmd
winget install nim
```

2. Open Command Prompt and verify the installation:

```cmd
nim --version
```

**Linux (Ubuntu / Debian):**

```bash
sudo apt-get update
sudo apt-get install -y nim
nim --version
```

**macOS:**

```bash
brew install nim
nim --version
```

> If you do not have Homebrew, install it first from https://brew.sh

**Termux (Android):**

```bash
pkg update && pkg upgrade -y
pkg install nim -y
nim --version
```

> The build needs the OpenSSL headers. On Debian and Ubuntu they come from `sudo apt-get install -y libssl-dev`, and on Termux from `pkg install openssl-dev -y`. Install them before building if the compiler reports a missing `ssl.h`.

---

### Clone and Install

**Clone the repository:**

```bash
git clone https://github.com/Yuurisan-N1/Nautilus-Miniapp.git
cd Nautilus-Miniapp
```

**Install dependencies:**

This bot uses only the Nim standard library, so there is nothing to install.

---

## Configuration

### 1. Accounts (data.txt)

Fill `data.txt` with the Telegram WebApp `initData` of each account, one per line:

```
user=%7B%22id%22...&hash=abc123
user=%7B%22id%22...&hash=def456
```

> `initData` can be obtained from the browser DevTools when opening the Nautilus Miniapp on Telegram Web.

### 2. Proxy (proxy.txt)

Fill `proxy.txt` with proxies, one per line (optional, leave empty to run without proxy):

```
host:port
host:port:user:pass
http://user:pass@host:port
```

Proxies are assigned to accounts by index in round-robin order. Proxy credentials are masked in the log.

### 3. Bot Settings (config.json)

`sleep_seconds` controls how many seconds the bot waits between cycles. If `config.json` is missing, it is created automatically with a default of `3600` seconds.

```json
{
  "settings": {
    "sleep_seconds": 3600
  }
}
```

---

## Running the Bot

**Linux / macOS:**

```bash
make release
./bin/nautilus
```

**Windows:**

**Command Prompt (`cmd.exe`)** - the file name is enough:

```cmd
run_pc.bat
```

**PowerShell** - PowerShell does not search the current folder, so the path prefix is required:

```powershell
.\run_pc.bat
```

Running `run_pc.bat` without `.\` in PowerShell fails with `run_pc.bat : The term 'run_pc.bat' is not recognized`. Double clicking the file in Explorer works in both cases.

**Manual build, step by step.** If you want to see each step instead of using the launcher, run these two commands from the bot folder:

```cmd
nim c -d:ssl -d:release --opt:speed --hints:off -o:bin\nautilus.exe src\nautilus.nim
bin\nautilus.exe
```

The first command compiles `src\nautilus.nim` into `bin\nautilus.exe` with TLS enabled and the release optimizer. The second one starts it. Run them one at a time: the build prints its own output, and the bot then runs in the foreground until you stop it.

If `nim` is not recognised, the Nim `bin` folder is not on your `PATH`. Reinstall with `winget install nim`, or open a new terminal after installing, because the installer only updates `PATH` for new sessions.

The release build links OpenSSL, so the `-d:ssl` flag is part of every build command in the `Makefile`, `run.sh` and `run_pc.bat`. A debug build without that flag cannot reach the server over HTTPS.

**Windows runtime files.** A Windows release binary needs three files next to `nautilus.exe`:

| File | Why |
|---|---|
| `libcrypto-1_1-x64.dll` | OpenSSL crypto library used by `-d:ssl` |
| `libssl-1_1-x64.dll` | OpenSSL TLS library used by `-d:ssl` |
| `cacert.pem` | CA bundle, the bot loads it from its own folder when `SSL_CERT_FILE` is not set |

All three ship inside the Nim distribution (`nim-<version>\bin`) and the GitHub Actions workflow copies them into `bin/` for the Windows artifact. Without them the binary exits with `could not load: libcrypto-1_1-x64.dll` or `No SSL/TLS CA certificates found`.

If the files are missing, find the Nim folder and copy them next to the binary:

```cmd
where nim
```

That prints the full path to `nim.exe`, for example `C:\Users\you\.nimble\bin\nim.exe`. Copy the three files from that same folder:

```cmd
copy "C:\Users\you\.nimble\bin\libcrypto-1_1-x64.dll" bin\
copy "C:\Users\you\.nimble\bin\libssl-1_1-x64.dll" bin\
copy "C:\Users\you\.nimble\bin\cacert.pem" bin\
```

Windows only looks for a DLL in the folder of the executable and in `PATH`, so keeping them in `bin\` next to `nautilus.exe` is the reliable option.

---

## Features

### Account Login
Every account is opened with the Telegram `initData` from `data.txt`. The bot registers the account on the server, reads the profile and logs the account name together with the current coin balance.

### Account Tasks
The task board is read once per account. Tasks that only need a start request are completed in one pass, and tasks that a real channel join has to unlock are left alone. Already completed tasks are counted as done, so a healthy account is never reported as broken.

### Ad Missions
The ad mission list comes from the server settings, so the bot never guesses a mission id or a reward. A mission the server refuses is retried once after the rewarded ad step, and every mission that pays is logged with the coins it credited.

### Rewarded Ads
The rewarded ad slot is read from the server settings. Each ad is tracked, the ad network is asked for a banner, the ad events are fired in order and the daily counter is re-read before anything is reported. A view is only logged as credited after the server counter moves, and the bot stops after three views that returned no credit.

### Mining Cycle
The mining state is read first. When the session is closed the bot starts a new one. When the reward is ready the bot tracks the mining ad the server asks for, claims the reward and restarts the session, so the claim is never left locked behind a missing ad step.

### Ape Upgrade
The ape levels and their costs come from the server settings. The next level is bought only when the balance covers the cost the server reports, and the upgrade is logged with the new level.

### Daily Check In
The daily check in is sent once per account. The reward that the server credits is logged, and a day that was already claimed is reported as such instead of as a failure.

### Invite Tasks
The invite task board is read and compared against the invite count of the account. Every tier the account has unlocked is claimed, and the tier is logged with the coins it paid.

### Multi Account
All accounts in `data.txt` are processed sequentially within every cycle. Each account is logged with its name and its balance. The cycle number is tracked and logged at the start of each round.

### Proxy Support
Proxies are loaded from `proxy.txt` and assigned to accounts by position in round-robin order. Running without proxies is fully supported.

### Auto Countdown
Every wait inside the cycle displays a live `HH:MM:SS` countdown in place, and after all accounts complete a cycle the bot shows a countdown until the next cycle starts.

---

## File Structure

```text
Nautilus-Miniapp/
├── nautilus.nimble    # Nim package manifest
├── Makefile           # Build, run and package targets
├── run.sh             # Launcher for Linux and macOS
├── run_pc.bat         # Launcher for Windows
├── config.json        # Sleep duration between cycles
├── data.txt           # Account initData, one per line
├── proxy.txt          # Proxy list, one per line (optional)
├── LICENSE            # License file
├── README.md          # This document
├── assets/
    └── icon.ico       # Bot icon
└── src/
    ├── nautilus.nim   # Main bot, full mining cycle automation
    ├── net/
        ├── client.nim # HTTP client and session
        ├── egress.nim # Proxy loading and masking
        └── adsgram.nim # Rewarded ad delivery
    ├── ops/
        ├── account.nim # Login, check in and invite tasks
        ├── ads.nim    # Rewarded ad phase
        ├── mining.nim # Mining cycle and ape upgrade
        └── tasks.nim  # Account tasks and ad missions
    └── support/
        ├── banner.nim # Banner display on startup
        ├── cfg.nim    # Config and credential loading
        └── log.nim    # Coloured log helpers and countdown
```

---

## Disclaimer

This tool is built for educational and technical exploration purposes. Use it wisely and at your own responsibility.

---

<div align="center">
<img width="100%" alt="footer" src="https://capsule-render.vercel.app/api?type=waving&height=120&section=footer"/>
</div>
