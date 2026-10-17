import std/[json, os, strutils]
import ../net/[client, adsgram]
import ../support/log

const POLL_ROUNDS = 6
const POLL_PAUSE = 2
const UNVERIFIED_LIMIT = 3
const AD_PAUSE = 12

proc adStatus(session: Session): JsonNode =
  let (code, node) = session.callJson("GET", "/api/ads/status/" & session.userId)
  if code == 200: node else: newJObject()

proc track(session: Session, kind: string): int =
  let (code, node) = session.callJson("POST", "/api/ads/track",
    %*{"userId": session.userId, "type": kind})
  if code == 200: 200 else: code

proc runAds*(session: Session, settings: JsonNode, language: string, isPremium: bool) =
  let blockId = valueOf(settings, "adsgramBlockId")
  let perDay = intOf(settings, "adsPerDay", 0)
  let coins = intOf(settings, "apeCoinsPerAd", 0)
  if blockId.len == 0:
    red("The rewarded ad slot is missing from the server settings")
    return

  var state = adStatus(session)
  var watched = intOf(state, "adsWatchedToday", 0)
  let before = watched
  var credited = 0
  var unverified = 0

  while watched < perDay:
    discard track(session, "earn")
    let served = serveAd(session, blockId, language, isPremium)
    if not served.ok:
      yellow("The ad network served no advertisement for this account on this run")
      break
    var landed = false
    for _ in 1 .. POLL_ROUNDS:
      sleep(POLL_PAUSE * 1000)
      state = adStatus(session)
      let nowWatched = intOf(state, "adsWatchedToday", 0)
      if nowWatched > watched:
        watched = nowWatched
        landed = true
        break
    if landed:
      inc credited
      green("Ad view " & $watched & " of " & $perDay & " was credited with " & $coins & " coins on this account")
    else:
      inc unverified
      yellow("Ad view number " & $(unverified) & " returned no credit from the ad network on this run")
      if unverified >= UNVERIFIED_LIMIT:
        break
    if watched < perDay:
      countdown(AD_PAUSE, "Next ad view starts in")

  let gained = watched - before
  if gained > 0:
    green("Rewarded ads credited " & $credited & " views and " & $(credited * coins) & " coins on this account")
  elif watched >= perDay:
    green("Every rewarded ad view for this account was already watched today")
