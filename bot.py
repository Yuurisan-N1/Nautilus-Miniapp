import os
import re
import sys
import json
import time
import base64
import signal
import asyncio
import urllib.parse
import aiohttp

from utils.banner import show_banner

RESET  = "\033[0m"
BOLD   = "\033[1m"
RED    = "\033[91m"
GREEN  = "\033[92m"
YELLOW = "\033[93m"

MY_PROJECT = "Nautilus Miniapp"
BASE_URL   = "https://nautilus.onelabs.online"
REF_CODE   = "6004380466"

CLAIM_ATTEMPTS = 6
CLAIM_RETRY_SECONDS = 20
AD_TRACK_ATTEMPTS = 4
AD_VERIFY_POLLS = 6
AD_VERIFY_DELAY = 4

ADSGRAM_URL = "https://api.adsgram.ai/adv"
ADSGRAM_SDK_VERSION = "2.2.4"
ADSGRAM_EVENT_ORDER = (
    "show",
    "start",
    "Show",
    "render",
    "Render",
    "complete",
    "Click",
    "ClickPixel",
    "SelfLink",
    "UserReturn",
    "Reward",
)

BANNED_CODES = (
    91, 93, 124, 35, 33, 64, 36, 37, 94, 38, 42, 40, 41,
    45, 44, 58, 59, 39, 34, 96, 126, 43, 61, 60, 62, 63, 47, 92,
)
BANNED_CHARS = tuple(chr(code) for code in BANNED_CODES)

HEADERS_BASE = {
    "accept": "*/*",
    "accept-encoding": "identity",
    "accept-language": "en-US,en;q=0.9",
    "cache-control": "no-cache",
    "content-type": "application/json",
    "origin": BASE_URL,
    "pragma": "no-cache",
    "priority": "u=1, i",
    "referer": f"{BASE_URL}/?tgWebAppStartParam={REF_CODE}&sv=1",
    "sec-ch-ua": '"Microsoft Edge";v="152", "Not?A_Brand";v="24", "Chromium";v="152", "Microsoft Edge WebView2";v="152"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"Windows"',
    "sec-fetch-dest": "empty",
    "sec-fetch-mode": "cors",
    "sec-fetch-site": "same-origin",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36 Edg/152.0.0.0",
}


def log_green(msg):
    print(f"{GREEN}{BOLD}{msg}{RESET}")


def log_yellow(msg):
    print(f"{YELLOW}{BOLD}{msg}{RESET}")


def log_red(msg):
    print(f"{RED}{BOLD}{msg}{RESET}")


def signal_handler(sig, frame):
    print()
    log_red("Script stopped by user")
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)


def load_config():
    defaults = {"settings": {"sleep_seconds": 3600}}
    if not os.path.exists("config.json"):
        return defaults
    try:
        with open("config.json") as f:
            return json.load(f)
    except Exception:
        return defaults


def load_data():
    if not os.path.exists("data.txt"):
        log_red("File data.txt was not found")
        sys.exit(1)
    lines = [l.strip() for l in open("data.txt").readlines() if l.strip()]
    if not lines:
        log_red("File data.txt is empty")
        sys.exit(1)
    return lines


def load_proxies():
    if not os.path.exists("proxy.txt"):
        return []
    try:
        return [l.strip() for l in open("proxy.txt").readlines() if l.strip()]
    except Exception:
        return []


def get_proxy(proxies, idx):
    if not proxies:
        return None
    return proxies[idx % len(proxies)]


def normalize_proxy(proxy_line):
    if not proxy_line:
        return None
    value = proxy_line.strip()
    if "://" in value:
        return value
    parts = value.split(":")
    if len(parts) == 4:
        host, port, user, password = parts
        return f"http://{user}:{password}@{host}:{port}"
    if len(parts) == 3:
        host, port, user = parts
        return f"http://{user}@{host}:{port}"
    return f"http://{value}"


