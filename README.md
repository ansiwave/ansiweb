To develop, [install Nim](https://nim-lang.org/install.html) and do:

```
nimble emscripten_dev
```

Or to make a release build:

```
nimble emscripten
```

NOTE: You must install Emscripten first:

```
git clone https://github.com/emscripten-core/emsdk
cd emsdk
./emsdk install latest
./emsdk activate latest
# add the dirs that are printed by the last command to your PATH
```
