import std/strutils
import ../support/cfg

proc maskProxy*(proxyUrl: string): string =
  try:
    let value = proxyUrl.split("://")[^1]
    let afterAt = value.split("@")[^1]
    let parts = afterAt.split(":")
    let hostPart = parts[0]
    let portPart = if parts.len > 1: parts[1] else: ""
    let octets = hostPart.split(".")
    var maskedHost = ""
    if octets.len == 4:
      maskedHost = octets[0] & "*****" & octets[3]
    elif hostPart.len > 4:
      maskedHost = hostPart[0 .. 1] & "*****" & hostPart[^2 .. ^1]
    else:
      maskedHost = "***"
    let suffix = if portPart.len > 0: ":" & portPart else: ""
    result = "http://user:pass@" & maskedHost & suffix
  except CatchableError:
    result = "http://user:pass@***:***"

proc normalizeProxy*(line: string): string =
  let value = line.strip()
  if value.len == 0:
    return ""
  if value.contains("://"):
    return value
  let parts = value.split(":")
  if parts.len == 2:
    return "http://" & parts[0] & ":" & parts[1]
  if parts.len == 4:
    return "http://" & parts[2] & ":" & parts[3] & "@" & parts[0] & ":" & parts[1]
  value

proc proxyFor*(proxies: seq[string], index: int): string =
  if proxies.len == 0:
    return ""
  normalizeProxy(proxies[index mod proxies.len])

proc loadProxies*(): seq[string] =
  for line in loadLines("proxy.txt"):
    let normalized = normalizeProxy(line)
    if normalized.len > 0:
      result.add(normalized)