def mask_proxy(proxy_url):
    try:
        value = proxy_url.split("://")[-1]
        after_at = value.split("@")[-1]
        host_part = after_at.split(":")[0]
        port_part = after_at.split(":")[1] if ":" in after_at else ""
        octets = host_part.split(".")
        if len(octets) == 4:
            masked_host = f"{octets[0]}*****{octets[3]}"
        elif len(host_part) > 4:
            masked_host = f"{host_part[:2]}*****{host_part[-2:]}"
        else:
            masked_host = "***"
        suffix = f":{port_part}" if port_part else ""
        return f"http://user:pass@{masked_host}{suffix}"
    except Exception:
        return "http://user:pass@***:***"


def clean_text(value, fallback):
    text = str(value)
    for symbol in BANNED_CHARS:
        text = text.replace(symbol, " ")
    text = " ".join(text.split())
    return text if text else fallback


def parse_init_data(init_data):
    try:
        parsed = dict(urllib.parse.parse_qsl(init_data))
        return json.loads(parsed.get("user", "{}"))
    except Exception:
        return {}


def init_data_fields(init_data):
    try:
        return dict(urllib.parse.parse_qsl(init_data, keep_blank_values=True))
    except Exception:
        return {}


def build_data_check_string(init_data):
    try:
        pairs = urllib.parse.parse_qsl(init_data, keep_blank_values=True)
        parts = sorted(f"{key}={value}" for key, value in pairs if key not in ("hash", "signature"))
        encoded = base64.urlsafe_b64encode("\n".join(parts).encode("utf-8")).decode("utf-8")
        return encoded.rstrip("=")
    except Exception:
        return ""


def normalize_block_id(value):
    text = str(value or "").strip()
    digits = ""
    for char in reversed(text):
        if char.isdigit():
            digits = char + digits
        else:
            break
    return digits or text


def adsgram_headers():
    return {
        "accept": "*/*",
        "accept-encoding": "identity",
        "accept-language": "en-US,en;q=0.9",
        "cache-control": "no-cache",
        "origin": BASE_URL,
        "pragma": "no-cache",
        "referer": f"{BASE_URL}/",
        "sec-fetch-dest": "empty",
        "sec-fetch-mode": "cors",
        "sec-fetch-site": "cross-site",
        "user-agent": HEADERS_BASE["user-agent"],
    }


def format_duration(seconds):
    try:
        seconds = int(seconds)
    except Exception:
        return "an unknown amount of time"
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    rest = seconds % 60
    if hours > 0:
        return f"{hours} hours {minutes} minutes"
    if minutes > 0:
        return f"{minutes} minutes {rest} seconds"
    return f"{rest} seconds"


def countdown(seconds):
    for remaining in range(seconds, 0, -1):
        h = remaining // 3600
        m = (remaining % 3600) // 60
        s = remaining % 60
        print(f"\r{YELLOW}{BOLD}Next cycle starts in {h:02d}:{m:02d}:{s:02d}{RESET}", end="", flush=True)
        time.sleep(1)
    print()


def retry_after(resp, default=5):
    wait = default
    if isinstance(resp, dict):
        try:
            wait = int(resp.get("retryAfter") or default)
        except Exception:
            wait = default
    return max(wait, 1)


async def api(session, method, endpoint, init_data, payload=None, proxy=None):
    headers = dict(HEADERS_BASE)
    headers["x-telegram-init-data"] = init_data
    try:
        async with session.request(
            method,
            f"{BASE_URL}{endpoint}",
            headers=headers,
            json=payload,
            proxy=proxy,
            timeout=aiohttp.ClientTimeout(total=30),
        ) as r:
            raw = await r.read()
            try:
                data = json.loads(raw)
            except Exception:
                data = None
            return r.status, data
    except Exception as e:
        log_red(f"Request to {endpoint} failed with {type(e).__name__}")
        return None, None


async def track_ad(session, init_data, uid, proxy, ad_type):
    for _ in range(AD_TRACK_ATTEMPTS):
        code, resp = await api(session, "POST", "/api/ads/track", init_data, {"userId": uid, "type": ad_type}, proxy)
        if code == 200:
            return True
        if code == 429:
            await asyncio.sleep(retry_after(resp) + 1)
            continue
        return False
    return False


