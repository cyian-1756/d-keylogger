# d-keylogger
A x11 keylogger written in D


This program uses the x11 bindings to log key strokes on linux (And maybe other unix like OSs)

## Features

* Records the name of the window the keys were sent to

* Stores pressed keys in a buffer before writing to disk to help avoid detection

* Xor encryption of the keylogs both in memory and on disk

* Catches SIGTERM and SIGINT and writes the keylog to disk before exiting

## Build

Build with `dub build` 