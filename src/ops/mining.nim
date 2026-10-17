import std/[json, os]
import ../net/client
import ../support/log

const CLAIM_ATTEMPTS = 4
const CLAIM_PAUSE = 6

proc gameStatus(session: Session): JsonNode =
  let (code, node) = session.callJson("GET", "/api/game/status/" & session.userId)
  if code == 200: node else: newJObject()

proc feed(session: Session): int =
  let (code, _) = session.callJson("POST", "/api/game/feed", %*{"userId": session.userId})
  code

proc claim(session: Session): tuple[code: int, reward: int] =
  let (code, node) = session.callJson("POST", "/api/game/claim", %*{"userId": session.userId})
  result = (code, intOf(node, "reward", 0))

proc claimReward(session: Session): bool =
  for attempt in 1 .. CLAIM_ATTEMPTS:
    discard session.callJson("POST", "/api/ads/track",
      %*{"userId": session.userId, "type": "mining"})
    let (code, reward) = claim(session)
    if code == 200:
      green("Mining reward of " & $reward & " coins was claimed on this account")
      if feed(session) == 200:
        green("Mining session was restarted after the claim landed")
      else:
        yellow("Mining session did not restart after the claim landed")
      return true
    if code == 403 and attempt < CLAIM_ATTEMPTS:
      countdown(CLAIM_PAUSE, "Next mining claim starts in")
      continue
    if code == 429 and attempt < CLAIM_ATTEMPTS:
      countdown(CLAIM_PAUSE, "Next mining claim starts in")
      continue
    break
  yellow("Mining claim stayed locked because the ad step did not land")
  return false

proc upgradeApe(session: Session, settings: JsonNode, balance: float) =
  let level = 0
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
  discard level

proc runMining*(session: Session, settings: JsonNode, balance: float) =
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
    discard claimReward(session)
  else:
    yellow("Mining reward is not ready yet on this account")
  upgradeApe(session, settings, balance)