async def serve_ad(session, init_data, block_id, uid, proxy):
    block = normalize_block_id(block_id)
    fields = init_data_fields(init_data)
    signature = fields.get("signature")
    check_string = build_data_check_string(init_data)
    if not block or not signature or not check_string:
        return None
    try:
        user = json.loads(fields.get("user") or "{}")
    except Exception:
        user = {}
    params = {
        "envType": "telegram",
        "blockId": block,
        "platform": "Windows",
        "language": user.get("language_code") or "en",
        "is_premium": "true" if user.get("is_premium") else "false",
        "top_domain": BASE_URL.split("://")[-1],
        "signature": signature,
        "data_check_string": check_string,
        "sdk_version": ADSGRAM_SDK_VERSION,
        "tg_id": uid,
        "tg_platform": "android",
        "tma_version": "9.6",
    }
    try:
        async with session.get(
            ADSGRAM_URL,
            params=params,
            headers=adsgram_headers(),
            proxy=proxy,
            timeout=aiohttp.ClientTimeout(total=30),
        ) as r:
            raw = await r.read()
            if r.status != 200:
                return None
            payload = json.loads(raw)
    except Exception:
        return None
    if not isinstance(payload, dict) or not payload.get("banners"):
        return None
    return payload


async def fire_ad_events(session, payload, proxy):
    try:
        blob = json.dumps(payload)
    except Exception:
        return 0
    urls = {}
    for url in re.findall(r"https://api\.adsgram\.ai/event\?[^\s\"'<>\\]+", blob):
        name = (urllib.parse.parse_qs(urllib.parse.urlparse(url).query).get("type") or [""])[0]
        if name and name not in urls:
            urls[name] = url
    fired = 0
    for name in ADSGRAM_EVENT_ORDER:
        url = urls.get(name)
        if not url:
            continue
        try:
            async with session.get(
                url,
                headers=adsgram_headers(),
                proxy=proxy,
                timeout=aiohttp.ClientTimeout(total=20),
            ) as r:
                if r.status == 200:
                    fired += 1
        except Exception:
            continue
        await asyncio.sleep(1)
    return fired


async def run_ad_reward(session, init_data, uid, proxy, block_id):
    ad = await serve_ad(session, init_data, block_id, uid, proxy)
    if not ad:
        return None
    if not await fire_ad_events(session, ad, proxy):
        return None
    return ad


async def ad_status(session, init_data, uid, proxy):
    code, state = await api(session, "GET", f"/api/ads/status/{uid}", init_data, None, proxy)
    if code != 200 or not isinstance(state, dict):
        return None
    return state


async def claim_mining(session, init_data, uid, proxy, block_id=None):
    for attempt in range(1, CLAIM_ATTEMPTS + 1):
        code, resp = await api(session, "POST", "/api/game/claim", init_data, {"userId": uid}, proxy)
        if code == 200 and resp and resp.get("success"):
            log_green(f"Mining reward claimed and earned {resp.get('reward', 0)} coins")
            restart, _ = await api(session, "POST", "/api/game/feed", init_data, {"userId": uid}, proxy)
            if restart == 200:
                log_green("Mining session restarted after claim")
            else:
                log_red("Mining session failed to restart after claim")
            return True
        if code == 403:
            await run_ad_reward(session, init_data, uid, proxy, block_id)
            if attempt < CLAIM_ATTEMPTS:
                await asyncio.sleep(CLAIM_RETRY_SECONDS)
            continue
        if code == 429:
            await asyncio.sleep(retry_after(resp, 10) + 1)
            continue
        break
    log_yellow(f"Mining claim stayed locked after {CLAIM_ATTEMPTS} attempts because no verified ad view was recorded")
    return False


async def run_mining(session, init_data, uid, proxy, settings=None, final_pass=False):
    status, state = await api(session, "GET", f"/api/game/status/{uid}", init_data, None, proxy)
    if status != 200 or not state:
        log_red("Mining status could not be retrieved")
        return

    if state.get("canFeed"):
        code, resp = await api(session, "POST", "/api/game/feed", init_data, {"userId": uid}, proxy)
        if code == 200 and resp and resp.get("success"):
            log_green("processing mining session started")
        else:
            log_red("Mining session failed to start")
        return

    if state.get("rewardReady"):
        settings = settings or {}
        await claim_mining(session, init_data, uid, proxy, settings.get("adsgramBlockId"))
        return

    if final_pass:
        return

    remaining = format_duration(state.get("timeRemaining", 0))
    log_yellow(f"Mining reward is not ready yet, {remaining} remaining")


