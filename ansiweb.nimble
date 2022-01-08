# Package

version       = "0.1.0"
author        = "FIXME"
description   = "FIXME"
license       = "FIXME"
srcDir        = "src"
bin           = @["ansiweb"]

task dev, "Run dev version":
  exec "nimble run ansiweb"

task emscripten_dev, "Build the emscripten dev version":
  exec "nimble build"
  exec "nimble build -d:emscripten_worker"

task emscripten, "Build the emscripten release version":
  exec "nimble build -d:release"
  exec "nimble build -d:release -d:emscripten_worker"

# Dependencies

requires "nim >= 1.2.6"
requires "ansiwave >= 1.3.3"
