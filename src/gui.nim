import core
from strutils import nil

when defined(emscripten):
  proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc.}
  proc emscripten_get_canvas_element_size(target: cstring, width: ptr cint, height: ptr cint): cint {.importc.}
  proc emscripten_set_canvas_element_size(target: cstring, width: cint, height: cint) {.importc.}
  from wavecorepkg/client/emscripten import nil

proc mainLoop() {.cdecl.} =
  tick()

proc main*() =
  init()

  emscripten_set_main_loop(mainLoop, 0, true)

