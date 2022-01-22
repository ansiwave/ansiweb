import core
import unicode
import tables
from ansiwavepkg/illwill as iw import `[]`, `[]=`

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
  try:
    tick()
  except Exception as ex:
    stderr.writeLine(ex.msg)
    stderr.writeLine(getStackTrace(ex))
    core.failAle = true

const
  nameToIllwillKey =
    {"Backspace": iw.Key.Backspace,
     "Delete": iw.Key.Delete,
     "Tab": iw.Key.Tab,
     "Enter": iw.Key.Enter,
     "Escape": iw.Key.Escape,
     "ArrowUp": iw.Key.Up,
     "ArrowDown": iw.Key.Down,
     "ArrowLeft": iw.Key.Left,
     "ArrowRight": iw.Key.Right,
     "Home": iw.Key.Home,
     "End": iw.Key.End,
     "PageUp": iw.Key.PageUp,
     "PageDown": iw.Key.PageDown,
     "Insert": iw.Key.Insert,
    }.toTable
  nameToIllwillCtrlKey =
    {"a": iw.Key.CtrlA,
     "b": iw.Key.CtrlB,
     "c": iw.Key.CtrlC,
     "d": iw.Key.CtrlD,
     "e": iw.Key.CtrlE,
     "f": iw.Key.CtrlF,
     "g": iw.Key.CtrlG,
     "h": iw.Key.CtrlH,
     # Ctrl-I is Tab
     "j": iw.Key.CtrlJ,
     "k": iw.Key.CtrlK,
     "l": iw.Key.CtrlL,
     # Ctrl-M is Enter
     "n": iw.Key.CtrlN,
     "o": iw.Key.CtrlO,
     "p": iw.Key.CtrlP,
     "q": iw.Key.CtrlQ,
     "r": iw.Key.CtrlR,
     "s": iw.Key.CtrlS,
     "t": iw.Key.CtrlT,
     "u": iw.Key.CtrlU,
     "v": iw.Key.CtrlV,
     "w": iw.Key.CtrlW,
     "x": iw.Key.CtrlX,
     "y": iw.Key.CtrlY,
     "z": iw.Key.CtrlZ,
     "\\": iw.Key.CtrlBackslash,
     "]": iw.Key.CtrlRightBracket,
     }.toTable

proc onKeyDown(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer) {.cdecl.} =
  let
    key = $cast[cstring](keyEvent.key.addr)
    keys = key.toRunes
  if keys.len == 1:
    if keyEvent.ctrlKey == 0 and keyEvent.altKey == 0 and keyEvent.metaKey == 0:
      onChar(uint32(keys[0]))
    elif keyEvent.ctrlKey == 1 and key in nameToIllwillCtrlKey:
      onKeyPress(nameToIllwillCtrlKey[key])
  elif keys.len > 1:
    if key in nameToIllwillKey:
      onKeyPress(nameToIllwillKey[key])

proc main*() =
  init()

  discard emscripten_set_keydown_callback("body", nil, true, onKeyDown)
  emscripten_set_main_loop(mainLoop, 0, true)

