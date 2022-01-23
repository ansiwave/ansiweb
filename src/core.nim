from ./constants import nil
import deques
from wavecorepkg/paths import nil
from strutils import format
import tables

from ansiwavepkg/bbs import nil
from ansiwavepkg/illwill as iw import `[]`, `[]=`
from ansiwavepkg/codes import stripCodes
import unicode

from wavecorepkg/client import nil
from terminal import nil

from wavecorepkg/client/emscripten import nil
from ansiwavepkg/ui/editor import nil
from ansiwavepkg/termtools/runewidth import nil

from htmlparser import nil
from xmltree import `$`, `[]`

from times import nil
from os import nil
import pararules
import streams
from math import nil

from ansiwavepkg/chafa import nil
from ansiwavepkg/ansi import nil
from ansiwavepkg/post import RefStrings
from ansiwavepkg/constants as waveconstants import editorWidth

const
  fontHeight = 20
  fontWidth = 10.81
  padding = "0.81"

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

proc fgColorToString(ch: iw.TerminalChar): string =
  var vec: Vec4
  vec =
    if ch.fgTruecolor != iw.rgbNone:
      let (r, g, b) = ch.fgTruecolor
      (r.int, g.int, b.int, 1.0)
    else:
      if terminal.styleBright in ch.style:
        case ch.fg:
        of iw.fgNone: return ""
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
        of iw.fgNone: return ""
        of iw.fgBlack: constants.blackColor
        of iw.fgRed: constants.redColor
        of iw.fgGreen: constants.greenColor
        of iw.fgYellow: constants.yellowColor
        of iw.fgBlue: constants.blueColor
        of iw.fgMagenta: constants.magentaColor
        of iw.fgCyan: constants.cyanColor
        of iw.fgWhite: constants.whiteColor
  if ch.cursor:
    vec.a = 0.7
  let (r, g, b, a) = vec
  "color: rgba($1, $2, $3, $4);".format(r, g, b, a)

proc bgColorToString(ch: iw.TerminalChar): string =
  var vec: Vec4
  vec =
    if ch.bgTruecolor != iw.rgbNone:
      let (r, g, b) = ch.bgTruecolor
      (r.int, g.int, b.int, 1.0)
    else:
      if terminal.styleBright in ch.style:
        case ch.bg:
        of iw.bgNone: return ""
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
        of iw.bgNone: return ""
        of iw.bgBlack: constants.blackColor
        of iw.bgRed: constants.redColor
        of iw.bgGreen: constants.greenColor
        of iw.bgYellow: constants.yellowColor
        of iw.bgBlue: constants.blueColor
        of iw.bgMagenta: constants.magentaColor
        of iw.bgCyan: constants.cyanColor
        of iw.bgWhite: constants.whiteColor
  if ch.cursor:
    vec.a = 0.7
  let (r, g, b, a) = vec
  "background-color: rgba($1, $2, $3, $4);".format(r, g, b, a)

proc parseRgb(rgb: string, output: var tuple[r: int, g: int, b: int]): bool =
  let parts = strutils.split(rgb, {'(', ')'})
  if parts.len >= 2:
    let
      cmd = strutils.strip(parts[0])
      args = strutils.strip(parts[1])
    if cmd == "rgba" or cmd == "rgb":
      let colors = strutils.split(args, ',')
      if colors.len >= 3:
        try:
          let
            r = strutils.parseInt(strutils.strip(colors[0]))
            g = strutils.parseInt(strutils.strip(colors[1]))
            b = strutils.parseInt(strutils.strip(colors[2]))
          output = (r, g, b)
          return true
        except Exception as ex:
          discard
  false

proc fgToAnsi(color: string): string =
  case color:
  of "black":
    "\e[30m"
  of "red":
    "\e[31m"
  of "green":
    "\e[32m"
  of "yellow":
    "\e[330m"
  of "blue":
    "\e[34m"
  of "magenta":
    "\e[35m"
  of "cyan":
    "\e[36m"
  of "white":
    "\e[37m"
  else:
    var rgb: tuple[r: int, g: int, b: int]
    if parseRgb(color, rgb):
      "\e[38;2;$1;$2;$3m".format(rgb[0], rgb[1], rgb[2])
    else:
      ""

proc bgToAnsi(color: string): string =
  case color:
  of "black":
    "\e[40m"
  of "red":
    "\e[41m"
  of "green":
    "\e[42m"
  of "yellow":
    "\e[43m"
  of "blue":
    "\e[44m"
  of "magenta":
    "\e[45m"
  of "cyan":
    "\e[46m"
  of "white":
    "\e[47m"
  else:
    var rgb: tuple[r: int, g: int, b: int]
    if parseRgb(color, rgb):
      "\e[48;2;$1;$2;$3m".format(rgb[0], rgb[1], rgb[2])
    else:
      ""

