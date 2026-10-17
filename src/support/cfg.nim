import std/[json, os, strutils]

const DEFAULT_SLEEP = 3600

var rootDir = ""

proc root*(): string =
  if rootDir.len == 0:
    let beside = getAppDir()
    if fileExists(beside / "data.txt"):
      rootDir = beside
    else:
      rootDir = getCurrentDir()
  rootDir

proc configPath*(): string = root() / "config.json"
proc dataPath*(): string = root() / "data.txt"
proc proxyPath*(): string = root() / "proxy.txt"

proc writeDefaultConfig() =
  let node = %*{"settings": {"sleep_seconds": DEFAULT_SLEEP}}
  writeFile(configPath(), node.pretty(2) & "\n")

proc loadLines*(name: string): seq[string] =
  let path = root() / name
  if not fileExists(path):
    return @[]
  for raw in readFile(path).splitLines():
    let line = raw.strip()
    if line.len == 0 or line.startsWith("#"):
      continue
    result.add(line)

proc sleepSeconds*(): int =
  if not fileExists(configPath()):
    writeDefaultConfig()
  try:
    let node = parseFile(configPath())
    result = node["settings"]["sleep_seconds"].getInt()
  except CatchableError:
    result = DEFAULT_SLEEP
  if result < 1:
    result = DEFAULT_SLEEP
