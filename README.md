<div align="center">

<img width="100%" alt="header" src="https://capsule-render.vercel.app/api?type=waving&height=210&text=Nautilus%20Mine%20Bot&fontAlign=50&fontAlignY=36&fontSize=56&desc=Auto%20Mining%20%7C%20Feed%20Claim%20%7C%20Daily%20Check%20In%20%7C%20Auto-Task&descAlign=50&descAlignY=58"/>

<img alt="typing" src="https://readme-typing-svg.demolab.com?font=Inter&size=18&duration=3000&pause=650&center=true&vCenter=true&width=900&lines=Auto+Mining+%7C+Start+Session+Claim+and+Restart;Auto+Daily+Check+In+%7C+Streak+Rewards+Every+Day;Auto+Tasks+%7C+Every+Task+Except+Telegram+Channels;Auto+Ad+Missions+%7C+Worked+Until+The+Daily+Maximum;Proxy+Support+%7C+Multi-Account"/>

<p>
  <img alt="python" src="https://img.shields.io/badge/Python-3.12+-3776AB?logo=python&logoColor=white"/>
  <img alt="platform" src="https://img.shields.io/badge/Platform-Nautilus%20Miniapp-111111"/>
  <img alt="multi-account" src="https://img.shields.io/badge/Multi--Account-Supported-111111"/>
  <img alt="proxy" src="https://img.shields.io/badge/Proxy-Supported-111111"/>
  <img alt="author" src="https://img.shields.io/badge/by-Yuurisandesu-111111"/>
</p>

<p>
  <b>Nautilus Bot</b> is a full automation bot for the Nautilus Telegram Miniapp.<br/>
  It handles the complete cycle for every account: logging in and reporting the account profile, starting the mining session or claiming the reward when it is ready and immediately restarting it, claiming the daily check in streak reward, completing every available task except telegram channel tasks, and working all ad missions until the daily maximum is reached, all running automatically across multiple accounts with proxy support, masked proxy logging, and a live countdown between cycles.<br/>
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

- Python `3.12+`
- Git

---

## Installation

**Clone the repository:**

```bash
git clone https://github.com/Yuurisan-N1/Nautilus-Miniapp.git
cd Nautilus-Miniapp
```

**Install dependencies:**

```bash
pip install aiohttp yuurisan
```

---

## Configuration

### 1. Accounts (data.txt)

Fill `data.txt` with Telegram WebApp `initData` for each account, one per line:

```
user=%7B%22id%22...&hash=abc123
user=%7B%22id%22...&hash=def456
```

> `initData` can be obtained from the browser DevTools when opening Nautilus on Telegram Web.
> Accounts are processed sequentially, and one blank line is printed between accounts to keep the log readable.

### 2. Proxy (proxy.txt)

Fill `proxy.txt` with proxies, one per line (optional, leave empty to run without proxy):

```
host:port
host:port:user:pass
http://user:pass@host:port
```

Proxies are assigned to accounts by index in round-robin order, so when there are fewer proxies than accounts the same proxy is reused for the remaining accounts. When `proxy.txt` is missing or empty the bot runs without any proxy. Credentials are never printed, the log only shows a masked form such as `http://user:pass@74*****81:10000`.

### 3. Bot Settings (config.json)

`sleep_seconds` controls how many seconds the bot waits between cycles. If `config.json` is missing, the bot falls back to a default of `3600` seconds.

---

## Running the Bot

```bash
python bot.py
```

Press `Ctrl+C` at any time to stop the bot cleanly.

---

## Features

### Account Loading
Every line of `data.txt` is one account. The bot logs in through the miniapp API and logs the account username, coin balance, ape level, skin and referral count before doing any work.

### Auto Mining
The bot reads the mining status first. When no session is running it starts one. When the reward is ready it claims the coins and immediately restarts the mining session afterwards. A mining claim is gated by the server behind a verified ad view, so a claim that is refused with the ad requirement is retried several times with the ad request issued before every attempt and a delay between attempts. When the reward is still on cooldown the bot logs the remaining time in hours, minutes and seconds.

### Auto Daily Check In
The bot submits the daily check in, logs the coins earned together with the current streak, and reports the status when the reward was already claimed for today.

### Auto Tasks
The bot fetches the full task list and completes every task whose type is not `telegram`. Telegram channel tasks are intentionally skipped and stay silent in the log. Tasks that are already completed are silently skipped as well, and the run only reports the total number of rewards claimed plus any task that genuinely failed.

### Auto Ad Missions
The bot works all ad task missions from the server settings. Every mission follows the exact order the official miniapp uses, which is an ad request followed by the mission completion call, and a mission the server already credited is skipped silently. Standard ad views are then requested up to the daily maximum reported by the server. Each request is verified against the server side ad counter before it is reported as a reward, so a view is only logged as rewarded when the server really credited the coins. Rate limited requests are respected with the server provided retry delay.

### Ad Reward Verification
Ad rewards on this miniapp are credited by the ad network through a server to server postback, which means the counter only moves after the network has served and verified a real advertisement. The bot therefore never reports progress it cannot verify: it re-reads the ad status after every request, logs the credited views in green with the coin amount, and reports once in yellow when the ad network served no advertisement for the account.

### Final Claim Pass
After tasks and ad missions are done the bot checks the mining status one more time and claims and restarts the session when the reward became ready during the cycle.

### Multi Account
All accounts in `data.txt` are processed sequentially within every cycle, with one blank line between accounts so every account block stays easy to read.

### Proxy Support
Proxies are loaded from `proxy.txt`, normalized to a full URL and assigned to accounts by position in round-robin order. Proxy credentials are masked in log output. Running without proxies is fully supported.

### Auto Countdown
After all accounts complete a cycle, the bot displays a live `HH:MM:SS` countdown in place until the next cycle starts, then prints the banner again and begins the next cycle.

---

## File Structure

```text
Nautilus-Miniapp/
├── bot.py          # Main bot, full cycle automation
├── config.json     # Sleep duration between cycles
├── data.txt        # Account initData, one per line
├── proxy.txt       # Proxy list, one per line (optional)
├── LICENSE         # License file
└── utils/
    └── banner.py   # Banner using yuurisan module
```

---

## Disclaimer

This tool is built for educational and technical exploration purposes. Use it wisely and at your own responsibility.

---

<div align="center">
<img width="100%" alt="footer" src="https://capsule-render.vercel.app/api?type=waving&height=120&section=footer"/>
</div>