async def run_checkin(session, init_data, uid, proxy):
    code, resp = await api(session, "POST", "/api/checkin", init_data, {"userId": uid}, proxy)
    if code == 200 and resp and resp.get("success"):
        log_green(f"Daily check in completed and earned {resp.get('reward', 0)} coins with a {resp.get('streak', 1)} day streak")
        return
    if code == 400:
        log_yellow("Daily check in was already claimed for today")
        return
    log_yellow("Daily check in is not available right now")


async def run_tasks(session, init_data, uid, proxy):
    status, tasks = await api(session, "GET", "/api/tasks", init_data, None, proxy)
    if status != 200 or not isinstance(tasks, list):
        log_red("Task list could not be retrieved")
        return

    claimed = 0
    pending = 0
    for task in tasks:
        if task.get("type") == "telegram":
            continue
        task_id = task.get("id")
        code, resp = await api(session, "POST", "/api/tasks/complete", init_data, {"userId": uid, "taskId": task_id}, proxy)
        if code == 200 and resp and resp.get("success"):
            claimed += 1
        elif code == 400:
            continue
        else:
            pending += 1
        await asyncio.sleep(1)

    if claimed > 0:
        log_green(f"All available tasks completed for this account and {claimed} rewards were claimed")
    elif pending > 0:
        log_yellow(f"{pending} account tasks could not be completed on this run")
    else:
        log_green("Every available account task was already completed")


async def run_ad_missions(session, init_data, uid, proxy, settings):
    missions = settings.get("adTaskMissions") or []
    if not missions:
        return
    claimed = 0
    for mission in missions:
        mission_id = mission.get("id")
        label = clean_text(mission.get("label") or "Ad mission", "Ad mission")
        code, resp = await api(session, "POST", "/api/tasks/complete-ad-task", init_data, {"userId": uid, "taskId": mission_id}, proxy)
        if code == 400:
            continue
        if not (code == 200 and resp and resp.get("success")):
            await run_ad_reward(session, init_data, uid, proxy, mission.get("blockId") or settings.get("adsgramTaskBlockId"))
            code, resp = await api(session, "POST", "/api/tasks/complete-ad-task", init_data, {"userId": uid, "taskId": mission_id}, proxy)
            if code == 400:
                continue
        if code == 200 and resp and resp.get("success"):
            claimed += 1
            log_green(f"Ad mission {label} completed and earned {resp.get('reward', 0)} coins")
        else:
            log_yellow(f"Ad mission {label} could not be completed because the ad network served no ad")
        await asyncio.sleep(2)
    if claimed == 0:
        log_green("Every ad mission was already completed for this account")


async def run_ads(session, init_data, uid, proxy, settings):
    status, ad_state = await api(session, "GET", f"/api/ads/status/{uid}", init_data, None, proxy)
    if status != 200 or not ad_state:
        log_red("Ad status could not be retrieved")
        return

    watched = ad_state.get("adsWatchedToday", 0)
    per_day = ad_state.get("adsPerDay", 0)
    remaining = ad_state.get("adsRemaining", 0)
    coins = ad_state.get("apeCoinsPerAd", 0)
    block_id = settings.get("adsgramBlockId")

    if remaining <= 0:
        log_green(f"All {per_day} daily ad rewards are already claimed for this account")
        return

    log_yellow(f"Daily ad progress is {watched} out of {per_day} and {remaining} ad views remain")

    credited = 0
    empty = 0
    for _ in range(remaining):
        before = watched
        if not await track_ad(session, init_data, uid, proxy, "earn"):
            break
        ad = await run_ad_reward(session, init_data, uid, proxy, block_id)
        if not ad:
            empty += 1
            if empty >= AD_TRACK_ATTEMPTS:
                break
            await asyncio.sleep(3)
            continue
        empty = 0
        fresh = None
        for _ in range(AD_VERIFY_POLLS):
            await asyncio.sleep(AD_VERIFY_DELAY)
            fresh = await ad_status(session, init_data, uid, proxy)
            if fresh and fresh.get("adsWatchedToday", 0) > before:
                break
        if fresh and fresh.get("adsWatchedToday", 0) > before:
            watched = fresh.get("adsWatchedToday", watched)
            credited += 1
            log_green(f"Ad view {watched} out of {per_day} was watched and rewarded {coins} coins")
        else:
            log_yellow(f"Ad view {before + 1} out of {per_day} was served but the reward postback did not arrive")
        await asyncio.sleep(2)

    if credited > 0:
        log_green(f"All daily ad views were verified and {credited} ad rewards were applied")
    else:
        log_yellow("No ad reward could be verified on this run because the ad network served no advertisement")


