import std/[httpclient, json, net, os, strutils, uri]

const USER_AGENT* = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " &
  "(KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36 Edg/152.0.0.0"

type
  Session* = ref object
    client*: HttpClient
    base*: string
    initData*: string
    userId*: string
    label*: string

proc userJson*(initData: string): JsonNode =
  try:
    let query = parseUri("?" & initData).query
    for pair in query.split("&"):
      let kv = pair.split("=", maxsplit = 1)
      if kv.len == 2 and kv[0] == "user":
        return parseJson(decodeUrl(kv[1]))
  except CatchableError:
    discard
  return newJObject()

proc userIdOf*(initData: string): string =
  let user = userJson(initData)
  if user.hasKey("id"):
    return $user["id"].getInt()
  return ""

proc accountLabel*(initData: string): string =
  let user = userJson(initData)
  for key in ["username", "first_name"]:
    if user.hasKey(key) and user[key].kind == JString and user[key].getStr().len > 0:
      return user[key].getStr()
  return "Unknown"

proc newSession*(base: string, initData: string, proxy: string): Session =
  var client: HttpClient
  if proxy.len > 0:
    let parsed = parseUri(proxy)
    var auth = ""
    if parsed.username.len > 0:
      auth = parsed.username & ":" & parsed.password
    let target = parsed.scheme & "://" & parsed.hostname & ":" & $parsed.port
    client = newHttpClient(proxy = newProxy(target, auth), timeout = 40000,
      userAgent = USER_AGENT)
  else:
    client = newHttpClient(timeout = 40000, userAgent = USER_AGENT)
  client.headers = newHttpHeaders({
    "accept": "application/json, text/plain, */*",
    "content-type": "application/json",
    "origin": base,
    "referer": base & "/",
    "x-telegram-init-data": initData
  })
  result = Session(client: client, base: base, initData: initData,
    userId: userIdOf(initData), label: accountLabel(initData))

proc close*(session: Session) =
  if session != nil and session.client != nil:
    session.client.close()

proc call*(session: Session, verb, path: string, body: JsonNode = nil): tuple[code: int, raw: string] =
  var payload = ""
  if body != nil:
    payload = $body
  try:
    if verb == "GET":
      let response = session.client.get(session.base & path)
      result = (response.code.int, response.body)
    elif verb == "POST":
      let response = session.client.post(session.base & path, payload)
      result = (response.code.int, response.body)
    else:
      let response = session.client.request(session.base & path, httpMethod = HttpPost,
        body = payload)
      result = (response.code.int, response.body)
  except CatchableError as error:
    result = (0, "transport failure: " & error.msg)

proc callJson*(session: Session, verb, path: string, body: JsonNode = nil): tuple[code: int, node: JsonNode] =
  let (code, raw) = call(session, verb, path, body)
  var node = newJObject()
  if raw.len > 0:
    try:
      node = parseJson(raw)
    except CatchableError:
      node = newJObject()
  result = (code, node)

proc valueOf*(node: JsonNode, key: string, fallback: string = ""): string =
  if node != nil and node.kind == JObject and node.hasKey(key):
    let value = node[key]
    case value.kind
    of JString: return value.getStr()
    of JInt: return $value.getInt()
    of JFloat: return $value.getFloat()
    of JBool: return $value.getBool()
    else: return fallback
  return fallback

proc intOf*(node: JsonNode, key: string, fallback: int = 0): int =
  if node != nil and node.kind == JObject and node.hasKey(key):
    let value = node[key]
    case value.kind
    of JInt: return value.getInt()
    of JFloat: return int(value.getFloat())
    of JString:
      try: return parseInt(value.getStr())
      except CatchableError: return fallback
    else: return fallback
  return fallback

proc floatOf*(node: JsonNode, key: string, fallback: float = 0.0): float =
  if node != nil and node.kind == JObject and node.hasKey(key):
    let value = node[key]
    case value.kind
    of JFloat: return value.getFloat()
    of JInt: return float(value.getInt())
    of JString:
      try: return parseFloat(value.getStr())
      except CatchableError: return fallback
    else: return fallback
  return fallback

proc boolOf*(node: JsonNode, key: string, fallback: bool = false): bool =
  if node != nil and node.kind == JObject and node.hasKey(key):
    let value = node[key]
    case value.kind
    of JBool: return value.getBool()
    of JInt: return value.getInt() != 0
    else: return fallback
  return fallback
