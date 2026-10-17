import std/[os, strutils, times]

const
  GREEN* = "\e[92m"
  YELLOW* = "\e[93m"
  RED* = "\e[91m"
  BOLD* = "\e[1m"
  RESET* = "\e[0m"

proc green*(message: string) =
  stdout.writeLine(GREEN & BOLD & message & RESET)
  stdout.flushFile()

proc yellow*(message: string) =
  stdout.writeLine(YELLOW & BOLD & message & RESET)
  stdout.flushFile()

proc red*(message: string) =
  stdout.writeLine(RED & BOLD & message & RESET)
  stdout.flushFile()

proc pad2(value: int): string =
  if value < 10: "0" & $value else: $value

proc duration(total: int): string =
  let left = max(total, 0)
  pad2(left div 3600) & ":" & pad2((left mod 3600) div 60) & ":" & pad2(left mod 60)

proc countdown*(seconds: int, label: string) =
  var left = max(seconds, 0)
  if left < 1:
    return
  var width = 0
  while left > 0:
    let frame = label & " " & duration(left)
    stdout.write("\r" & YELLOW & BOLD & frame & RESET)
    stdout.flushFile()
    width = max(width, frame.len)
    sleep(1000)
    left -= 1
  stdout.write("\r" & repeat(' ', width) & "\r")
  stdout.flushFile()

proc stamp*(): string =
  now().format("dd-MM-yyyy HH:mm:ss")
