import ./log

const ART = "__   __                _                     _\n" &
  "\\ \\ / /   _ _   _ _ __(_)___  __ _ _ __   __| | ___  ___ _   _\n" &
  " \\ V / | | | | | | '__| / __|/ _` | '_ \\ / _` |/ _ \\/ __| | | |\n" &
  "  | || |_| | |_| | |  | \\__ \\ (_| | | | | (_| |  __/\\__ \\ |_| |\n" &
  "  |_| \\__,_|\\__,_|_|  |_|___/\\__,_|_| |_|\\_,__|\\___||___/\\__,_|"

const COMMUNITY = "https://t.me/Y3YuYuYo"

proc setTitle(project: string) =
  stdout.write("\e]2;" & project & " by : 佐賀県産 (YUURI)\a")
  stdout.flushFile()

proc showBanner*(project: string) =
  setTitle(project)
  stdout.write("\e[H\e[2J\e[3J")
  stdout.write("\e[36m\e[1m" & ART & "\e[0m\n\n")
  stdout.write("\e[35m\e[1mWelcome to Yuuri's " & project & "\e[0m\n")
  stdout.write("\e[32m\e[1mJoin our community: " & COMMUNITY & "\e[0m\n")
  stdout.write("\e[33m\e[1mCurrent time: " & stamp() & "\e[0m\n")
  stdout.write("\n")
  stdout.flushFile()