async def process_account(init_data, proxy, index):
    user_info = parse_init_data(init_data)
    user_id = user_info.get("id")
    if not user_id:
        log_red(f"Account on line {index} holds invalid initData and was skipped")
        return

    uid = str(user_id)
    connector = aiohttp.TCPConnector(ssl=False)
    async with aiohttp.ClientSession(connector=connector) as session:
        code, init = await api(session, "POST", "/api/users/init", init_data, {
            "userId": uid,
            "username": user_info.get("username") or f"user_{uid}",
            "firstName": user_info.get("first_name") or "",
            "lastName": user_info.get("last_name") or "",
            "photoUrl": user_info.get("photo_url"),
            "isPremium": bool(user_info.get("is_premium")),
            "refereeId": REF_CODE,
        }, proxy)

        if code != 200 or not init or not init.get("user"):
            log_red("Login failed for this account")
            return

        user = init.get("user") or {}
        if user.get("isBanned"):
            log_red("Account is banned and was skipped")
            return

        username = clean_text(user.get("username") or user.get("firstName") or "Unknown", "Unknown")
        settings = init.get("settings") or {}
        skin = clean_text(user.get("apeSkin") or "baby", "baby")

        log_green(f"Account {username} loaded successfully")
        log_green(f"Total balance is {user.get('balance', 0)} coins")
        log_yellow(f"Ape level {user.get('apeLevel', 1)} with {skin} skin and {user.get('referralCount', 0)} referrals")

        await run_mining(session, init_data, uid, proxy, settings)
        await run_checkin(session, init_data, uid, proxy)
        await run_tasks(session, init_data, uid, proxy)
        await run_ad_missions(session, init_data, uid, proxy, settings)
        await run_ads(session, init_data, uid, proxy, settings)
        await run_mining(session, init_data, uid, proxy, settings, final_pass=True)

        code, final_user = await api(session, "GET", f"/api/users/{uid}", init_data, None, proxy)
        if code == 200 and final_user:
            log_green(f"Final balance is {final_user.get('balance', 0)} coins with {final_user.get('totalEarned', 0)} coins earned in total")


async def main_async(accounts, proxies, sleep_secs):
    cycle = 1
    while True:
        log_yellow(f"Starting automation cycle number {cycle}")

        for idx, init_data in enumerate(accounts):
            if idx > 0:
                print()

            proxy_line = get_proxy(proxies, idx)
            proxy_url = normalize_proxy(proxy_line) if proxy_line else None
            if proxy_url:
                log_yellow(f"Using proxy {mask_proxy(proxy_url)}")

            await process_account(init_data, proxy_url, idx + 1)

        log_yellow(f"Automation cycle number {cycle} is complete and all accounts were processed")
        cycle += 1
        countdown(sleep_secs)
        show_banner(MY_PROJECT)


def main():
    show_banner(MY_PROJECT)

    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

    config = load_config()
    sleep_secs = config.get("settings", {}).get("sleep_seconds", 3600)
    accounts = load_data()
    proxies = load_proxies()
    asyncio.run(main_async(accounts, proxies, sleep_secs))


if __name__ == "__main__":
    main()
