import std/[algorithm, base64, httpclient, json, net, re, strutils, uri]
import ./client

const ADV_HOST = "https://api.adsgram.ai/adv"
let EVENT_PATTERN = re"""https://api\.adsgram\.ai/event\?[^\s"'<>\\]+"""
const EVENT_ORDER = ["show", "start", "render", "complete", "Reward"]

proc checkString(initData: string): string =
  var pairs: seq[string]
  for pair in initData.split("&"):
    let kv = pair.split("=", maxsplit = 1)
    if kv.len != 2:
      continue
    let key = decodeUrl(kv[0])
    if key == "hash" or key == "signature":
      continue
    pairs.add(key & "=" & decodeUrl(kv[1]))
  pairs.sort()
  let joined = pairs.join("\n")
  result = base64.encode(joined)
  result = result.replace('+', '-').replace('/', '_').replace("=", "")

proc param(initData, key: string): string =
  for pair in initData.split("&"):
    let kv = pair.split("=", maxsplit = 1)
    if kv.len == 2 and decodeUrl(kv[0]) == key:
      return decodeUrl(kv[1])
  return ""

proc typeOfEvent(url: string): string =
  let query = parseUri(url).query
  for pair in query.split("&"):
    let kv = pair.split("=", maxsplit = 1)
    if kv.len == 2 and kv[0] == "type":
      return kv[1]
  return ""

proc serveAd*(session: Session, blockId, language: string, isPremium: bool): tuple[ok: bool, banners: int, fired: int] =
  if blockId.len == 0:
    return (false, 0, 0)
  let host = parseUri(session.base).hostname
  let query = encodeQuery({
    "envType": "telegram",
    "blockId": blockId,
    "platform": "Win32",
    "language": (if language.len > 0: language else: "en"),
    "is_premium": (if isPremium: "true" else: "false"),
    "top_domain": host,
    "signature": param(session.initData, "signature"),
    "data_check_string": checkString(session.initData),
    "sdk_version": "2.2.4",
    "tg_id": session.userId,
    "tg_platform": "android",
    "tma_version": "9.6"
  })
  var raw = ""
  var banners = 0
  let adClient = newHttpClient(timeout = 30000, userAgent = USER_AGENT)
  adClient.headers = newHttpHeaders({
    "accept": "*/*",
    "origin": session.base,
    "referer": session.base & "/"
  })
  try:
    let response = adClient.get(ADV_HOST & "?" & query)
    if response.code.int != 200:
      adClient.close()
      return (false, 0, 0)
    raw = response.body
    let node = parseJson(raw)
    if node.hasKey("banners") and node["banners"].kind == JArray:
      banners = node["banners"].len
  except CatchableError:
    adClient.close()
    return (false, 0, 0)

  var urls: seq[string]
  for found in findAll(raw, EVENT_PATTERN):
    let kind = typeOfEvent(found)
    if kind.len == 0:
      continue
    var known = false
    for existing in urls:
      if typeOfEvent(existing) == kind:
        known = true
        break
    if known:
      continue
    urls.add(found)

  var fired = 0
  for name in EVENT_ORDER:
    var target = ""
    for url in urls:
      if typeOfEvent(url) == name:
        target = url
        break
    if target.len == 0:
      continue
    try:
      let response = adClient.get(target)
      if response.code.int == 200:
        inc fired
    except CatchableError:
      discard
  adClient.close()
  result = (fired > 0, banners, fired)
