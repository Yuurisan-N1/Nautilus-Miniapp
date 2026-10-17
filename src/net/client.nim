import std/[httpclient, json, net, os, strutils, uri]

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

when defined(ssl):
  proc caFile(): string =
    let fromEnv = getEnv("SSL_CERT_FILE")
    if fromEnv.len > 0 and fileExists(fromEnv):
      return fromEnv
    for folder in [getAppDir(), getCurrentDir()]:
      let candidate = folder / "cacert.pem"
      if fileExists(candidate):
        return candidate
    return ""

proc newSession*(base: string, initData: string, proxy: string): Session =
  var client: HttpClient
  when defined(ssl):
    let ca = caFile()
    let context = if ca.len > 0: newContext(caFile = ca) else: newContext()
    if proxy.len > 0:
      let parsed = parseUri(proxy)
      var auth = ""
      if parsed.username.len > 0:
        auth = parsed.username & ":" & parsed.password
      let target = parsed.scheme & "://" & parsed.hostname & ":" & $parsed.port
      client = newHttpClient(proxy = newProxy(target, auth), timeout = 40000,
        sslContext = context)
    else:
      client = newHttpClient(timeout = 40000, sslContext = context)
  else:
    if proxy.len > 0:
      let parsed = parseUri(proxy)
      var auth = ""
      if parsed.username.len > 0:
        auth = parsed.username & ":" & parsed.password
      let target = parsed.scheme & "://" & parsed.hostname & ":" & $parsed.port
      client = newHttpClient(proxy = newProxy(target, auth), timeout = 40000)
    else:
      client = newHttpClient(timeout = 40000)
  client.headers = newHttpHeaders({
    "accept": "application/json, text/plain, */*",
    "content-type": "application/json",
    "origin": base,
    "referer": base & "/",
    "user-agent": "Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Mobile Safari/537.36",
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
