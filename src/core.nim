from ./constants import nil
import deques
from wavecorepkg/paths import nil
from strutils import format
import tables

from ansiwavepkg/bbs import nil
from ansiwavepkg/illwill as iw import `[]`, `[]=`
from ansiwavepkg/codes import nil
import unicode

from wavecorepkg/client import nil
from os import joinPath
from terminal import nil

when defined(emscripten):
  from wavecorepkg/client/emscripten import nil
  from ansiwavepkg/ui/editor import nil

var
  clnt: client.Client
  session*: bbs.BbsSession
  keyQueue: Deque[(iw.Key, iw.MouseInfo)]
  charQueue: Deque[uint32]

proc onKeyPress*(key: iw.Key) =
  keyQueue.addLast((key, iw.gMouseInfo))

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  charQueue.addLast(codepoint)

proc onMouseClick*(button: iw.MouseButton, action: iw.MouseButtonAction) =
  iw.gMouseInfo.button = button
  iw.gMouseInfo.action = action
  keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc onMouseUpdate*(xpos: float, ypos: float) =
  discard

proc onMouseMove*(xpos: float, ypos: float) =
  onMouseUpdate(xpos, ypos)
  if iw.gMouseInfo.action == iw.MouseButtonAction.mbaPressed and bbs.isEditor(session):
    keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc onWindowResize*(windowWidth: int, windowHeight: int) =
  discard

when defined(emscripten):
  proc hashChanged() {.exportc.} =
    bbs.insertHash(session, emscripten.getHash())

type
  Vec4 = tuple[r: int, g: int, b: int, a: float]

proc fgColorToVec4(ch: iw.TerminalChar, defaultColor: Vec4): Vec4 =
  if ch.fgTruecolor != iw.rgbNone:
    let (r, g, b) = ch.fgTruecolor
    (r.int, g.int, b.int, 1.0)
  else:
    if terminal.styleBright in ch.style:
      case ch.fg:
      of iw.fgNone: defaultColor
      of iw.fgBlack: constants.blackColor
      of iw.fgRed: constants.brightRedColor
      of iw.fgGreen: constants.brightGreenColor
      of iw.fgYellow: constants.brightYellowColor
      of iw.fgBlue: constants.brightBlueColor
      of iw.fgMagenta: constants.brightMagentaColor
      of iw.fgCyan: constants.brightCyanColor
      of iw.fgWhite: constants.whiteColor
    else:
      case ch.fg:
      of iw.fgNone: defaultColor
      of iw.fgBlack: constants.blackColor
      of iw.fgRed: constants.redColor
      of iw.fgGreen: constants.greenColor
      of iw.fgYellow: constants.yellowColor
      of iw.fgBlue: constants.blueColor
      of iw.fgMagenta: constants.magentaColor
      of iw.fgCyan: constants.cyanColor
      of iw.fgWhite: constants.whiteColor

proc bgColorToVec4(ch: iw.TerminalChar, defaultColor: Vec4): Vec4 =
  if ch.bgTruecolor != iw.rgbNone:
    let (r, g, b) = ch.bgTruecolor
    (r.int, g.int, b.int, 1.0)
  else:
    if terminal.styleBright in ch.style:
      case ch.bg:
      of iw.bgNone: defaultColor
      of iw.bgBlack: constants.blackColor
      of iw.bgRed: constants.brightRedColor
      of iw.bgGreen: constants.brightGreenColor
      of iw.bgYellow: constants.brightYellowColor
      of iw.bgBlue: constants.brightBlueColor
      of iw.bgMagenta: constants.brightMagentaColor
      of iw.bgCyan: constants.brightCyanColor
      of iw.bgWhite: constants.whiteColor
    else:
      case ch.bg:
      of iw.bgNone: defaultColor
      of iw.bgBlack: constants.blackColor
      of iw.bgRed: constants.redColor
      of iw.bgGreen: constants.greenColor
      of iw.bgYellow: constants.yellowColor
      of iw.bgBlue: constants.blueColor
      of iw.bgMagenta: constants.magentaColor
      of iw.bgCyan: constants.cyanColor
      of iw.bgWhite: constants.whiteColor

proc init*() =
  clnt = client.initClient(paths.address, paths.postAddress)
  client.start(clnt)

  bbs.init()

  var hash: Table[string, string]
  when defined(emscripten):
    hash = editor.parseHash(emscripten.getHash())
  if "board" notin hash:
    hash["board"] = paths.defaultBoard

  session = bbs.initSession(clnt, hash)

var
  lastContent = ""
  termWidth = 84
  termHeight = 42

proc tick*() =
  var finishedLoading = false

  let tb = bbs.tick(session, clnt, termWidth, termHeight, (iw.Key.None, 0'u32), finishedLoading)

  termWidth = iw.width(tb)
  termHeight = iw.height(tb)

  var content = ""
  for y in 0 ..< termHeight:
    var line = ""
    for x in 0 ..< termWidth:
      let
        fg = fgColorToVec4(tb[x, y], (230, 235, 255, 1.0))
        bg = bgColorToVec4(tb[x, y], (0, 0, 0, 0.0))
      line &= "<span style='color: rgba($1, $2, $3, $4); background-color: rgba($5, $6, $7, $8);'>".format(fg[0], fg[1], fg[2], fg[3], bg[0], bg[1], bg[2], bg[3]) & $tb[x, y].ch & "</span>"
    content &= "<div>" & line & "</div>"

  if content != lastContent:
    emscripten.setInnerHtml("#content", content)
    lastContent = content
