import deques
from wavecorepkg/paths import nil
from strutils import format
import tables

from illwave as iw import `[]`, `[]=`, `==`
from ansiwavepkg/bbs import nil
import unicode

from wavecorepkg/client import nil

from ansiwavepkg/ui/editor import nil

from times import nil
from os import nil
import pararules
import streams
from math import nil

from ansiwavepkg/chafa import nil
from ansiwavepkg/post import RefStrings
from ansiwavepkg/constants as waveconstants import editorWidth
from nimwave/tui/termtools/runewidth import nil

from nimwave/web import nil
from nimwave/web/emscripten as nw_emscripten import nil
from nimwave/tui import nil

from ./emscripten as aw_emscripten import nil
from ./html import nil

from ansiutils/cp437 import nil

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

proc charToHtml(ch: iw.TerminalChar, position: tuple[x: int, y: int] = (-1, -1)): string =
  if cast[uint32](ch.ch) == 0:
    return ""
  let
    fg = web.fgColorToString(ch)
    bg = web.bgColorToString(ch)
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
  let lines = tui.writeMaybe(lines)
  for line in lines:
    var htmlLine = ""
    for ch in line:
      htmlLine &= charToHtml(ch)
    if htmlLine == "":
      htmlLine = "<br />"
    result &= "<div>" & htmlLine & "</div>"
  result = "<span>" & result & "</span>"

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

proc onMouseUp*() {.exportc.} =
  iw.gMouseInfo.button = iw.MouseButton.mbLeft
  iw.gMouseInfo.action = iw.MouseButtonAction.mbaReleased
  keyQueue.addLast((iw.Key.Mouse, iw.gMouseInfo))

proc onWindowResize*(windowWidth: int, windowHeight: int) =
  discard

proc hashChanged() {.exportc.} =
  bbs.insertHash(session, nw_emscripten.getHash())

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
        cp437.write(ss, cp437.toUtf8(data, editorWidth), editorWidth)
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
  for line in ansiLines:
    post.add(newLines, line[])
  post.add(newLines, "")
  editor.insert(editorSession, buffer.id, editor.Lines, newLines)
  editorSession.fireRules
  if buffer.mode == 0:
    nw_emscripten.setInnerHtml("#editor", ansiToHtml(bbs.getEditorLines(session)))
    nw_emscripten.scrollDown("#editor")
  else:
    editor.insert(editorSession, buffer.id, editor.WrappedCursorY, newLines[].len)
  # sometimes the mouse can get "stuck" in the mousedown state due to the file dialog
  onMouseUp()

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

proc onScroll() {.exportc.} =
  updateCursor(aw_emscripten.getCursorLine("#editor"))
  let scrollTop = nw_emscripten.getScrollTop("#editor")
  updateScrollY(math.round(scrollTop.float / fontHeight.float).int)

proc init*() =
  clnt = client.initClient(paths.address, paths.postAddress)
  client.start(clnt)

  bbs.init()

  var hash: Table[string, string]
  hash = editor.parseHash(nw_emscripten.getHash())
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
    termHeight = int(nw_emscripten.getClientHeight() / fontHeight)

  if failAle:
    tb = iw.newTerminalBuffer(termWidth, termHeight)
    const lines = strutils.splitLines(staticRead("assets/failale.ansiwave"))
    var y = 0
    for line in lines:
      tui.write(tb, 0, y, line)
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
        onScroll()
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

  if isEditing != lastIsEditing:
    nw_emscripten.setDisplay("#editor", if isEditing: "block" else: "none")

  if isEditor:
    let
      (x, y, w, h) = bbs.getEditorSize(session)
      left = x.float * fontWidth
      top = y.float * fontHeight
      # subtract 2 because that's the width used by the text wrapping code,
      # and we want the built-in editor to wrap as similarly as possible
      width = (w - 2).float * fontWidth
      height = h.float * fontHeight
    nw_emscripten.setPosition("#editor", left.int32 - 1, top.int32 - 1)
    nw_emscripten.setSize("#editor", width.int32 + 1, height.int32 + 1)

    # no need to render the characters under the contenteditable editor
    # since they aren't visible anyway
    if isEditing:
      const ch = iw.TerminalChar(ch: " ".toRunes[0])
      for yy in y ..< y + h:
        for xx in x ..< x + w:
          tb[xx, yy] = ch

    if isEditing and not lastIsEditing:
      let s = ansiToHtml(bbs.getEditorLines(session))
      nw_emscripten.setInnerHtml("#editor", s)
      onScroll()
      nw_emscripten.focus("#editor")
      lastEditorContent = html.toAnsi(s)
    else:
      const saveCheckDelay = 0.25
      let ts = times.epochTime()
      if ts - lastSaveCheck >= saveCheckDelay:
        let content = html.toAnsi(nw_emscripten.getInnerHtml("#editor"))
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
    nw_emscripten.setInnerHtml("#content", content)
    lastTb = tb