proc htmlToAnsi(node: xmltree.XmlNode): string =
  var
    fg: string
    bg: string
  case xmltree.kind(node):
  of xmltree.xnVerbatimText, xmltree.xnElement:
    case xmltree.tag(node):
    of "span":
      let
        style = xmltree.attr(node, "style")
        statements = strutils.split(style, ';')
      for statement in statements:
        let parts = strutils.split(statement, ':')
        if parts.len == 2:
          let
            key = strutils.strip(parts[0])
            val = strutils.strip(parts[1])
          if key == "color":
            fg = fgToAnsi(val)
          elif key == "background-color":
            bg = bgToAnsi(val)
    else:
      discard
  else:
    discard
  let colors = fg & bg
  if colors.len > 0:
    result &= colors
  for i in 0 ..< xmltree.len(node):
    result &= htmlToAnsi(node[i])
  if colors.len > 0:
    result &= "\e[0m"
  case xmltree.kind(node):
  of xmltree.xnText:
    result &= xmltree.innerText(node)
  of xmltree.xnVerbatimText, xmltree.xnElement:
    case xmltree.tag(node):
    of "div":
      result &= "\n"
    else:
      discard
  else:
    discard

proc htmlToAnsi(html: string): string =
  result = htmlToAnsi(htmlparser.parseHtml(html))
  if strutils.endsWith(result, "\n"):
    result = result[0 ..< result.len-1]

proc charToHtml(ch: iw.TerminalChar, position: tuple[x: int, y: int] = (-1, -1)): string =
  if cast[uint32](ch.ch) == 0:
    return ""
  let
    fg = fgColorToString(ch)
    bg = bgColorToString(ch)
    additionalStyles =
      if runewidth.runeWidth(ch.ch) == 2:
        # add some padding because double width characters are a little bit narrower
        # than two normal characters due to font differences
        "display: inline-block; max-width: $1px; padding-left: $2px; padding-right: $2px;".format(fontHeight, padding)
      else:
        ""
    mouseEvents =
      if position != (-1, -1):
        "onmousedown='mouseDown($1, $2)' onmousemove='mouseMove($1, $2)'".format(position.x, position.y)
      else:
        ""
  return "<span style='$1 $2 $3' $4>".format(fg, bg, additionalStyles, mouseEvents) & $ch.ch & "</span>"

proc ansiToHtml(lines: seq[ref string]): string =
  let lines = codes.writeMaybe(lines)
  for line in lines:
    var htmlLine = ""
    for ch in line:
      htmlLine &= charToHtml(ch)
    if htmlLine == "":
      htmlLine = "<br />"
    result &= "<div>" & htmlLine & "</div>"
  result = "<span>" & result & "</span>"

proc free(p: pointer) {.importc.}

proc insertFile(name: cstring, image: pointer, length: cint) {.exportc.} =
  var editorSession =
    try:
      bbs.getEditorSession(session)
    except Exception as ex:
      return
  let
    (_, _, ext) = os.splitFile($name)
    buffer = editor.getEditor(editorSession)
    data = block:
      var s = newSeq[uint8](length)
      copyMem(s[0].addr, image, length)
      free(image)
      cast[string](s)
  let content =
    case strutils.toLowerAscii(ext):
    of ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".psd":
      try:
        chafa.imageToAnsi(data, editorWidth)
      except Exception as ex:
        "Error reading image"
    of ".ans":
      try:
        var ss = newStringStream("")
        ansi.write(ss, ansi.ansiToUtf8(data, editorWidth), editorWidth)
        ss.setPosition(0)
        let s = ss.readAll()
        ss.close()
        s
      except Exception as ex:
        "Error reading file"
    else:
      if unicode.validateUtf8(data) != -1:
        "Error reading file"
      else:
        data
  let ansiLines = post.splitLines(content)[]
  var newLines: RefStrings
  new newLines
  newLines[] = buffer.lines[]
  if newLines[][newLines[].len-1][].stripCodes == "":
    discard newLines[].pop
  newLines[] &= ansiLines
  editor.insert(editorSession, buffer.id, editor.Lines, newLines)
  editorSession.fireRules
  if buffer.mode == 0:
    emscripten.setInnerHtml("#editor", ansiToHtml(bbs.getEditorLines(session)))
    emscripten.scrollDown("#editor")
  else:
    editor.insert(editorSession, buffer.id, editor.WrappedCursorY, newLines[].len)

proc onScrollDown() {.exportc.} =
  if bbs.isEditor(session):
    var editorSession =
      try:
        bbs.getEditorSession(session)
      except Exception as ex:
        return
    editor.scrollDown(editorSession)

