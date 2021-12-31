import core
from strutils import nil
import unicode

const EM_HTML5_SHORT_STRING_LEN_BYTES = 32

type
  EmscriptenKeyboardEvent* {.bycopy.} = object
    timestamp*: cdouble
    location*: culong
    ctrlKey*: cint
    shiftKey*: cint
    altKey*: cint
    metaKey*: cint
    repeat*: cint
    charCode*: culong
    keyCode*: culong
    which*: culong
    key*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
    code*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
    charValue*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
    locale*: array[EM_HTML5_SHORT_STRING_LEN_BYTES, uint8]
  em_key_callback_func = proc (eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer) {.cdecl.}

proc emscripten_set_main_loop(f: proc() {.cdecl.}, a: cint, b: bool) {.importc, header: "<emscripten/emscripten.h>".}
proc emscripten_set_keydown_callback(target: cstring, userData: pointer, useCapture: bool, callback: em_key_callback_func): cint {.importc, header: "<emscripten/html5.h>".}

proc mainLoop() {.cdecl.} =
  tick()

proc onKeyDown(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer) {.cdecl.} =
  let
    key = $cast[cstring](keyEvent.key.addr)
    keys = key.toRunes
  if keys.len > 1:
    echo "(", key, ")"
  else:
    echo key

proc main*() =
  init()

  discard emscripten_set_keydown_callback("body", nil, true, onKeyDown)
  emscripten_set_main_loop(mainLoop, 0, true)

