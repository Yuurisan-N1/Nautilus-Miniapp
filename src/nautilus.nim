import std/[json, os, strutils]
import support/[banner, cfg, log, signal]
import net/[client, egress]
import ops/[account, tasks, ads, mining]

const PROJECT = "Nautilus Miniapp"
const BASE_URL = "https://nautilus.onelabs.online"
const REFERRAL_ID = "6004380466"

proc processAccount(initData, proxy: string) =
  let session = newSession(BASE_URL, initData, proxy)
  try:
    if proxy.len > 0:
      yellow("Using proxy " & maskProxy(proxy))
    let (user, settings) = bootstrap(session, REFERRAL_ID)
    if user.len == 0:
      red("Account " & session.label & " could not be signed in on this run")
      return
    let profile = userJson(initData)
    let language = valueOf(profile, "language_code")
    let isPremium = boolOf(profile, "is_premium", false)
    green("Account " & session.label & " logged in with " & $int(balanceOf(user)) & " coins")
    runTasks(session)
    runAdMissions(session, settings, language, isPremium)
    runAds(session, settings, language, isPremium)
    runMining(session, settings, language, isPremium, balanceOf(user))
    runCheckin(session)
    let fresh = refresh(session)
    runInviteTasks(session, fresh)
    green("Cycle closed with a balance of " & $int(balanceOf(fresh)) & " coins")
  except CatchableError:
    red("Account " & session.label & " was skipped after an unexpected error")
  finally:
    session.close()

proc main() =
  installSignal()
  showBanner(PROJECT)

  let accounts = loadLines("data.txt")
  if accounts.len == 0:
    red("File data.txt is empty, please add your initData entries")
    quit(1)

  let proxies = loadProxies()

  var cycle = 1
  while true:
    yellow("Starting automation cycle number " & $cycle)
    for index, account in accounts:
      if index > 0:
        stdout.write("\n")
        stdout.flushFile()
      processAccount(account, proxyFor(proxies, index))
    yellow("All accounts were processed for cycle number " & $cycle)
    countdown(sleepSeconds(), "Next cycle starts in")
    showBanner(PROJECT)
    inc cycle

main()