proc onScrollUp() {.exportc.} =
  if bbs.isEditor(session):
    var editorSession =
      try:
        bbs.getEditorSession(session)
      except Exception as ex:
        return
    editor.scrollUp(editorSession)

proc updateCursor(line: int) =
  var editorSession =
    try:
      bbs.getEditorSession(session)
    except Exception as ex:
      return
  let buffer = editor.getEditor(editorSession)
  editor.insert(editorSession, buffer.id, editor.WrappedCursorY, line)
  editorSession.fireRules

proc updateScrollY(line: int) =
  var editorSession =
    try:
      bbs.getEditorSession(session)
    except Exception as ex:
      return
  let buffer = editor.getEditor(editorSession)
  editor.insert(editorSession, buffer.id, editor.ScrollY, line)
  editorSession.fireRules

proc onScroll(scrollTop: int) {.exportc.} =
  updateCursor(emscripten.getCursorLine("#editor"))
  updateScrollY(math.round(scrollTop.float / fontHeight.float).int)

proc init*() =
  clnt = client.initClient(paths.address, paths.postAddress)
  client.start(clnt)

  bbs.init()

  var hash: Table[string, string]
  hash = editor.parseHash(emscripten.getHash())
  if "board" notin hash:
    hash["board"] = paths.defaultBoard

  session = bbs.initBbsSession(clnt, hash)

var
  lastTb: iw.TerminalBuffer
  lastIsEditing: bool
  lastEditorContent: string
  lastSaveCheck: float

proc tick*() =
  var finishedLoading = false

  var
    tb: iw.TerminalBuffer
    termWidth = 84
    termHeight = int(emscripten.getClientHeight() / fontHeight)

  if failAle:
    tb = iw.newTerminalBuffer(termWidth, termHeight)
    const lines = strutils.splitLines(staticRead("assets/failale.ansiwave"))
    var y = 0
    for line in lines:
      codes.write(tb, 0, y, line)
      y += 1
  else:
    let
      isEditor = bbs.isEditor(session)
      isEditing = isEditor and bbs.isEditing(session)
    var rendered = false
    while keyQueue.len > 0 or charQueue.len > 0:
      let
        (key, mouseInfo) = if keyQueue.len > 0: keyQueue.popFirst else: (iw.Key.None, iw.gMouseInfo)
        ch = if charQueue.len > 0 and key == iw.Key.None: charQueue.popFirst else: 0
        input =
          if isEditing:
            # if we're editing, don't send any input to the editor besides ctrl shortcuts
            ((if key in {iw.Key.Mouse, iw.Key.Escape, iw.Key.Tab} or strutils.contains($key, "Ctrl"): key else: iw.Key.None), 0'u32)
          else:
            (key, ch)
      if isEditing and input[0] == iw.Key.Tab:
        updateCursor(emscripten.getCursorLine("#editor"))
      iw.gMouseInfo = mouseInfo
      tb = bbs.tick(session, clnt, termWidth, termHeight, input, finishedLoading)
      rendered = true
    if not rendered:
      tb = bbs.tick(session, clnt, termWidth, termHeight, (iw.Key.None, 0'u32), finishedLoading)

  termWidth = iw.width(tb)
  termHeight = iw.height(tb)

  let
    isEditor = bbs.isEditor(session)
    isEditing = isEditor and bbs.isEditing(session)

  emscripten.setDisplay("#editor", if isEditing: "block" else: "none")

  if isEditor:
    let
      (x, y, w, h) = bbs.getEditorSize(session)
      left = x.float * fontWidth
      top = y.float * fontHeight
      width = w.float * fontWidth
      height = h.float * fontHeight
    emscripten.setLocation("#editor", left.int32 - 1, top.int32 - 1)
    emscripten.setSize("#editor", width.int32 + 1, height.int32 + 1)

    if isEditing and not lastIsEditing:
      let html = ansiToHtml(bbs.getEditorLines(session))
      emscripten.setInnerHtml("#editor", html)
      emscripten.focus("#editor")
      lastEditorContent = htmlToAnsi(html)
    else:
      const saveCheckDelay = 0.25
      let ts = times.epochTime()
      if ts - lastSaveCheck >= saveCheckDelay:
        let content = htmlToAnsi(emscripten.getInnerHtml("#editor"))
        if content != lastEditorContent:
          bbs.setEditorContent(session, content)
          lastEditorContent = content
        lastSaveCheck = ts

    lastIsEditing = isEditing

  if lastTb == nil or lastTb[] != tb[]:
    var content = ""
    for y in 0 ..< termHeight:
      var line = ""
      for x in 0 ..< termWidth:
        line &= charToHtml(tb[x, y], (x, y))
      content &= "<div style='user-select: $1;'>".format(if isEditor: "none" else: "auto") & line & "</div>"
    emscripten.setInnerHtml("#content", content)
    lastTb = tb
