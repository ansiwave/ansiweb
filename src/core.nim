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

from wavecorepkg/client/emscripten import nil
from ansiwavepkg/ui/editor import nil

var
  clnt: client.Client
  session*: bbs.BbsSession
  keyQueue: Deque[(iw.Key, iw.MouseInfo)]
  charQueue: Deque[uint32]
  failAle*: bool

proc onKeyPress*(key: iw.Key) =
  keyQueue.addLast((key, iw.gMouseInfo))

proc onKeyRelease*(key: iw.Key) =
  discard

proc onChar*(codepoint: uint32) =
  charQueue.addLast(codepoint)

proc onMouseDown*(x: int, y: int) {.exportc.} =
  iw.gMouseInfo.button = iw.MouseButton.mbLeft
  iw.gMouseInfo.action = iw.MouseButtonAction.mbaPressed
  iw.gMouseInfo.x = x
  iw.gMouseInfo.y = y
  keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc onMouseMove*(x: int, y: int) {.exportc.} =
  iw.gMouseInfo.x = x
  iw.gMouseInfo.y = y
  if iw.gMouseInfo.action == iw.MouseButtonAction.mbaPressed and bbs.isEditor(session):
    keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc onMouseUp*(x: int, y: int) {.exportc.} =
  iw.gMouseInfo.button = iw.MouseButton.mbLeft
  iw.gMouseInfo.action = iw.MouseButtonAction.mbaReleased
  keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc onWindowResize*(windowWidth: int, windowHeight: int) =
  discard

proc hashChanged() {.exportc.} =
  bbs.insertHash(session, emscripten.getHash())

type
  Vec4 = tuple[r: int, g: int, b: int, a: float]

proc fgColorToVec4(ch: iw.TerminalChar, defaultColor: Vec4): Vec4 =
  result =
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
  if ch.cursor:
    result.a = 0.7

proc bgColorToVec4(ch: iw.TerminalChar, defaultColor: Vec4): Vec4 =
  result =
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
  if ch.cursor:
    result.a = 0.7

proc init*() =
  clnt = client.initClient(paths.address, paths.postAddress)
  client.start(clnt)

  bbs.init()

  var hash: Table[string, string]
  hash = editor.parseHash(emscripten.getHash())
  if "board" notin hash:
    hash["board"] = paths.defaultBoard

  session = bbs.initBbsSession(clnt, hash)

var lastTb: iw.TerminalBuffer

proc tick*() =
  var finishedLoading = false

  var
    tb: iw.TerminalBuffer
    termWidth = 84
    termHeight = int(emscripten.getClientHeight() / 20)

  if failAle:
    tb = iw.newTerminalBuffer(termWidth, termHeight)
    const lines = strutils.splitLines(staticRead("assets/failale.ansiwave"))
    var y = 0
    for line in lines:
      codes.write(tb, 0, y, line)
      y += 1
  else:
    var rendered = false
    while keyQueue.len > 0 or charQueue.len > 0:
      let
        (key, mouseInfo) = if keyQueue.len > 0: keyQueue.popFirst else: (iw.Key.None, iw.gMouseInfo)
        ch = if charQueue.len > 0 and key == iw.Key.None: charQueue.popFirst else: 0
      iw.gMouseInfo = mouseInfo
      tb = bbs.tick(session, clnt, termWidth, termHeight, (key, ch), finishedLoading)
      rendered = true
    if not rendered:
      tb = bbs.tick(session, clnt, termWidth, termHeight, (iw.Key.None, 0'u32), finishedLoading)

  termWidth = iw.width(tb)
  termHeight = iw.height(tb)

  if lastTb == nil or lastTb[] != tb[]:
    var content = ""
    for y in 0 ..< termHeight:
      var line = ""
      for x in 0 ..< termWidth:
        if cast[uint32](tb[x, y].ch) == 0:
          continue
        let
          fg = fgColorToVec4(tb[x, y], constants.textColor)
          bg = bgColorToVec4(tb[x, y], (0, 0, 0, 0.0))
        line &= "<span style='color: rgba($1, $2, $3, $4); background-color: rgba($5, $6, $7, $8);' onmousedown='mouseDown($9, $10)' onmousemove='mouseMove($9, $10)'>".format(fg[0], fg[1], fg[2], fg[3], bg[0], bg[1], bg[2], bg[3], x, y) & $tb[x, y].ch & "</span>"
      content &= "<div style='user-select: $1;'>".format(if bbs.isEditor(session): "none" else: "auto") & line & "</div>"
    emscripten.setInnerHtml("#content", content)
    lastTb = tb
