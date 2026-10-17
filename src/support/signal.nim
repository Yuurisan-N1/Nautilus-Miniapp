import ./log

when defined(windows):
  type
    CtrlHandler = proc (ctrlType: uint32): int32 {.stdcall.}

  proc setConsoleCtrlHandler(handler: CtrlHandler, add: int32): int32
    {.stdcall, dynlib: "kernel32", importc: "SetConsoleCtrlHandler".}
  proc exitProcess(code: uint32)
    {.stdcall, dynlib: "kernel32", importc: "ExitProcess".}
  proc getStdHandle(kind: int32): pointer
    {.stdcall, dynlib: "kernel32", importc: "GetStdHandle".}
  proc writeHandle(handle: pointer, data: pointer, size: uint32,
                   written: ptr uint32, overlapped: pointer): int32
    {.stdcall, dynlib: "kernel32", importc: "WriteFile".}

  const STD_OUTPUT_HANDLE = -11'i32
  const CTRL_C_EVENT = 0'u32
  const CTRL_BREAK_EVENT = 1'u32
  const CTRL_CLOSE_EVENT = 2'u32

  const STOP_LINE = "\r\n" & RED & BOLD & "Script stopped by user" & RESET & "\r\n"

  proc emit(text: string) =
    if text.len == 0:
      return
    let handle = getStdHandle(STD_OUTPUT_HANDLE)
    if handle == nil:
      return
    var written: uint32 = 0
    discard writeHandle(handle, unsafeAddr text[0], uint32(text.len), addr written, nil)

  proc onCtrl(ctrlType: uint32): int32 {.stdcall.} =
    if ctrlType in [CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT]:
      emit(STOP_LINE)
      exitProcess(0)
      return 1
    return 0

proc installSignal*() =
  when defined(windows):
    discard setConsoleCtrlHandler(onCtrl, 1)
  else:
    setControlCHook(proc() {.noconv.} =
      stdout.write("\n")
      stdout.flushFile()
      red("Script stopped by user")
      quit(0))
