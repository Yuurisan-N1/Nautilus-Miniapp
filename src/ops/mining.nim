import std/[json, os, strutils]
import ../net/[client, adsgram]
import ../support/log

const CLAIM_POLLS = 10
const CLAIM_POLL_PAUSE = 2
const AD_ATTEMPTS = 3

proc gameStatus(session: Session): JsonNode =
  let (code, node) = session.callJson("GET", "/api/game/status/" & session.userId)
  if code == 200: node else: newJObject()

proc feed(session: Session): int =
  let (code, _) = session.callJson("POST", "/api/game/feed", %*{"userId": session.userId})
  code

proc claim(session: Session): tuple[code: int, reward: int, message: string] =
  let (code, node) = session.callJson("POST", "/api/game/claim", %*{"userId": session.userId})
  result = (code, intOf(node, "reward", 0), valueOf(node, "message"))
  if result.message.len == 0:
    result.message = valueOf(node, "error")

proc settle(session: Session): bool =
  for _ in 1 .. CLAIM_POLLS:
    let (code, reward, _) = claim(session)
    if code == 200:
      green("Mining reward of " & $reward & " coins was claimed on this account")
      if feed(session) == 200:
        green("Mining session was restarted after the claim landed")
      else:
        yellow("Mining session did not restart after the claim landed")
      return true
    sleep(CLAIM_POLL_PAUSE * 1000)
  return false

proc claimReward(session: Session, settings: JsonNode, language: string, isPremium: bool): bool =
  let blockId = valueOf(settings, "adsgramBlockId")
  let (code, _, message) = claim(session)
  if code == 200:
    green("Mining reward was claimed on this account without a new advertisement")
    discard feed(session)
    return true
  if "watch an ad" notin message.toLowerAscii():
    yellow("Mining claim was refused by the server on this run")
    return false
  if blockId.len == 0:
    red("The rewarded ad slot is missing from the server settings")
    return false
  discard session.callJson("POST", "/api/ads/track",
    %*{"userId": session.userId, "type": "mining"})
  var served = false
  for _ in 1 .. AD_ATTEMPTS:
    if serveAd(session, blockId, language, isPremium).ok:
      served = true
      break
  if not served:
    yellow("Mining claim stayed locked because the ad network served no advertisement on this run")
    return false
  if settle(session):
    return true
  yellow("Mining claim stayed locked because the ad step did not land")
  return false

proc upgradeApe(session: Session, settings: JsonNode, balance: float) =
  let levels = settings{"apeLevels"}
  if levels == nil or levels.kind != JArray:
    return
  let state = gameStatus(session)
  let current = intOf(state, "apeLevel", 0)
  for entry in levels:
    if intOf(entry, "level", 0) == current + 1:
      let cost = floatOf(entry, "cost", 0.0)
      if cost > 0.0 and balance >= cost:
        let (code, _) = session.callJson("POST", "/api/game/upgrade")
        if code == 200:
          green("Mining ape was upgraded to level " & $(current + 1) & " on this account")
        else:
          yellow("Mining ape upgrade was refused by the server on this run")
      elif cost > 0.0:
        yellow("Mining ape upgrade was skipped because the balance is short")
      return

proc runMining*(session: Session, settings: JsonNode, language: string, isPremium: bool, balance: float) =
  let state = gameStatus(session)
  if state.len == 0:
    red("Mining status could not be retrieved for this account")
    return
  if boolOf(state, "canFeed", false):
    if feed(session) == 200:
      green("Mining session was started on this account")
    else:
      red("Mining session failed to start on this account")
    return
  if boolOf(state, "rewardReady", false):
    discard claimReward(session, settings, language, isPremium)
  else:
    yellow("Mining reward is not ready yet on this account")
  upgradeApe(session, settings, balance)
